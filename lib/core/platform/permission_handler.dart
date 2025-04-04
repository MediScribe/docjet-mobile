import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Abstract interface for permission handler operations to allow for mocking.
abstract class PermissionHandler {
  /// Requests the specified permissions.
  Future<Map<Permission, PermissionStatus>> request(
    List<Permission> permissions,
  );

  /// Checks the status of the specified permission.
  Future<PermissionStatus> status(Permission permission);

  /// Opens the app settings.
  Future<bool> openAppSettings();
}

/// Concrete implementation of [PermissionHandler] using the permission_handler package.
class AppPermissionHandler implements PermissionHandler {
  @override
  Future<Map<Permission, PermissionStatus>> request(
    List<Permission> permissions,
  ) async {
    return await permissions.request();
  }

  @override
  Future<PermissionStatus> status(Permission permission) async {
    return await permission.status;
  }

  @override
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }
}
