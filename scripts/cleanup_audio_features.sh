#!/bin/bash

# This script removes files related to active audio recording and playback features.
# It retains files related to listing recordings and managing transcription data.
# It also removes any resulting empty directories within the feature folder.

echo "Deleting audio recording and playback specific files..."

rm -f lib/features/audio_recorder/presentation/pages/audio_recorder_page.dart
rm -f lib/features/audio_recorder/presentation/widgets/recording_controls.dart
rm -f lib/features/audio_recorder/presentation/cubit/audio_recording_cubit.dart
rm -f lib/features/audio_recorder/domain/entities/playback_state.dart
rm -f lib/features/audio_recorder/domain/adapters/audio_player_adapter.dart
rm -f lib/features/audio_recorder/data/adapters/audio_player_adapter_impl.dart
rm -f lib/features/audio_recorder/domain/services/audio_playback_service.dart
rm -f lib/features/audio_recorder/data/services/audio_playback_service_impl.dart
rm -f lib/features/audio_recorder/data/datasources/audio_local_data_source.dart
rm -f lib/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart
rm -f lib/features/audio_recorder/domain/mappers/playback_state_mapper.dart
rm -f lib/features/audio_recorder/data/mappers/playback_state_mapper_impl.dart
rm -f lib/features/audio_recorder/domain/services/audio_concatenation_service.dart
rm -f lib/features/audio_recorder/data/services/audio_concatenation_service_impl.dart

echo "Deleting empty directories within lib/features/audio_recorder..."
find lib/features/audio_recorder -type d -empty -delete

echo "Cleanup script finished." 