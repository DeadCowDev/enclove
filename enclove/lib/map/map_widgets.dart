// map_widgets.dart
import 'package:flutter/material.dart';
import 'map_controller.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void showAddPinDialog(BuildContext context, MapController mapController, LatLng position) {
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
              await mapController.addPin(position, description);
              Navigator.pop(context);
            },
            child: Text('Add Pin'),
          ),
        ],
      );
    },
  );
}
