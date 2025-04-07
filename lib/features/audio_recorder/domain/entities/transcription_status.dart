/// Enum representing the possible states of a transcription job.
///
/// These values MUST align *exactly* with the status strings expected
/// and returned by the backend API (`spec.md`) for reliable mapping.
enum TranscriptionStatus {
  /// Initial state: Recording saved locally, not yet submitted to the backend.
  created,

  /// Job successfully submitted to the backend API, awaiting processing.
  submitted,

  /// Backend is actively uploading or transferring the audio file internally.
  // uploading, // NOTE: Based on spec.md, backend might go straight to processing

  /// Backend is actively processing the audio (transcription).
  processing, // Renamed from 'transcribing' to match spec.md
  /// Transcription text is complete, but final output/formatting is pending.
  transcribed,

  /// Backend is generating the final formatted output (e.g., structured text).
  generating, // Renamed from 'generated' to match spec.md
  /// Job successfully completed, transcription and output are available.
  completed, // Renamed from 'generated' to match spec.md
  /// An error occurred during the process.
  failed, // Renamed from 'error' to match spec.md
  /// Represents an unknown or unexpected status received from the backend.
  /// Crucial for handling potential future API changes gracefully.
  unknown,
}

/// Extension to add helper methods to `TranscriptionStatus`.
/// This allows parsing from strings and potentially adding other utilities.
extension TranscriptionStatusX on TranscriptionStatus {
  /// Parses a status string (likely from the backend API) into the corresponding enum value.
  ///
  /// Handles potential mismatches by defaulting to `unknown`.
  /// Case-insensitive comparison for robustness.
  static TranscriptionStatus fromString(String? statusString) {
    if (statusString == null) return TranscriptionStatus.unknown;

    switch (statusString.toLowerCase()) {
      case 'created':
        return TranscriptionStatus.created;
      case 'submitted':
        return TranscriptionStatus.submitted;
      // case 'uploading': return TranscriptionStatus.uploading;
      case 'processing': // Was 'transcribing'
        return TranscriptionStatus.processing;
      case 'transcribed':
        return TranscriptionStatus.transcribed;
      case 'generating': // Was 'generated'
        return TranscriptionStatus.generating;
      case 'completed': // Was 'generated' before, now distinct
        return TranscriptionStatus.completed;
      case 'failed': // Was 'error'
        return TranscriptionStatus.failed;
      default:
        // Log this unknown status? Might indicate API changes.
        return TranscriptionStatus.unknown;
    }
  }

  /// Converts the enum value back to its string representation (lowercase).
  /// Useful for sending status filters or potentially for local storage if needed.
  String toJson() => name;

  /// Provides a user-friendly display label for the status.
  /// TODO: Needs localization/internationalization (i18n)
  String get displayLabel {
    switch (this) {
      case TranscriptionStatus.created:
        return 'Lokal'; // Local / Pending Upload
      case TranscriptionStatus.submitted:
        return 'Gesendet'; // Submitted
      // case TranscriptionStatus.uploading:
      //   return 'Hochladen...'; // Uploading...
      case TranscriptionStatus.processing:
        return 'Verarbeite...'; // Processing...
      case TranscriptionStatus.transcribed:
        return 'Transkribiert'; // Transcribed
      case TranscriptionStatus.generating:
        return 'Generiere...'; // Generating...
      case TranscriptionStatus.completed:
        return 'Fertig'; // Completed
      case TranscriptionStatus.failed:
        return 'Fehler'; // Error
      case TranscriptionStatus.unknown:
        return 'Unbekannt'; // Unknown
    }
  }

  /// Indicates if the job is in a final state (completed or failed).
  bool get isFinal =>
      this == TranscriptionStatus.completed ||
      this == TranscriptionStatus.failed;

  /// Indicates if the job is actively being worked on by the backend.
  bool get isInProgress =>
      this == TranscriptionStatus.submitted ||
      // this == TranscriptionStatus.uploading ||
      this == TranscriptionStatus.processing ||
      this == TranscriptionStatus.transcribed ||
      this == TranscriptionStatus.generating;
}
