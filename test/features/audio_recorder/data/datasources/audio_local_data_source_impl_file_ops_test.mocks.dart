// Mocks generated by Mockito 5.4.5 from annotations
// in docjet_mobile/test/features/audio_recorder/data/datasources/audio_local_data_source_impl_file_ops_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:io' as _i2;
import 'dart:typed_data' as _i10;

import 'package:docjet_mobile/core/platform/file_system.dart' as _i4;
import 'package:docjet_mobile/core/platform/path_provider.dart' as _i6;
import 'package:docjet_mobile/core/platform/permission_handler.dart' as _i11;
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_concatenation_service.dart'
    as _i13;
import 'package:docjet_mobile/features/audio_recorder/data/services/audio_duration_getter.dart'
    as _i7;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i8;
import 'package:permission_handler/permission_handler.dart' as _i12;
import 'package:record/src/record.dart' as _i9;
import 'package:record_platform_interface/record_platform_interface.dart'
    as _i3;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeFileStat_0 extends _i1.SmartFake implements _i2.FileStat {
  _FakeFileStat_0(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeDirectory_1 extends _i1.SmartFake implements _i2.Directory {
  _FakeDirectory_1(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeDuration_2 extends _i1.SmartFake implements Duration {
  _FakeDuration_2(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeUri_3 extends _i1.SmartFake implements Uri {
  _FakeUri_3(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeFileSystemEntity_4 extends _i1.SmartFake
    implements _i2.FileSystemEntity {
  _FakeFileSystemEntity_4(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeDateTime_5 extends _i1.SmartFake implements DateTime {
  _FakeDateTime_5(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeAmplitude_6 extends _i1.SmartFake implements _i3.Amplitude {
  _FakeAmplitude_6(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

/// A class which mocks [FileSystem].
///
/// See the documentation for Mockito's code generation for more information.
class MockFileSystem extends _i1.Mock implements _i4.FileSystem {
  @override
  _i5.Future<_i2.FileStat> stat(String? path) =>
      (super.noSuchMethod(
            Invocation.method(#stat, [path]),
            returnValue: _i5.Future<_i2.FileStat>.value(
              _FakeFileStat_0(this, Invocation.method(#stat, [path])),
            ),
            returnValueForMissingStub: _i5.Future<_i2.FileStat>.value(
              _FakeFileStat_0(this, Invocation.method(#stat, [path])),
            ),
          )
          as _i5.Future<_i2.FileStat>);

  @override
  _i5.Future<bool> fileExists(String? path) =>
      (super.noSuchMethod(
            Invocation.method(#fileExists, [path]),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  _i5.Future<void> deleteFile(String? path) =>
      (super.noSuchMethod(
            Invocation.method(#deleteFile, [path]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<bool> directoryExists(String? path) =>
      (super.noSuchMethod(
            Invocation.method(#directoryExists, [path]),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  _i5.Future<void> createDirectory(String? path, {bool? recursive = false}) =>
      (super.noSuchMethod(
            Invocation.method(
              #createDirectory,
              [path],
              {#recursive: recursive},
            ),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Stream<_i2.FileSystemEntity> listDirectory(String? path) =>
      (super.noSuchMethod(
            Invocation.method(#listDirectory, [path]),
            returnValue: _i5.Stream<_i2.FileSystemEntity>.empty(),
            returnValueForMissingStub: _i5.Stream<_i2.FileSystemEntity>.empty(),
          )
          as _i5.Stream<_i2.FileSystemEntity>);

  @override
  List<_i2.FileSystemEntity> listDirectorySync(String? path) =>
      (super.noSuchMethod(
            Invocation.method(#listDirectorySync, [path]),
            returnValue: <_i2.FileSystemEntity>[],
            returnValueForMissingStub: <_i2.FileSystemEntity>[],
          )
          as List<_i2.FileSystemEntity>);
}

/// A class which mocks [PathProvider].
///
/// See the documentation for Mockito's code generation for more information.
class MockPathProvider extends _i1.Mock implements _i6.PathProvider {
  @override
  _i5.Future<_i2.Directory> getApplicationDocumentsDirectory() =>
      (super.noSuchMethod(
            Invocation.method(#getApplicationDocumentsDirectory, []),
            returnValue: _i5.Future<_i2.Directory>.value(
              _FakeDirectory_1(
                this,
                Invocation.method(#getApplicationDocumentsDirectory, []),
              ),
            ),
            returnValueForMissingStub: _i5.Future<_i2.Directory>.value(
              _FakeDirectory_1(
                this,
                Invocation.method(#getApplicationDocumentsDirectory, []),
              ),
            ),
          )
          as _i5.Future<_i2.Directory>);
}

/// A class which mocks [AudioDurationGetter].
///
/// See the documentation for Mockito's code generation for more information.
class MockAudioDurationGetter extends _i1.Mock
    implements _i7.AudioDurationGetter {
  @override
  _i5.Future<Duration> getDuration(String? filePath) =>
      (super.noSuchMethod(
            Invocation.method(#getDuration, [filePath]),
            returnValue: _i5.Future<Duration>.value(
              _FakeDuration_2(
                this,
                Invocation.method(#getDuration, [filePath]),
              ),
            ),
            returnValueForMissingStub: _i5.Future<Duration>.value(
              _FakeDuration_2(
                this,
                Invocation.method(#getDuration, [filePath]),
              ),
            ),
          )
          as _i5.Future<Duration>);
}

/// A class which mocks [Directory].
///
/// See the documentation for Mockito's code generation for more information.
class MockDirectory extends _i1.Mock implements _i2.Directory {
  @override
  String get path =>
      (super.noSuchMethod(
            Invocation.getter(#path),
            returnValue: _i8.dummyValue<String>(this, Invocation.getter(#path)),
            returnValueForMissingStub: _i8.dummyValue<String>(
              this,
              Invocation.getter(#path),
            ),
          )
          as String);

  @override
  Uri get uri =>
      (super.noSuchMethod(
            Invocation.getter(#uri),
            returnValue: _FakeUri_3(this, Invocation.getter(#uri)),
            returnValueForMissingStub: _FakeUri_3(
              this,
              Invocation.getter(#uri),
            ),
          )
          as Uri);

  @override
  _i2.Directory get absolute =>
      (super.noSuchMethod(
            Invocation.getter(#absolute),
            returnValue: _FakeDirectory_1(this, Invocation.getter(#absolute)),
            returnValueForMissingStub: _FakeDirectory_1(
              this,
              Invocation.getter(#absolute),
            ),
          )
          as _i2.Directory);

  @override
  bool get isAbsolute =>
      (super.noSuchMethod(
            Invocation.getter(#isAbsolute),
            returnValue: false,
            returnValueForMissingStub: false,
          )
          as bool);

  @override
  _i2.Directory get parent =>
      (super.noSuchMethod(
            Invocation.getter(#parent),
            returnValue: _FakeDirectory_1(this, Invocation.getter(#parent)),
            returnValueForMissingStub: _FakeDirectory_1(
              this,
              Invocation.getter(#parent),
            ),
          )
          as _i2.Directory);

  @override
  _i5.Future<_i2.Directory> create({bool? recursive = false}) =>
      (super.noSuchMethod(
            Invocation.method(#create, [], {#recursive: recursive}),
            returnValue: _i5.Future<_i2.Directory>.value(
              _FakeDirectory_1(
                this,
                Invocation.method(#create, [], {#recursive: recursive}),
              ),
            ),
            returnValueForMissingStub: _i5.Future<_i2.Directory>.value(
              _FakeDirectory_1(
                this,
                Invocation.method(#create, [], {#recursive: recursive}),
              ),
            ),
          )
          as _i5.Future<_i2.Directory>);

  @override
  void createSync({bool? recursive = false}) => super.noSuchMethod(
    Invocation.method(#createSync, [], {#recursive: recursive}),
    returnValueForMissingStub: null,
  );

  @override
  _i5.Future<_i2.Directory> createTemp([String? prefix]) =>
      (super.noSuchMethod(
            Invocation.method(#createTemp, [prefix]),
            returnValue: _i5.Future<_i2.Directory>.value(
              _FakeDirectory_1(this, Invocation.method(#createTemp, [prefix])),
            ),
            returnValueForMissingStub: _i5.Future<_i2.Directory>.value(
              _FakeDirectory_1(this, Invocation.method(#createTemp, [prefix])),
            ),
          )
          as _i5.Future<_i2.Directory>);

  @override
  _i2.Directory createTempSync([String? prefix]) =>
      (super.noSuchMethod(
            Invocation.method(#createTempSync, [prefix]),
            returnValue: _FakeDirectory_1(
              this,
              Invocation.method(#createTempSync, [prefix]),
            ),
            returnValueForMissingStub: _FakeDirectory_1(
              this,
              Invocation.method(#createTempSync, [prefix]),
            ),
          )
          as _i2.Directory);

  @override
  _i5.Future<String> resolveSymbolicLinks() =>
      (super.noSuchMethod(
            Invocation.method(#resolveSymbolicLinks, []),
            returnValue: _i5.Future<String>.value(
              _i8.dummyValue<String>(
                this,
                Invocation.method(#resolveSymbolicLinks, []),
              ),
            ),
            returnValueForMissingStub: _i5.Future<String>.value(
              _i8.dummyValue<String>(
                this,
                Invocation.method(#resolveSymbolicLinks, []),
              ),
            ),
          )
          as _i5.Future<String>);

  @override
  String resolveSymbolicLinksSync() =>
      (super.noSuchMethod(
            Invocation.method(#resolveSymbolicLinksSync, []),
            returnValue: _i8.dummyValue<String>(
              this,
              Invocation.method(#resolveSymbolicLinksSync, []),
            ),
            returnValueForMissingStub: _i8.dummyValue<String>(
              this,
              Invocation.method(#resolveSymbolicLinksSync, []),
            ),
          )
          as String);

  @override
  _i5.Future<_i2.Directory> rename(String? newPath) =>
      (super.noSuchMethod(
            Invocation.method(#rename, [newPath]),
            returnValue: _i5.Future<_i2.Directory>.value(
              _FakeDirectory_1(this, Invocation.method(#rename, [newPath])),
            ),
            returnValueForMissingStub: _i5.Future<_i2.Directory>.value(
              _FakeDirectory_1(this, Invocation.method(#rename, [newPath])),
            ),
          )
          as _i5.Future<_i2.Directory>);

  @override
  _i2.Directory renameSync(String? newPath) =>
      (super.noSuchMethod(
            Invocation.method(#renameSync, [newPath]),
            returnValue: _FakeDirectory_1(
              this,
              Invocation.method(#renameSync, [newPath]),
            ),
            returnValueForMissingStub: _FakeDirectory_1(
              this,
              Invocation.method(#renameSync, [newPath]),
            ),
          )
          as _i2.Directory);

  @override
  _i5.Future<_i2.FileSystemEntity> delete({bool? recursive = false}) =>
      (super.noSuchMethod(
            Invocation.method(#delete, [], {#recursive: recursive}),
            returnValue: _i5.Future<_i2.FileSystemEntity>.value(
              _FakeFileSystemEntity_4(
                this,
                Invocation.method(#delete, [], {#recursive: recursive}),
              ),
            ),
            returnValueForMissingStub: _i5.Future<_i2.FileSystemEntity>.value(
              _FakeFileSystemEntity_4(
                this,
                Invocation.method(#delete, [], {#recursive: recursive}),
              ),
            ),
          )
          as _i5.Future<_i2.FileSystemEntity>);

  @override
  void deleteSync({bool? recursive = false}) => super.noSuchMethod(
    Invocation.method(#deleteSync, [], {#recursive: recursive}),
    returnValueForMissingStub: null,
  );

  @override
  _i5.Stream<_i2.FileSystemEntity> list({
    bool? recursive = false,
    bool? followLinks = true,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#list, [], {
              #recursive: recursive,
              #followLinks: followLinks,
            }),
            returnValue: _i5.Stream<_i2.FileSystemEntity>.empty(),
            returnValueForMissingStub: _i5.Stream<_i2.FileSystemEntity>.empty(),
          )
          as _i5.Stream<_i2.FileSystemEntity>);

  @override
  List<_i2.FileSystemEntity> listSync({
    bool? recursive = false,
    bool? followLinks = true,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#listSync, [], {
              #recursive: recursive,
              #followLinks: followLinks,
            }),
            returnValue: <_i2.FileSystemEntity>[],
            returnValueForMissingStub: <_i2.FileSystemEntity>[],
          )
          as List<_i2.FileSystemEntity>);

  @override
  _i5.Future<bool> exists() =>
      (super.noSuchMethod(
            Invocation.method(#exists, []),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  bool existsSync() =>
      (super.noSuchMethod(
            Invocation.method(#existsSync, []),
            returnValue: false,
            returnValueForMissingStub: false,
          )
          as bool);

  @override
  _i5.Future<_i2.FileStat> stat() =>
      (super.noSuchMethod(
            Invocation.method(#stat, []),
            returnValue: _i5.Future<_i2.FileStat>.value(
              _FakeFileStat_0(this, Invocation.method(#stat, [])),
            ),
            returnValueForMissingStub: _i5.Future<_i2.FileStat>.value(
              _FakeFileStat_0(this, Invocation.method(#stat, [])),
            ),
          )
          as _i5.Future<_i2.FileStat>);

  @override
  _i2.FileStat statSync() =>
      (super.noSuchMethod(
            Invocation.method(#statSync, []),
            returnValue: _FakeFileStat_0(
              this,
              Invocation.method(#statSync, []),
            ),
            returnValueForMissingStub: _FakeFileStat_0(
              this,
              Invocation.method(#statSync, []),
            ),
          )
          as _i2.FileStat);

  @override
  _i5.Stream<_i2.FileSystemEvent> watch({
    int? events = 15,
    bool? recursive = false,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#watch, [], {
              #events: events,
              #recursive: recursive,
            }),
            returnValue: _i5.Stream<_i2.FileSystemEvent>.empty(),
            returnValueForMissingStub: _i5.Stream<_i2.FileSystemEvent>.empty(),
          )
          as _i5.Stream<_i2.FileSystemEvent>);
}

/// A class which mocks [FileStat].
///
/// See the documentation for Mockito's code generation for more information.
class MockFileStat extends _i1.Mock implements _i2.FileStat {
  @override
  DateTime get changed =>
      (super.noSuchMethod(
            Invocation.getter(#changed),
            returnValue: _FakeDateTime_5(this, Invocation.getter(#changed)),
            returnValueForMissingStub: _FakeDateTime_5(
              this,
              Invocation.getter(#changed),
            ),
          )
          as DateTime);

  @override
  DateTime get modified =>
      (super.noSuchMethod(
            Invocation.getter(#modified),
            returnValue: _FakeDateTime_5(this, Invocation.getter(#modified)),
            returnValueForMissingStub: _FakeDateTime_5(
              this,
              Invocation.getter(#modified),
            ),
          )
          as DateTime);

  @override
  DateTime get accessed =>
      (super.noSuchMethod(
            Invocation.getter(#accessed),
            returnValue: _FakeDateTime_5(this, Invocation.getter(#accessed)),
            returnValueForMissingStub: _FakeDateTime_5(
              this,
              Invocation.getter(#accessed),
            ),
          )
          as DateTime);

  @override
  _i2.FileSystemEntityType get type =>
      (super.noSuchMethod(
            Invocation.getter(#type),
            returnValue: _i8.dummyValue<_i2.FileSystemEntityType>(
              this,
              Invocation.getter(#type),
            ),
            returnValueForMissingStub: _i8.dummyValue<_i2.FileSystemEntityType>(
              this,
              Invocation.getter(#type),
            ),
          )
          as _i2.FileSystemEntityType);

  @override
  int get mode =>
      (super.noSuchMethod(
            Invocation.getter(#mode),
            returnValue: 0,
            returnValueForMissingStub: 0,
          )
          as int);

  @override
  int get size =>
      (super.noSuchMethod(
            Invocation.getter(#size),
            returnValue: 0,
            returnValueForMissingStub: 0,
          )
          as int);

  @override
  String modeString() =>
      (super.noSuchMethod(
            Invocation.method(#modeString, []),
            returnValue: _i8.dummyValue<String>(
              this,
              Invocation.method(#modeString, []),
            ),
            returnValueForMissingStub: _i8.dummyValue<String>(
              this,
              Invocation.method(#modeString, []),
            ),
          )
          as String);
}

/// A class which mocks [FileSystemEntity].
///
/// See the documentation for Mockito's code generation for more information.
class MockFileSystemEntity extends _i1.Mock implements _i2.FileSystemEntity {
  @override
  String get path =>
      (super.noSuchMethod(
            Invocation.getter(#path),
            returnValue: _i8.dummyValue<String>(this, Invocation.getter(#path)),
            returnValueForMissingStub: _i8.dummyValue<String>(
              this,
              Invocation.getter(#path),
            ),
          )
          as String);

  @override
  Uri get uri =>
      (super.noSuchMethod(
            Invocation.getter(#uri),
            returnValue: _FakeUri_3(this, Invocation.getter(#uri)),
            returnValueForMissingStub: _FakeUri_3(
              this,
              Invocation.getter(#uri),
            ),
          )
          as Uri);

  @override
  bool get isAbsolute =>
      (super.noSuchMethod(
            Invocation.getter(#isAbsolute),
            returnValue: false,
            returnValueForMissingStub: false,
          )
          as bool);

  @override
  _i2.FileSystemEntity get absolute =>
      (super.noSuchMethod(
            Invocation.getter(#absolute),
            returnValue: _FakeFileSystemEntity_4(
              this,
              Invocation.getter(#absolute),
            ),
            returnValueForMissingStub: _FakeFileSystemEntity_4(
              this,
              Invocation.getter(#absolute),
            ),
          )
          as _i2.FileSystemEntity);

  @override
  _i2.Directory get parent =>
      (super.noSuchMethod(
            Invocation.getter(#parent),
            returnValue: _FakeDirectory_1(this, Invocation.getter(#parent)),
            returnValueForMissingStub: _FakeDirectory_1(
              this,
              Invocation.getter(#parent),
            ),
          )
          as _i2.Directory);

  @override
  _i5.Future<bool> exists() =>
      (super.noSuchMethod(
            Invocation.method(#exists, []),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  bool existsSync() =>
      (super.noSuchMethod(
            Invocation.method(#existsSync, []),
            returnValue: false,
            returnValueForMissingStub: false,
          )
          as bool);

  @override
  _i5.Future<_i2.FileSystemEntity> rename(String? newPath) =>
      (super.noSuchMethod(
            Invocation.method(#rename, [newPath]),
            returnValue: _i5.Future<_i2.FileSystemEntity>.value(
              _FakeFileSystemEntity_4(
                this,
                Invocation.method(#rename, [newPath]),
              ),
            ),
            returnValueForMissingStub: _i5.Future<_i2.FileSystemEntity>.value(
              _FakeFileSystemEntity_4(
                this,
                Invocation.method(#rename, [newPath]),
              ),
            ),
          )
          as _i5.Future<_i2.FileSystemEntity>);

  @override
  _i2.FileSystemEntity renameSync(String? newPath) =>
      (super.noSuchMethod(
            Invocation.method(#renameSync, [newPath]),
            returnValue: _FakeFileSystemEntity_4(
              this,
              Invocation.method(#renameSync, [newPath]),
            ),
            returnValueForMissingStub: _FakeFileSystemEntity_4(
              this,
              Invocation.method(#renameSync, [newPath]),
            ),
          )
          as _i2.FileSystemEntity);

  @override
  _i5.Future<String> resolveSymbolicLinks() =>
      (super.noSuchMethod(
            Invocation.method(#resolveSymbolicLinks, []),
            returnValue: _i5.Future<String>.value(
              _i8.dummyValue<String>(
                this,
                Invocation.method(#resolveSymbolicLinks, []),
              ),
            ),
            returnValueForMissingStub: _i5.Future<String>.value(
              _i8.dummyValue<String>(
                this,
                Invocation.method(#resolveSymbolicLinks, []),
              ),
            ),
          )
          as _i5.Future<String>);

  @override
  String resolveSymbolicLinksSync() =>
      (super.noSuchMethod(
            Invocation.method(#resolveSymbolicLinksSync, []),
            returnValue: _i8.dummyValue<String>(
              this,
              Invocation.method(#resolveSymbolicLinksSync, []),
            ),
            returnValueForMissingStub: _i8.dummyValue<String>(
              this,
              Invocation.method(#resolveSymbolicLinksSync, []),
            ),
          )
          as String);

  @override
  _i5.Future<_i2.FileStat> stat() =>
      (super.noSuchMethod(
            Invocation.method(#stat, []),
            returnValue: _i5.Future<_i2.FileStat>.value(
              _FakeFileStat_0(this, Invocation.method(#stat, [])),
            ),
            returnValueForMissingStub: _i5.Future<_i2.FileStat>.value(
              _FakeFileStat_0(this, Invocation.method(#stat, [])),
            ),
          )
          as _i5.Future<_i2.FileStat>);

  @override
  _i2.FileStat statSync() =>
      (super.noSuchMethod(
            Invocation.method(#statSync, []),
            returnValue: _FakeFileStat_0(
              this,
              Invocation.method(#statSync, []),
            ),
            returnValueForMissingStub: _FakeFileStat_0(
              this,
              Invocation.method(#statSync, []),
            ),
          )
          as _i2.FileStat);

  @override
  _i5.Future<_i2.FileSystemEntity> delete({bool? recursive = false}) =>
      (super.noSuchMethod(
            Invocation.method(#delete, [], {#recursive: recursive}),
            returnValue: _i5.Future<_i2.FileSystemEntity>.value(
              _FakeFileSystemEntity_4(
                this,
                Invocation.method(#delete, [], {#recursive: recursive}),
              ),
            ),
            returnValueForMissingStub: _i5.Future<_i2.FileSystemEntity>.value(
              _FakeFileSystemEntity_4(
                this,
                Invocation.method(#delete, [], {#recursive: recursive}),
              ),
            ),
          )
          as _i5.Future<_i2.FileSystemEntity>);

  @override
  void deleteSync({bool? recursive = false}) => super.noSuchMethod(
    Invocation.method(#deleteSync, [], {#recursive: recursive}),
    returnValueForMissingStub: null,
  );

  @override
  _i5.Stream<_i2.FileSystemEvent> watch({
    int? events = 15,
    bool? recursive = false,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#watch, [], {
              #events: events,
              #recursive: recursive,
            }),
            returnValue: _i5.Stream<_i2.FileSystemEvent>.empty(),
            returnValueForMissingStub: _i5.Stream<_i2.FileSystemEvent>.empty(),
          )
          as _i5.Stream<_i2.FileSystemEvent>);
}

/// A class which mocks [AudioRecorder].
///
/// See the documentation for Mockito's code generation for more information.
class MockAudioRecorder extends _i1.Mock implements _i9.AudioRecorder {
  @override
  _i5.Future<void> start(_i3.RecordConfig? config, {required String? path}) =>
      (super.noSuchMethod(
            Invocation.method(#start, [config], {#path: path}),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<_i5.Stream<_i10.Uint8List>> startStream(
    _i3.RecordConfig? config,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#startStream, [config]),
            returnValue: _i5.Future<_i5.Stream<_i10.Uint8List>>.value(
              _i5.Stream<_i10.Uint8List>.empty(),
            ),
            returnValueForMissingStub:
                _i5.Future<_i5.Stream<_i10.Uint8List>>.value(
                  _i5.Stream<_i10.Uint8List>.empty(),
                ),
          )
          as _i5.Future<_i5.Stream<_i10.Uint8List>>);

  @override
  _i5.Future<String?> stop() =>
      (super.noSuchMethod(
            Invocation.method(#stop, []),
            returnValue: _i5.Future<String?>.value(),
            returnValueForMissingStub: _i5.Future<String?>.value(),
          )
          as _i5.Future<String?>);

  @override
  _i5.Future<void> cancel() =>
      (super.noSuchMethod(
            Invocation.method(#cancel, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> pause() =>
      (super.noSuchMethod(
            Invocation.method(#pause, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> resume() =>
      (super.noSuchMethod(
            Invocation.method(#resume, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<bool> isRecording() =>
      (super.noSuchMethod(
            Invocation.method(#isRecording, []),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  _i5.Future<bool> isPaused() =>
      (super.noSuchMethod(
            Invocation.method(#isPaused, []),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  _i5.Future<bool> hasPermission() =>
      (super.noSuchMethod(
            Invocation.method(#hasPermission, []),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  _i5.Future<List<_i3.InputDevice>> listInputDevices() =>
      (super.noSuchMethod(
            Invocation.method(#listInputDevices, []),
            returnValue: _i5.Future<List<_i3.InputDevice>>.value(
              <_i3.InputDevice>[],
            ),
            returnValueForMissingStub: _i5.Future<List<_i3.InputDevice>>.value(
              <_i3.InputDevice>[],
            ),
          )
          as _i5.Future<List<_i3.InputDevice>>);

  @override
  _i5.Future<_i3.Amplitude> getAmplitude() =>
      (super.noSuchMethod(
            Invocation.method(#getAmplitude, []),
            returnValue: _i5.Future<_i3.Amplitude>.value(
              _FakeAmplitude_6(this, Invocation.method(#getAmplitude, [])),
            ),
            returnValueForMissingStub: _i5.Future<_i3.Amplitude>.value(
              _FakeAmplitude_6(this, Invocation.method(#getAmplitude, [])),
            ),
          )
          as _i5.Future<_i3.Amplitude>);

  @override
  _i5.Future<bool> isEncoderSupported(_i3.AudioEncoder? encoder) =>
      (super.noSuchMethod(
            Invocation.method(#isEncoderSupported, [encoder]),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  _i5.Future<void> dispose() =>
      (super.noSuchMethod(
            Invocation.method(#dispose, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Stream<_i3.RecordState> onStateChanged() =>
      (super.noSuchMethod(
            Invocation.method(#onStateChanged, []),
            returnValue: _i5.Stream<_i3.RecordState>.empty(),
            returnValueForMissingStub: _i5.Stream<_i3.RecordState>.empty(),
          )
          as _i5.Stream<_i3.RecordState>);

  @override
  _i5.Stream<_i3.Amplitude> onAmplitudeChanged(Duration? interval) =>
      (super.noSuchMethod(
            Invocation.method(#onAmplitudeChanged, [interval]),
            returnValue: _i5.Stream<_i3.Amplitude>.empty(),
            returnValueForMissingStub: _i5.Stream<_i3.Amplitude>.empty(),
          )
          as _i5.Stream<_i3.Amplitude>);

  @override
  List<int> convertBytesToInt16(
    _i10.Uint8List? bytes, [
    dynamic endian = _i10.Endian.little,
  ]) =>
      (super.noSuchMethod(
            Invocation.method(#convertBytesToInt16, [bytes, endian]),
            returnValue: <int>[],
            returnValueForMissingStub: <int>[],
          )
          as List<int>);
}

/// A class which mocks [PermissionHandler].
///
/// See the documentation for Mockito's code generation for more information.
class MockPermissionHandler extends _i1.Mock implements _i11.PermissionHandler {
  @override
  _i5.Future<Map<_i12.Permission, _i12.PermissionStatus>> request(
    List<_i12.Permission>? permissions,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#request, [permissions]),
            returnValue:
                _i5.Future<Map<_i12.Permission, _i12.PermissionStatus>>.value(
                  <_i12.Permission, _i12.PermissionStatus>{},
                ),
            returnValueForMissingStub:
                _i5.Future<Map<_i12.Permission, _i12.PermissionStatus>>.value(
                  <_i12.Permission, _i12.PermissionStatus>{},
                ),
          )
          as _i5.Future<Map<_i12.Permission, _i12.PermissionStatus>>);

  @override
  _i5.Future<_i12.PermissionStatus> status(_i12.Permission? permission) =>
      (super.noSuchMethod(
            Invocation.method(#status, [permission]),
            returnValue: _i5.Future<_i12.PermissionStatus>.value(
              _i12.PermissionStatus.denied,
            ),
            returnValueForMissingStub: _i5.Future<_i12.PermissionStatus>.value(
              _i12.PermissionStatus.denied,
            ),
          )
          as _i5.Future<_i12.PermissionStatus>);

  @override
  _i5.Future<bool> openAppSettings() =>
      (super.noSuchMethod(
            Invocation.method(#openAppSettings, []),
            returnValue: _i5.Future<bool>.value(false),
            returnValueForMissingStub: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);
}

/// A class which mocks [AudioConcatenationService].
///
/// See the documentation for Mockito's code generation for more information.
class MockAudioConcatenationService extends _i1.Mock
    implements _i13.AudioConcatenationService {
  @override
  _i5.Future<String> concatenate(List<String>? inputFilePaths) =>
      (super.noSuchMethod(
            Invocation.method(#concatenate, [inputFilePaths]),
            returnValue: _i5.Future<String>.value(
              _i8.dummyValue<String>(
                this,
                Invocation.method(#concatenate, [inputFilePaths]),
              ),
            ),
            returnValueForMissingStub: _i5.Future<String>.value(
              _i8.dummyValue<String>(
                this,
                Invocation.method(#concatenate, [inputFilePaths]),
              ),
            ),
          )
          as _i5.Future<String>);
}
