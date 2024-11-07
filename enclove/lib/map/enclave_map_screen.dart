// enclave_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import './map_controller.dart';
import './map_widgets.dart';

class EnclaveMapScreen extends StatefulWidget {
  final int enclaveId;
  final String enclaveName;

  EnclaveMapScreen({required this.enclaveId, required this.enclaveName});

  @override
  _EnclaveMapScreenState createState() => _EnclaveMapScreenState();
}

class _EnclaveMapScreenState extends State<EnclaveMapScreen> {
  late MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController(widget.enclaveId, onPinsLoaded: () {
      setState(() {}); // Rebuild when pins are loaded or updated
    });
    mapController.fetchCurrentLocation();
    mapController.loadEnclavePins();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.enclaveName)),
      body: mapController.currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: mapController.currentLocation!,
          zoom: 14,
        ),
        onMapCreated: mapController.onMapCreated,
        markers: mapController.markers,
        onTap: (position) => showAddPinDialog(context, mapController, position),
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}