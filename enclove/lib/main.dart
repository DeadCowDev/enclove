// main.dart
import 'package:flutter/material.dart';
import 'enclave_list/enclave_list_screen.dart';
import 'nearby_service_manager.dart';
import 'permissions_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PermissionsHandler.requestPermissions();
  final nearbyServiceManager = NearbyServiceManager();// Initialize the manager
  nearbyServiceManager.initializeNearbyService();
  runApp(MyApp(nearbyServiceManager: nearbyServiceManager));
}

class MyApp extends StatelessWidget {

  final NearbyServiceManager nearbyServiceManager;

  const MyApp({Key? key, required this.nearbyServiceManager}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enclave Network',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: EnclavesScreen(nearbyServiceManager: nearbyServiceManager),
    );
  }
}