import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return true;

    var granted = false;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        final mediaStatus = await Permission.audio.request();
        granted = mediaStatus.isGranted || mediaStatus.isLimited;
      } else {
        final storageStatus = await Permission.storage.request();
        granted = storageStatus.isGranted || storageStatus.isLimited;
      }
    } catch (_) {}

    if (!granted) {
      try {
        final audioStatus = await Permission.audio.request();
        if (audioStatus.isGranted || audioStatus.isLimited) {
          granted = true;
        }
      } catch (_) {}
    }

    if (!granted) {
      try {
        final storageStatus = await Permission.storage.request();
        granted = storageStatus.isGranted || storageStatus.isLimited;
      } catch (_) {}
    }

    try {
      await requestNotificationPermission();
    } catch (_) {}

    return granted;
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> isNotificationDenied() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.notification.status;
    return !status.isGranted && !status.isLimited;
  }

  Future<bool> isNotificationPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.notification.status;
    return status.isPermanentlyDenied;
  }

  Future<bool> openSettings() async {
    return openAppSettings();
  }
}
