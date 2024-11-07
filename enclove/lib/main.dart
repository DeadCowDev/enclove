import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database/database_helper.dart';
import 'enclave_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  runApp(MyApp());
}

Future<void> requestPermissions() async {
  await [
    Permission.location,
    Permission.bluetooth,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.locationWhenInUse,
  ].request();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enclave Network',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: EnclavesScreen(),
    );
  }
}

class EnclavesScreen extends StatefulWidget {
  @override
  _EnclavesScreenState createState() => _EnclavesScreenState();
}

class _EnclavesScreenState extends State<EnclavesScreen> {
  List<Map<String, dynamic>> ownedEnclaves = []; // Enclaves this user owns
  List<Map<String, dynamic>> joinedEnclaves = []; // Enclaves this user has joined
  List<Device> nearbyDevices = [];
  int? selectedEnclaveId;
  late NearbyService nearbyService;
  late StreamSubscription subscription;
  late StreamSubscription receivedDataSubscription;
  bool isOwner = false; // Tracks if current user is the enclave owner

  @override
  void initState() {
    super.initState();
    initNearbyService();
    loadEnclaves();
  }

  // Add this helper method for connecting to a device
  void connectToDevice(Device device) async {
    if (device.state == SessionState.notConnected) {
      try {
        // Attempt to connect to the selected device
        await nearbyService.invitePeer(deviceID: device.deviceId, deviceName: device.deviceName);
        showToast("Connecting to ${device.deviceName}", context: context);
      } catch (e) {
        showToast("Failed to connect: $e", context: context);
      }
    } else {
      showToast("${device.deviceName} is already connected", context: context);
    }
  }

  Future<void> loadEnclaves() async {
    final dbEnclaves = await DatabaseHelper.instance.getEnclaves();
    setState(() {
      ownedEnclaves = dbEnclaves.where((e) => e['created_by_me'] == 1).toList();
      joinedEnclaves = dbEnclaves.where((e) => e['is_member'] == 1 && e['created_by_me'] == 0).toList();
    });
    startAdvertisingEnclaves();
  }

  Future<void> createEnclave(String name, String description) async {
    await DatabaseHelper.instance.createEnclave(name, description);
    await loadEnclaves();
    startAdvertisingEnclaves();
  }

  Future<void> deleteEnclave(int enclaveId) async {
    await DatabaseHelper.instance.deleteEnclave(enclaveId);
    await loadEnclaves();
  }

  void startAdvertisingEnclaves() async {
    await nearbyService.stopAdvertisingPeer(); // Stop any existing advertising
    await nearbyService.startAdvertisingPeer(); // Start advertising own enclaves
    showToast("Advertising owned enclaves", context: context);
  }

  void startBrowsingForDevices() async {
    await nearbyService.stopBrowsingForPeers(); // Stop any existing browsing
    await nearbyService.startBrowsingForPeers(); // Browse for devices advertising enclaves
  }

  void initNearbyService() async {
    nearbyService = NearbyService();
    await nearbyService.init(
      serviceType: 'enclave_conn',
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning) {
          startBrowsingForDevices();
        }
      },
    );

    // Listen for state changes in nearby devices
    subscription = nearbyService.stateChangedSubscription(callback: (devicesList) {
      setState(() {
        nearbyDevices = devicesList;
      });
    });

    // Handle incoming data from other devices
    receivedDataSubscription = nearbyService.dataReceivedSubscription(callback: (data) {
      final receivedMessage = jsonDecode(data['message']);
      if (receivedMessage['type'] == 'enclave_list') {
        _showEnclavesToJoin(receivedMessage['enclaves'], data['deviceId']);
      } else if (receivedMessage['type'] == 'join_request') {
        _showJoinRequest(receivedMessage['enclave_name'], data['deviceId']);
      } else if (receivedMessage['type'] == 'join_approval') {
        _handleJoinApproval(receivedMessage['enclave_name']);
      }
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    receivedDataSubscription.cancel();
    nearbyService.stopAdvertisingPeer();
    nearbyService.stopBrowsingForPeers();
    super.dispose();
  }

  // Show list of enclaves available to join
  void _showEnclavesToJoin(List enclaves, String deviceId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Join an Enclave"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: enclaves.map<Widget>((enclave) {
              return ListTile(
                title: Text(enclave['name']),
                subtitle: Text(enclave['description']),
                onTap: () => _requestJoinEnclave(enclave['name'], deviceId),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Send a request to join a specific enclave on another device
  void _requestJoinEnclave(String enclaveName, String deviceId) {
    final message = jsonEncode({
      'type': 'join_request',
      'enclave_name': enclaveName,
    });
    nearbyService.sendMessage(deviceId, message);
    Navigator.of(context).pop();
    showToast("Requested to join enclave: $enclaveName", context: context);
  }

  //AIzaSyBX7UoM_YCPffDGIOjDHJlrXGQa2_vk6Ho

  // Show a join request for approval
  void _showJoinRequest(String enclaveName, String deviceId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Join Request"),
          content: Text("User requests to join your enclave: $enclaveName"),
          actions: [
            TextButton(
              onPressed: () {
                _approveJoinRequest(enclaveName, deviceId);
                Navigator.of(context).pop();
              },
              child: Text("Approve"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Deny"),
            ),
          ],
        );
      },
    );
  }

  // Approve the join request and notify the requester
  void _approveJoinRequest(String enclaveName, String deviceId) {
    final message = jsonEncode({
      'type': 'join_approval',
      'enclave_name': enclaveName,
    });
    nearbyService.sendMessage(deviceId, message);
    showToast("Approved join request for: $enclaveName", context: context);
  }

  // Handle approval and add user to the enclave
  void _handleJoinApproval(String enclaveName) async {
    await DatabaseHelper.instance.joinEnclave(enclaveName);
    await loadEnclaves();
    showToast("Successfully joined enclave: $enclaveName", context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enclaves")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () => _showCreateEnclaveDialog(),
            child: Text("Create New Enclave"),
          ),
// Owned Enclaves ListView.builder
          Expanded(
            child: ListView.builder(
              itemCount: ownedEnclaves.length,
              itemBuilder: (context, index) {
                final enclave = ownedEnclaves[index];
                return ListTile(
                  title: Text(enclave['name']),
                  subtitle: Text(enclave['description'] ?? ""),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => deleteEnclave(enclave['id']),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EnclaveMapScreen(
                        enclaveId: enclave['id'],
                        enclaveName: enclave['name'],

                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(),
          // Joined Enclaves ListView.builder
          Expanded(
            child: ListView.builder(
              itemCount: joinedEnclaves.length,
              itemBuilder: (context, index) {
                final enclave = joinedEnclaves[index];
                return ListTile(
                  title: Text(enclave['name']),
                  subtitle: Text(enclave['description'] ?? ""),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EnclaveMapScreen(
                        enclaveId: enclave['id'],
                        enclaveName: enclave['name']
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(),
          Text("Nearby Devices"),
          Expanded(
            child: ListView.builder(
              itemCount: nearbyDevices.length,
              itemBuilder: (context, index) {
                final device = nearbyDevices[index];
                return ListTile(
                  title: Text(device.deviceName),
                  subtitle: Text(getStateName(device.state)),
                  trailing: IconButton(
                    icon: Icon(device.state == SessionState.notConnected ? Icons.person_add : Icons.message),
                    onPressed: () => connectToDevice(device),
                  ),
                  onTap: () {
                    if (device.state == SessionState.connected) {
                      _sendEnclaveList(device.deviceId);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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

  void _sendEnclaveList(String deviceId) {
    final message = jsonEncode({
      'type': 'enclave_list',
      'enclaves': ownedEnclaves,
    });
    nearbyService.sendMessage(deviceId, message);
    showToast("Sent enclave list to ${deviceId}", context: context);
  }

  void _showCreateEnclaveDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Create Enclave"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Enclave Name"),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: "Description"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                createEnclave(nameController.text, descriptionController.text);
                Navigator.of(context).pop();
              },
              child: Text("Create"),
            ),
          ],
        );
      },
    );
  }
}


