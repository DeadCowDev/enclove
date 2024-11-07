
import 'dart:convert';

import 'package:flutter/material.dart';
import '../nearby_service_manager.dart';
import './enclave_list_controller.dart';
import './enclave_list_widgets.dart';

class EnclavesScreen extends StatefulWidget {

  final NearbyServiceManager nearbyServiceManager;

  const EnclavesScreen({Key? key, required this.nearbyServiceManager}) : super(key: key);

  @override
  _EnclavesScreenState createState() => _EnclavesScreenState();
}

class _EnclavesScreenState extends State<EnclavesScreen> {
  late EnclaveListController enclaveController;
  late NearbyServiceManager nearbyServiceManager;

  @override
  void initState() {
    super.initState();
    enclaveController = EnclaveListController(onDataChanged: () {();
      setState(() { }); // Trigger UI update on data change
    }, nearbyServiceManager: widget.nearbyServiceManager);

    // Add data received callback to show notifications or dialogs in the UI
    widget.nearbyServiceManager.onDataReceived.add((data) {
      final receivedMessage  = jsonDecode(data['message']);
      if (receivedMessage['type'] == 'enclave_list') {
        showEnclavesToJoin(receivedMessage['enclaves'], data['deviceId']);
      } else if (receivedMessage['type'] == 'join_request') {
        showJoinRequest(receivedMessage['enclave_name'], data['deviceId']);
      } else if (receivedMessage['type'] == 'join_approval') {
        enclaveController.handleJoinApproval(receivedMessage['enclave_name']);
      }
    });


    enclaveController.loadEnclaves();
    nearbyServiceManager = widget.nearbyServiceManager;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enclaves")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () => showCreateEnclaveDialog(context, enclaveController),
            child: Text("Create New Enclave"),
          ),
          EnclaveListView(
            title: "Owned Enclaves",
            enclaves: enclaveController.ownedEnclaves,
            onDelete: enclaveController.deleteEnclave,
            onSelect: enclaveController.navigateToMapScreen,
          ),
          EnclaveListView(
            title: "Joined Enclaves",
            enclaves: enclaveController.joinedEnclaves,
            onSelect: enclaveController.navigateToMapScreen,
          ),
          DeviceListView(
            devices: nearbyServiceManager.nearbyDevices,
            onConnect: enclaveController.connectToDevice,
            onSendEnclaves: enclaveController.sendEnclaveList,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    enclaveController.dispose();
    super.dispose();
  }

  void showEnclavesToJoin(List enclaves, String deviceId) {
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
                onTap: () => requestJoinEnclave(enclave['name'], deviceId),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void requestJoinEnclave(String enclaveName, String deviceId) {
    final message = jsonEncode({
      'type': 'join_request',
      'enclave_name': enclaveName,
    });
    nearbyServiceManager.sendMessage(deviceId, message);
    Navigator.of(context).pop();
  }

  void showJoinRequest(String enclaveName, String deviceId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Join Request"),
          content: Text("User requests to join your enclave: $enclaveName"),
          actions: [
            TextButton(
              onPressed: () {
                approveJoinRequest(enclaveName, deviceId);
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

  void approveJoinRequest(String enclaveName, String deviceId) {
    final message = jsonEncode({
      'type': 'join_approval',
      'enclave_name': enclaveName,
    });
    nearbyServiceManager.sendMessage(deviceId, message);
  }

  void sendEnclaveList(String deviceId) {
    final message = jsonEncode({
      'type': 'enclave_list',
      'enclaves': enclaveController.ownedEnclaves,
    });
    nearbyServiceManager.sendMessage(deviceId, message);
  }

  void showCreateEnclaveDialog(BuildContext context, EnclaveListController controller) {
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
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                controller.createEnclave(nameController.text, descriptionController.text);
                Navigator.pop(context);
              },
              child: Text("Create"),
            ),
          ],
        );
      },
    );
  }
}