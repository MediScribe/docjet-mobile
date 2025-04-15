// Import interfaces and exceptions
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
// Import the new service interfaces needed for constructor
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/adapters/audio_player_adapter.dart';
import 'package:docjet_mobile/features/audio_recorder/domain/repositories/local_job_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart';

// Import generated mocks (will be generated for this file)
import 'audio_local_data_source_impl_permission_test.mocks.dart';

// Define mocks for dependencies
@GenerateNiceMocks([
  MockSpec<AudioRecorder>(),
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<PermissionHandler>(), // Mock OUR interface
  MockSpec<AudioConcatenationService>(),
  MockSpec<LocalJobStore>(),
  MockSpec<AudioPlayerAdapter>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioLocalDataSourceImpl dataSource;
  late MockAudioRecorder mockRecorder;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockPermissionHandler mockPermissionHandler; // Mock for our interface
  late MockAudioConcatenationService mockConcatenationService;
  late MockLocalJobStore mockLocalJobStore;

  // Use the aliased type from the package for constants
  const tPermission = ph.Permission.microphone;

  setUp(() {
    mockRecorder = MockAudioRecorder();
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockPermissionHandler = MockPermissionHandler();
    mockConcatenationService = MockAudioConcatenationService();
    mockLocalJobStore = MockLocalJobStore();
    final mockAudioPlayerAdapter = MockAudioPlayerAdapter();

    dataSource = AudioLocalDataSourceImpl(
      recorder: mockRecorder,
      fileSystem: mockFileSystem,
      pathProvider: mockPathProvider,
      permissionHandler: mockPermissionHandler,
      audioConcatenationService: mockConcatenationService,
      localJobStore: mockLocalJobStore,
      audioPlayerAdapter: mockAudioPlayerAdapter,
    );
  });

  group('Permission Checks', () {
    group('checkPermission', () {
      test(
        'should return true when recorder.hasPermission returns true',
        () async {
          when(mockRecorder.hasPermission()).thenAnswer((_) async => true);
          final result = await dataSource.checkPermission();
          expect(result, isTrue);
          verify(mockRecorder.hasPermission());
          verifyNever(mockPermissionHandler.status(any));
        },
      );

      test(
        'should check handler status when recorder.hasPermission is false and return true if handler status is granted',
        () async {
          when(mockRecorder.hasPermission()).thenAnswer((_) async => false);
          when(
            mockPermissionHandler.status(tPermission), // Use our interface mock
          ).thenAnswer(
            (_) async => ph.PermissionStatus.granted,
          ); // Use package enum

          final result = await dataSource.checkPermission();
          verify(mockRecorder.hasPermission());
          expect(result, isTrue);
        },
      );

      test(
        'should check handler status when recorder.hasPermission is false and return false if handler status is not granted',
        () async {
          when(mockRecorder.hasPermission()).thenAnswer((_) async => false);
          when(
            mockPermissionHandler.status(tPermission), // Use our interface mock
          ).thenAnswer(
            (_) async => ph.PermissionStatus.denied,
          ); // Use package enum (not granted)

          final result = await dataSource.checkPermission();
          verify(mockRecorder.hasPermission());
          expect(result, isFalse);
        },
      );

      test(
        'should throw AudioPermissionException if recorder.hasPermission throws',
        () async {
          final exception = Exception('Recorder error');
          when(mockRecorder.hasPermission()).thenThrow(exception);

          expect(
            () => dataSource.checkPermission(),
            throwsA(isA<AudioPermissionException>()),
          );
          verify(mockRecorder.hasPermission());
        },
      );

      test(
        'should throw AudioPermissionException if handler.status throws',
        () async {
          final exception = Exception('Handler error');
          when(mockRecorder.hasPermission()).thenAnswer((_) async => false);
          when(
            mockPermissionHandler.status(tPermission),
          ).thenAnswer((_) => Future.error(exception));

          // Act: Use try/catch in the test
          Future<void> action() async {
            // Verify the status call is ATTEMPTED before the overall function throws
            // This requires waiting for the call, even if it throws immediately
            await untilCalled(mockPermissionHandler.status(tPermission));
            verify(mockPermissionHandler.status(tPermission));
          }

          expectLater(
            dataSource.checkPermission(),
            throwsA(isA<AudioPermissionException>()),
          );

          // Ensure the mock interaction verification happens
          await action();

          // Verify the initial recorder check also happened
          verify(mockRecorder.hasPermission());
        },
      );
    });

    group('requestPermission', () {
      test('should return true when handler.request returns granted', () async {
        // Arrange
        when(
          mockPermissionHandler.request([
            tPermission,
          ]), // Use our interface mock
        ).thenAnswer(
          (_) async => {
            tPermission: ph.PermissionStatus.granted, // Use package enum
          },
        );

        // Act
        final result = await dataSource.requestPermission();

        // Assert
        expect(result, isTrue);
        verify(mockPermissionHandler.request([tPermission]));
      });

      test(
        'should return false when handler.request returns not granted',
        () async {
          // Arrange
          when(
            mockPermissionHandler.request([
              tPermission,
            ]), // Use our interface mock
          ).thenAnswer(
            (_) async => {
              tPermission: ph.PermissionStatus.denied, // Use package enum
            },
          );

          // Act
          final result = await dataSource.requestPermission();

          // Assert
          expect(result, isFalse);
          verify(mockPermissionHandler.request([tPermission]));
        },
      );

      test(
        'should throw AudioPermissionException when handler.request throws',
        () async {
          // Arrange
          final exception = Exception('Request failed');
          when(
            mockPermissionHandler.request([
              tPermission,
            ]), // Use our interface mock
          ).thenThrow(exception);

          // Act & Assert
          expect(
            () => dataSource.requestPermission(),
            throwsA(isA<AudioPermissionException>()),
          );
          verify(mockPermissionHandler.request([tPermission]));
        },
      );
    });
  });
}
