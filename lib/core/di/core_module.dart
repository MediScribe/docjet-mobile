import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:docjet_mobile/core/auth/secure_storage_auth_credentials_provider.dart';
import 'package:docjet_mobile/core/interfaces/network_info.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:docjet_mobile/core/auth/auth_credentials_provider.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart';
import 'package:docjet_mobile/core/auth/infrastructure/dio_factory.dart';
import 'package:docjet_mobile/core/auth/utils/jwt_validator.dart';
import 'package:docjet_mobile/core/config/app_config.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/network_info_impl.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Registers core infrastructure and utility dependencies.
///
/// This module handles the registration of singleton dependencies that are
/// fundamental to the application's operation but are not specific to any
/// particular feature. It assumes that `AppConfig` and potentially `HiveInterface`
/// (if needed directly by a registration here) have already been registered.
class CoreModule {
  /// Registers all dependencies provided by this module.
  ///
  /// Requires an instance of [GetIt] to register the dependencies.
  Future<void> register(GetIt getIt) async {
    final logger = LoggerFactory.getLogger('CoreModule');
    final tag = logTag('CoreModule');

    // --- Register External Dependencies EARLY ---
    if (!getIt.isRegistered<Uuid>()) {
      getIt.registerLazySingleton<Uuid>(() => const Uuid());
      logger.d('$tag Registered Uuid');
    }
    if (!getIt.isRegistered<Connectivity>()) {
      getIt.registerLazySingleton<Connectivity>(() => Connectivity());
      logger.d('$tag Registered Connectivity');
    }
    if (!getIt.isRegistered<HiveInterface>()) {
      getIt.registerLazySingleton<HiveInterface>(() => Hive);
      logger.d('$tag Registered HiveInterface');
    }
    if (!getIt.isRegistered<FlutterSecureStorage>()) {
      getIt.registerLazySingleton<FlutterSecureStorage>(
        () => const FlutterSecureStorage(),
      );
      logger.d('$tag Registered FlutterSecureStorage');
    }
    if (!getIt.isRegistered<JwtValidator>()) {
      getIt.registerLazySingleton<JwtValidator>(() => JwtValidator());
      logger.d('$tag Registered JwtValidator');
    }

    // --- Register Platform Dependencies ---
    if (!getIt.isRegistered<FileSystem>()) {
      // Need path_provider to get the path
      final appDocDir = await getApplicationDocumentsDirectory();
      final documentsPath = appDocDir.path;
      getIt.registerLazySingleton<FileSystem>(
        () => IoFileSystem(documentsPath),
      );
      logger.d('$tag Registered FileSystem');
    }

    // --- Core Infrastructure (Dio, EventBus) ---
    if (!getIt.isRegistered<AuthEventBus>()) {
      getIt.registerLazySingleton<AuthEventBus>(() => AuthEventBus());
      logger.d('$tag Registered AuthEventBus');
    }

    if (!getIt.isRegistered<NetworkInfo>()) {
      // Register with disposal function
      getIt.registerLazySingleton<NetworkInfo>(
        () => NetworkInfoImpl(getIt<Connectivity>(), getIt<AuthEventBus>()),
        dispose: (NetworkInfo networkInfo) async {
          // We need to cast to access the dispose method
          await (networkInfo as NetworkInfoImpl).dispose();
          logger.d('$tag NetworkInfoImpl disposed during singleton disposal');
        },
      );
      logger.d('$tag Registered NetworkInfo with disposal function');
    }

    if (!getIt.isRegistered<DioFactory>()) {
      getIt.registerLazySingleton<DioFactory>(
        () => DioFactory(appConfig: getIt<AppConfig>()),
      );
      logger.d('$tag Registered DioFactory');
    }

    // Register concrete providers needed by modules BEFORE the modules run
    if (!getIt.isRegistered<AuthCredentialsProvider>()) {
      getIt.registerLazySingleton<AuthCredentialsProvider>(
        () => SecureStorageAuthCredentialsProvider(
          secureStorage: getIt<FlutterSecureStorage>(),
          jwtValidator: getIt<JwtValidator>(),
          appConfig: getIt<AppConfig>(),
        ),
      );
      logger.d('$tag Registered AuthCredentialsProvider');
    }
  }
}
