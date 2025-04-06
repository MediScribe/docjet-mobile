import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_retriever_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'audio_duration_retriever_impl_test.mocks.dart';

@GenerateNiceMocks([MockSpec<AudioPlayer>()])
void main() {
  late MockAudioPlayer mockAudioPlayer;
  late AudioDurationRetrieverImpl durationRetriever;

  // Factory function to provide the mock player
  AudioPlayer playerFactory() => mockAudioPlayer;

  setUp(() {
    mockAudioPlayer = MockAudioPlayer();
    durationRetriever = AudioDurationRetrieverImpl(
      playerFactory: playerFactory,
    );

    // Default stub for dispose to avoid errors in `finally`
    when(mockAudioPlayer.dispose()).thenAnswer((_) async {});
  });

  const tFilePath = '/test/audio.m4a';
  const tDuration = Duration(seconds: 30);

  test('should return duration when setFilePath is successful', () async {
    // Arrange
    when(
      mockAudioPlayer.setFilePath(tFilePath),
    ).thenAnswer((_) async => tDuration);

    // Act
    final result = await durationRetriever.getDuration(tFilePath);

    // Assert
    expect(result, tDuration);
    verify(mockAudioPlayer.setFilePath(tFilePath));
    verify(mockAudioPlayer.dispose()); // Ensure dispose is called
  });

  test(
    'should throw AudioPlayerException when setFilePath returns null',
    () async {
      // Arrange
      when(
        mockAudioPlayer.setFilePath(tFilePath),
      ).thenAnswer((_) async => null); // Simulate null duration

      // Act
      final call = durationRetriever.getDuration(tFilePath);

      // Assert
      expectLater(
        call,
        throwsA(
          isA<AudioPlayerException>().having(
            (e) => e.message,
            'message',
            contains('Could not determine duration'),
          ),
        ),
      );
      // Verify interactions AFTER expectLater
      await untilCalled(mockAudioPlayer.dispose()); // Wait for finally block
      verify(mockAudioPlayer.setFilePath(tFilePath));
      verify(mockAudioPlayer.dispose());
    },
  );

  test(
    'should throw AudioPlayerException when setFilePath throws PlayerException',
    () async {
      // Arrange
      final playerException = PlayerException(404, 'File not found by player');
      when(mockAudioPlayer.setFilePath(tFilePath)).thenThrow(playerException);

      // Act
      final call = durationRetriever.getDuration(tFilePath);

      // Assert
      expectLater(
        call,
        throwsA(
          isA<AudioPlayerException>()
              .having((e) => e.message, 'message', contains('player error'))
              .having(
                (e) => e.originalException,
                'originalException',
                playerException,
              ),
        ),
      );
      // Verify interactions AFTER expectLater
      await untilCalled(mockAudioPlayer.dispose());
      verify(mockAudioPlayer.setFilePath(tFilePath));
      verify(mockAudioPlayer.dispose());
    },
  );

  test(
    'should throw AudioPlayerException for other unexpected exceptions',
    () async {
      // Arrange
      final unexpectedException = Exception('Something weird happened');
      when(
        mockAudioPlayer.setFilePath(tFilePath),
      ).thenThrow(unexpectedException);

      // Act
      final call = durationRetriever.getDuration(tFilePath);

      // Assert
      expectLater(
        call,
        throwsA(
          isA<AudioPlayerException>()
              .having((e) => e.message, 'message', contains('unexpected error'))
              .having(
                (e) => e.originalException,
                'originalException',
                unexpectedException,
              ),
        ),
      );
      // Verify interactions AFTER expectLater
      await untilCalled(mockAudioPlayer.dispose());
      verify(mockAudioPlayer.setFilePath(tFilePath));
      verify(mockAudioPlayer.dispose());
    },
  );

  test('should always call player.dispose even on success', () async {
    // Arrange
    when(
      mockAudioPlayer.setFilePath(tFilePath),
    ).thenAnswer((_) async => tDuration);
    // Act
    await durationRetriever.getDuration(tFilePath);
    // Assert
    verify(mockAudioPlayer.dispose()).called(1);
  });

  test(
    'should always call player.dispose even on failure (e.g., null duration)',
    () async {
      // Arrange
      when(
        mockAudioPlayer.setFilePath(tFilePath),
      ).thenAnswer((_) async => null);
      // Act
      try {
        await durationRetriever.getDuration(tFilePath);
      } catch (_) {}
      // Assert
      verify(mockAudioPlayer.dispose()).called(1);
    },
  );

  test('should always call player.dispose even on PlayerException', () async {
    // Arrange
    final playerException = PlayerException(404, 'File not found by player');
    when(mockAudioPlayer.setFilePath(tFilePath)).thenThrow(playerException);
    // Act
    try {
      await durationRetriever.getDuration(tFilePath);
    } catch (_) {}
    // Assert
    verify(mockAudioPlayer.dispose()).called(1);
  });
}
