// map_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../database/database_helper.dart';

class MapController {
  final int enclaveId;
  final VoidCallback onPinsLoaded;
  GoogleMapController? mapController;
  LatLng? currentLocation;
  Set<Marker> markers = {};

  MapController(this.enclaveId, {required this.onPinsLoaded});

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> fetchCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    currentLocation = LatLng(position.latitude, position.longitude);
  }

  Future<void> loadEnclavePins() async {
    final pins = await DatabaseHelper.instance.getPins(enclaveId);
    markers = pins.map((pin) {
      return Marker(
        markerId: MarkerId(pin['id'].toString()),
        position: LatLng(pin['latitude'], pin['longitude']),
        infoWindow: InfoWindow(title: pin['description']),
      );
    }).toSet();
    onPinsLoaded(); // Notify the UI to rebuild with new pins
  }

  Future<void> addPin(LatLng position, String description) async {
    await DatabaseHelper.instance.addPin(enclaveId, position.latitude, position.longitude, description);
    markers.add(
      Marker(
        markerId: MarkerId(DateTime.now().toString()),
        position: position,
        infoWindow: InfoWindow(title: description),
      ),
    );
    onPinsLoaded();
  }

  void dispose() {
    mapController?.dispose();
  }
}
