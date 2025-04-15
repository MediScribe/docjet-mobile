# File Path Handling: The Only Way That Doesn't Suck

---
**2024-06 Update:**
- [DONE] FileSystem is now fully async—no sync methods, no legacy code, no dead weight.
- [DONE] All path logic is internal to FileSystem; no public path helpers, no leaky abstractions.
- [DONE] Tests for FileSystem and PathResolver are DRY, robust, and double as developer documentation.
- [DONE] PathResolver and FileSystem are fully covered by tests, with proper mocking and isolation.
- [DONE] No global mutable state in tests; all tests are isolated and parallel-safe.
- [DONE] All test and implementation code is readable, maintainable, and follows best practice.
- [DONE] Lessons learned: test isolation, DRY, fail fast, no global state, readable tests, and always run your shit after you change it.
---

## Refactor Plan: Centralize Path Logic (2024 Update)

1. **Inject `PathResolver` only into `IoFileSystem`.** All path wrangling is internal to `FileSystem`. No other class touches it. **[DONE]**
2. **Refactor `AudioFileManagerImpl` and `AudioPlayerAdapterImpl` to use only `FileSystem` for all file and path operations.** Remove `PathResolver` from their constructors and fields. **[DONE: AudioFileManagerImpl, AudioPlayerAdapterImpl]**
3. **Update dependency injection:** Only `IoFileSystem` gets `PathResolver`. Remove `PathResolver` from DI for all other classes. **[DONE]**
4. **Enforce DI discipline:** The DI container MUST inject `PathResolver` *only* into `IoFileSystem`. If you see `PathResolver` injected anywhere else, that's a code review fail—refactor it and tell the offender to go fuck themselves. Axe would fire you for less. **[DONE]**
5. **Remove all direct uses of `PathResolver` outside `IoFileSystem`.** Refactor any code (including tests) that uses `PathResolver` to use `FileSystem` instead. **[DONE]**
6. **Search for and clean up any manual path wrangling or references to "relative"/"absolute" outside `FileSystem`.** **[DONE]**
7. **Update tests to mock `FileSystem`, not `PathResolver`.** **[DONE: AudioPlayerAdapterImpl tests fully mock FileSystem and cover all public API, error, and edge cases]**
8. **Clarify path resolution contract:**
    - If a client provides an **absolute path**, it is accepted **only if the file exists**. If it does not exist, throw a clear error and log the caller, path, and context for debugging. No fallback, no guessing, no silent fixes. **[DONE]**
    - If a client provides a **relative path** (including subdirectories), it is always resolved to the app's container directory. If the resolved file does not exist, throw a clear error and log full context. **[DONE]**
    - **Never attempt to "fix" or "guess" a broken path.** Fail fast and loud. This prevents silent bugs and makes upstream issues obvious. **[DONE]**
9. **Test the hell out of `PathResolver` and `FileSystem`.** Cover all platform edge cases, subdirectory handling, and error scenarios. If you half-ass these, you'll be chasing bugs like Mafee chasing Axe's approval. **[DONE]**

### **2024 Update: PathResolver & Testing Discipline**
- [DONE] `PathResolver` is now **internal-only**. It is not exposed or tested outside `FileSystem` except for its own isolated edge-case tests.
- [DONE] All file/path logic is centralized in `FileSystem`; `PathResolver` is only used internally.
- [DONE] The test suite for `PathResolver` is **lean and focused**: it only covers iOS/Android (POSIX) and general normalization edge cases, not Windows-specific paths unless cross-platform path strings are a real use case for the app.
- [DONE] **No public path helpers, no leaky abstractions, no retesting the Dart path package.**
- [DONE] Platform-specific edge cases are only covered if they are relevant to the app's actual usage. If you ever need to support cross-platform path strings (e.g., for migration/import/export), add a helper and test it—otherwise, keep it DRY and focused.
- [DONE] The plan is now **Hard Bob certified**: DRY, focused, and production-ready. If you see a path helper on the public interface, refactor it and tell the offender to go fuck themselves.

## The Problem: Path Hell and Broken Abstractions

After refactoring our app to improve file system handling, we ran into the usual suspects:

1. **Files disappear after app restart** (iOS container path roulette)
2. **Deleting or playing files fails** (works on simulator, dies on device)
3. **Slow or broken playback** (wrong path, wrong time)
4. **Codebase full of path-wrangling hacks**

**Root Cause:**
- Too many places in the codebase were doing their own path wrangling.
- Some code stored absolute paths, some stored relative, some tried to "fix" paths on the fly.
- Platform differences (iOS/Android) made it worse.

## The Only Solution: One File System To Rule Them All

### Principles
- **Store the full relative path** (including subdirectories, e.g., `meeting1/recording.m4a`) in all persistent storage (Hive, DB, prefs, etc.). Storing just the filename is NOT sufficient if you need to distinguish files in different directories.
- **All file and path logic lives in one place:** the `FileSystem` abstraction.
- [DONE] **PathResolver is an internal detail**—nobody outside `FileSystem` should ever touch it.
- **All file operations go through `FileSystem`**. No exceptions. No leaky abstractions.
- **Domain/data/UI code never cares about absolute vs. relative.**

### Why?
- iOS app container paths change. Absolute paths in storage are a time bomb.
- If you let every part of your codebase do path wrangling, you guarantee bugs and tech debt.
- Centralizing all file/path logic means you can fix platform issues in one place, forever.
- If you only store filenames, you WILL have collisions and silent data loss if you ever allow subdirectories or user-imported files.

## Implementation: The Hard Bob Way

### 1. `FileSystem` Abstraction (Already Exists)
- Handles all file operations: stat, exists, delete, create, list, write, etc.
- Internally uses `PathResolver` to convert any path (relative or absolute, including subdirectories) to the correct, current absolute path.
- [DONE] **No other class touches `PathResolver`.**

### 2. PathResolver (Internal Only)
- Handles platform weirdness, slashes, and iOS container roulette.
- Only used by `FileSystem`.
- Has tests to guarantee correctness, but is not injected or used anywhere else.
- [DONE] **Tests only cover iOS/Android (POSIX) and general normalization edge cases.**
- [DONE] **No Windows-specific path handling unless cross-platform path strings are a real use case.**

### 3. Domain/Data/UI Code
- Only ever calls `FileSystem` methods.
- Passes in the path it got from storage (should be a full relative path, including subdirectories, but `FileSystem` will handle it regardless).
- Never does path wrangling, never checks for "relative" or "absolute".

### 4. AudioFileManager (or other domain managers)
- If you need domain-specific logic (e.g., audio duration, format validation), create a thin manager that composes `FileSystem`.
- Never duplicates file/path logic.
- **[DONE: AudioFileManagerImpl now uses only FileSystem for all file ops; no direct file wrangling remains.]**

## Migration: Cleaning Up the Mess

1. **Migrate all stored paths to be full relative paths (including subdirectories, not just filenames).**
2. **Update all code to use only `FileSystem` for file ops.**
3. **Remove all direct uses of `PathResolver` outside `IoFileSystem`.**
4. **Update tests to mock `FileSystem`, not `PathResolver`.**
5. **Search for and destroy all references to "relative", "absolute", or manual path wrangling in the codebase.**
6. **[DONE: AudioFileManagerImpl is now fully compliant—no direct file wrangling, only FileSystem used.]**

## Testing: How To Not Be A Dumbass

- **Test `PathResolver` in isolation** to guarantee it handles all edge cases, including subdirectory paths.
- **Test `FileSystem` with both relative (including subdirectories) and absolute paths**—it should always do the right thing.
- **Mock `FileSystem` in all other tests.**
- **Never test path logic in domain/data/UI tests.**
- [DONE] **Test suite is lean and focused: only platform-specific edge cases relevant to the app are covered.**

## Best Practices: Tattoo These On Your Brain

1. **Store the full relative path (including subdirectories) in persistent storage.**
2. **All file ops go through `FileSystem`.**
3. [DONE] **No code outside `FileSystem` ever touches `PathResolver`.**
4. **No manual path wrangling anywhere else.**
5. **If you need domain logic, compose, don't duplicate.**
6. **Test on real devices, not just simulators.**
7. **If you see code doing path wrangling, refactor it.**

## Impact: Why This Makes You Rich, Not Pretty

- Files persist across app restarts and device upgrades.
- File ops work everywhere, every time.
- No more "it works on my machine" bullshit.
- One place to fix all future path/file bugs.
- Codebase is DRY, SOLID, and maintainable.
- No silent data loss or file collisions due to duplicate filenames in different directories.

## Appendix: Debugging Checklist

1. **Trace all file ops through `FileSystem`.**
2. **Log resolved paths in `FileSystem` for debugging.**
3. **Test with both relative (including subdirectories) and absolute paths.**
4. **Check directory contents on device if things go missing.**
5. **If a test fails, check if it's using the right abstraction.**

## Path Resolution Contract: Fail Fast, Fail Loud (NEW)

- **Absolute Path Provided:**
  - If the file exists at the given absolute path, use it as-is.
  - If the file does not exist, throw a clear error. Do not attempt to "fix" or "redirect" the path.
- **Relative Path Provided (including subdirectories):**
  - Always resolve the path to the app's container directory, preserving subdirectory structure.
  - If the resolved file exists, use it.
  - If not, throw a clear error.
- **No Silent Fallbacks:**
  - Never try to "guess" or "fallback" to another path if the provided one is invalid.
  - This ensures bugs are caught early and upstream issues are not hidden.

**Rationale:**
- Explicit is better than implicit. If the client gives you a path, you either use it (if it exists) or you fail fast and loud.
- No silent failures, no magic, no "it works on my machine."
- If the client is broken, you want to know immediately, not after a week of debugging.

---

**Remember:**
> "Path handling isn't rocket science. Store the full relative path, resolve when needed, and don't overthink it. Everything else is just covering your ass for past mistakes." — Hard Bob

If you see code using `PathResolver` outside `FileSystem`, tell it to go fuck itself and refactor it. Axe would be proud.

## Interface Contracts: No Bullshit Allowed (NEW)

### FileSystem (Public API)
- Only exposes file operations: stat, fileExists, deleteFile, directoryExists, createDirectory, listDirectory, listDirectorySync, writeFile, readFile.
- **NO path-wrangling methods** (no getAbsolutePath, no getApplicationDocumentsDirectory, no helpers).
- All path logic is internal. Clients pass in whatever path they have; FileSystem figures it out.
- If you see a path helper on the public interface, refactor it and tell the offender to go fuck themselves.
- Example:

```dart
abstract class FileSystem {
  Future<FileStat> stat(String path);
  Future<bool> fileExists(String path);
  Future<void> deleteFile(String path);
  Future<bool> directoryExists(String path);
  Future<void> createDirectory(String path, {bool recursive = false});
  Stream<FileSystemEntity> listDirectory(String path);
  List<FileSystemEntity> listDirectorySync(String path);
  Future<void> writeFile(String path, Uint8List bytes);
  Future<List<int>> readFile(String path);
}
```

### PathResolver (Internal Only)
- **NEVER exposed outside IoFileSystem.**
- Single method: resolves any path (absolute or relative) to a platform-correct absolute path, or fails LOUD if it can't.
- No guessing, no fixing, no helpers. Fail fast, fail loud.
- Example:

```dart
abstract class PathResolver {
  /// Resolves [inputPath] to an absolute, platform-correct path.
  /// Throws [PathResolutionException] if it can't resolve or (optionally) if the file doesn't exist.
  Future<String> resolve(String inputPath, {bool mustExist = false});
}
```

- If you see PathResolver anywhere but inside IoFileSystem, refactor and slap the offender. Axe would be proud. 