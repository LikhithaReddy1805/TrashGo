import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveMapPage extends StatefulWidget {
  final String? driverId;
  final bool isResident;
  final double? targetLat;
  final double? targetLon;

  const LiveMapPage({
    super.key,
    this.driverId,
    this.isResident = false,
    this.targetLat,
    this.targetLon,
  });

  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage> {
  LatLng? currentPosition;
  double? accuracyMeters;

  StreamSubscription<Position>? posStream;
  StreamSubscription<DocumentSnapshot>? driverStream;

  final MapController mapController = MapController();
  final double defaultZoom = 15;

  LatLng? routeTarget;

  @override
  void initState() {
    super.initState();

    if (widget.isResident) {
      _listenToDriverLocation();
    } else {
      _trackDriverLocation();
    }
  }

  @override
  void dispose() {
    posStream?.cancel();
    driverStream?.cancel();
    super.dispose();
  }

  // =====================================================
  //                DRIVER SIDE : LIVE LOCATION
  // =====================================================
  Future<void> _trackDriverLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    // FIRST FIXED LOCATION
    try {
      final pos = await Geolocator.getCurrentPosition();
      _updateLocalPosition(pos.latitude, pos.longitude, pos.accuracy);

      if (widget.driverId != null) {
        FirebaseFirestore.instance
            .collection("drivers")
            .doc(widget.driverId)
            .set({
              "latitude": pos.latitude,
              "longitude": pos.longitude,
              "last_updated": FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (_) {}

    // REAL-TIME UPDATES
    posStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        ).listen((Position p) {
          _updateLocalPosition(p.latitude, p.longitude, p.accuracy);

          if (widget.driverId != null) {
            FirebaseFirestore.instance
                .collection("drivers")
                .doc(widget.driverId)
                .set({
                  "latitude": p.latitude,
                  "longitude": p.longitude,
                  "last_updated": FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          }
        });
  }

  void _updateLocalPosition(double lat, double lon, double? acc) {
    setState(() {
      currentPosition = LatLng(lat, lon);
      accuracyMeters = acc;
    });

    try {
      mapController.move(currentPosition!, defaultZoom);
    } catch (_) {}
  }

  // =====================================================
  //              RESIDENT SIDE : TRACK DRIVER
  // =====================================================
  void _listenToDriverLocation() {
    if (widget.driverId == null) return;

    driverStream = FirebaseFirestore.instance
        .collection("drivers")
        .doc(widget.driverId)
        .snapshots()
        .listen((snap) {
          if (!snap.exists) return;

          final d = snap.data()!;
          if (d["latitude"] != null && d["longitude"] != null) {
            setState(() {
              currentPosition = LatLng(d["latitude"], d["longitude"]);
            });

            try {
              mapController.move(currentPosition!, defaultZoom);
            } catch (_) {}
          }
        });
  }

  // =====================================================
  //                  OPEN REPORT POPUP
  // =====================================================
  void openPopup(Map<String, dynamic> data, String id, LatLng point) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Report ID: $id",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text("Resident: ${data['residentId'] ?? 'Unknown'}"),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openNavigation(point.latitude, point.longitude);
                },
                child: const Text("Navigate"),
              ),
              const SizedBox(height: 8),

              ElevatedButton(
                onPressed: widget.driverId == null
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await FirebaseFirestore.instance
                            .collection("reports")
                            .doc(id)
                            .update({
                              "driver_id": widget.driverId,
                              "status": "assigned",
                              "assigned_at": FieldValue.serverTimestamp(),
                            });
                      },
                child: const Text("Accept"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openNavigation(double lat, double lon) async {
    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lon",
    );
    await launchUrl(url);
  }

  // =====================================================
  //                    AUTO ZOOM
  // =====================================================
  void _autoFit(List<Marker> markers) {
    if (markers.isEmpty) return;

    final lats = markers.map((e) => e.point.latitude).toList();
    final lons = markers.map((e) => e.point.longitude).toList();

    final south = lats.reduce((a, b) => a < b ? a : b);
    final north = lats.reduce((a, b) => a > b ? a : b);
    final west = lons.reduce((a, b) => a < b ? a : b);
    final east = lons.reduce((a, b) => a > b ? a : b);

    final center = LatLng((south + north) / 2, (west + east) / 2);

    final latDiff = (north - south).abs();
    double zoom;

    if (latDiff < 0.002) {
      zoom = 17;
    } else if (latDiff < 0.01) {
      zoom = 15;
    } else if (latDiff < 0.05) {
      zoom = 13;
    } else {
      zoom = 10;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        mapController.move(center, zoom);
      } catch (_) {}
    });
  }

  // =====================================================
  //                        UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final acc = accuracyMeters != null
        ? " · acc ${accuracyMeters!.toStringAsFixed(0)}m"
        : "";

    const tileUrl =
        "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png";

    return Scaffold(
      appBar: AppBar(
        title: Text("Live Map$acc"),
        backgroundColor: Colors.green,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("reports")
            .where("status", whereIn: ["pending", "assigned"])
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Marker> markers = [];

          if (currentPosition != null) {
            markers.add(
              Marker(
                point: currentPosition!,
                width: 60,
                height: 60,
                child: Image.asset("assets/truck.png"),
              ),
            );
          }

          for (var doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lat = data["latitude"];
            final lon = data["longitude"];
            if (lat == null || lon == null) continue;

            final point = LatLng(lat, lon);

            markers.add(
              Marker(
                point: point,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    setState(() => routeTarget = point);
                    openPopup(data, doc.id, point);
                  },
                  child: const Icon(
                    Icons.delete_forever,
                    size: 34,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          if (widget.targetLat != null && widget.targetLon != null) {
            markers.add(
              Marker(
                point: LatLng(widget.targetLat!, widget.targetLon!),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.place,
                  size: 35,
                  color: Colors.deepOrange,
                ),
              ),
            );
          }

          if (markers.isNotEmpty) _autoFit(markers);

          return FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentPosition ?? const LatLng(20.59, 78.96),
              initialZoom: defaultZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.garbage_collection_app',
              ),

              MarkerLayer(markers: markers),

              if (routeTarget != null && currentPosition != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [currentPosition!, routeTarget!],
                      strokeWidth: 4,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}