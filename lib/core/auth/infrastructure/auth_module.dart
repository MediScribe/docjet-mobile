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

/// Authentication module for dependency injection setup
///
/// Encapsulates the configuration of authentication-related services.
class AuthModule {
  /// Registers authentication services with GetIt
  static void register(GetIt getIt) {
    // Register the secure storage
    getIt.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    );

    // Register the JWT Validator
    getIt.registerLazySingleton<JwtValidator>(() => JwtValidator());

    // Register the credentials provider
    getIt.registerLazySingleton<AuthCredentialsProvider>(
      () => SecureStorageAuthCredentialsProvider(
        secureStorage: getIt<FlutterSecureStorage>(),
        jwtValidator: getIt<JwtValidator>(),
      ),
    );

    // Register the basic Dio client (for auth only)
    getIt.registerLazySingleton<Dio>(
      () => DioFactory.createBasicDio(),
      instanceName: 'basicDio',
    );

    // Register the auth API client
    getIt.registerLazySingleton<AuthApiClient>(
      () => AuthApiClient(
        httpClient: getIt<Dio>(instanceName: 'basicDio'),
        credentialsProvider: getIt<AuthCredentialsProvider>(),
      ),
    );

    // Register the authenticated Dio client (with auth interceptor)
    getIt.registerLazySingleton<Dio>(
      () => DioFactory.createAuthenticatedDio(
        authApiClient: getIt<AuthApiClient>(),
        credentialsProvider: getIt<AuthCredentialsProvider>(),
        authEventBus: getIt<AuthEventBus>(),
      ),
      instanceName: 'authenticatedDio',
    );

    // Register the auth service implementation
    getIt.registerLazySingleton<AuthService>(
      () => AuthServiceImpl(
        apiClient: getIt<AuthApiClient>(),
        credentialsProvider: getIt<AuthCredentialsProvider>(),
        eventBus: getIt<AuthEventBus>(),
      ),
    );
  }

  /// Configures Riverpod providers for auth state management
  static List<Override> providerOverrides(GetIt getIt) {
    return [
      // Override the auth service provider with the implementation from GetIt
      authServiceProvider.overrideWithValue(getIt<AuthService>()),
    ];
  }
}
