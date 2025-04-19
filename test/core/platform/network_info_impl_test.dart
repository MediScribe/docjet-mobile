import 'dart:async'; // Import async for StreamController

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/platform/network_info_impl.dart'; // Implementation path
// import 'package:docjet_mobile/core/interfaces/network_info.dart'; // UNUSED

// Generate mocks for Connectivity
@GenerateMocks([Connectivity])
import 'network_info_impl_test.mocks.dart';

void main() {
  late NetworkInfoImpl networkInfo;
  late MockConnectivity mockConnectivity;
  // Stream controller for mocking connectivity changes
  late StreamController<List<ConnectivityResult>> connectivityStreamController;

  setUp(() {
    mockConnectivity = MockConnectivity();
    // Create a new stream controller for each test
    connectivityStreamController =
        StreamController<List<ConnectivityResult>>.broadcast();
    // Stub the onConnectivityChanged stream
    when(
      mockConnectivity.onConnectivityChanged,
    ).thenAnswer((_) => connectivityStreamController.stream);

    // Important: Instantiate the IMPLEMENTATION, not the interface!
    networkInfo = NetworkInfoImpl(mockConnectivity);
  });

  tearDown(() {
    // Close the stream controller after each test
    connectivityStreamController.close();
  });

  // Group for the original isConnected tests
  group('isConnected', () {
    // Helper function for stubbing connectivity results
    void arrangeConnectivityCheckResult(ConnectivityResult result) {
      when(
        mockConnectivity.checkConnectivity(),
      ).thenAnswer((_) async => [result]);
    }

    test(
      'should return true when Connectivity returns ConnectivityResult.wifi',
      () async {
        // Arrange
        arrangeConnectivityCheckResult(ConnectivityResult.wifi);
        // Act
        final result = await networkInfo.isConnected;
        // Assert
        expect(result, true);
        verify(mockConnectivity.checkConnectivity());
        verifyNoMoreInteractions(mockConnectivity);
      },
    );

    test(
      'should return true when Connectivity returns ConnectivityResult.mobile',
      () async {
        // Arrange
        arrangeConnectivityCheckResult(ConnectivityResult.mobile);
        // Act
        final result = await networkInfo.isConnected;
        // Assert
        expect(result, true);
        verify(mockConnectivity.checkConnectivity());
        verifyNoMoreInteractions(mockConnectivity);
      },
    );

    test(
      'should return true when Connectivity returns ConnectivityResult.ethernet',
      () async {
        // Arrange
        arrangeConnectivityCheckResult(ConnectivityResult.ethernet);
        // Act
        final result = await networkInfo.isConnected;
        // Assert
        expect(result, true);
        verify(mockConnectivity.checkConnectivity());
        verifyNoMoreInteractions(mockConnectivity);
      },
    );

    test(
      'should return true when Connectivity returns ConnectivityResult.vpn',
      () async {
        // Arrange
        arrangeConnectivityCheckResult(ConnectivityResult.vpn);
        // Act
        final result = await networkInfo.isConnected;
        // Assert
        expect(result, true);
        verify(mockConnectivity.checkConnectivity());
        verifyNoMoreInteractions(mockConnectivity);
      },
    );

    test(
      'should return true when Connectivity returns ConnectivityResult.bluetooth',
      () async {
        // Arrange
        arrangeConnectivityCheckResult(ConnectivityResult.bluetooth);
        // Act
        final result = await networkInfo.isConnected;
        // Assert
        expect(result, true);
        verify(mockConnectivity.checkConnectivity());
        verifyNoMoreInteractions(mockConnectivity);
      },
    );

    test(
      'should return true when Connectivity returns ConnectivityResult.other',
      () async {
        // Arrange
        arrangeConnectivityCheckResult(ConnectivityResult.other);
        // Act
        final result = await networkInfo.isConnected;
        // Assert
        expect(result, true);
        verify(mockConnectivity.checkConnectivity());
        verifyNoMoreInteractions(mockConnectivity);
      },
    );

    test(
      'should return false when Connectivity returns ConnectivityResult.none',
      () async {
        // Arrange
        arrangeConnectivityCheckResult(ConnectivityResult.none);
        // Act
        final result = await networkInfo.isConnected;
        // Assert
        expect(result, false);
        verify(mockConnectivity.checkConnectivity());
        verifyNoMoreInteractions(mockConnectivity);
      },
    );
  });

  // Group for the new onConnectivityChanged stream tests
  group('onConnectivityChanged', () {
    // Use a small non-zero delay for stream processing in tests
    const streamProcessingDelay = Duration(milliseconds: 10);

    test(
      'should emit false then true when connectivity changes from none to wifi',
      () async {
        // Arrange
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );

        // Act: Simulate the change
        connectivityStreamController.add([ConnectivityResult.none]);
        await Future.delayed(
          streamProcessingDelay,
        ); // Let initial false process
        connectivityStreamController.add([ConnectivityResult.wifi]);
        await Future.delayed(
          streamProcessingDelay,
        ); // Let change to true process

        // Assert: Expect initial state then changed state
        expect(emittedValues, [false, true]);

        // Cleanup
        await subscription.cancel();
      },
    );

    test(
      'should emit true then false when connectivity changes from wifi to none',
      () async {
        // Arrange
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );

        // Act: Simulate the change
        connectivityStreamController.add([ConnectivityResult.wifi]);
        await Future.delayed(streamProcessingDelay); // Let initial true process
        connectivityStreamController.add([ConnectivityResult.none]);
        await Future.delayed(
          streamProcessingDelay,
        ); // Let change to false process

        // Assert: Expect initial state then changed state
        expect(emittedValues, [true, false]);

        // Cleanup
        await subscription.cancel();
      },
    );

    test(
      'should only emit initial true when connectivity changes from wifi to mobile (both online)',
      () async {
        // Arrange
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );

        // Act: Simulate the change
        connectivityStreamController.add([ConnectivityResult.wifi]);
        await Future.delayed(
          streamProcessingDelay,
        ); // Process wifi (emits true)
        connectivityStreamController.add([ConnectivityResult.mobile]);
        await Future.delayed(
          streamProcessingDelay,
        ); // Process mobile (no change)

        // Assert: Should only emit the first true state
        expect(emittedValues, [true]);

        // Cleanup
        await subscription.cancel();
      },
    );

    test(
      'should emit true then false when changing wifi -> none -> none',
      () async {
        // Arrange
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );

        // Act
        connectivityStreamController.add([
          ConnectivityResult.wifi,
        ]); // Go online (emits true)
        await Future.delayed(streamProcessingDelay);
        connectivityStreamController.add([
          ConnectivityResult.none,
        ]); // Go offline (emits false)
        await Future.delayed(streamProcessingDelay);
        connectivityStreamController.add([
          ConnectivityResult.none,
        ]); // Still offline (no emit)
        await Future.delayed(streamProcessingDelay);

        // Assert: Only the initial true and the change to false should emit
        expect(emittedValues, [true, false]);

        // Cleanup
        await subscription.cancel();
      },
    );

    test(
      'should emit false then true when changing none -> wifi -> wifi',
      () async {
        // Arrange
        final emittedValues = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emittedValues.add,
        );

        // Act
        connectivityStreamController.add([
          ConnectivityResult.none,
        ]); // Go offline (emits false)
        await Future.delayed(streamProcessingDelay);
        connectivityStreamController.add([
          ConnectivityResult.wifi,
        ]); // Go online (emits true)
        await Future.delayed(streamProcessingDelay);
        connectivityStreamController.add([
          ConnectivityResult.wifi,
        ]); // Still online (no emit)
        await Future.delayed(streamProcessingDelay);

        // Assert: Only the initial false and the change to true should emit
        expect(emittedValues, [false, true]);

        // Cleanup
        await subscription.cancel();
      },
    );
  });
}
