import 'package:dio/dio.dart';
import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/auth_service.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_api_client.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_module.dart';
import 'package:docjet_mobile/core/auth/infrastructure/auth_service_impl.dart';
import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  late GetIt getIt;

  setUp(() {
    // Create a new GetIt instance for each test
    getIt = GetIt.asNewInstance();
  });

  tearDown(() async {
    // Reset GetIt after each test
    await getIt.reset();
  });

  group('AuthModule', () {
    test('should register all dependencies correctly', () {
      // Act
      AuthModule.register(getIt);

      // Assert
      expect(getIt.isRegistered<FlutterSecureStorage>(), isTrue);
      expect(getIt.isRegistered<AuthCredentialsProvider>(), isTrue);
      expect(getIt.isRegistered<AuthApiClient>(), isTrue);
      expect(getIt.isRegistered<AuthService>(), isTrue);
      expect(getIt.isRegistered<Dio>(instanceName: 'basicDio'), isTrue);
      expect(getIt.isRegistered<Dio>(instanceName: 'authenticatedDio'), isTrue);
    });

    test('should resolve dependencies with correct types', () {
      // Arrange
      AuthModule.register(getIt);

      // Act & Assert
      expect(
        getIt<AuthCredentialsProvider>(),
        isA<SecureStorageAuthCredentialsProvider>(),
      );
      expect(getIt<AuthService>(), isA<AuthServiceImpl>());
      expect(getIt<Dio>(instanceName: 'basicDio'), isA<Dio>());
      expect(getIt<Dio>(instanceName: 'authenticatedDio'), isA<Dio>());
    });

    test('should create provider overrides', () {
      // Arrange
      AuthModule.register(getIt);

      // Act
      final overrides = AuthModule.providerOverrides(getIt);

      // Assert
      expect(overrides, isA<List<Override>>());
      expect(overrides.length, 1); // One override for authServiceProvider
    });
  });
}
