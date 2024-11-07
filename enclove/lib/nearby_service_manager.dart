import 'dart:async';
import 'dart:convert';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';

class NearbyServiceManager{
  final Function(List<Device>) onDeviceUpdate;
  late NearbyService nearbyService;
  late StreamSubscription subscription;
  List<Device> nearbyDevices = [];

  NearbyServiceManager({required this.onDeviceUpdate});

  void initializeNearbyService() async {
    nearbyService = NearbyService();
    await nearbyService.init(
      serviceType: 'enclave_conn',
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning) {
          await startBrowsingForDevices();
        }
      },
    );

    nearbyService.stateChangedSubscription(callback: (devices) {
      onDeviceUpdate(devices); // Update the device list in the controller
    });

    await startBrowsingForDevices();
   }

  Future<void> startBrowsingForDevices() async {
    await nearbyService.startAdvertisingPeer();
    await nearbyService.startBrowsingForPeers();
  }

  Future<void> connectToDevice(Device device) async {
    if (device.state == SessionState.notConnected) {
      await nearbyService.invitePeer(
        deviceID: device.deviceId,
        deviceName: device.deviceName
      );
    }
  }

  void dispose() {
    nearbyService.stopBrowsingForPeers();
    nearbyService.stopAdvertisingPeer();
  }

  void sendEnclaveList(String deviceId, List<Map<String, dynamic>> enclaves) {
    final message = jsonEncode({
      'type': 'enclave_list',
      'enclaves': enclaves,
    });
    nearbyService.sendMessage(deviceId, message);
  }

  String getStateName(SessionState state) {
    switch (state) {
      case SessionState.notConnected:
        return "Disconnected";
      case SessionState.connecting:
        return "Connecting";
      case SessionState.connected:
        return "Connected";
      default:
        return "Unknown";
    }
  }
}