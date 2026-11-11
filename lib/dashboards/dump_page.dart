// lib/dashboards/dump_page.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';

final Map<String, IconData> trashTypesMap = {
  "Household": Icons.house,
  "Automotive": Icons.directions_car,
  "Construction": Icons.construction,
  "Plastic": Icons.delete,
  "Electronic": Icons.devices_other,
  "Organic": Icons.eco,
  "Metal": Icons.settings,
  "Liquid": Icons.water_drop,
  "Dangerous": Icons.warning,
  "Animal Carcass": Icons.pets,
  "Glass": Icons.wine_bar,
};

class DumpDashboard extends StatefulWidget {
  final String uid;
  const DumpDashboard({super.key, required this.uid});

  @override
  State<DumpDashboard> createState() => _DumpDashboardState();
}

class _DumpDashboardState extends State<DumpDashboard> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;

  String selectedTrashType = "";
  String selectedSize = "";

  double? _latitude;
  double? _longitude;

  bool _gettingLocation = false;
  bool _submitting = false;
  String _locationStatus = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // -------------------------------------------------------------
  // GET LOCATION
  // -------------------------------------------------------------
  Future<void> _getCurrentLocation() async {
    setState(() {
      _gettingLocation = true;
      _locationStatus = "Fetching location...";
    });

    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _locationStatus = "Turn ON location services";
          _gettingLocation = false;
        });
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = "Permission denied permanently";
          _gettingLocation = false;
        });
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationStatus = "Location permission denied.";
          _gettingLocation = false;
        });
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationStatus = "Location Captured!";
        _gettingLocation = false;
      });
    } catch (_) {
      setState(() {
        _locationStatus = "Unable to get location";
        _gettingLocation = false;
      });
    }
  }

  // -------------------------------------------------------------
  // PICK IMAGE
  // -------------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(source: source, imageQuality: 75);
      if (img != null) setState(() => _pickedFile = img);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Image error: $e")));
    }
  }

  // -------------------------------------------------------------
  // SUBMIT REPORT  ✔ FIXED ✔ WORKING ✔
  // -------------------------------------------------------------
  Future<void> _submit() async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Location not captured")));
      return;
    }

    if (selectedTrashType.isEmpty || selectedSize.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Select type & size")));
      return;
    }

    setState(() => _submitting = true);

    final reportId = const Uuid().v4();
    String? imageUrl;

    if (_pickedFile != null) {
      try {
        final ref = FirebaseStorage.instance.ref("reports/$reportId.jpg");

        if (kIsWeb) {
          final bytes = await _pickedFile!.readAsBytes();
          await ref.putData(bytes);
        } else {
          await ref.putFile(File(_pickedFile!.path));
        }

        imageUrl = await ref.getDownloadURL();
      } catch (_) {}
    }

    // GET USER NAME
    String residentName = "Resident";

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .get();

    if (userDoc.exists && userDoc.data()!.containsKey("name")) {
      residentName = userDoc["name"];
    }

    // CLEAN + CORRECT DATA STRUCTURE
    final data = {
      "reportId": reportId,
      "residentId": widget.uid,
      "residentName": residentName,
      "latitude": _latitude,
      "longitude": _longitude,
      "photo_url": imageUrl,
      "trashType": selectedTrashType,
      "trashSize": selectedSize,

      /// IMPORTANT → lowercase (Driver Dashboard needs this!)
      "status": "pending",

      /// FIXED → ensures NEW reports show first
      "timestamp": FieldValue.serverTimestamp(),
      "reported_at": FieldValue.serverTimestamp(),

      /// MUST exist → driver dashboard filters by this field
      "driver_id": null,
    };

    await FirebaseFirestore.instance
        .collection("reports")
        .doc(reportId)
        .set(data);

    setState(() {
      _submitting = false;
      _pickedFile = null;
      selectedSize = "";
      selectedTrashType = "";
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Report submitted!")));
  }

  // -------------------------------------------------------------
  // SMALL CARD
  // -------------------------------------------------------------
  Widget _card({required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        title: const Text("Report Garbage"),
        actions: [
          IconButton(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt)),
          IconButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library)),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 90),
          child: Center(
            child: Container(
              width: isWeb ? 800 : double.infinity,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade900, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      "Quickly report garbage with photo & location",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  // LOCATION
                  _card(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.green, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _latitude == null
                                ? _locationStatus
                                : "Lat: ${_latitude!.toStringAsFixed(4)},  Lon: ${_longitude!.toStringAsFixed(4)}",
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _gettingLocation ? null : _getCurrentLocation,
                          icon: _gettingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh, color: Colors.green),
                        ),
                      ],
                    ),
                  ),

                  // SIZE SELECT
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Select Size",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: ["Small", "Medium", "Large"].map((s) {
                            bool sel = selectedSize == s;
                            return GestureDetector(
                              onTap: () => setState(() => selectedSize = s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 14),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: sel
                                          ? Colors.green
                                          : Colors.grey.shade400),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.green.shade900
                                          : Colors.black),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // TYPE SELECT
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Select Type",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: trashTypesMap.entries.map((entry) {
                            bool sel = selectedTrashType == entry.key;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedTrashType = entry.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: sel
                                          ? Colors.green
                                          : Colors.grey.shade400),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(entry.value,
                                        color: sel
                                            ? Colors.green.shade900
                                            : Colors.black),
                                    const SizedBox(width: 8),
                                    Text(entry.key),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
      ),

      // SUBMIT BUTTON
      bottomSheet: Container(
        padding: const EdgeInsets.all(14),
        child: ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white))
              : const Icon(Icons.send),
          label: Text(_submitting ? "Submitting..." : "Submit Report"),
        ),
      ),
    );
  }
}
