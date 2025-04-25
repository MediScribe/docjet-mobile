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
class AuthModule {
  /// Logger for AuthModule instances
  final _logger = LoggerFactory.getLogger('AuthModule');
  final _tag = logTag('AuthModule');

  /// Registers authentication services with the provided GetIt instance using
  /// explicitly passed dependencies. This avoids implicit lookups and ensures
  /// testability by allowing direct injection of mocks or specific implementations.
  ///
  /// Dependencies like AuthCredentialsProvider and AuthSessionProvider are expected
  /// to be pre-registered in GetIt *before* calling this method if specific
  /// instances (like mocks) are required. Otherwise, default implementations
  /// will be registered if they are not already present.
  void register(
    GetIt getIt, {
    // Explicit dependencies needed for registration logic
    required DioFactory dioFactory,
    required AuthCredentialsProvider credentialsProvider,
    required AuthEventBus authEventBus,
    // Optional explicit dependencies (will register defaults if not provided and not already in GetIt)
    FlutterSecureStorage? secureStorage,
    JwtValidator? jwtValidator,
    AuthSessionProvider? authSessionProvider,
  }) {
    _logger.i(
      '$_tag Registering auth module components via instance method...',
    );

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
    final FlutterSecureStorage finalSecureStorage =
        secureStorage ?? getIt<FlutterSecureStorage>();

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
    final JwtValidator finalJwtValidator =
        jwtValidator ?? getIt<JwtValidator>();

    // Ensure AuthCredentialsProvider is registered (uses the provided one)
    // Note: We assume the caller registers the *correct* provider (real or mock) beforehand.
    // This method now only uses the provided instance.
    _logger.d('$_tag Using provided AuthCredentialsProvider.');

    // Register basic Dio (using the provided factory instance)
    if (!getIt.isRegistered<Dio>(instanceName: 'basicDio')) {
      getIt.registerLazySingleton<Dio>(
        () => dioFactory.createBasicDio(), // Use instance method
        instanceName: 'basicDio',
      );
      _logger.d('$_tag Registered basicDio.');
    } else {
      _logger.i('$_tag basicDio already registered. Skipping registration.');
    }

    // Register the auth API client (depends on basicDio and provided credentialsProvider)
    if (!getIt.isRegistered<AuthApiClient>()) {
      getIt.registerLazySingleton<AuthApiClient>(
        () => AuthApiClient(
          httpClient: getIt<Dio>(instanceName: 'basicDio'),
          credentialsProvider: credentialsProvider, // Use provided instance
        ),
      );
      _logger.d('$_tag Registered AuthApiClient.');
    } else {
      _logger.i(
        '$_tag AuthApiClient already registered. Skipping registration.',
      );
    }

    // Ensure AuthEventBus is registered (uses the provided one)
    _logger.d('$_tag Using provided AuthEventBus.');

    // Register the authenticated Dio client (using provided dependencies)
    if (!getIt.isRegistered<Dio>(instanceName: 'authenticatedDio')) {
      getIt.registerLazySingleton<Dio>(
        () => dioFactory.createAuthenticatedDio(
          authApiClient:
              getIt<
                AuthApiClient
              >(), // Depends on the one just registered/existing
          credentialsProvider: credentialsProvider, // Use provided instance
          authEventBus: authEventBus, // Use provided instance
        ),
        instanceName: 'authenticatedDio',
      );
      _logger.d('$_tag Registered authenticatedDio.');
    } else {
      _logger.i(
        '$_tag authenticatedDio already registered. Skipping registration.',
      );
    }

    // Register the auth service implementation (depends on apiClient, provider, eventBus)
    if (!getIt.isRegistered<AuthService>()) {
      _logger.d('$_tag Registering AuthServiceImpl');
      getIt.registerLazySingleton<AuthService>(
        () => AuthServiceImpl(
          apiClient: getIt<AuthApiClient>(), // Depends on registered/existing
          credentialsProvider: credentialsProvider, // Use provided instance
          eventBus: authEventBus, // Use provided instance
        ),
      );
    } else {
      _logger.i('$_tag AuthService already registered. Skipping registration.');
    }

    // Register AuthSessionProvider if not provided and not already registered
    if (authSessionProvider == null &&
        !getIt.isRegistered<AuthSessionProvider>()) {
      _logger.d(
        '$_tag Registering default SecureStorageAuthSessionProvider as AuthSessionProvider',
      );
      getIt.registerLazySingleton<AuthSessionProvider>(
        () => SecureStorageAuthSessionProvider(
          credentialsProvider: credentialsProvider, // Use provided instance
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
    final AuthSessionProvider finalAuthSessionProvider =
        authSessionProvider ?? getIt<AuthSessionProvider>();
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
