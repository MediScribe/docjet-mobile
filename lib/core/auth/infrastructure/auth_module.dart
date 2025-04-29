import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/data/repositories/shared_preferences_user_profile_cache.dart';
import 'package:docjet_mobile/core/auth/domain/repositories/i_user_profile_cache.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/authentication_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/user/infrastructure/user_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/secure_storage_auth_session_provider.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication module for dependency injection setup using explicit dependencies.
///
/// Encapsulates the configuration of authentication-related services.
/// Instances of this class are responsible for registering services into a GetIt
/// container using provided dependencies.
///
/// IMPORTANT: The registration order in this module is critical to avoid circular
/// dependencies. The current design uses a function-based DI approach for token refresh,
/// allowing AuthenticationApiClient to be used with basicDio while authenticatedDio uses
/// AuthInterceptor with a function reference to the AuthenticationApiClient's refreshToken method.
///
/// The module uses a "Split Client" pattern where:
/// - AuthenticationApiClient: Handles login/refresh with basicDio
/// - UserApiClient: Handles user profile with authenticatedDio
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
  /// 2. Then register AuthenticationApiClient (using basicDio)
  /// 3. Then register UserApiClient (using authenticatedDio)
  /// 4. Then register authenticatedDio (using AuthenticationApiClient for token refresh via function reference)
  /// 5. Finally, register shared services like SharedPreferences, IUserProfileCache, AuthService, etc.
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
    // Added optional dependency for SharedPreferences for testing flexibility
    SharedPreferences? sharedPreferences,
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

    // Register SharedPreferences if not provided and not already registered
    // We use registerSingletonAsync for SharedPreferences.getInstance()
    if (sharedPreferences == null && !getIt.isRegistered<SharedPreferences>()) {
      _logger.d('$_tag Registering default SharedPreferences asynchronously.');
      getIt.registerSingletonAsync<SharedPreferences>(() async {
        _logger.d('$_tag SharedPreferences factory: calling getInstance().');
        final prefs = await SharedPreferences.getInstance();
        _logger.d('$_tag SharedPreferences factory: getInstance() completed.');
        return prefs;
      });
      // Ensure dependent registrations wait for SharedPreferences
      // getIt.isReady<SharedPreferences>(); // Consider if needed based on usage pattern
    } else if (sharedPreferences != null &&
        !getIt.isRegistered<SharedPreferences>()) {
      // If provided but not registered, register the provided one (synchronously)
      _logger.d('$_tag Registered provided SharedPreferences.');
      getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
    } else {
      _logger.d(
        '$_tag Using ${sharedPreferences != null ? 'provided' : 'existing'} SharedPreferences.',
      );
    }
    // Note: Downstream dependencies need to 'await getIt.isReady<SharedPreferences>()'
    // OR ensure SharedPreferences is ready before they are first accessed if using async registration.
    // Lazy singletons depending on it might need adjustment if immediate access is required.

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

    // STEP 2: Register the AuthenticationApiClient (depends on basicDio)
    // This must be registered BEFORE authenticatedDio to break the circular dependency
    if (!getIt.isRegistered<AuthenticationApiClient>()) {
      getIt.registerLazySingleton<AuthenticationApiClient>(
        () => AuthenticationApiClient(
          basicHttpClient: getIt<Dio>(instanceName: 'basicDio'),
          credentialsProvider:
              finalCredentialsProvider, // Use instance field via variable
        ),
      );
      _logger.d('$_tag Registered AuthenticationApiClient with basicDio.');
    } else {
      _logger.i(
        '$_tag AuthenticationApiClient already registered. Skipping registration.',
      );
    }

    // Use the constructor-provided instance for AuthEventBus
    _logger.d('$_tag Using constructor-provided AuthEventBus.');
    final AuthEventBus finalAuthEventBus = _authEventBus;

    // STEP 3: Register the authenticated Dio client
    // This must be registered AFTER AuthenticationApiClient since it depends on it for the refreshToken function
    if (!getIt.isRegistered<Dio>(instanceName: 'authenticatedDio')) {
      _logger.d(
        '$_tag About to create authenticatedDio via createAuthenticatedDio...',
      );
      _logger.d(
        '$_tag AuthenticationApiClient to be passed: ${getIt<AuthenticationApiClient>()}',
      );
      _logger.d(
        '$_tag CredentialsProvider to be passed: $finalCredentialsProvider',
      );
      _logger.d('$_tag AuthEventBus to be passed: $finalAuthEventBus');

      getIt.registerLazySingleton<Dio>(() {
        _logger.d('$_tag Inside factory function for authenticatedDio...');
        final authenticatedDio = _dioFactory.createAuthenticatedDio(
          authApiClient:
              getIt<AuthenticationApiClient>(), // Use the new client class
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

    // STEP 4: Register UserApiClient (depends on authenticatedDio)
    if (!getIt.isRegistered<UserApiClient>()) {
      getIt.registerLazySingleton<UserApiClient>(
        () => UserApiClient(
          authenticatedHttpClient: getIt<Dio>(instanceName: 'authenticatedDio'),
          credentialsProvider: finalCredentialsProvider,
        ),
      );
      _logger.d('$_tag Registered UserApiClient with authenticatedDio.');
    } else {
      _logger.i(
        '$_tag UserApiClient already registered. Skipping registration.',
      );
    }

    // STEP 5: Register shared services

    // Register the User Profile Cache implementation
    // Depends on SharedPreferences, so it must be registered asynchronously.
    if (!getIt.isRegistered<IUserProfileCache>()) {
      _logger.d(
        '$_tag Registering SharedPreferencesUserProfileCache as IUserProfileCache asynchronously',
      );
      // Use registerSingletonAsync because it depends on async SharedPreferences
      getIt.registerSingletonAsync<IUserProfileCache>(
        () async {
          // Logger retrieval is safe
          final cacheLogger = LoggerFactory.getLogger(
            'SharedPreferencesUserProfileCache',
          );

          // Since dependsOn is used, SharedPreferences *should* be ready.
          // A final check can remain if paranoia is high, but getIt manages the dependency wait.
          final prefs = getIt<SharedPreferences>();

          // Provide SharedPreferences and a Logger instance
          return SharedPreferencesUserProfileCache(prefs, cacheLogger);
        },
        dependsOn: [SharedPreferences],
      ); // <-- Use dependsOn with async registration
    } else {
      _logger.i(
        '$_tag IUserProfileCache already registered. Skipping registration.',
      );
    }

    // Register the auth service implementation
    // Depends on IUserProfileCache (which is now async), so this must also be async.
    if (!getIt.isRegistered<AuthService>()) {
      _logger.d('$_tag Registering AuthServiceImpl asynchronously');
      // Use registerSingletonAsync because it depends on async IUserProfileCache
      getIt.registerSingletonAsync<AuthService>(
        () async {
          // All synchronous dependencies can be resolved directly
          final authApiClient = getIt<AuthenticationApiClient>();
          final userApiClient = getIt<UserApiClient>();
          final credProvider = finalCredentialsProvider;
          final bus = finalAuthEventBus;

          // Asynchronous dependency must be awaited if needed inside factory,
          // but here we just need the instance passed to the constructor.
          // getIt handles the wait via dependsOn.
          final cache = getIt<IUserProfileCache>();

          return AuthServiceImpl(
            authenticationApiClient: authApiClient,
            userApiClient: userApiClient,
            credentialsProvider: credProvider,
            eventBus: bus,
            userProfileCache: cache, // Inject the cache instance
          );
        },
        dependsOn: [IUserProfileCache], // <-- Wait for the cache to be ready
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
