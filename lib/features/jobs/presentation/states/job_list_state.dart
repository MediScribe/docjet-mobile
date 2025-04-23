import 'package:equatable/equatable.dart';

import 'package:docjet_mobile/features/jobs/presentation/models/job_view_model.dart';

abstract class JobListState extends Equatable {
  const JobListState();

  @override
  List<Object> get props => [];
}

class JobListInitial extends JobListState {
  const JobListInitial();
}

class JobListLoading extends JobListState {
  const JobListLoading();
}

class JobListLoaded extends JobListState {
  final List<JobViewModel> jobs;

  const JobListLoaded(this.jobs);

  @override
  List<Object> get props => [jobs];
}

class JobListError extends JobListState {
  final String message;

  const JobListError(this.message);

  @override
  List<Object> get props => [message];
}
