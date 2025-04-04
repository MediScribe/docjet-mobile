import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus;

// Import interfaces and exceptions
import 'package:docjet_mobile/core/platform/permission_handler.dart';
import 'package:docjet_mobile/features/audio_recorder/data/datasources/audio_local_data_source_impl.dart';
import 'package:docjet_mobile/features/audio_recorder/data/exceptions/audio_exceptions.dart';
// Import interfaces needed for the DataSource constructor, even if not directly mocked/used here
import 'package:record/record.dart';
import 'package:docjet_mobile/core/platform/file_system.dart';
import 'package:docjet_mobile/core/platform/path_provider.dart';
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_getter.dart';

// Import generated mocks (will be generated for this file)
import 'audio_local_data_source_impl_permission_test.mocks.dart';

// Generate mocks ONLY for what's needed in these tests + DataSource dependencies
@GenerateNiceMocks([
  MockSpec<PermissionHandler>(),
  // Add mocks for unused dependencies required by constructor
  MockSpec<AudioRecorder>(),
  MockSpec<FileSystem>(),
  MockSpec<PathProvider>(),
  MockSpec<AudioDurationGetter>(),
])
void main() {
  late AudioLocalDataSourceImpl dataSource;
  late MockPermissionHandler mockPermissionHandler;
  // Declare mocks for unused dependencies
  late MockAudioRecorder mockAudioRecorder;
  late MockFileSystem mockFileSystem;
  late MockPathProvider mockPathProvider;
  late MockAudioDurationGetter mockAudioDurationGetter;

  final tPermission = Permission.microphone;

  setUp(() {
    mockPermissionHandler = MockPermissionHandler();
    // Instantiate unused mocks
    mockAudioRecorder = MockAudioRecorder();
    mockFileSystem = MockFileSystem();
    mockPathProvider = MockPathProvider();
    mockAudioDurationGetter = MockAudioDurationGetter();

    dataSource = AudioLocalDataSourceImpl(
      recorder: mockAudioRecorder, // Provide unused mock
      fileSystem: mockFileSystem, // Provide unused mock
      pathProvider: mockPathProvider, // Provide unused mock
      permissionHandler: mockPermissionHandler, // Provide used mock
      audioDurationGetter: mockAudioDurationGetter, // Provide unused mock
    );
  });

  group('checkPermission', () {
    test(
      'should return true when permission handler status is granted',
      () async {
        // Arrange
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.granted);
        // Act
        final result = await dataSource.checkPermission();
        // Assert
        expect(result, isTrue);
        verify(mockPermissionHandler.status(tPermission));
      },
    );

    test(
      'should return false when permission handler status is denied',
      () async {
        // Arrange
        when(
          mockPermissionHandler.status(tPermission),
        ).thenAnswer((_) async => PermissionStatus.denied);
        // Act
        final result = await dataSource.checkPermission();
        // Assert
        expect(result, isFalse);
        verify(mockPermissionHandler.status(tPermission));
      },
    );

    test(
      'should throw AudioPermissionException when permission handler status throws',
      () async {
        // Arrange
        final exception = Exception('Handler error');
        when(mockPermissionHandler.status(tPermission)).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.checkPermission(),
          throwsA(isA<AudioPermissionException>()),
        );
        verify(mockPermissionHandler.status(tPermission));
      },
    );
  });

  group('requestPermission', () {
    test('should return true when permission request is granted', () async {
      // Arrange
      when(
        mockPermissionHandler.request([tPermission]),
      ).thenAnswer((_) async => {tPermission: PermissionStatus.granted});
      // Act
      final result = await dataSource.requestPermission();
      // Assert
      expect(result, isTrue);
      verify(mockPermissionHandler.request([tPermission]));
    });

    test('should return false when permission request is denied', () async {
      // Arrange
      when(
        mockPermissionHandler.request([tPermission]),
      ).thenAnswer((_) async => {tPermission: PermissionStatus.denied});
      // Act
      final result = await dataSource.requestPermission();
      // Assert
      expect(result, isFalse);
      verify(mockPermissionHandler.request([tPermission]));
    });

    test(
      'should throw AudioPermissionException when permission request throws',
      () async {
        // Arrange
        final exception = Exception('Request failed');
        when(mockPermissionHandler.request([tPermission])).thenThrow(exception);
        // Act & Assert
        expect(
          () => dataSource.requestPermission(),
          throwsA(isA<AudioPermissionException>()),
        );
        verify(mockPermissionHandler.request([tPermission]));
      },
    );
  });
}
