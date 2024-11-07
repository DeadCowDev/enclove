import 'dart:async';
import 'dart:convert';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';

class NearbyServiceManager{
  List<Function(List<Device>)> onDeviceUpdate = [];
  List<Function(dynamic)> onDataReceived = [];
  late NearbyService nearbyService;
  late StreamSubscription subscription;
  List<Device> nearbyDevices = [];

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
      nearbyDevices = devices;
      for (var update in onDeviceUpdate) {
        update(devices);
      }
    });

    nearbyService.dataReceivedSubscription(callback: (data) {
      for (var update in onDataReceived) {
        update(data);
      }
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

  void sendMessage(String deviceId, String message){
    nearbyService.sendMessage(deviceId, message);
  }

  // void sendEnclaveList(String deviceId, List<Map<String, dynamic>> enclaves) {
  //   final message = jsonEncode({
  //     'type': 'enclave_list',
  //     'enclaves': enclaves,
  //   });
  //   nearbyService.sendMessage(deviceId, message);
  // }

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