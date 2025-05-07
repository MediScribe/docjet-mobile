import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:docjet_mobile/core/audio/audio_recorder_service_impl.dart';
import 'package:record/record.dart';

// Helper to flush the microtask queue
Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

// Mock the record package's AudioRecorder (no need for call verification, only stubbing)
class MockAudioRecorder extends Fake implements AudioRecorder {
  bool _isPaused = false;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {}

  @override
  Future<void> pause() async {
    _isPaused = true;
  }

  @override
  Future<void> resume() async {
    _isPaused = false;
  }

  @override
  Future<bool> isPaused() async => _isPaused;

  @override
  Future<String?> stop() async => '/tmp/test_recording.m4a';

  @override
  Future<void> dispose() async {}
}

class TestTimer implements Timer {
  final Function() _callback;
  bool _isActive = true;

  TestTimer(this._callback);

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() => _isActive = false;

  void fire() {
    if (_isActive) _callback();
  }
}

void main() {
  // Initialize Flutter binding
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fake clock
  DateTime fakeNow = DateTime(2020, 1, 1);

  DateTime nowFn() => fakeNow;

  late AudioRecorderServiceImpl recorderService;
  late List<TestTimer> timers;

  Timer Function(Duration, Function()) timerFactory() {
    return (duration, callback) {
      final t = TestTimer(() {
        fakeNow = fakeNow.add(const Duration(milliseconds: 250));
        (callback as void Function())();
      });
      timers.add(t);
      return t;
    };
  }

  setUp(() {
    timers = [];
    // Use a modified implementation that doesn't access path_provider
    recorderService = AudioRecorderServiceImpl.test(
      recorder: MockAudioRecorder(),
      createTimer: timerFactory(),
      testOutputPath: '/tmp/test_recording.m4a',
      nowFn: nowFn,
    );
  });

  tearDown(() async => recorderService.dispose());

  test('emits elapsed time in 250 ms steps', () async {
    final emitted = <Duration>[];
    recorderService.elapsed$.listen(emitted.add);

    await recorderService.start();
    expect(timers.length, 1);

    for (int i = 0; i < 5; i++) {
      timers.first.fire();
    }
    await _flushMicrotasks();

    expect(emitted, [
      const Duration(milliseconds: 250),
      const Duration(milliseconds: 500),
      const Duration(milliseconds: 750),
      const Duration(milliseconds: 1000),
      const Duration(milliseconds: 1250),
    ]);
  });

  test('stop returns file path and resets elapsed', () async {
    await recorderService.start();
    timers.first.fire();
    timers.first.fire();
    await _flushMicrotasks();

    final path = await recorderService.stop();
    expect(path, '/tmp/test_recording.m4a');

    // restart and ensure elapsed restarts from zero
    final emitted = <Duration>[];
    recorderService.elapsed$.listen(emitted.add);

    await recorderService.start();
    timers.last.fire();
    await _flushMicrotasks();

    expect(emitted, [const Duration(milliseconds: 250)]);
  });

  test('pause blocks elapsed emission and resume continues', () async {
    final emitted = <Duration>[];
    recorderService.elapsed$.listen(emitted.add);

    await recorderService.start();
    timers.first.fire();
    await _flushMicrotasks();

    await recorderService.pause();
    timers.first.fire();
    timers.first.fire();
    await _flushMicrotasks();

    expect(emitted.length, 1); // no new events while paused

    await recorderService.resume();
    timers.first.fire();
    await _flushMicrotasks();

    expect(emitted.length, 2);
    expect(emitted.last, const Duration(milliseconds: 500));
  });
}
