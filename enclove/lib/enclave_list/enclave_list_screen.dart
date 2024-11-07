
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