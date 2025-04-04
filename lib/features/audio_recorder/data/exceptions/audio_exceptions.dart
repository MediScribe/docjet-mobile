/// Base class for audio feature specific exceptions.
abstract class AudioException implements Exception {
  final String message;
  final Object? originalException;

  const AudioException(this.message, [this.originalException]);

  @override
  String toString() {
    if (originalException != null) {
      return '$runtimeType: $message (Caused by: $originalException)';
    }
    return '$runtimeType: $message';
  }
}

/// Exception related to microphone permissions.
class AudioPermissionException extends AudioException {
  const AudioPermissionException(super.message, [super.originalException]);
}

/// Exception related to file system operations (read, write, delete, list).
class AudioFileSystemException extends AudioException {
  const AudioFileSystemException(super.message, [super.originalException]);
}

/// Exception related to the recording process itself (start, stop, pause, resume).
class AudioRecordingException extends AudioException {
  const AudioRecordingException(super.message, [super.originalException]);
}

/// Exception related to audio playback or duration retrieval.
class AudioPlayerException extends AudioException {
  const AudioPlayerException(super.message, [super.originalException]);
}

/// Exception related to audio file concatenation issues.
class AudioConcatenationException extends AudioException {
  final String? logs;

  const AudioConcatenationException(
    super.message,
    super.originalException, {
    this.logs,
  });

  @override
  String toString() {
    final cause =
        super.originalException != null
            ? ' (Caused by: ${super.originalException})'
            : '';
    final logMessage =
        logs != null && logs!.isNotEmpty ? '\nFFmpeg Logs:\n$logs' : '';
    return 'AudioConcatenationException: ${super.message}$cause$logMessage';
  }
}

/// Exception for when an operation is attempted but no recording is active.
class NoActiveRecordingException extends AudioException {
  const NoActiveRecordingException(super.message, [super.originalException]);
}

/// Exception for when a file is expected but not found.
class RecordingFileNotFoundException extends AudioException {
  const RecordingFileNotFoundException(
    super.message, [
    super.originalException,
  ]);
}
