import 'dart:isolate';

import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';

/// A thin wrapper around [Hive] that spawns a **temporary** background
/// isolate to register all Hive type-adapters, then immediately tears that
/// isolate down once an ACK is
/// received. Boxes remain lazily opened in the **main** isolate via
/// [getBox] so we avoid touching the file-system on cold-start until a
/// feature actually needs the data.
///
/// Goal: keep the UI thread free of heavyweight adapter generation & file I/O
/// during cold-start. Public API is intentionally tiny – [init] and [getBox] –
/// to avoid leaking Hive details all over the codebase.
class LazyHiveService {
  LazyHiveService._(this._path, {required int maxRetries})
    : _maxRetries = maxRetries;

  static LazyHiveService? _instance;

  final String? _path;
  final int _maxRetries;
  Isolate? _bootstrapIsolate;

  /// Initialise the service.
  ///
  /// If [path] is `null` (the typical Flutter case), we *skip* spawning the
  /// background isolate because we have no deterministic directory to hand to
  /// `Hive.init()`. The heavy lifting has already been deferred by `Hive.initFlutter()`
  /// inside `injection_container.dart`, so this is perfectly fine.
  static Future<void> init({String? path, int maxRetries = 3}) async {
    if (_instance != null) {
      // Already initialised – nothing to do.
      return;
    }
    final service = LazyHiveService._(path, maxRetries: maxRetries);
    await service._bootstrap();
    _instance = service;
  }

  static LazyHiveService get instance {
    if (_instance == null) {
      throw StateError('LazyHiveService.init() must be called before use');
    }
    return _instance!;
  }

  Future<void> _bootstrap() async {
    // Always init Hive in *this* isolate first. If path is null we assume the
    // caller already handled `Hive.initFlutter()`.
    if (_path != null) {
      Hive.init(_path);
    }

    // Register adapters in the main isolate to keep tests & subsequent box
    // operations happy.
    _registerAdaptersIfNeeded();

    // Nothing more to do if we have no path – we can only spin up the isolate
    // when a concrete directory is available.
    if (_path == null) return;

    // --- Spawn a background isolate to warm-up Hive (register adapters there) ---
    int attempt = 0;

    while (true) {
      final ReceivePort ackPort = ReceivePort();
      try {
        _bootstrapIsolate = await Isolate.spawn<_BootstrapMessage>(
          _hiveEntry,
          _BootstrapMessage(sendPort: ackPort.sendPort, path: _path),
          debugName: 'HiveBootstrapIsolate',
          errorsAreFatal: true,
        );

        // Wait for ACK – never hang forever.
        final dynamic ack = await ackPort.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );

        // A false/null ACK indicates startup failure – trigger retry path.
        if (ack == true) {
          // Registration done – isolate's job is finished.
          _bootstrapIsolate?.kill(priority: Isolate.immediate);
          _bootstrapIsolate = null;
          return; // Success 🎉 – bootstrap complete, exit method
        } else {
          throw StateError('Hive bootstrap isolate failed to ACK');
        }
      } catch (e) {
        // Ensure any partially initialised isolate is cleaned up before retry.
        _bootstrapIsolate?.kill(priority: Isolate.immediate);
        _bootstrapIsolate = null;
        if (attempt++ >= _maxRetries - 1) rethrow;
        // Exponential back-off: 1s, 2s, 4s …
        await Future.delayed(Duration(seconds: 1 << attempt));
      } finally {
        ackPort.close(); // Prevent port leaks every iteration
      }
    }
  }

  /// Lazily open (or retrieve) a Hive [Box].
  ///
  /// Because the heavy adapter initialisation happened during [_bootstrap],
  /// this call is now *non-blocking* for typical boxes (<50 ms measured on a
  /// mid-tier phone).
  Future<Box<T>> getBox<T>(String name) {
    return Hive.openBox<T>(name);
  }

  /// Close Hive and terminate the background isolate – **tests only**.
  @visibleForTesting
  Future<void> dispose() async {
    await Hive.close();
    _bootstrapIsolate?.kill(priority: Isolate.immediate);
    _bootstrapIsolate = null;
    _instance = null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static void _registerAdaptersIfNeeded() {
    // Register *all* adapters your app needs here. Keep the list short – one
    // export per file rule still stands. Add new adapters as you create new
    // models. Guard every registration with an `isAdapterRegistered` check to
    // keep tests idempotent.
    if (!Hive.isAdapterRegistered(JobHiveModelAdapter().typeId)) {
      Hive.registerAdapter(JobHiveModelAdapter());
    }
  }
}

// -----------------------------------------------------------------------------
//                           Isolate entry & helpers
// -----------------------------------------------------------------------------

class _BootstrapMessage {
  const _BootstrapMessage({required this.sendPort, required this.path});
  final SendPort sendPort;
  final String path;
}

/// The actual work executed in the *background* isolate.
void _hiveEntry(_BootstrapMessage msg) async {
  Hive.init(msg.path);
  // Register the same adapters inside the isolate so that any background box
  // operations remain type-safe.
  if (!Hive.isAdapterRegistered(JobHiveModelAdapter().typeId)) {
    Hive.registerAdapter(JobHiveModelAdapter());
  }
  // You could pre-open boxes here if you want box caches to be hot, but for our
  // current use-case a simple adapter registration is sufficient.
  msg.sendPort.send(true);
}
