import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/presentation/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

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

    // Register the credentials provider
    getIt.registerLazySingleton<AuthCredentialsProvider>(
      () => SecureStorageAuthCredentialsProvider(
        secureStorage: getIt<FlutterSecureStorage>(),
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
      ),
      instanceName: 'authenticatedDio',
    );

    // Register the auth service implementation
    getIt.registerLazySingleton<AuthService>(
      () => AuthServiceImpl(
        apiClient: getIt<AuthApiClient>(),
        credentialsProvider: getIt<AuthCredentialsProvider>(),
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
