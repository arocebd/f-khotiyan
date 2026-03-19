import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// Helper class for managing app permissions
class PermissionHelper {
  /// Check if all required permissions are granted
  static Future<bool> checkAllPermissions() async {
    final storage = await Permission.storage.status;
    final camera = await Permission.camera.status;
    final location = await Permission.location.status;
    final contacts = await Permission.contacts.status;

    return storage.isGranted &&
        camera.isGranted &&
        location.isGranted &&
        contacts.isGranted;
  }

  /// Request storage permission
  static Future<PermissionStatus> requestStoragePermission() async {
    return await Permission.storage.request();
  }

  /// Request camera permission
  static Future<PermissionStatus> requestCameraPermission() async {
    return await Permission.camera.request();
  }

  /// Request location permission
  static Future<PermissionStatus> requestLocationPermission() async {
    return await Permission.location.request();
  }

  /// Request contacts permission
  static Future<PermissionStatus> requestContactsPermission() async {
    return await Permission.contacts.request();
  }

  /// Request all permissions at once
  static Future<Map<Permission, PermissionStatus>>
      requestAllPermissions() async {
    return await [
      Permission.storage,
      Permission.camera,
      Permission.location,
      Permission.contacts,
    ].request();
  }

  /// Check if a specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Show permission rationale dialog
  static Future<bool?> showPermissionRationaleDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onGrantPressed,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              onGrantPressed();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  /// Open app settings if permission is permanently denied
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Handle permission status and show appropriate message
  static Future<bool> handlePermissionStatus(
    BuildContext context,
    Permission permission,
    String permissionName,
  ) async {
    final status = await permission.request();

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$permissionName Required'),
            content: Text(
              '$permissionName permission is permanently denied. Please enable it from app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        return result ?? false;
      }
    } else if (status.isDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$permissionName permission denied'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                handlePermissionStatus(context, permission, permissionName);
              },
            ),
          ),
        );
      }
    }

    return false;
  }

  /// Request permissions with context for showing dialogs
  static Future<bool> requestPermissionsWithDialogs(
    BuildContext context,
  ) async {
    // Storage Permission
    if (!await isPermissionGranted(Permission.storage)) {
      if (!context.mounted) return false;
      final granted = await handlePermissionStatus(
        context,
        Permission.storage,
        'Storage',
      );
      if (!granted) return false;
    }

    // Camera Permission
    if (!await isPermissionGranted(Permission.camera)) {
      if (!context.mounted) return false;
      final granted = await handlePermissionStatus(
        context,
        Permission.camera,
        'Camera',
      );
      if (!granted) return false;
    }

    // Location Permission
    if (!await isPermissionGranted(Permission.location)) {
      if (!context.mounted) return false;
      final granted = await handlePermissionStatus(
        context,
        Permission.location,
        'Location',
      );
      if (!granted) return false;
    }

    // Contacts Permission
    if (!await isPermissionGranted(Permission.contacts)) {
      if (!context.mounted) return false;
      final granted = await handlePermissionStatus(
        context,
        Permission.contacts,
        'Contacts',
      );
      if (!granted) return false;
    }

    return true;
  }
}
