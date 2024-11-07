// enclave_list_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';

class EnclaveListView extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> enclaves;
  final Function(int enclaveId)? onDelete;
  final Function(BuildContext, Map<String, dynamic>) onSelect;

  const EnclaveListView({
    required this.title,
    required this.enclaves,
    this.onDelete,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Divider(),
          Text(title),
          Expanded(
            child: ListView.builder(
              itemCount: enclaves.length,
              itemBuilder: (context, index) {
                final enclave = enclaves[index];
                return ListTile(
                  title: Text(enclave['name']),
                  subtitle: Text(enclave['description'] ?? ""),
                  trailing: onDelete != null
                      ? IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => onDelete!(enclave['id']),
                  )
                      : null,
                  onTap: () => onSelect(context, enclave),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceListView extends StatelessWidget {
  final List<Device> devices;
  final Function(Device device) onConnect;
  final Function(String deviceId) onSendEnclaves;

  const DeviceListView({
    required this.devices,
    required this.onConnect,
    required this.onSendEnclaves,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Divider(),
          Text("Nearby Devices"),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return ListTile(
                  title: Text(device.deviceName),
                  subtitle: Text(_getStateName(device.state)),
                  trailing: IconButton(
                    icon: Icon(device.state == SessionState.notConnected
                        ? Icons.person_add
                        : Icons.message),
                    onPressed: () => onConnect(device),
                  ),
                  onTap: () {
                    if (device.state == SessionState.connected) {
                      onSendEnclaves(device.deviceId);
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

  String _getStateName(SessionState state) {
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
