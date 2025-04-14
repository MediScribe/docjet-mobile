import 'package:docjet_mobile/features/audio_recorder/data/factories/audio_playback_service_factory.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/services/audio_playback_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

class MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

void main() {
  // Initialize Flutter test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioPlaybackService mockService;

  setUp(() {
    mockService = MockAudioPlaybackService();
    GetIt.instance.registerSingleton<AudioPlaybackService>(mockService);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  group('AudioPlaybackServiceProvider', () {
    test(
      'getService() should return the registered AudioPlaybackService instance',
      () {
        // Act
        final service = AudioPlaybackServiceProvider.getService();

        // Assert
        expect(service, isA<AudioPlaybackService>());
        expect(service, equals(mockService));
      },
    );
  });
}
