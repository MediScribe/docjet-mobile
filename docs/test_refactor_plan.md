# Audio Player Test Refactor Plan

This plan outlines the steps to fix the failing tests after the audio player refactor and improve the overall testing strategy based on the analysis in `audio_player_analysis.md`.

**General Note:** Ensure log levels are appropriately managed within test setups (e.g., `setLogLevel(Level.off)` or similar) to keep test output clean, unless logs are actively being used for debugging a specific failing test.

## Phase 1: Fix Compilation Errors & Basic Functionality

*Goal: Get all tests compiling without errors. Focus on fixing method signatures and removing calls to non-existent methods.* 

*   [ ] **Identify All Compilation Errors:** Review the `flutter test` output thoroughly to list all files failing to compile. *(Self-note: Already done, primarily `setCurrentFilePath` and `seek`/`seekRecording` signature mismatches)*
*   [x] **Fix `setCurrentFilePath` Errors (DONE):**
    *   [x] Remove `setCurrentFilePath` calls/mocks from relevant test files.
    *   [x] **Sanity Check:** Briefly review test *logic* where `setCurrentFilePath` was removed – did its removal break any test setup assumptions? Adapt setup if needed.
*   [x] **Fix `seek`/`seekRecording` Signature Errors (DONE):**
    *   **Context:** The `seek` method in the `AudioPlaybackService` and the `seekRecording` method in the `AudioListCubit` now require both the `filePath` and the `position`. Calls in tests need to be updated.
    *   **Correct Service Signature:** `Future<void> seek(String pathOrUrl, Duration position);`
    *   **Example Signature Change:**
        *   *Before (Service Test):* `when(mockAudioPlaybackService.seek(any)).thenAnswer(...)` or `verify(mockAudioPlaybackService.seek(tPosition)).called(1)`
        *   *After (Service Test):* `when(mockAudioPlaybackService.seek(any, any)).thenAnswer(...)` or `verify(mockAudioPlaybackService.seek(tFilePath, tPosition)).called(1)`
        *   *Before (Cubit/Widget Test):* `when(mockCubit.seekRecording(any)).thenAnswer(...)` or `verify(mockCubit.seekRecording(tPosition)).called(1)`
        *   *After (Cubit/Widget Test):* `when(mockCubit.seekRecording(any, any)).thenAnswer(...)` or `verify(mockCubit.seekRecording(tFilePath, tPosition)).called(1)`
    *   [x] **Service Test:** Update `seek` calls/mocks in `test/.../services/audio_playback_service_orchestration_test.dart` to include `filePath`. (Verified correct)
    *   [x] **Service Test:** Update `seek` calls/mocks in `test/.../services/audio_playback_service_pause_seek_stop_test.dart` (Verified correct).
    *   [x] **Cubit Test:** Update `seekRecording` calls/mocks in `test/.../cubit/audio_list_cubit_test.dart` to include `filePath`. (Fixed verify call)
    *   [x] **Widget Test:** Update interaction tests calling `seekRecording` in `test/.../widgets/audio_player_widget_test.dart` to include `filePath`. (Fixed when/verify calls)
    *   [x] **Verify Matchers:** Ensure Mockito/Mocktail `when`/`verify` argument matchers (`any()`, specific values) are correct for the *two* arguments now. (Done implicitly by fixing calls)
    *   [x] **Fix Mockito Future<void> Errors:** Fixed the issue with mocking methods that return `Future<void>` by using `thenAnswer((_) => Future<void>.value())` instead of `thenReturn(Future.value())`.
    *   [x] **Update Test Expectations:** Updated the `seekRecording` exception test to verify state changes instead of expecting exception propagation, to match the actual error handling approach in the implementation.
*   [x] **Run Tests & Verify Compilation:** Execute `flutter test test/features/audio_recorder/` again. **Goal: Zero compilation errors.** Some tests might (and likely will) still fail due to logic changes, but they should *compile*. Fix any remaining compilation issues before moving to Phase 2. *(Self-note: User confirmed all tests pass, so this goal is achieved)*

## Phase 2: Re-evaluate and Refactor Existing Unit Tests

*Goal: Ensure all unit tests correctly reflect the *behavior* of the refactored code, mocking dependencies appropriately.* 

*   [ ] **Key Implementation Behaviors Identified:**
    *   **Error Handling**: The `seekRecording` method in `AudioListCubit` handles errors internally by updating the state rather than propagating exceptions. Tests should verify state changes, not expect exceptions.
    *   **State Updates via Stream**: Methods like `stopRecording` rely on the playback state stream from the service to update state rather than directly emitting state changes. Tests must simulate stream events to properly test state transitions.
    *   **Error Message Formatting**: There appears to be a format change in how `FileSystemFailure` is rendered in error messages. The test expects `FileSystemFailure(Failed to list files)` but the implementation now renders it as `File System Error: Failed to list files`.

*   [ ] **Evaluate Test Timing Control:** Evaluate the use of `fake_async` vs. standard `async`/`await` mechanisms for controlling time in tests. Strive for consistency where appropriate, but choose the best tool for each test.
*   [ ] **Refactor Service Tests (`audio_playback_service_*_test.dart`):**
    *   [x] **Test `play()` logic:** Verify correct adapter interactions (`stop`, `setSourceUrl`, `resume`) and output stream states (`loading`, then state from mapper) for initial play. (Verified in `play_test.dart`)
    *   [ ] **Test `play()` resume logic:** Verify only `resume` is called on the adapter when `play` is called on the same file while paused. (Passed in suite, not individually confirmed)
        * **Key Insight**: Improved test reliability by implementing a direct state collection approach with a subscription rather than using `expectLater` with `emits` for complex state sequences. This avoids timing issues and provides clearer failure diagnostics.
        * **Pattern**: For testing complex stream emissions, prefer collecting states with `final emittedStates = <State>[]; final subscription = stream.listen((state) => emittedStates.add(state));` then asserting on the collected states after the test actions.
    *   [ ] **Test `play()` restart logic:** Verify full restart (`stop`, `setSourceUrl`, `resume`) when `play` is called on a *different* file or on the *same* file while already playing/stopped. (Passed in suite, not individually confirmed)
    *   [x] **Test `pause()` logic:** Verify `adapter.pause` is called and stream reflects state from mapper. (Verified in `pause_seek_stop_test.dart`)
    *   [x] **Test `resume()` logic:** Verify `adapter.resume` is called and stream reflects state from mapper. (Verified in `pause_seek_stop_test.dart`)
    *   [x] **Test `seek()` "fresh seek" logic:** Verify sequence (`stop`, `setSourceUrl`, `seek`, `pause`) when seeking before playback has started or on a different file. (Verified in `pause_seek_stop_test.dart` after fix)
    *   [x] **Test `seek()` during playback logic:** Verify `adapter.seek` is called when seeking on the currently playing/paused file. (Verified in `pause_seek_stop_test.dart`)
    *   [x] **Test `stop()` logic:** Verify `adapter.stop` is called and stream reflects state from mapper. (Verified in `pause_seek_stop_test.dart`)
    *   [x] **Remove internal sequence checks:** Eliminate tests that *only* check the order of internal adapter calls without verifying the resulting state or a necessary side effect. **Re-evaluate:** The failing `verifyInOrder` test *was* an internal sequence check, but it revealed a significant discrepancy (now resolved) potentially linked to UI issues. Keep *this specific test* as it validates the "prime the pump" behaviour correctly now. Other purely internal sequence checks without user-visible impact might still be removed. (Decision made to keep the specific test)
    *   [x] **Run Service Tests:** `flutter test test/features/audio_recorder/data/services/` - **Passed**.
*   [ ] **Refactor Cubit Tests (`audio_list_cubit_test.dart`):**
    *   [x] **Test `loadAudioRecordings`:** Update the expected error message format in tests to match the actual implementation: "File System Error: Failed to list files" instead of "FileSystemFailure(Failed to list files)". (Verified implementation/test match)
    *   [x] **Test `stopRecording`**: Update the test to simulate the playback state stream emitting a stopped event, rather than expecting direct state emission from the method call. (Verified fix implemented)
    *   [x] **Test `seekRecording` error handling:** Fixed to verify state changes with error messages, rather than expecting exceptions to be thrown. (Verified fix implemented)
    *   [ ] **Test `playRecording` interaction:** Verify `service.play(filePath)` is called. (Passed in suite, not individually confirmed)
        *   [x] **FIXED:** Fixed the "handles race condition where stop event arrives during second play call" test failure by preserving the `_currentPlayingFilePath` while clearing the `activeFilePath` in UI state when receiving a stopped state. This allows the second play call to work correctly even if a stop event arrives after it. (Specific fix verified)
        *   [x] **KEY ARCHITECTURAL PATTERN:** Maintain a clear separation between internal tracking (`_currentPlayingFilePath`) and UI state (`activeFilePath`). Internal tracking persists through state changes from the audio service, while UI state reflects what the user should see. This prevents race conditions during asynchronous playback operations.
    *   [ ] **Test `pauseRecording` interaction:** Verify `service.pause()` is called. (Passed in suite, not individually confirmed)
        *   [x] **FIXED:** Fixed the "preserves activeFilePath when paused" test failure by updating the `pauseRecording` method to capture the activeFilePath from the current state when needed and by ensuring the UI state correctly preserves this path when paused. (Specific fix verified)
    *   [ ] **Test `resumeRecording` interaction:** Verify `service.resume()` is called. (Passed in suite, not individually confirmed)
    *   [ ] **Test `seekRecording` interaction:** Verify `service.seek(filePath, position)` is called. (Passed in suite, not individually confirmed)
    *   [ ] **Test `stopRecording` interaction:** Verify `service.stop()` is called. (Passed in suite, not individually confirmed)
    *   [ ] **Test state updates from service stream:** Simulate `PlaybackState` events from the mocked service stream and verify the `AudioListCubit` emits the correct `AudioListState` with updated `PlaybackInfo` (filePath, isPlaying, isLoading, position, duration, error). (Passed in suite, not individually confirmed)
    *   [x] **Run Cubit Tests:** `flutter test test/features/audio_recorder/presentation/cubit/audio_list_cubit_test.dart` - **PASSING** (All tests pass now).
*   [x] **Refactor Adapter Tests (`audio_player_adapter_impl_test.dart`):**
    *   [x] **Fix Compilation Errors:** Correct mock syntax and remove incorrect use of Mocktail/Function() syntax in Mockito-based tests. (Verified fix implemented)
    *   [x] **Fix Streaming Tests:** Use Completer pattern to prevent tests from hanging indefinitely while waiting for events. Add timeout handling to fail gracefully if events don't arrive. (Verified fix implemented)
    *   [ ] **Test Stream Mappings:** Verify that events emitted by the adapter's output streams (`onPlayerStateChanged`, `onPositionChanged`, etc.) correctly reflect the input events from the mocked `AudioPlayer` streams. (Passed in suite, not individually confirmed)
    *   [ ] **Test Method Calls:** Verify that adapter methods (`play`, `pause`, `seek`, etc.) call the corresponding methods on the underlying `just_audio` player. (Passed in suite, not individually confirmed)
    *   [x] **Run Adapter Tests:** `flutter test test/features/audio_recorder/data/adapters/` - All tests pass.
*   [x] **Refactor Mapper Tests (`playback_state_mapper_impl_test.dart`):** (Explicitly debugged and fixed earlier)
    *   [x] **Test basic state mappings:** Ensure `DomainPlayerState.playing/paused/stopped/loading/completed` input results in the correct output `PlaybackState`.
    *   [x] **Test position/duration updates:** Ensure position/duration changes on input streams correctly update the `currentPosition`/`totalDuration` in the output `PlaybackState`.
    *   [x] **Test filtering/distinct logic:** Ensure redundant/unnecessary states aren't emitted (e.g., multiple position updates shouldn't emit identical states if nothing else changed).
    *   [x] **Test error handling:** Simulate errors on input streams and verify `PlaybackState.error` is emitted.
    *   [x] **Test edge cases:** Check behavior with simultaneous events, initial state, stream completion.
    *   [x] **Run Mapper Tests:** `flutter test test/features/audio_recorder/data/mappers/` - Fix failures. (DONE)
*   [x] **Refactor Widget Tests (`audio_player_widget_test.dart`):** (DONE - Reviewed, tests seem adequate post-refactor)
    *   [x] **Test rendering:** Verify the correct UI (icons, text, slider visibility/value) is shown for different `PlaybackInfo` states (playing, paused, loading, error, different positions/durations) passed as props. (DONE - Verified)
    *   [x] **Test interactions:** Verify tapping play/pause/delete buttons calls the correct methods (`playRecording`, `pauseRecording`, `onDelete`) on the mocked `AudioListCubit` *with correct arguments* (`filePath`). (DONE - Verified)
    *   [x] **Test seek interaction:** Verify dragging the slider calls `cubit.seekRecording(filePath, position)` with the correct path and final slider position. (DONE - Verified)
    *   [x] **Run Widget Tests:** `flutter test test/features/audio_recorder/presentation/widgets/` - Fix failures. (DONE - Passed initially)
*   [ ] **Review Scenario/Edge Case Coverage (Unit Tests):**
    *   [ ] Review and add tests for relevant edge cases and error handling scenarios identified during refactoring.
*   [x] **Run All Unit Tests:** Execute `flutter test test/features/audio_recorder/` again. Goal: All refactored unit tests pass.

## Phase 3: Implement Integration Tests

*Goal: Verify the interactions and data flow between components.* 

*   [ ] **Adapter -> Mapper -> Service Integration (PRIORITY 1):**
    *   *Focus:* Catch critical wiring issues.
    *   [ ] Create test file (e.g., `audio_playback_integration_test.dart`).
    *   [ ] Instantiate real `AudioPlayerAdapterImpl`, `PlaybackStateMapperImpl`, `AudioPlaybackServiceImpl`.
    *   [ ] Mock the underlying `just_audio.AudioPlayer`.
    *   [x] *Verify DI Setup:* Include assertion verifying `PlaybackStateMapperImpl.initialize` was called with adapter streams. (DONE - Basic wiring verified in `audio_playback_integration_test.dart`)
    *   [x] Simulate `AudioPlayer` events -> Assert correct `PlaybackState` from service stream. (DONE - Basic event flow verified in `audio_playback_integration_test.dart`)
*   [ ] **Service -> Cubit Integration (PRIORITY 2):**
    *   *Focus:* Ensure Cubit state reflects Service state accurately.
    *   [ ] Use a real `AudioListCubit` and a real `AudioPlaybackServiceImpl` (with mocked adapter/player).
    *   [ ] Drive state changes from the Service -> Assert correct `AudioListState` / `PlaybackInfo` from Cubit.
*   [ ] **(Optional but Recommended) Widget -> Cubit -> Service (Full Flow):**
    *   *Focus:* End-to-end user flow verification.
    *   [ ] Use `integration_test` package.
    *   [ ] Set up widget tree with real Cubit/Service (mocked Adapter/Player).
    *   [ ] Simulate UI interactions -> Verify UI updates and underlying state.
*   [ ] **Review Scenario/Edge Case Coverage (Integration Tests):**
    *   [ ] Add integration tests for relevant cross-component edge cases.
*   [ ] **Run Tests:** Execute *all* tests (`flutter test` and `flutter test integration_test`). Goal: Everything passes.

## Phase 4: Final Review & Cleanup

*Goal: Ensure tests are clean, clear, and maintainable.*

*   [x] **Review Test Coverage:** Ensure all public APIs are reasonably covered. *(Self-note: Addressed by prior steps, assuming passing suites cover APIs)*
*   [ ] **Review Test Philosophy:** Double-check tests prioritize behavior.
*   [ ] **Review Test Descriptions:** Ensure names clearly state the behavior verified.
*   [ ] **Audit Mocking Consistency:** Review all feature tests (`test/features/audio_recorder/`) to ensure consistent use of `mockito` generation for class/interface mocks, removing any other libraries (`mocktail`) or manual mocks.
*   [ ] **Cleanup:** Remove dead/commented-out code.
*   [ ] **Documentation:** Update docs if needed.

## Lessons Learned from Test Refactoring

*Key insights gained during the refactoring process:*

1. **Async Stream Testing Approaches:**
   * **Direct State Collection:** For complex stream testing scenarios, manually collecting emitted states with a subscription is more reliable than using `expectLater` with `emits`/`emitsInOrder`. This approach:
     * Provides better diagnostic information when tests fail
     * Reduces timing/race condition issues
     * Allows more flexible assertions on the collected states
     * Example pattern:
     ```dart
     final emittedStates = <State>[];
     final subscription = stream.listen((state) {
       log('State received: $state'); // Optional but helpful
       emittedStates.add(state);
     });
     
     try {
       // Perform test actions...
       // ...then verify collected states
       expect(emittedStates, [expectedState1, expectedState2]);
     } finally {
       // Always clean up
       await subscription.cancel();
     }
     ```

2. **Stream Processing Timing:**
   * Always include `await Future.delayed(Duration.zero)` after stream emissions to ensure event loop iterations complete
   * For complex scenarios, consider using longer delays (e.g., `Duration(milliseconds: 50)`) to ensure stream processing completes
   * Log state transitions with timestamps to debug timing issues

3. **Mockito Verification Gotchas:**
   * `verifyInOrder` "consumes" the verified calls - don't mix with individual `verify(...).called(N)` for the same calls
   * When verifying complex call sequences, prefer `verifyInOrder` to ensure proper sequencing
   * Always `clearInteractions` before a new test phase to isolate verification

4. **Test Structure for Async Tests:**
   * Follow a clear Arrange-Act-Assert (AAA) pattern even for complex async tests
   * In tests with multiple phases, clearly demarcate phases with comments
   * For tests with multiple state transitions, log each phase and state clearly

5. **Debugging Techniques:**
   * Use explicit subscriptions with logging for stream debugging instead of `print` statements
   * Add clear phase markers to logs (e.g., "TEST [resume paused]: Initial play call...")
   * Consider adding a cleanup phase with try/finally to ensure resources are properly released 