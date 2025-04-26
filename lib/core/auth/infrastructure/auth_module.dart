import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/secure_storage_auth_session_provider.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Authentication module for dependency injection setup using explicit dependencies.
///
/// Encapsulates the configuration of authentication-related services.
/// Instances of this class are responsible for registering services into a GetIt
/// container using provided dependencies.
///
/// IMPORTANT: The registration order in this module is critical to avoid circular
/// dependencies. The current design uses a function-based DI approach for token refresh,
/// allowing AuthApiClient to be used with basicDio while authenticatedDio uses
/// AuthInterceptor with a function reference to the AuthApiClient's refreshToken method.
class AuthModule {
  final DioFactory _dioFactory;
  final AuthCredentialsProvider _credentialsProvider;
  final AuthEventBus _authEventBus;

  /// Logger for AuthModule instances
  final _logger = LoggerFactory.getLogger('AuthModule');
  final _tag = logTag('AuthModule');

  /// Creates an AuthModule instance with explicitly provided dependencies.
  AuthModule({
    required DioFactory dioFactory,
    required AuthCredentialsProvider credentialsProvider,
    required AuthEventBus authEventBus,
  }) : _dioFactory = dioFactory,
       _credentialsProvider = credentialsProvider,
       _authEventBus = authEventBus;

  /// Registers authentication services with the provided GetIt instance using
  /// the dependencies provided during construction. This avoids implicit lookups
  /// and ensures testability.
  ///
  /// The registration order is important to avoid circular dependencies:
  /// 1. First register basicDio
  /// 2. Then register AuthApiClient (using basicDio)
  /// 3. Then register authenticatedDio (using AuthApiClient for token refresh via function reference)
  ///
  /// Optional dependencies like FlutterSecureStorage, JwtValidator, and
  /// AuthSessionProvider can still be passed to override default registrations,
  /// but the core dependencies (`DioFactory`, `AuthCredentialsProvider`,
  /// `AuthEventBus`) are taken from the instance fields.
  void register(
    GetIt getIt, {
    // Core dependencies are now instance fields, removed from parameters
    // Optional explicit dependencies (will register defaults if not provided and not already in GetIt)
    FlutterSecureStorage? secureStorage,
    JwtValidator? jwtValidator,
    AuthSessionProvider? authSessionProvider,
  }) {
    _logger.i(
      '$_tag Registering auth module components via instance method...',
    );
    _logger.d('$_tag Using internal dioFactory: $_dioFactory');
    _logger.d(
      '$_tag Using internal credentialsProvider: $_credentialsProvider',
    );
    _logger.d('$_tag Using internal authEventBus: $_authEventBus');

    // Register FlutterSecureStorage if not provided and not already registered
    if (secureStorage == null && !getIt.isRegistered<FlutterSecureStorage>()) {
      getIt.registerLazySingleton<FlutterSecureStorage>(
        () => const FlutterSecureStorage(),
      );
      _logger.d('$_tag Registered default FlutterSecureStorage.');
    } else if (secureStorage != null &&
        !getIt.isRegistered<FlutterSecureStorage>()) {
      // If provided but not registered, register the provided one
      getIt.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);
      _logger.d('$_tag Registered provided FlutterSecureStorage.');
    } else {
      _logger.d(
        '$_tag Using ${secureStorage != null ? 'provided' : 'existing'} FlutterSecureStorage.',
      );
    }
    // Resolve the instance to be used downstream (might be provided, existing, or newly registered)
    // final FlutterSecureStorage finalSecureStorage =
    //     secureStorage ?? getIt<FlutterSecureStorage>(); // Removed as unused

    // Register JwtValidator if not provided and not already registered
    if (jwtValidator == null && !getIt.isRegistered<JwtValidator>()) {
      getIt.registerLazySingleton<JwtValidator>(() => JwtValidator());
      _logger.d('$_tag Registered default JwtValidator.');
    } else if (jwtValidator != null && !getIt.isRegistered<JwtValidator>()) {
      getIt.registerLazySingleton<JwtValidator>(() => jwtValidator);
      _logger.d('$_tag Registered provided JwtValidator.');
    } else {
      _logger.d(
        '$_tag Using ${jwtValidator != null ? 'provided' : 'existing'} JwtValidator.',
      );
    }
    // Resolve the instance to be used downstream
    // final JwtValidator finalJwtValidator =
    //     jwtValidator ?? getIt<JwtValidator>(); // Removed as unused

    // Use the constructor-provided instance for AuthCredentialsProvider
    _logger.d('$_tag Using constructor-provided AuthCredentialsProvider.');
    final AuthCredentialsProvider finalCredentialsProvider =
        _credentialsProvider;

    // STEP 1: Register basic Dio (using the constructor-provided factory instance)
    // This must be registered before AuthApiClient
    if (!getIt.isRegistered<Dio>(instanceName: 'basicDio')) {
      getIt.registerLazySingleton<Dio>(
        () => _dioFactory.createBasicDio(), // Use instance field
        instanceName: 'basicDio',
      );
      _logger.d('$_tag Registered basicDio.');
    } else {
      _logger.i('$_tag basicDio already registered. Skipping registration.');
    }

    // STEP 2: Register the auth API client (depends on basicDio)
    // This must be registered BEFORE authenticatedDio to break the circular dependency
    if (!getIt.isRegistered<AuthApiClient>()) {
      getIt.registerLazySingleton<AuthApiClient>(
        () => AuthApiClient(
          httpClient: getIt<Dio>(instanceName: 'basicDio'),
          credentialsProvider:
              finalCredentialsProvider, // Use instance field via variable
        ),
      );
      _logger.d('$_tag Registered AuthApiClient with basicDio.');
    } else {
      _logger.i(
        '$_tag AuthApiClient already registered. Skipping registration.',
      );
    }

    // Use the constructor-provided instance for AuthEventBus
    _logger.d('$_tag Using constructor-provided AuthEventBus.');
    final AuthEventBus finalAuthEventBus = _authEventBus;

    // STEP 3: Register the authenticated Dio client
    // This must be registered AFTER AuthApiClient since it depends on it for the refreshToken function
    if (!getIt.isRegistered<Dio>(instanceName: 'authenticatedDio')) {
      _logger.d(
        '$_tag About to create authenticatedDio via createAuthenticatedDio...',
      );
      _logger.d('$_tag AuthApiClient to be passed: ${getIt<AuthApiClient>()}');
      _logger.d(
        '$_tag CredentialsProvider to be passed: $finalCredentialsProvider',
      );
      _logger.d('$_tag AuthEventBus to be passed: $finalAuthEventBus');

      getIt.registerLazySingleton<Dio>(() {
        _logger.d('$_tag Inside factory function for authenticatedDio...');
        final authenticatedDio = _dioFactory.createAuthenticatedDio(
          authApiClient:
              getIt<AuthApiClient>(), // Depends on registered/existing
          credentialsProvider:
              finalCredentialsProvider, // Use instance field via variable
          authEventBus: finalAuthEventBus, // Use instance field via variable
        );
        _logger.d(
          '$_tag Successfully created authenticatedDio: $authenticatedDio',
        );
        return authenticatedDio;
      }, instanceName: 'authenticatedDio');
      _logger.d('$_tag Registered authenticatedDio.');
    } else {
      _logger.i(
        '$_tag authenticatedDio already registered. Skipping registration.',
      );
    }

    // Register the auth service implementation (depends on apiClient, provider, eventBus from instance fields)
    if (!getIt.isRegistered<AuthService>()) {
      _logger.d('$_tag Registering AuthServiceImpl');
      getIt.registerLazySingleton<AuthService>(
        () => AuthServiceImpl(
          apiClient: getIt<AuthApiClient>(), // Depends on registered/existing
          credentialsProvider:
              finalCredentialsProvider, // Use instance field via variable
          eventBus: finalAuthEventBus, // Use instance field via variable
        ),
      );
    } else {
      _logger.i('$_tag AuthService already registered. Skipping registration.');
    }

    // Register AuthSessionProvider using the constructor-provided credentialsProvider
    if (authSessionProvider == null &&
        !getIt.isRegistered<AuthSessionProvider>()) {
      _logger.d(
        '$_tag Registering default SecureStorageAuthSessionProvider as AuthSessionProvider',
      );
      getIt.registerLazySingleton<AuthSessionProvider>(
        () => SecureStorageAuthSessionProvider(
          credentialsProvider:
              finalCredentialsProvider, // Use instance field via variable
        ),
      );
    } else if (authSessionProvider != null &&
        !getIt.isRegistered<AuthSessionProvider>()) {
      _logger.d('$_tag Registering provided AuthSessionProvider');
      getIt.registerLazySingleton<AuthSessionProvider>(
        () => authSessionProvider,
      );
    } else {
      _logger.d(
        '$_tag Using ${authSessionProvider != null ? 'provided' : 'existing'} AuthSessionProvider.',
      );
    }
    // Resolve the instance to be used downstream
    // final AuthSessionProvider finalAuthSessionProvider =
    //     authSessionProvider ?? getIt<AuthSessionProvider>(); // Removed as unused
    _logger.d(
      '$_tag Final AuthSessionProvider instance resolved.',
    ); // Added log
  }

  // Static method remains for Riverpod compatibility for now, but doesn't use instance state
  // Consider refactoring Riverpod setup later if needed.
  /// Configures Riverpod providers for auth state management
  static List<Override> providerOverrides(GetIt getIt) {
    return [
      // Override the auth service provider with the implementation from GetIt
      authServiceProvider.overrideWithValue(getIt<AuthService>()),
    ];
  }
}
