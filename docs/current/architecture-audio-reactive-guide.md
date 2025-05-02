# Hard Bob's Guide to Audio Playback & Reactive State

## 1. Introduction

This document is your goddamn shield against the clusterfuck that is audio playback and reactive state management in Flutter. We spilled blood figuring this shit out (see the war report: `../old_system/audio_player_analysis.md`), so you better fucking listen up. The goal here is simple: build audio features that *work*, don't flicker like a cheap motel sign, and are testable without sacrificing your sanity. Follow these rules, or prepare for a Wags-level dressing down.

## 2. The Core Shit We Fucked Up (And You Shouldn't)

We walked through hell so you don't have to. Remember these cardinal sins:

*   **UI Flickering Nightmare**: What happens when your UI tries to rebuild for every tiny, intermediate state change from the audio player? A flickering mess that looks amateurish. Rapid state changes (`loading` -> `paused` -> `playing` in milliseconds) kill the user experience.
*   **Integration Blindness**: Our unit tests were green, singing praises while the app integration was burning down. We tested components in isolation perfectly, but missed the broken connections, especially in dependency injection (DI) wiring and stream handoffs between layers. Don't be the Dollar Bill who thinks his solo win makes the whole fund profitable.
*   **Library Naivety**: We assumed `just_audio` (or any complex library) would behave logically, like *we* thought it should. Big mistake. Libraries have their own quirks, especially around asynchronous operations and state transitions (like `play()` returning *before* the state is actually `playing`). Assuming otherwise is like trusting a trader who *just knows* the market will turn. Verify, don't assume.

## 3. Hard Bob's Commandments for Audio & Reactive Code

Engrave these on your fucking soul.

### I. Thou Shalt Tame Thy Streams

*   **The Problem**: Raw, unfiltered streams from media players are noisy bastards. Every little state change cascades through your reactive layers (Adapter -> Mapper -> Service/Cubit -> UI), triggering expensive rebuilds and causing visual chaos.
*   **The Fix: Strategic Debouncing**: You need to smooth out the noise. Use `debounceTime` (RxDart) or equivalent techniques to wait for the stream to settle before propagating the state. Place this strategically, often in the *Mapper* layer, *after* basic distinction but *before* the state hits your business logic (Cubit/Bloc) or UI. This collapses rapid, intermediate states into one meaningful update.

    ```dart
    // Example in a PlaybackStateMapper
    combinedStream
      .distinct(areStatesEquivalent) // First, filter out truly identical states
      // THEN, debounce to filter rapid intermediate transitions
      .debounceTime(const Duration(milliseconds: 80)) // 50-100ms is often enough
      .listen((stableState) {
        // Only propagate the stable state downstream
        _outputController.add(stableState);
      });
    ```

*   **Filter Smart**: Basic `.distinct()` isn't enough for complex state objects. You need custom equality checks (`areStatesEquivalent` in the example above) that understand *your* state's definition of "different enough to warrant an update". Don't just compare object identities.

### II. Thou Shalt Test Like You Mean It

*   **Beyond Units**: Unit tests are table stakes. You *must* test the *connections* and *interactions* between components. Did your DI container wire things correctly? Does the Mapper receive stream events from the Adapter? Write integration tests for these critical seams.
*   **User's Eyes**: Test the *observable behavior*, the *outcome* from the user's perspective. Don't just check if `adapter.resume()` was called; check if the playback *actually resumed* from the correct position after the user pressed play/pause/play. Focus on "What should happen?" not "Which function ran?".
*   **Async Testing That Doesn't Suck**: Testing asynchronous streams is a bitch, but necessary.
    *   **Mock Dependencies Correctly**: Provide mock streams that simulate the player's behavior, including delays and multiple emissions.
    *   **Verify Emissions**: Don't rely on flaky `expectLater` with complex matchers. Collect emissions into a list and assert against the final list or specific items. Use `pumpAndSettle` or explicit `Future.delayed` where necessary, but sparingly.
    *   **Clean Up**: Always cancel stream subscriptions in `tearDown`.

    ```dart
    // Good pattern for testing stream output
    test('should emit Playing state after play is called', () async {
      final service = // setup your service with mocks
      final emittedStates = <PlaybackState>[];
      final subscription = service.playbackStateStream.listen(emittedStates.add);

      await service.play('some/path');
      // Give time for async operations and debouncing
      await Future.delayed(Duration(milliseconds: 150));

      expect(emittedStates.last, isA<PlaybackStatePlaying>());

      await subscription.cancel(); // CLEAN UP!
    });
    ```

*   **Test Streams Without Races**: Use a broadcast `StreamController` to stub your source, hand-shake with a `Completer` in your production code to await the first event, and schedule emissions in tests via `Future.microtask` so no event is dropped or raced. Then assert with `emitsInOrder` or `blocTest` for deterministic state sequences:

    ```dart
    // In your Cubit or service:
    Future<void> loadData() {
      final firstEvent = Completer<void>();
      _subscription = source.stream.listen((data) {
        emit(DataLoaded(data));
        if (!firstEvent.isCompleted) firstEvent.complete();
      });
      return firstEvent.future;
    }

    // In tests:
    final ctrl = StreamController<Either<Failure,List<Item>>>.broadcast();
    when(mockSource.stream).thenAnswer((_) => ctrl.stream);

    blocTest<MyCubit, MyState>(
      build: () => MyCubit(source: mockSource),
      act: (cubit) {
        final f = cubit.loadData();
        Future.microtask(() => ctrl.add(Right(testItems)));
        return f;
      },
      expect: () => [isA<DataLoading>(), isA<DataLoaded>()],
    );
    ```

### III. Thou Shalt Not Trust Blindly

*   **Know Thy Library**: Read the fucking docs. Understand the state machine of your audio library. When does `play()` actually result in a `playing` state? Are there intermediate `loading` or `buffering` states? What happens on errors? What happens when seeking before loading? Ignorance here *will* bite you in the ass. The `just_audio` `play()` behavior was our "I'm not uncertain" moment that turned out to be pure bullshit.
*   **Isolate & Conquer**: If a library behaves unexpectedly, create a minimal reproduction case outside your main app. Test its specific methods and state transitions in isolation until you understand its quirks.

### IV. Thou Shalt Debug Like a Pro, Not a Chump

*   **Instrument Everything**: When shit goes wrong, you need visibility. Add detailed logging at each layer (Adapter, Mapper, Cubit, Widget build). Include timestamps, state transitions (before/after), and unique flow IDs to trace a single user action through the entire reactive chain.
*   **Visualize the Chaos**: Standardize your log output (`TIMELINE|timestamp|layer|operation|data_json`). This allows you to parse logs and generate timelines, making it easy to spot rapid-fire state changes and identify bottlenecks or unexpected sequences. Don't just stare at a wall of text.

## 4. Golden Implementation Patterns

Steal these shamelessly.

*   **Debounce Player State by Default**: Treat raw player state streams as inherently noisy. Apply a `.distinct().debounceTime()` combo (like 50-100ms) in your Mapper or equivalent layer *before* it hits your application logic. This is your first line of defense against flickering.
*   **Optimistic UI (Use With Caution)**: For user-initiated actions (like tapping play), you *can* optimistically update the UI *immediately* to the expected final state (e.g., show the pause button instantly). This feels responsive. **BUT**, ensure your system eventually reconciles with the *actual* state from the stream. If the play action fails, the UI must revert. Use this sparingly and consciously.
*   **Smooth It Out Visually**: Even with debouncing, some state transitions might be noticeable. Use Flutter widgets like `AnimatedSwitcher` or `AnimatedCrossFade` to create smoother visual transitions between states (e.g., fading between a loading indicator and player controls).

## 5. Conclusion

Handling audio and reactive state is tricky, but it's not black magic. It requires discipline, attention to detail, and a healthy distrust of asynchronous operations. By understanding the pitfalls (flickering, integration gaps, library quirks) and applying these commandments (tame streams, test thoroughly, verify libraries, debug professionally), you can build audio features that are robust, performant, and don't make our users feel like they're having a seizure. Now go forth and code like the technical badasses you are. Don't fuck it up. 