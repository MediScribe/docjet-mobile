import 'package:dio/dio.dart';

/// Utility function to check if a DioException type represents a network connectivity issue
///
/// Returns true for connection errors and timeouts that typically occur when
/// the device is offline or the server is unreachable.
bool isNetworkConnectivityError(DioExceptionType type) {
  return type == DioExceptionType.connectionError ||
      type == DioExceptionType.sendTimeout ||
      type == DioExceptionType.receiveTimeout ||
      type == DioExceptionType.connectionTimeout;
}
