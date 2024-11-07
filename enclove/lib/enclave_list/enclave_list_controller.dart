// enclave_list_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import '../database/database_helper.dart';
import '../map/enclave_map_screen.dart';
import '../nearby_service_manager.dart'; // Import NearbyServiceManager

class EnclaveListController {
  List<Map<String, dynamic>> ownedEnclaves = [];
  List<Map<String, dynamic>> joinedEnclaves = [];

  final VoidCallback onDataChanged;
  late NearbyServiceManager nearbyServiceManager;

  EnclaveListController({required this.onDataChanged, required this.nearbyServiceManager}) {
    // nearbyServiceManager = NearbyServiceManager(onDeviceUpdate: (devices) {
    //   nearbyDevices = devices;
    //   onDataChanged(); // Notify UI when device list changes
    // });
    //nearbyServiceManager.initializeNearbyService();
  }

  Future<void> loadEnclaves() async {
    final enclaves = await DatabaseHelper.instance.getEnclaves();
    ownedEnclaves = enclaves.where((e) => e['created_by_me'] == 1).toList();
    joinedEnclaves = enclaves.where((e) => e['is_member'] == 1 && e['created_by_me'] == 0).toList();
    onDataChanged();
  }

  void sendEnclaveList(String deviceId) {
    nearbyServiceManager.sendEnclaveList(deviceId, ownedEnclaves);
  }

  Future<void> connectToDevice(Device device) async {
    if (device.state == SessionState.notConnected) {
      await nearbyServiceManager.connectToDevice(device);
    }
  }

  Future<void> createEnclave(String name, String description) async {
    await DatabaseHelper.instance.createEnclave(name, description);
    await loadEnclaves(); // Reload enclaves to refresh the list
  }

  Future<void> deleteEnclave(int enclaveId) async {
    await DatabaseHelper.instance.deleteEnclave(enclaveId);
    await loadEnclaves();
  }

  void navigateToMapScreen(BuildContext context, Map<String, dynamic> enclave) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnclaveMapScreen(
          enclaveId: enclave['id'],
          enclaveName: enclave['name'],
        ),
      ),
    );
  }

  void dispose() {
    nearbyServiceManager.dispose();
  }
}
