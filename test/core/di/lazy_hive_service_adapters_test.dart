import 'dart:io';

import 'package:docjet_mobile/core/di/lazy_hive_service.dart';
import 'package:docjet_mobile/features/jobs/data/models/job_hive_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LazyHiveService – adapters', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_adapter_test');
      await LazyHiveService.init(path: tempDir.path);
    });

    tearDownAll(() async {
      await LazyHiveService.instance.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('JobHiveModel adapter works across isolates', () async {
      final box = await LazyHiveService.instance.getBox<JobHiveModel>('jobs');
      final model = JobHiveModel(localId: 'abc123');
      await box.put('k', model);
      await box.close();

      final reopened = await LazyHiveService.instance.getBox<JobHiveModel>(
        'jobs',
      );
      final retrieved = reopened.get('k');
      expect(retrieved, isNotNull);
      expect(retrieved?.localId, equals('abc123'));
    });
  });
}
