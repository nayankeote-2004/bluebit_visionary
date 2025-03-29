import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Request all required permissions at app startup
  static Future<void> requestInitialPermissions(BuildContext context) async {
    // Determine which permissions to request based on Android version
    List<Permission> permissions = [];

    // Storage permissions
    if (await _isAndroid13OrHigher()) {
      // For Android 13+, use granular media permissions
      permissions.add(Permission.photos);
      permissions.add(Permission.videos);
    } else {
      // For older versions, use storage permission
      permissions.add(Permission.storage);
    }

    // Always request notification permission
    permissions.add(Permission.notification);

    // Request each permission with proper explanation
    for (var permission in permissions) {
      await _requestPermissionWithRationale(context, permission);
    }
  }

  // Check if device is running Android 13 or higher
  static Future<bool> _isAndroid13OrHigher() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt >= 33; // Android 13 is API 33
  }

  // Request a specific permission with explanation
  static Future<bool> _requestPermissionWithRationale(
    BuildContext context,
    Permission permission,
  ) async {
    // Check current status
    PermissionStatus status = await permission.status;

    // Return if already granted
    if (status.isGranted) return true;

    // If permanently denied, guide to settings
    if (status.isPermanentlyDenied) {
      return await _handlePermanentlyDenied(context, permission);
    }

    // Show explanation before requesting permission
    String title = _getPermissionTitle(permission);
    String rationale = _getPermissionRationale(permission);

    bool shouldRequest =
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(rationale),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('NOT NOW'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('ALLOW'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldRequest) {
      final result = await permission.request();
      return result.isGranted;
    }

    return false;
  }

  // Handle permanently denied permissions
  static Future<bool> _handlePermanentlyDenied(
    BuildContext context,
    Permission permission,
  ) async {
    String title = _getPermissionTitle(permission);

    final bool shouldOpenSettings =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('$title Required'),
              content: Text(
                'This permission is required for the app to function properly. '
                'Please enable it in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('OPEN SETTINGS'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldOpenSettings) {
      await openAppSettings();
      return await permission.status.isGranted;
    }

    return false;
  }

  // Get user-friendly permission title
  static String _getPermissionTitle(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return 'Storage Access';
      case Permission.photos:
        return 'Photo Access';
      case Permission.videos:
        return 'Video Access';
      case Permission.notification:
        return 'Notifications';
      default:
        return 'Permission';
    }
  }

  // Get permission rationale explanation
  static String _getPermissionRationale(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return 'WikiTok needs storage access to save and read PDF files from your device.';
      case Permission.photos:
      case Permission.videos:
        return 'WikiTok needs media access to save PDF files to your device.';
      case Permission.notification:
        return 'WikiTok would like to send you notifications when PDFs are downloaded and for other important updates.';
      default:
        return 'This permission is required for app functionality.';
    }
  }
}
