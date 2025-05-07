import 'dart:async';

import 'package:docjet_mobile/core/audio/audio_player_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Concrete implementation of [AudioPlayerService] that wraps the
/// `just_audio` [AudioPlayer] while applying our stream-hygiene rules.
class AudioPlayerServiceImpl implements AudioPlayerService {
  AudioPlayerServiceImpl({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _bindStreams();
  }

  // -----------------------------------------------------------------------
  // Dependencies / Fields
  // -----------------------------------------------------------------------
  final AudioPlayer _player;

  late final BehaviorSubject<Duration> _positionSubject;
  late final BehaviorSubject<Duration> _durationSubject;
  late final BehaviorSubject<ProcessingState> _processingStateSubject;

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<ProcessingState> _processingStateSub;

  /// Binds to the underlying player's streams, applying stream hygiene and
  /// throttling rules as per spec.
  void _bindStreams() {
    // --- POSITION STREAM --------------------------------------------------
    // Note: just_audio's positionStream already emits at updatePositionInterval
    // (default ~200ms). Our additional throttle may cause us to miss alternate
    // ticks if they precisely align, but this ensures we don't exceed spec.
    _positionSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
    _positionSub = _player.positionStream
        .distinct()
        .throttleTime(const Duration(milliseconds: 200))
        .listen((d) {
          if (d != _positionSubject.value) {
            _positionSubject.add(d);
          }
        });

    // --- DURATION STREAM --------------------------------------------------
    _durationSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
    _durationSub = _player.durationStream
        .distinct()
        .throttleTime(const Duration(milliseconds: 200))
        .map((d) => d ?? Duration.zero)
        .listen((d) {
          if (d != _durationSubject.value) {
            _durationSubject.add(d);
          }
        });

    // --- PROCESSING STATE STREAM -----------------------------------------
    _processingStateSubject = BehaviorSubject<ProcessingState>.seeded(
      ProcessingState.idle,
    );
    _processingStateSub = _player.playerStateStream
        .map((s) => s.processingState)
        .distinct()
        .listen(_processingStateSubject.add);
  }

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------
  @override
  Stream<Duration> get position$ => _positionSubject.stream;

  @override
  Stream<Duration> get duration$ => _durationSubject.stream;

  @override
  Stream<ProcessingState> get processingState$ =>
      _processingStateSubject.stream;

  @override
  Future<void> load(String filePath) async {
    await _player.setFilePath(filePath);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> reset() async {
    await _player.stop();
    // Emit fresh baseline so late subscribers don't get stale values.
    _positionSubject.add(Duration.zero);
    _durationSubject.add(Duration.zero);
    _processingStateSubject.add(ProcessingState.idle);
  }

  @override
  Future<void> dispose() async {
    await _positionSub.cancel();
    await _durationSub.cancel();
    await _processingStateSub.cancel();

    await _positionSubject.close();
    await _durationSubject.close();
    await _processingStateSubject.close();

    await _player.dispose();
  }
}
