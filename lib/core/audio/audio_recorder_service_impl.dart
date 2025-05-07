import 'dart:async';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:docjet_mobile/core/audio/audio_recorder_service.dart';
import 'package:docjet_mobile/core/utils/log_helpers.dart';

/// Implementation of the [AudioRecorderService] using the 'record' package.
class AudioRecorderServiceImpl implements AudioRecorderService {
  /// The underlying recorder from the 'record' package.
  final AudioRecorder _recorder;

  /// Function to create timers, can be injected for testing.
  final Timer Function(Duration, Function()) _createTimer;

  /// Function that returns current time, injectable for testing.
  final DateTime Function() _now;

  /// Stream controller for the elapsed time.
  final _elapsedController = StreamController<Duration>.broadcast();

  /// Current timer for tracking elapsed time.
  Timer? _timer;

  /// Track if we're in a paused state.
  bool _isPaused = false;

  /// Track recording state
  bool _isRecording = false;

  /// Timestamp when recording started
  DateTime? _recordingStartTime;

  /// Timestamp when paused
  DateTime? _pauseTime;

  /// Total elapsed milliseconds before current segment
  int _previousElapsedMs = 0;

  /// Current recording file path
  String? _recordingPath;

  /// For testing - bypass path provider
  final String? testOutputPath;

  /// Logger for this class
  static final Logger _logger = LoggerFactory.getLogger(
    AudioRecorderServiceImpl,
  );
  static final String _tag = logTag(AudioRecorderServiceImpl);

  /// Create a new instance of [AudioRecorderServiceImpl].
  ///
  /// [recorder] - The underlying recorder instance.
  /// [createTimer] - Function to create timers, injectable for testing.
  AudioRecorderServiceImpl({
    AudioRecorder? recorder,
    Timer Function(Duration, Function())? createTimer,
  }) : _recorder = recorder ?? AudioRecorder(),
       _createTimer =
           createTimer ??
           ((duration, callback) =>
               Timer.periodic(duration, (_) => callback())),
       _now = DateTime.now,
       testOutputPath = null;

  /// Create a test instance that doesn't require path_provider.
  ///
  /// [recorder] - The underlying recorder instance.
  /// [createTimer] - Function to create timers, injectable for testing.
  /// [testOutputPath] - The fixed output path to use for testing.
  factory AudioRecorderServiceImpl.test({
    required AudioRecorder recorder,
    required Timer Function(Duration, Function()) createTimer,
    required String testOutputPath,
    DateTime Function()? nowFn,
  }) {
    return AudioRecorderServiceImpl._internal(
      recorder: recorder,
      createTimer: createTimer,
      testOutputPath: testOutputPath,
      nowFn: nowFn,
    );
  }

  // Internal constructor with optional testOutputPath
  AudioRecorderServiceImpl._internal({
    AudioRecorder? recorder,
    Timer Function(Duration, Function())? createTimer,
    this.testOutputPath,
    DateTime Function()? nowFn,
  }) : _recorder = recorder ?? AudioRecorder(),
       _createTimer =
           createTimer ??
           ((duration, callback) =>
               Timer.periodic(duration, (_) => callback())),
       _now = nowFn ?? DateTime.now;

  @override
  Stream<Duration> get elapsed$ => _elapsedController.stream;

  @override
  Future<void> start() async {
    // Guard against multiple start() calls
    if (_isRecording) {
      _logger.w('$_tag start() called while recording is already in progress');
      await stop();
    }

    // Reset state
    _isPaused = false;
    _isRecording = true;
    _recordingStartTime = _now();
    _pauseTime = null;
    _previousElapsedMs = 0;

    // Determine recording path
    if (testOutputPath != null) {
      // Use test output path
      _recordingPath = testOutputPath;
    } else {
      // Get a platform-safe temporary directory
      final tempDir = await getTemporaryDirectory();
      _recordingPath = path.join(
        tempDir.path,
        'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
    }

    // Start recording with config
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );

    // Create a timer that emits every 250ms
    _timer = _createTimer(const Duration(milliseconds: 250), _emitElapsed);
  }

  @override
  Future<void> pause() async {
    if (!_isRecording) {
      _logger.w('$_tag pause() called while not recording');
      return;
    }

    try {
      await _recorder.pause();

      // Store current pause time for accurate resuming
      _pauseTime = _now();

      // Accumulate elapsed time so far
      if (_recordingStartTime != null) {
        _previousElapsedMs +=
            _pauseTime!.difference(_recordingStartTime!).inMilliseconds;
        _recordingStartTime = null;
      }

      // On iOS < 13, pause() may silently fail - check actual state
      final actuallyPaused = await _recorder.isPaused();
      _isPaused = true;

      if (!actuallyPaused) {
        _logger.w(
          '$_tag Platform reports recorder is not paused - this may be iOS < 13',
        );
      }
    } catch (e) {
      _logger.e('$_tag Error pausing recording: $e');
      // Set paused state even on error to maintain consistent UI
      _isPaused = true;
    }
  }

  @override
  Future<void> resume() async {
    if (!_isRecording) {
      _logger.w('$_tag resume() called while not recording');
      return;
    }

    // Always forward the resume command, even if we think we're not paused
    // This ensures recorder state stays in sync with our internal state
    try {
      await _recorder.resume();

      // Reset start time to now for elapsed calculation
      _recordingStartTime = _now();
      _pauseTime = null;
      _isPaused = false;
    } catch (e) {
      _logger.e('$_tag Error resuming recording: $e');
      // Try to resync our state with the recorder
      _isPaused = await _recorder.isPaused();
    }
  }

  @override
  Future<String> stop() async {
    // Cancel the timer
    _timer?.cancel();
    _timer = null;

    String? recordedPath;
    if (_isRecording) {
      try {
        // Stop recording
        recordedPath = await _recorder.stop();

        if (recordedPath == null) {
          throw Exception('Recording failed: No file path returned');
        }
      } catch (e) {
        _logger.e('$_tag Error stopping recording: $e');
        throw Exception('Recording failed to stop: $e');
      }
    }

    // Reset state
    _isRecording = false;
    _isPaused = false;
    _recordingStartTime = null;
    _pauseTime = null;
    _previousElapsedMs = 0;

    if (recordedPath == null) {
      throw Exception('Recording failed: No file path returned');
    }

    return recordedPath;
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;

    await _elapsedController.close();

    try {
      await _recorder.dispose();
    } catch (e) {
      _logger.e('$_tag Error disposing recorder: $e');
    }
  }

  /// Emits the current elapsed time through the stream.
  /// Uses timestamps for accuracy rather than fixed increments.
  void _emitElapsed() {
    if (_isPaused) return;

    final now = _now();
    final currentElapsedMs =
        _previousElapsedMs +
        (_recordingStartTime != null
            ? now.difference(_recordingStartTime!).inMilliseconds
            : 0);

    _elapsedController.add(Duration(milliseconds: currentElapsedMs));
  }
}
