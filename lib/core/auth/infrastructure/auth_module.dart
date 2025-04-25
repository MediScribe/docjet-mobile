import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/interfaces/app_config_interface.dart';
import 'package:docjet_mobile/core/auth/auth_session_provider.dart';
import 'package:docjet_mobile/core/auth/infrastructure/secure_storage_auth_session_provider.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Authentication module for dependency injection setup
///
/// Encapsulates the configuration of authentication-related services.
class AuthModule {
  /// Static logger for AuthModule
  static final _logger = LoggerFactory.getLogger('AuthModule');
  static final _tag = logTag('AuthModule');

  /// Registers authentication services with GetIt
  ///
  /// If mockAppConfig is provided, it will be used instead of attempting to get
  /// the AppConfig from GetIt. This is useful for testing.
  static void register(GetIt getIt, {AppConfigInterface? mockAppConfig}) {
    _logger.i('$_tag Registering auth module components...');

    // *** Instantiate DioFactory if testing with mock, otherwise use the one from GetIt ***
    final DioFactory dioFactory =
        mockAppConfig != null
            ? DioFactory(
              appConfig: mockAppConfig,
            ) // Create local factory for mock test
            : getIt<DioFactory>(); // Use the globally registered factory

    _logger.d(
      '$_tag Using ${mockAppConfig != null ? 'LOCAL' : 'GLOBAL'} DioFactory instance${mockAppConfig != null ? ' with mock AppConfig' : ''}',
    );

    // Register the secure storage
    if (!getIt.isRegistered<FlutterSecureStorage>()) {
      getIt.registerLazySingleton<FlutterSecureStorage>(
        () => const FlutterSecureStorage(),
      );
    }

    // Register the JWT Validator
    if (!getIt.isRegistered<JwtValidator>()) {
      getIt.registerLazySingleton<JwtValidator>(() => JwtValidator());
    }

    // Register the credentials provider
    if (!getIt.isRegistered<AuthCredentialsProvider>()) {
      getIt.registerLazySingleton<AuthCredentialsProvider>(
        () => SecureStorageAuthCredentialsProvider(
          secureStorage: getIt<FlutterSecureStorage>(),
          jwtValidator: getIt<JwtValidator>(),
        ),
      );
    }

    // Register basic Dio (using the determined factory instance)
    if (!getIt.isRegistered<Dio>(instanceName: 'basicDio')) {
      getIt.registerLazySingleton<Dio>(
        () => dioFactory.createBasicDio(), // Use instance method
        instanceName: 'basicDio',
      );
    }

    // Register the auth API client
    if (!getIt.isRegistered<AuthApiClient>()) {
      getIt.registerLazySingleton<AuthApiClient>(
        () => AuthApiClient(
          httpClient: getIt<Dio>(instanceName: 'basicDio'),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
        ),
      );
    }

    // Register the authenticated Dio client (using the determined factory instance)
    if (!getIt.isRegistered<Dio>(instanceName: 'authenticatedDio')) {
      // Make sure AuthEventBus is registered
      if (!getIt.isRegistered<AuthEventBus>()) {
        getIt.registerLazySingleton<AuthEventBus>(() => AuthEventBus());
      }

      getIt.registerLazySingleton<Dio>(
        () => dioFactory.createAuthenticatedDio(
          // Use instance method
          authApiClient: getIt<AuthApiClient>(),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
          authEventBus: getIt<AuthEventBus>(),
        ),
        instanceName: 'authenticatedDio',
      );
    }

    // Register the auth service implementation
    if (!getIt.isRegistered<AuthService>()) {
      _logger.d('$_tag Registering AuthServiceImpl');
      getIt.registerLazySingleton<AuthService>(
        () => AuthServiceImpl(
          apiClient: getIt<AuthApiClient>(),
          credentialsProvider: getIt<AuthCredentialsProvider>(),
          eventBus: getIt<AuthEventBus>(),
        ),
      );
    } else {
      _logger.i('$_tag AuthService already registered. Skipping registration.');
    }

    // Register AuthSessionProvider if needed
    if (!getIt.isRegistered<AuthSessionProvider>()) {
      _logger.d(
        '$_tag Registering SecureStorageAuthSessionProvider as AuthSessionProvider',
      );
      getIt.registerLazySingleton<AuthSessionProvider>(
        () => SecureStorageAuthSessionProvider(
          credentialsProvider: getIt<AuthCredentialsProvider>(),
        ),
      );
    } else {
      // Add debug log about existing registration
      _logger.i(
        '$_tag AuthSessionProvider already registered (likely by a test). Skipping registration.',
      );
    }
  }

  /// Configures Riverpod providers for auth state management
  static List<Override> providerOverrides(GetIt getIt) {
    return [
      // Override the auth service provider with the implementation from GetIt
      authServiceProvider.overrideWithValue(getIt<AuthService>()),
    ];
  }
}
