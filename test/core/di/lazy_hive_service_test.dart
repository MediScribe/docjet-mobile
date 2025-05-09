import 'dart:io';

import 'package:docjet_mobile/core/di/lazy_hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('LazyHiveService', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_test');
    });

    tearDownAll(() async {
      // Clean up Hive & temporary directory.
      // Dispose service if it was initialised.
      try {
        await LazyHiveService.instance.dispose();
      } catch (_) {
        // Service was never initialised – nothing to dispose.
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('initialises in <150 ms (bootstrap overhead)', () async {
      final sw = Stopwatch()..start();
      await LazyHiveService.init(path: tempDir.path);
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(milliseconds: 150)));
    });

    test(
      'getBox returns functional box without blocking main thread',
      () async {
        // Assume service already initialised in previous test.
        final sw = Stopwatch()..start();
        final Box<String> box = await LazyHiveService.instance.getBox<String>(
          'testBox',
        );
        sw.stop();
        expect(box.isOpen, isTrue);
        expect(sw.elapsed, lessThan(const Duration(milliseconds: 150)));
      },
    );
  });
}
