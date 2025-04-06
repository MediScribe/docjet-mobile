import 'package:docjet_mobile/features/audio_recorder/domain/entities/audio_record.dart'; // Might need this if passing full entities
import 'package:equatable/equatable.dart';

// Base class
abstract class AudioListState extends Equatable {
  const AudioListState();

  @override
  List<Object?> get props => [];
}

// Initial State
class AudioListInitial extends AudioListState {}

// Loading State
class AudioListLoading extends AudioListState {}

// Error State
class AudioListError extends AudioListState {
  final String message;

  const AudioListError(this.message);

  @override
  List<Object?> get props => [message];
}

// Loaded State - Adjust if using a specific UI model later
class AudioListLoaded extends AudioListState {
  final List<AudioRecord> recordings; // Using domain entity for now

  const AudioListLoaded(this.recordings);

  @override
  List<Object> get props => [recordings];

  @override
  String toString() => 'AudioListLoaded { count: ${recordings.length} }';
}
