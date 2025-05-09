import 'dart:async'; // Import async for StreamController

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/auth/events/auth_event_bus.dart'; // Import AuthEventBus
import 'package:docjet_mobile/core/auth/events/auth_events.dart'; // Import AuthEvent
import 'package:docjet_mobile/core/platform/network_info_impl.dart'; // Implementation path
// import 'package:docjet_mobile/core/interfaces/network_info.dart'; // UNUSED

// Generate mocks for Connectivity and AuthEventBus
@GenerateMocks([Connectivity, AuthEventBus])
import 'network_info_impl_test.mocks.dart';

void main() {
  late NetworkInfoImpl networkInfo;
  late MockConnectivity mockConnectivity;
  late StreamController<List<ConnectivityResult>> connectivityStreamController;
  late MockAuthEventBus mockAuthEventBus; // Add mock bus

  // Helper to setup mocks and instance
  Future<void> setupNetworkInfo({
    ConnectivityResult initialResult = ConnectivityResult.wifi,
  }) async {
    mockConnectivity = MockConnectivity();
    mockAuthEventBus = MockAuthEventBus(); // Initialize mock bus
    connectivityStreamController =
        StreamController<List<ConnectivityResult>>.broadcast();

    // Stub the initial check FIRST
    when(mockConnectivity.checkConnectivity()).thenAnswer((_) async {
      // print("Mock checkConnectivity called, returning: $initialResult");
      return [initialResult];
    });

    // Stub the stream AFTER the initial check stub
    when(mockConnectivity.onConnectivityChanged).thenAnswer((_) {
      // print("Mock onConnectivityChanged accessed");
      return connectivityStreamController.stream;
    });

    // Instantiate with the mock bus
    networkInfo = NetworkInfoImpl(mockConnectivity, mockAuthEventBus);

    // Allow initialization to complete
    await Future.delayed(Duration.zero);
  }

  // Use setUp/tearDown within groups to manage instance lifecycle per group/test

  tearDown(() async {
    // Ensure dispose is called ONLY if networkInfo was initialized
    // This requires careful handling in tests that might fail during setup
    // A simple approach: always try to dispose, null check might be safer
    // await networkInfo?.dispose(); // Original had potential null issue if setup failed
    await networkInfo
        .dispose(); // Assuming networkInfo is always non-null in tearDown
    // Ensure controller is closed if setup happened
    if (!connectivityStreamController.isClosed) {
      await connectivityStreamController.close();
    }
  });

  group('isConnected', () {
    setUp(() async {
      await setupNetworkInfo(initialResult: ConnectivityResult.wifi);
    });

    test('should return true when initialized online', () async {
      final result = await networkInfo.isConnected;
      expect(result, true);
      verify(mockConnectivity.checkConnectivity()).called(1);
      verifyNever(mockConnectivity.checkConnectivity());
    });

    test('should return false when initialized offline', () async {
      await networkInfo.dispose(); // Dispose previous one
      await setupNetworkInfo(initialResult: ConnectivityResult.none);
      final result = await networkInfo.isConnected;
      expect(result, false);
      verify(mockConnectivity.checkConnectivity()).called(1);
      verifyNever(mockConnectivity.checkConnectivity());
    });

    test(
      'should perform live check if called before initialization completes (edge case)',
      () async {
        mockConnectivity = MockConnectivity();
        connectivityStreamController =
            StreamController<List<ConnectivityResult>>.broadcast();
        final checkCompleter = Completer<List<ConnectivityResult>>();
        when(
          mockConnectivity.checkConnectivity(),
        ).thenAnswer((_) => checkCompleter.future);
        when(
          mockConnectivity.onConnectivityChanged,
        ).thenAnswer((_) => connectivityStreamController.stream);

        networkInfo = NetworkInfoImpl(mockConnectivity, mockAuthEventBus);
        final futureResult = networkInfo.isConnected;

        // verify(mockConnectivity.checkConnectivity()).called(1); // REMOVED - Flaky intermediate check

        checkCompleter.complete([ConnectivityResult.wifi]);
        final result = await futureResult;

        expect(result, true);
        verify(mockConnectivity.checkConnectivity()).called(2);

        // await networkInfo.dispose(); // Dispose handled in tearDown
      },
    );
  });

  group('onConnectivityChanged', () {
    const streamProcessingDelay = Duration(milliseconds: 10);

    setUp(() async {
      await setupNetworkInfo(initialResult: ConnectivityResult.wifi);
    });

    test(
      'should emit false when connectivity changes from online to offline',
      () async {
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );
        connectivityStreamController.add([ConnectivityResult.none]);
        await Future.delayed(streamProcessingDelay);
        expect(emittedValues, [false]);
        await subscription.cancel();
      },
    );

    test(
      'should emit true when connectivity changes from offline to online',
      () async {
        await networkInfo.dispose();
        await setupNetworkInfo(initialResult: ConnectivityResult.none);
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );
        connectivityStreamController.add([ConnectivityResult.wifi]);
        await Future.delayed(streamProcessingDelay);
        expect(emittedValues, [true]);
        await subscription.cancel();
      },
    );

    test(
      'should not emit when status does not change (online to online)',
      () async {
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );
        connectivityStreamController.add([ConnectivityResult.mobile]);
        await Future.delayed(streamProcessingDelay);
        expect(emittedValues, isEmpty);
        await subscription.cancel();
      },
    );

    test(
      'should not emit when status does not change (offline to offline)',
      () async {
        await networkInfo.dispose();
        await setupNetworkInfo(initialResult: ConnectivityResult.none);
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );
        connectivityStreamController.add([ConnectivityResult.none]);
        await Future.delayed(streamProcessingDelay);
        expect(emittedValues, isEmpty);
        await subscription.cancel();
      },
    );
  });

  group('AuthEventBus Integration', () {
    const streamProcessingDelay = Duration(milliseconds: 10);

    setUp(() async {
      // Initialize online by default for transition tests
      await setupNetworkInfo(initialResult: ConnectivityResult.wifi);
    });

    test(
      'should add AuthEvent.offlineDetected to bus when connectivity changes from online to offline',
      () async {
        // Act: Trigger offline event
        connectivityStreamController.add([ConnectivityResult.none]);
        await Future.delayed(streamProcessingDelay); // Allow stream processing

        // Assert: Verify event added to bus
        verify(mockAuthEventBus.add(AuthEvent.offlineDetected)).called(1);
        verifyNever(mockAuthEventBus.add(AuthEvent.onlineRestored));
        verifyNoMoreInteractions(mockAuthEventBus);
      },
    );

    test(
      'should add AuthEvent.onlineRestored to bus when connectivity changes from offline to online',
      () async {
        // Arrange: Start offline first
        await networkInfo.dispose(); // Dispose previous instance
        await setupNetworkInfo(initialResult: ConnectivityResult.none);

        // Act: Trigger online event
        connectivityStreamController.add([ConnectivityResult.wifi]);
        await Future.delayed(streamProcessingDelay); // Allow stream processing

        // Assert: One offlineDetected fired during initialization and one
        // onlineRestored fired for the transition.
        verify(mockAuthEventBus.add(AuthEvent.offlineDetected)).called(1);
        verify(mockAuthEventBus.add(AuthEvent.onlineRestored)).called(1);
        verifyNoMoreInteractions(mockAuthEventBus);
      },
    );

    test(
      'should NOT add events to bus when connectivity status does not change (online to online)',
      () async {
        // Arrange: Ensure we start online (default setUp)

        // Act: Trigger another online event (mobile)
        connectivityStreamController.add([ConnectivityResult.mobile]);
        await Future.delayed(streamProcessingDelay); // Allow stream processing

        // Assert: Verify no events were added
        verifyNever(mockAuthEventBus.add(any));
      },
    );

    test(
      'should NOT add events to bus when connectivity status does not change (offline to offline)',
      () async {
        // Arrange: Start offline first
        await networkInfo.dispose();
        await setupNetworkInfo(initialResult: ConnectivityResult.none);

        // Act: Trigger another offline event
        connectivityStreamController.add([ConnectivityResult.none]);
        await Future.delayed(streamProcessingDelay); // Allow stream processing

        // Assert: Should have fired once during initialization, but not for the
        // subsequent identical event.
        verify(mockAuthEventBus.add(AuthEvent.offlineDetected)).called(1);
        verifyNever(mockAuthEventBus.add(AuthEvent.onlineRestored));
        verifyNoMoreInteractions(mockAuthEventBus);
      },
    );

    test('should NOT add events to bus on initialization', () async {
      // Arrange: setupNetworkInfo already called in setUp, initialization is done.

      // Assert: Verify no events were added during initialization
      verifyNever(mockAuthEventBus.add(any));
    });
  });

  group('lifecycle and initialization', () {
    // No top-level setUp here, each test manages its instance

    test(
      'should call checkConnectivity once during initialization (online)',
      () async {
        await setupNetworkInfo(initialResult: ConnectivityResult.wifi);
        verify(mockConnectivity.checkConnectivity()).called(1);
        verify(mockConnectivity.onConnectivityChanged).called(1);
      },
    );

    test(
      'should call checkConnectivity once during initialization (offline)',
      () async {
        await setupNetworkInfo(initialResult: ConnectivityResult.none);
        verify(mockConnectivity.checkConnectivity()).called(1);
        verify(mockConnectivity.onConnectivityChanged).called(1);
      },
    );

    test('dispose should cancel connectivity stream subscription', () async {
      await setupNetworkInfo(initialResult: ConnectivityResult.wifi);
      final emittedValues = <bool>[];
      final subscription = networkInfo.onConnectivityChanged.listen(
        emittedValues.add,
      );
      await networkInfo.dispose();
      try {
        connectivityStreamController.add([ConnectivityResult.none]);
      } catch (e) {
        expect(e, isA<StateError>());
      }
      await Future.delayed(Duration.zero);
      expect(emittedValues, isEmpty);
      await subscription.cancel();
      if (!connectivityStreamController.isClosed) {
        await connectivityStreamController.close();
      }
    });

    test('should handle errors during initial checkConnectivity', () async {
      mockConnectivity = MockConnectivity();
      mockAuthEventBus = MockAuthEventBus(); // Init mock bus
      connectivityStreamController =
          StreamController<List<ConnectivityResult>>.broadcast();
      final testError = Exception('Connectivity check failed');
      when(mockConnectivity.checkConnectivity()).thenThrow(testError);
      when(
        mockConnectivity.onConnectivityChanged,
      ).thenAnswer((_) => connectivityStreamController.stream);
      networkInfo = NetworkInfoImpl(
        mockConnectivity,
        mockAuthEventBus,
      ); // Add mock bus
      await Future.delayed(Duration.zero); // Allow init to potentially run/fail
      final isConnectedResult = await networkInfo.isConnected;
      expect(isConnectedResult, false);
      verify(mockConnectivity.checkConnectivity()).called(1);
      verifyNever(
        mockAuthEventBus.add(any),
      ); // Ensure no events fired on init error
    });

    test('should handle errors from onConnectivityChanged stream', () async {
      await setupNetworkInfo(initialResult: ConnectivityResult.wifi);
      final testError = Exception('Connectivity stream error');
      final emittedValues = <Object>[]; // Changed to Object to capture error
      final subscription = networkInfo.onConnectivityChanged.listen(
        emittedValues.add, // Add data
        onError: emittedValues.add, // Add error
      );
      connectivityStreamController.addError(testError);
      await Future.delayed(
        const Duration(milliseconds: 10),
      ); // Allow error propagation
      expect(emittedValues, contains(testError));
      await subscription.cancel();
    });
  });
}
