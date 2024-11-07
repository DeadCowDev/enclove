import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'database/database_helper.dart';

class EnclaveMapScreen extends StatefulWidget {
  final int enclaveId;
  final String enclaveName;

  EnclaveMapScreen({required this.enclaveId, required this.enclaveName});

  @override
  _EnclaveMapScreenState createState() => _EnclaveMapScreenState();
}

class _EnclaveMapScreenState extends State<EnclaveMapScreen> {
  late GoogleMapController _mapController;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _loadEnclavePins();
  }

  Future<void> _fetchCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _loadEnclavePins() async {
    final pins = await DatabaseHelper.instance.getPins(widget.enclaveId);
    setState(() {
      _markers = pins.map((pin) {
        return Marker(
          markerId: MarkerId(pin['id'].toString()),
          position: LatLng(pin['latitude'], pin['longitude']),
          infoWindow: InfoWindow(title: pin['description']),
        );
      }).toSet();
    });
  }

  Future<void> _addPin(LatLng position) async {
    final descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Pin'),
          content: TextField(
            controller: descriptionController,
            decoration: InputDecoration(hintText: 'Enter pin description'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final description = descriptionController.text;
                await DatabaseHelper.instance.addPin(
                  widget.enclaveId,
                  position.latitude,
                  position.longitude,
                  description,
                );
                setState(() {
                  _markers.add(
                    Marker(
                      markerId: MarkerId(DateTime.now().toString()),
                      position: position,
                      infoWindow: InfoWindow(title: description),
                    ),
                  );
                });
                Navigator.pop(context);
              },
              child: Text('Add Pin'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.enclaveName)),
      body: _currentLocation == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentLocation!,
          zoom: 14,
        ),
        onMapCreated: (controller) => _mapController = controller,
        markers: _markers,
        onTap: _addPin,
      ),
    );
  }
}
