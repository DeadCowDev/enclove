import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database/database_helper.dart';

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
  List<Map<String, dynamic>> enclaves = [];
  List<Map<String, dynamic>> messages = [];
  List<Device> nearbyDevices = [];
  int? selectedEnclaveId;
  late NearbyService nearbyService;
  late StreamSubscription subscription;
  late StreamSubscription receivedDataSubscription;

  @override
  void initState() {
    super.initState();
    initNearbyService();
    loadEnclaves();
  }

  Future<void> loadEnclaves() async {
    final dbEnclaves = await DatabaseHelper.instance.getEnclaves();
    setState(() {
      enclaves = dbEnclaves.where((e) => e['is_member'] == 1).toList();
    });
    startAdvertisingEnclaves();  // Start advertising the user's enclaves
  }

  Future<void> createEnclave(String name, String description) async {
    await DatabaseHelper.instance.createEnclave(name, description);
    await loadEnclaves();
    startAdvertisingEnclaves(); // Ensure the new enclave is also advertised
  }

  Future<void> deleteEnclave(int enclaveId) async {
    await DatabaseHelper.instance.deleteEnclave(enclaveId);
    await loadEnclaves();
  }

  void startAdvertisingEnclaves() async {
    await nearbyService.stopAdvertisingPeer(); // Stop any existing advertising session
    enclaves.forEach((enclave) async {
      // Encode enclave data to include name and description
      await nearbyService.startAdvertisingPeer();
      showToast("Advertising Enclave: ${enclave['name']}", context: context);
    });
  }

  Future<void> startBrowsingForEnclaves() async {
    await nearbyService.stopBrowsingForPeers(); // Stop any existing browsing session
    await nearbyService.startBrowsingForPeers();
  }

  void initNearbyService() async {
    nearbyService = NearbyService();
    await nearbyService.init(
      serviceType: 'enclave_conn',
      strategy: Strategy.P2P_CLUSTER,
      callback: (isRunning) async {
        if (isRunning) {
          await startBrowsingForEnclaves(); // Continuous browsing for other enclaves
        }
      },
    );

    // Listen for nearby devices that advertise enclaves
    subscription = nearbyService.stateChangedSubscription(callback: (devicesList) {
      setState(() {
        nearbyDevices = devicesList;
      });
    });

    // Listen for messages from nearby devices (e.g., join requests)
    receivedDataSubscription = nearbyService.dataReceivedSubscription(callback: (data) {
      final receivedMessage = jsonDecode(data['message']);
      if (receivedMessage['type'] == 'join_request') {
        showToast("Received Join Request for Enclave: ${receivedMessage['enclave_name']}", context: context);
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
          Expanded(
            child: ListView.builder(
              itemCount: enclaves.length,
              itemBuilder: (context, index) {
                final enclave = enclaves[index];
                return ListTile(
                  title: Text(enclave['name']),
                  subtitle: Text(enclave['description'] ?? ""),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (enclave['created_by_me'] == 1)
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => deleteEnclave(enclave['id']),
                        ),
                      IconButton(
                        icon: Icon(Icons.message),
                        onPressed: () => loadMessages(enclave['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: nearbyDevices.length,
              itemBuilder: (context, index) {
                final device = nearbyDevices[index];
                return ListTile(
                  title: Text(device.deviceName),
                  subtitle: Text(getStateName(device.state)),
                  trailing: IconButton(
                    icon: Icon(Icons.person_add),
                    onPressed: () => sendJoinRequest(device),
                  ),
                );
              },
            ),
          ),
          if (selectedEnclaveId != null) ...[
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return ListTile(
                    title: Text(message['content']),
                    subtitle: Text(message['timestamp']),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onSubmitted: (text) {
                  sendMessage(text);
                },
                decoration: InputDecoration(
                  labelText: 'Enter message',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
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

  Future<void> loadMessages(int enclaveId) async {
    final dbMessages = await DatabaseHelper.instance.getMessages(enclaveId);
    setState(() {
      messages = dbMessages;
      selectedEnclaveId = enclaveId;
    });
  }

  void sendMessage(String content) async {
    if (selectedEnclaveId != null) {
      await DatabaseHelper.instance.insertMessage(content, selectedEnclaveId!);
      await loadMessages(selectedEnclaveId!);
    }
  }

  Future<void> sendJoinRequest(Device device) async {
    // Encode a join request message
    final message = jsonEncode({
      'type': 'join_request',
      'enclave_name': enclaves.first['name'], // Change this to send the desired enclave name
    });
    nearbyService.sendMessage(device.deviceId, message);
    showToast("Sent join request for enclave: ${enclaves.first['name']}", context: context);
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
        });
  }
}
