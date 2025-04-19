import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:docjet_mobile/core/platform/network_info_impl.dart'; // Implementation path
import 'package:docjet_mobile/core/interfaces/network_info.dart'; // Interface path

// Generate mocks for Connectivity
@GenerateMocks([Connectivity])
import 'network_info_impl_test.mocks.dart';

void main() {
  late NetworkInfoImpl networkInfo;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockConnectivity = MockConnectivity();
    // Important: Instantiate the IMPLEMENTATION, not the interface!
    networkInfo = NetworkInfoImpl(mockConnectivity);
  });

  // Helper function for stubbing connectivity results
  void arrangeConnectivityResult(ConnectivityResult result) {
    when(mockConnectivity.checkConnectivity())
    // Return a list containing the single result
    .thenAnswer((_) async => [result]);
  }

  test(
    'isConnected should return true when Connectivity returns ConnectivityResult.wifi',
    () async {
      // Arrange
      arrangeConnectivityResult(ConnectivityResult.wifi);
      // Act
      final result = await networkInfo.isConnected;
      // Assert
      expect(result, true);
      verify(mockConnectivity.checkConnectivity());
      verifyNoMoreInteractions(mockConnectivity);
    },
  );

  test(
    'isConnected should return true when Connectivity returns ConnectivityResult.mobile',
    () async {
      // Arrange
      arrangeConnectivityResult(ConnectivityResult.mobile);
      // Act
      final result = await networkInfo.isConnected;
      // Assert
      expect(result, true);
      verify(mockConnectivity.checkConnectivity());
      verifyNoMoreInteractions(mockConnectivity);
    },
  );

  test(
    'isConnected should return true when Connectivity returns ConnectivityResult.ethernet',
    () async {
      // Arrange
      arrangeConnectivityResult(ConnectivityResult.ethernet);
      // Act
      final result = await networkInfo.isConnected;
      // Assert
      expect(result, true);
      verify(mockConnectivity.checkConnectivity());
      verifyNoMoreInteractions(mockConnectivity);
    },
  );

  test(
    'isConnected should return true when Connectivity returns ConnectivityResult.vpn',
    () async {
      // Arrange
      arrangeConnectivityResult(ConnectivityResult.vpn);
      // Act
      final result = await networkInfo.isConnected;
      // Assert
      expect(result, true);
      verify(mockConnectivity.checkConnectivity());
      verifyNoMoreInteractions(mockConnectivity);
    },
  );

  test(
    'isConnected should return true when Connectivity returns ConnectivityResult.bluetooth',
    () async {
      // Arrange
      arrangeConnectivityResult(ConnectivityResult.bluetooth);
      // Act
      final result = await networkInfo.isConnected;
      // Assert
      expect(result, true);
      verify(mockConnectivity.checkConnectivity());
      verifyNoMoreInteractions(mockConnectivity);
    },
  );

  test(
    'isConnected should return true when Connectivity returns ConnectivityResult.other',
    () async {
      // Arrange
      arrangeConnectivityResult(ConnectivityResult.other);
      // Act
      final result = await networkInfo.isConnected;
      // Assert
      expect(result, true);
      verify(mockConnectivity.checkConnectivity());
      verifyNoMoreInteractions(mockConnectivity);
    },
  );

  test(
    'isConnected should return false when Connectivity returns ConnectivityResult.none',
    () async {
      // Arrange
      arrangeConnectivityResult(ConnectivityResult.none);
      // Act
      final result = await networkInfo.isConnected;
      // Assert
      expect(result, false);
      verify(mockConnectivity.checkConnectivity());
      verifyNoMoreInteractions(mockConnectivity);
    },
  );
}
