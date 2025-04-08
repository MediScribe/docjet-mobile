import 'package:docjet_mobile/features/audio_recorder/data/factories/audio_playback_service_factory.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_playback_service_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize Flutter test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlaybackServiceFactory', () {
    test('create() should return a valid AudioPlaybackService instance', () {
      // Act
      final service = AudioPlaybackServiceFactory.create();

      // Assert
      expect(service, isA<AudioPlaybackService>());
      expect(service, isA<AudioPlaybackServiceImpl>());

      // Dispose to clean up resources
      service.dispose();
    });
  });
}
