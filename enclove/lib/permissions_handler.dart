// permissions_handler.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionsHandler {
  static Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
  }
}