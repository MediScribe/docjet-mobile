import 'package:equatable/equatable.dart';
import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';

/// Represents the state for the job list screen.
class JobListState extends Equatable {
  final bool isLoading;
  final List<JobViewModel> jobs;
  final String? error;

  const JobListState({required this.isLoading, required this.jobs, this.error});

  /// Initial state for the job list.
  factory JobListState.initial() {
    return const JobListState(isLoading: false, jobs: [], error: null);
  }

  /// Creates a copy of the state with optional changes.
  JobListState copyWith({
    bool? isLoading,
    List<JobViewModel>? jobs,
    String? error,
    bool clearError = false, // Helper to explicitly clear error
  }) {
    return JobListState(
      isLoading: isLoading ?? this.isLoading,
      jobs: jobs ?? this.jobs,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [isLoading, jobs, error];
}
