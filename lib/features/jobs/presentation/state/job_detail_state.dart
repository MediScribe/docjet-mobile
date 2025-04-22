import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';

/// Represents the state for the job detail screen.
class JobDetailState extends Equatable {
  final bool isLoading;
  final JobViewModel? job; // Nullable: might be loading or not found
  final String? error;

  const JobDetailState({required this.isLoading, this.job, this.error});

  /// Initial state for the job detail.
  factory JobDetailState.initial() {
    return const JobDetailState(isLoading: false, job: null, error: null);
  }

  /// Creates a copy of the state with optional changes.
  JobDetailState copyWith({
    bool? isLoading,
    JobViewModel? job,
    bool setJobNull = false, // Helper to explicitly clear job
    String? error,
    bool clearError = false, // Helper to explicitly clear error
  }) {
    return JobDetailState(
      isLoading: isLoading ?? this.isLoading,
      job: setJobNull ? null : job ?? this.job,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, job, error];
}
