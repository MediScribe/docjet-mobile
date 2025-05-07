import 'dart:async';

import 'package:docjet_mobile/core/audio/audio_player_service_impl.dart';
import 'package:docjet_mobile/core/audio/audio_player_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

// Simple microtask flusher helper
Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

// Simple Fake implementation avoiding Mockito complexity
class FakeAudioPlayer implements AudioPlayer {
  FakeAudioPlayer(
    this._positionCtrl,
    this._durationCtrl,
    this._playerStateCtrl,
  );

  final StreamController<Duration> _positionCtrl;
  final StreamController<Duration?> _durationCtrl;
  final StreamController<PlayerState> _playerStateCtrl;

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateCtrl.stream;

  @override
  ProcessingState get processingState => _currentProcessingState;

  ProcessingState _currentProcessingState = ProcessingState.idle;

  void setProcessingState(ProcessingState state) {
    _currentProcessingState = state;
    _playerStateCtrl.add(PlayerState(false, state));
  }

  // The following AudioPlayer APIs are stubbed out as no-ops for test purposes.
  @override
  Future<Duration?> setFilePath(
    String path, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    return null;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration? position, {int? index}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  // For all other members of [AudioPlayer] not required in the tests,
  // delegate to [noSuchMethod] so the fake remains lightweight.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioPlayer fakePlayer;
  late AudioPlayerService service;
  late StreamController<Duration> positionCtrl;
  late StreamController<Duration?> durationCtrl;
  late StreamController<PlayerState> playerStateCtrl;

  setUp(() {
    positionCtrl = StreamController<Duration>.broadcast();
    durationCtrl = StreamController<Duration?>.broadcast();
    playerStateCtrl = StreamController<PlayerState>.broadcast();

    fakePlayer = FakeAudioPlayer(positionCtrl, durationCtrl, playerStateCtrl);

    // Use the implementation under test with our fake player
    service = AudioPlayerServiceImpl(player: fakePlayer);
  });

  tearDown(() async {
    await service.dispose();
    await positionCtrl.close();
    await durationCtrl.close();
    await playerStateCtrl.close();
  });

  test('emits duration & position correctly', () async {
    // Collect emissions
    final positions = <Duration>[];
    final durations = <Duration>[];

    service.position$.listen(positions.add);
    service.duration$.listen((d) {
      if (d != Duration.zero) durations.add(d);
    });

    await service.load('/tmp/fake.m4a');

    // Push some fake stream events
    durationCtrl.add(const Duration(seconds: 5));
    positionCtrl.add(const Duration(milliseconds: 0));
    await _flushMicrotasks();

    // Wait for throttle window to elapse before pushing next update.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    positionCtrl.add(const Duration(milliseconds: 200));
    await _flushMicrotasks();

    expect(durations, [const Duration(seconds: 5)]);
    expect(positions, [
      const Duration(milliseconds: 0),
      const Duration(milliseconds: 200),
    ]);
  });

  test('supports seek and reset', () async {
    await service.load('/tmp/fake.m4a');

    const target = Duration(seconds: 2);
    await service.seek(target);
    // Since fake implementation is a no-op, we simply ensure no throw.

    // Reset should emit zero again
    final resetPositions = <Duration>[];
    service.position$.listen(resetPositions.add);

    await service.reset();

    // Give stream time to emit post-reset values.
    await _flushMicrotasks();

    expect(resetPositions.last, Duration.zero);
  });

  test('forwards processing state changes', () async {
    // Collect emissions
    final states = <ProcessingState>[];
    service.processingState$.listen(states.add);

    // Initial state
    await _flushMicrotasks();
    expect(states, [ProcessingState.idle]);

    // Change to buffering
    fakePlayer.setProcessingState(ProcessingState.buffering);
    await _flushMicrotasks();

    // Change to ready then completed
    fakePlayer.setProcessingState(ProcessingState.ready);
    await _flushMicrotasks();
    fakePlayer.setProcessingState(ProcessingState.completed);
    await _flushMicrotasks();

    // All changes should be forwarded
    expect(states, [
      ProcessingState.idle,
      ProcessingState.buffering,
      ProcessingState.ready,
      ProcessingState.completed,
    ]);
  });
}
