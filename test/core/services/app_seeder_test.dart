import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/services/app_seeder.dart';
import 'package:docjet_mobile/core/utils/logger.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_retriever.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generate mocks for the dependencies
@GenerateMocks([
  LocalJobStore,
  PathProvider,
  FileSystem,
  AudioDurationRetriever,
  SharedPreferences,
])
import 'app_seeder_test.mocks.dart';

void main() {
  late MockLocalJobStore mockLocalJobStore;
  late MockPathProvider mockPathProvider;
  late MockFileSystem mockFileSystem;
  late MockAudioDurationRetriever mockAudioDurationRetriever;
  late MockSharedPreferences mockSharedPreferences;
  late AppSeeder appSeeder;

  // --- Test Constants ---
  const seedingDoneKey = 'app_seeding_done_v1';

  setUp(() {
    // Set logger level to off for tests
    setLogLevel(Level.off);

    // Create fresh mocks for each test
    mockLocalJobStore = MockLocalJobStore();
    mockPathProvider = MockPathProvider();
    mockFileSystem = MockFileSystem();
    mockAudioDurationRetriever = MockAudioDurationRetriever();
    mockSharedPreferences = MockSharedPreferences();

    // Instantiate the AppSeeder with mocks
    appSeeder = AppSeeder(
      localJobStore: mockLocalJobStore,
      pathProvider: mockPathProvider,
      fileSystem: mockFileSystem,
      audioDurationRetriever: mockAudioDurationRetriever,
      sharedPreferences: mockSharedPreferences,
    );
  });

  group('AppSeeder', () {
    test(
      'seedInitialDataIfNeeded should return immediately if seeding is already marked as done',
      () async {
        // Arrange: Configure SharedPreferences mock to indicate seeding is done
        when(mockSharedPreferences.getBool(seedingDoneKey)).thenReturn(true);

        // Act: Call the method under test
        await appSeeder.seedInitialDataIfNeeded();

        // Assert: Verify that no other dependencies were interacted with
        verify(mockSharedPreferences.getBool(seedingDoneKey)).called(1);
        verifyNoMoreInteractions(mockSharedPreferences);
        verifyZeroInteractions(mockLocalJobStore);
        verifyZeroInteractions(mockPathProvider);
        verifyZeroInteractions(mockFileSystem);
        verifyZeroInteractions(mockAudioDurationRetriever);
      },
    );

    // TODO: Add more tests later for the actual seeding logic when not done
    // test('seedInitialDataIfNeeded should copy asset and create LocalJob if seeding not done', () async { ... });
  });
}
