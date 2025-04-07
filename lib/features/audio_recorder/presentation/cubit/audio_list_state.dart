part of 'audio_list_cubit.dart';

// Removed imports from here - they belong in audio_list_cubit.dart
// import 'package:docjet_mobile/features/audio_recorder/domain/entities/transcription.dart';
// import 'package:equatable/equatable.dart';

// Base class
abstract class AudioListState extends Equatable {
  const AudioListState();

  @override
  List<Object> get props => [];
}

// Initial State
class AudioListInitial extends AudioListState {}

// Loading State
class AudioListLoading extends AudioListState {}

// Error State
class AudioListError extends AudioListState {
  final String message;

  const AudioListError({required this.message});

  @override
  List<Object> get props => [message];
}

// Loaded State - Adjust if using a specific UI model later
class AudioListLoaded extends AudioListState {
  final List<Transcription> recordings; // Change to List<Transcription>

  const AudioListLoaded({required this.recordings}); // Update constructor

  @override
  List<Object> get props => [recordings];

  @override
  String toString() => 'AudioListLoaded { count: ${recordings.length} }';
}
