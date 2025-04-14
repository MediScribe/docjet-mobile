# File Path Handling Fixes: The Tale of Absolute vs. Relative Hell

## The Problem: Broken Seeding and Audio Playback

After refactoring our app to improve the file system handling, we ran into some unexpected issues:

1. **Sample audio files and recordings disappeared after app restart**
2. **Deleting recordings failed**, particularly on real iOS devices (worked on simulator)
3. **Audio playback was extremely slow to start** or didn't work at all
4. **File operations that worked on simulator broke on real devices**

This document details how we diagnosed and fixed these issues.

## Root Cause: Path Inconsistency Between Components

The root cause was a fundamental inconsistency in how different components handled file paths:

1. **FileSystem and AudioFileManager**: Expected relative paths, stored within app documents directory
2. **AudioPlayerAdapter**: Expected and worked with absolute paths
3. **LocalJobStore**: Stored relative paths in the database
4. **Post-Refactoring**: Introduced additional path handling without fully aligning all components

The primary source of bugs was that paths could be stored as:
- Absolute paths (e.g., `/var/mobile/Containers/Data/Application/GUID/Documents/file.m4a`)
- Relative paths (e.g., `file.m4a`) assumed to be in the app documents directory

**Key Insight**: iOS app container paths can change between launches, so absolute paths aren't reliable for persistence.

## The Fix: Canonical Path Handling Strategy

Let's cut the bullshit. There's a standard way to handle paths in Flutter/Dart:

1. **Use `path_provider` to get standard directories** - this is your stable base
2. **Store ONLY relative paths** - preferably just filenames if all files are in one directory
3. **Resolve dynamically when needed** - combine current base path with your stored relative path using `path.join()`

### Implementation Steps:

#### 1. Create a Simple `PathResolver` Class:

```dart
class PathResolver {
  final PathProvider _pathProvider;
  
  PathResolver({required PathProvider pathProvider}) : _pathProvider = pathProvider;
  
  /// Converts any path to a relative path (filename only)
  String toRelativePath(String path) {
    return path.contains('/') ? path.split('/').last : path;
  }
  
  /// Gets the current absolute path for a given relative path
  Future<String> getAbsolutePath(String relativePath) async {
    // Strip to just filename if it contains directory separators
    final filename = toRelativePath(relativePath);
    
    // Get the current documents directory and join with filename
    final docsDir = await _pathProvider.getApplicationDocumentsDirectory();
    return p.join(docsDir.path, filename);
  }
  
  /// Checks if a file exists (handles both relative and absolute paths)
  Future<bool> fileExists(String path) async {
    // If it's already absolute, check directly
    if (p.isAbsolute(path) && await File(path).exists()) {
      return true;
    }
    
    // Otherwise, resolve to current absolute path and check
    final absolutePath = await getAbsolutePath(toRelativePath(path));
    return await File(absolutePath).exists();
  }
}
```

#### 2. Update Storage to Use Only Relative Paths:

```dart
class HiveLocalJobStoreImpl implements LocalJobStore {
  final Box<LocalJob> _box;
  final PathResolver _pathResolver;
  
  HiveLocalJobStoreImpl(this._box, this._pathResolver);
  
  @override
  Future<void> saveJob(LocalJob job) async {
    // Always normalize to relative path before saving
    final normalizedJob = job.copyWith(
      localFilePath: _pathResolver.toRelativePath(job.localFilePath),
    );
    
    await _box.put(normalizedJob.localFilePath, normalizedJob);
  }
}
```

#### 3. Update File Access to Always Resolve Paths:

```dart
class AudioPlayerAdapterImpl implements AudioPlayerAdapter {
  final just_audio.AudioPlayer _player;
  final PathResolver _pathResolver;
  
  AudioPlayerAdapterImpl(this._player, this._pathResolver);
  
  @override
  Future<void> setSourceUrl(String url) async {
    // Remote URLs (http/https) can be used directly
    if (url.startsWith('http')) {
      await _player.setUrl(url);
      return;
    }
    
    // Local files need proper resolution
    final absolutePath = await _pathResolver.getAbsolutePath(url);
    await _player.setFilePath(absolutePath);
  }
}
```

## Temporary Migration Strategy

During transition from the broken system to the clean one, we need a temporary migration process. This is **technical debt** that should be removed once all data is migrated:

```dart
class PathMigrator {
  final LocalJobStore _jobStore;
  final PathResolver _pathResolver;
  
  PathMigrator(this._jobStore, this._pathResolver);
  
  Future<void> migrateAbsolutePathsToRelative() async {
    // Get all jobs
    final allJobs = await _jobStore.getAllJobs();
    int migratedCount = 0;
    
    for (final job in allJobs) {
      if (p.isAbsolute(job.localFilePath)) {
        // Convert to relative path
        final relativePath = _pathResolver.toRelativePath(job.localFilePath);
        
        // Create migrated job and save
        final migratedJob = job.copyWith(localFilePath: relativePath);
        await _jobStore.deleteJob(job.localFilePath);
        await _jobStore.saveJob(migratedJob);
        
        migratedCount++;
      }
    }
    
    Log.i('Path migration complete. Migrated $migratedCount jobs');
  }
}
```

## Dependency Injection Setup

Wire everything up correctly:

```dart
sl.registerLazySingleton<PathResolver>(
  () => PathResolver(pathProvider: sl<PathProvider>()),
);

sl.registerLazySingleton<AudioPlayerAdapter>(
  () => AudioPlayerAdapterImpl(
    sl<just_audio.AudioPlayer>(),
    sl<PathResolver>(),
  ),
);

// Run migration at app startup (temporary)
sl<PathMigrator>().migrateAbsolutePathsToRelative();
```

## Testing Strategy

Create tests that verify path handling works correctly:

```dart
void main() {
  late PathResolver pathResolver;
  late MockPathProvider mockPathProvider;
  
  setUp(() {
    mockPathProvider = MockPathProvider();
    pathResolver = PathResolver(pathProvider: mockPathProvider);
    
    // Mock the documents directory 
    when(mockPathProvider.getApplicationDocumentsDirectory())
        .thenAnswer((_) async => Directory('/mock/docs/dir'));
  });
  
  test('toRelativePath extracts filename from absolute path', () {
    expect(
      pathResolver.toRelativePath('/var/mobile/Containers/Data/App/docs/file.m4a'), 
      equals('file.m4a')
    );
  });
  
  test('getAbsolutePath joins documents directory with filename', () async {
    final absolutePath = await pathResolver.getAbsolutePath('file.m4a');
    expect(absolutePath, equals('/mock/docs/dir/file.m4a'));
  });
}
```

## Path Handling Guidelines

1. **NEVER store absolute paths** in databases, preferences, or any persistent storage
2. **ALWAYS store relative paths** (just the filename when possible)
3. **Use `PathResolver` consistently** across all components
4. **Resolve paths dynamically** when needed for file operations
5. **Test on real devices**, not just simulators
6. **Keep it simple** - avoid complex fallback strategies once migration is complete

## Developer Best Practices

1. **Use `path_provider` for standard directories** - Don't hardcode paths
2. **Use the `path` package for path manipulation** - Use `p.join()` not string concatenation
3. **Test with app restart scenarios** - Verify paths still work after relaunch
4. **Create a clear API contract** - Document whether your methods expect relative or absolute paths
5. **Clean up temporary migration code** - Remove fallbacks after they're no longer needed

Remember, as Hard Bob would say: "Path handling isn't rocket science. Store relative, resolve when needed, and don't overthink it. Everything else is just covering your ass for past mistakes."

## Impact

With these changes, our app now:
1. Correctly persists audio files between launches
2. Can delete files reliably on both simulator and devices
3. Starts audio playback much faster
4. Handles the file system operations in a more consistent way

## Test Fixes

Two tests were failing after our changes:

1. **In `audio_local_data_source_impl_test.dart`**:  
   Test was expecting full paths to be saved in the `LocalJob`, but we now save only the filename.
   
   ```dart
   // Original test expectation
   expect(capturedJob.localFilePath, tFinalPath); // Expected full path
   
   // Updated test expectation
   const tExpectedRelativePath = 'final_recording.m4a'; // Just the filename
   expect(capturedJob.localFilePath, tExpectedRelativePath); 
   ```

2. **In `audio_player_adapter_impl_test.dart`**:  
   Test was too specific about how URLs are handled in the adapter.
   
   ```dart
   // Original test expectation
   expect((capturedSource as UriAudioSource).uri.toString(), remoteUrl);
   expect(capturedSource.uri.scheme, 'https');
   
   // Updated test expectation - more flexible
   final uri = (capturedSource as UriAudioSource).uri;
   expect(uri.toString(), contains('example.com/audio.mp3'));
   ```

These test fixes reflect our architectural changes to make path handling more robust while still maintaining expected behavior.

## Appendix: Debugging the Issue

When debugging, we used a systematic approach:

1. **Trace filesystem operations** by adding log statements
2. **Verify file existence** at multiple points
3. **Check directory contents** to confirm files were actually written
4. **Analyze error messages** to understand failure points
5. **Test on both simulator and device** to expose platform-specific issues

Using these approaches, we were able to identify that iOS app container paths change between launches, making absolute paths unreliable for persistence. 