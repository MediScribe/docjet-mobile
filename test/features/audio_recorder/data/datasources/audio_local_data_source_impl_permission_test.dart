import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus;

// Import interfaces and exceptions
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/core/platform/permission_handler.dart'
    as custom_ph;
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_getter.dart';
// Import the new service interface
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart';
// Import interfaces needed for the DataSource constructor, even if not directly mocked/used here
import 'package:record/record.dart';

// Import generated mocks (will be generated for this file)
import 'audio_local_data_source_impl_permission_test.mocks.dart';

// Generate mocks ONLY for PermissionHandler and unused DataSource dependencies
@GenerateNiceMocks([
  MockSpec<AudioRecorder>(),
  MockSpec<custom_ph.PermissionHandler>(as: #MockPermissionHandler),
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<AudioDurationGetter>(),
  MockSpec<AudioConcatenationService>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioLocalDataSourceImpl dataSource;
  late MockPermissionHandler mockPermissionHandler;
  late MockAudioRecorder mockAudioRecorder;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockAudioDurationGetter mockAudioDurationGetter;
  late MockAudioConcatenationService mockAudioConcatenationService;

  const tPermission = Permission.microphone;

  setUp(() {
    mockPermissionHandler = MockPermissionHandler();
    mockAudioRecorder = MockAudioRecorder();
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockAudioDurationGetter = MockAudioDurationGetter();
    mockAudioConcatenationService = MockAudioConcatenationService();

    dataSource = AudioLocalDataSourceImpl(
      recorder: mockAudioRecorder,
      fileSystem: mockFileSystem,
      pathProvider: mockPathProvider,
      permissionHandler: mockPermissionHandler,
      audioDurationGetter: mockAudioDurationGetter,
      audioConcatenationService: mockAudioConcatenationService,
    );
  });

  group('checkPermission', () {
    test(
      'should return true when recorder.hasPermission returns true',
      () async {
        when(mockAudioRecorder.hasPermission()).thenAnswer((_) async => true);
        final result = await dataSource.checkPermission();
        expect(result, isTrue);
        verify(mockAudioRecorder.hasPermission());
        verifyNever(mockPermissionHandler.status(any));
      },
    );

    test(
      'should check handler status when recorder.hasPermission is false and return true if handler status is granted',
      () async {
        when(mockAudioRecorder.hasPermission()).thenAnswer((_) async => false);
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.granted);
        final result = await dataSource.checkPermission();
        verify(mockAudioRecorder.hasPermission());
        verify(mockPermissionHandler.status(tPermission));
        expect(result, isTrue);
      },
    );

    test(
      'should check handler status when recorder.hasPermission is false and return false if handler status is not granted',
      () async {
        when(mockAudioRecorder.hasPermission()).thenAnswer((_) async => false);
        final result = await dataSource.checkPermission();
        verify(mockAudioRecorder.hasPermission());
        expect(result, isFalse);
      },
    );

    test(
      'should throw AudioPermissionException when recorder.hasPermission throws',
      () async {
        final exception = Exception('Recorder error');
        when(mockAudioRecorder.hasPermission()).thenThrow(exception);
        expect(
          () => dataSource.checkPermission(),
          throwsA(isA<AudioPermissionException>()),
        );
        verify(mockAudioRecorder.hasPermission());
        verifyNever(mockPermissionHandler.status(any));
      },
    );
  });

  group('requestPermission', () {
    test('should return true when permission request is granted', () async {
      when(
        mockPermissionHandler.request([tPermission]),
      ).thenAnswer((_) async => {tPermission: PermissionStatus.granted});
      final result = await dataSource.requestPermission();
      expect(result, isTrue);
      verify(mockPermissionHandler.request([tPermission]));
    });

    test('should return false when permission request is denied', () async {
      when(
        mockPermissionHandler.request([tPermission]),
      ).thenAnswer((_) async => {tPermission: PermissionStatus.denied});
      final result = await dataSource.requestPermission();
      expect(result, isFalse);
      verify(mockPermissionHandler.request([tPermission]));
    });

    test(
      'should throw AudioPermissionException when permission request throws',
      () async {
        final exception = Exception('Request failed');
        when(mockPermissionHandler.request([tPermission])).thenThrow(exception);
        expect(
          () => dataSource.requestPermission(),
          throwsA(isA<AudioPermissionException>()),
        );
        verify(mockPermissionHandler.request([tPermission]));
      },
    );
  });
}
