/// Represents the processing status of a Job.
///
/// Based on the states defined in the system specification.
enum JobStatus {
  /// The job record has been created locally but not yet sent to the backend.
  created,

  /// The job (audio + metadata) has been successfully submitted to the backend.
  submitted,

  /// The backend has started transcribing the audio.
  transcribing,

  /// The backend has finished transcribing the audio.
  transcribed,

  /// The backend is generating the final document(s) from the transcript.
  generating,

  /// The backend has finished generating the document(s).
  generated,

  /// The job is fully processed, and documents are available.
  completed,

  /// An error occurred during processing.
  error,
}
