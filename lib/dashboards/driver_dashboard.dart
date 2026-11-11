// lib/dashboards/driver_dashboard.dart
// FINAL FULL VERSION — OTP + LOCATION + PROFILE + NOTIFICATION + HISTORY + BILLING

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared/waste_rates.dart';


import 'live_map_page.dart';
import '../role_selection_page.dart';

class DriverDashboard extends StatefulWidget {
  final String driverId;
  const DriverDashboard({super.key, required this.driverId});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _selectedIndex = 0;

  Position? currentPos;
  StreamSubscription<Position>? positionSubscription;
  StreamSubscription<QuerySnapshot>? assignedListener;

  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController vehicleTypeCtrl = TextEditingController();
  final TextEditingController vehicleNoCtrl = TextEditingController();
  final TextEditingController licenseNoCtrl = TextEditingController();
  final TextEditingController areaCtrl = TextEditingController();
  final TextEditingController expCtrl = TextEditingController();

  // 🔹 NEW: UPI ID for billing
  final TextEditingController upiIdCtrl = TextEditingController();

  bool profileLoaded = false;
  bool editingProfile = false;
  bool savingProfile = false;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    _initNotifications();
    _listenForAssignedReports();
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    assignedListener?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOCATION TRACKING
  // ---------------------------------------------------------------------------
  Future<void> _initLocationTracking() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (!(await Geolocator.isLocationServiceEnabled())) return;

    currentPos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _updateDriverLocation();

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      currentPos = pos;
      _updateDriverLocation();
    });
  }

  Future<void> _updateDriverLocation() async {
    if (currentPos == null) return;
    FirebaseFirestore.instance.collection("drivers").doc(widget.driverId).set({
      "latitude": currentPos!.latitude,
      "longitude": currentPos!.longitude,
      "heading": currentPos!.heading,
      "last_updated": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------
  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await localNotifications.initialize(init);
  }

  void _listenForAssignedReports() {
    assignedListener = FirebaseFirestore.instance
        .collection("reports")
        .where("driver_id", isEqualTo: widget.driverId)
        .where("status", isEqualTo: "assigned")
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _showAssignmentNotification(change.doc.data()!);
        }
      }
    });
  }

  Future<void> _showAssignmentNotification(Map<String, dynamic> data) async {
    const android = AndroidNotificationDetails(
      'assignments',
      'Assignments',
      importance: Importance.max,
      priority: Priority.high,
    );

    await localNotifications.show(
      Random().nextInt(99999),
      "New Garbage Pickup Assigned",
      "Location: ${data['latitude']}, ${data['longitude']}",
      NotificationDetails(android: android),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER FUNCTIONS
  // ---------------------------------------------------------------------------
  Future<String> _getResidentName(String uid) async {
    if (uid.isEmpty) return "Resident";

    final doc =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();

    if (doc.exists && doc.data()!.containsKey("name")) {
      return doc["name"];
    }
    return "Resident";
  }

  String _generateOtp() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  String _formatDate(dynamic ts) {
    if (ts == null || ts is! Timestamp) return "-";
    final d = ts.toDate();
    return "${d.day.toString().padLeft(2, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.year}  ${d.hour.toString().padLeft(2, '0')}:"
        "${d.minute.toString().padLeft(2, '0')}";
  }

  String timeAgo(dynamic ts) {
    if (ts == null || ts is! Timestamp) return "-";
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes} min ago";
    if (diff.inDays < 1) return "${diff.inHours} hr ago";
    return "${diff.inDays} days ago";
  }

  // 🔹 BILL CALCULATION based on trashSize
  num _calculateBill(Map<String, dynamic> report) {
    final size = (report["trashSize"] ?? "").toString().toLowerCase();

    if (size == "small") return 30;
    if (size == "medium") return 60;
    if (size == "large") return 100;

    // Default fallback
    return 50;
  }

  // 🔹 Create a bill after OTP verification
  Future<void> _createBillAfterOtp(String reportId) async {
  try {
    final reportSnap = await FirebaseFirestore.instance
        .collection("reports")
        .doc(reportId)
        .get();

    if (!reportSnap.exists) return;

    final report = reportSnap.data()!;
    final residentId = report["residentId"];
    final driverId = report["driver_id"];
    final trashType = report["trashType"] ?? "Household";

    final int rate = wasteRates[trashType] ?? 5;

    await FirebaseFirestore.instance.collection("billing").add({
      "residentId": residentId,
      "driverId": driverId,
      "reportId": reportId,
      "trashType": trashType,
      "rate": rate,
      "paid": false,
      "createdAt": FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection("reports")
        .doc(reportId)
        .update({
      "billGenerated": true,
    });
  } catch (e) {
    debugPrint("Billing error: $e");
  }
}

  // ----------------------- OTP POPUP ---------------------------------------
  Future<void> _showOtpDialog(String reportId, String otp) async {
    TextEditingController ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enter OTP received by Resident"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Enter 6-digit OTP"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Verify"),
            onPressed: () async {
              if (ctrl.text.trim() == otp.trim()) {
                await FirebaseFirestore.instance
                    .collection("reports")
                    .doc(reportId)
                    .update({
                  "status": "completed",
                  "completed_at": FieldValue.serverTimestamp(),
                  "otpVerified": true,
                });

                // 🔹 Create bill right after successful OTP verification
                await _createBillAfterOtp(reportId);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "OTP Correct — Garbage collected & bill generated ✅",
                      ),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Incorrect OTP ❌")),
                  );
                }
              }
            },
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  void _setPage(int i) {
    setState(() => _selectedIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _pendingReports(),
          _assignedReports(),
          LiveMapPage(driverId: widget.driverId, isResident: false),
          _profilePage(),
          _completedReports(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: _setPage,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Pending"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Assigned"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Live Map"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PENDING REPORTS
  // ---------------------------------------------------------------------------
  Widget _pendingReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reports")
          .where("status", isEqualTo: "pending")
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No Pending Reports"));
        }

        return ListView(
          padding: const EdgeInsets.all(10),
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;

            return FutureBuilder<String>(
              future: _getResidentName(data["residentId"]),
              builder: (_, nameSnap) {
                return _reportCard(
                  title: data["trashType"] ?? "Garbage",
                  subtitle:
                      "Reported by: ${nameSnap.data ?? "Resident"}\n"
                      "Lat: ${data["latitude"]}, Lon: ${data["longitude"]}\n"
                      "Reported At: ${_formatDate(data["timestamp"])}",
                  timeAgo: timeAgo(data["timestamp"]),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Accept"),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection("reports")
                          .doc(data["reportId"])
                          .update({
                        "driver_id": widget.driverId,
                        "status": "assigned",
                        "assigned_at": FieldValue.serverTimestamp(),
                      });
                    },
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ASSIGNED REPORTS (OTP SEND)
  // ---------------------------------------------------------------------------
  Widget _assignedReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reports")
          .where("driver_id", isEqualTo: widget.driverId)
          .where("status", whereIn: ["assigned", "awaiting_verification"])
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No Assigned Reports"));
        }

        return ListView(
          padding: const EdgeInsets.all(10),
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;

            return _reportCard(
              title: data["trashType"],
              subtitle:
                  "Lat: ${data["latitude"]}, Lon: ${data["longitude"]}\n"
                  "Assigned At: ${_formatDate(data["assigned_at"])}",
              timeAgo: timeAgo(data["assigned_at"]),
              trailing: Wrap(
                children: [
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text("Route"),
                    onPressed: () {
                      launchUrl(Uri.parse(
                          "https://www.google.com/maps/dir/?api=1&destination=${data["latitude"]},${data["longitude"]}"));
                    },
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Complete"),
                    onPressed: () async {
                      String otp = _generateOtp();

                      await FirebaseFirestore.instance
                          .collection("reports")
                          .doc(data["reportId"])
                          .update({
                        "collectionOtp": otp,
                        "otpVerified": false,
                        "notifyResident": true,
                        "status": "awaiting_verification",
                      });

                      _showOtpDialog(data["reportId"], otp);
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // COMPLETED REPORTS
  // ---------------------------------------------------------------------------
  Widget _completedReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reports")
          .where("driver_id", isEqualTo: widget.driverId)
          .where("status", isEqualTo: "completed")
          .orderBy("completed_at", descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No History Yet"));
        }

        return ListView(
          padding: const EdgeInsets.all(10),
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;

            return _reportCard(
              title: "Completed Pickup",
              subtitle:
                  "Lat: ${data["latitude"]}, Lon: ${data["longitude"]}\n"
                  "Completed At: ${_formatDate(data["completed_at"])}",
              timeAgo: timeAgo(data["completed_at"]),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILE PAGE (with UPI ID)
  // ---------------------------------------------------------------------------
  Widget _profilePage() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("drivers")
          .doc(widget.driverId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};

        if (!profileLoaded) {
          nameCtrl.text = data["name"] ?? "";
          phoneCtrl.text = data["phone"] ?? "";
          vehicleTypeCtrl.text = data["vehicle_type"] ?? "";
          vehicleNoCtrl.text = data["vehicle_number"] ?? "";
          licenseNoCtrl.text = data["license_number"] ?? "";
          areaCtrl.text = data["area"] ?? "";
          expCtrl.text = data["experience_years"] ?? "";
          upiIdCtrl.text = data["upi_id"] ?? ""; // 🔹 load upi
          profileLoaded = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nameCtrl.text.isEmpty
                            ? "Driver ID: ${widget.driverId}"
                            : nameCtrl.text,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(phoneCtrl.text.isEmpty
                          ? "Phone not set"
                          : phoneCtrl.text),
                      Text(areaCtrl.text.isEmpty
                          ? "Area not assigned"
                          : "Area: ${areaCtrl.text}"),
                    ],
                  )
                ]),
              ),
            ),
            const SizedBox(height: 16),

            editingProfile
                ? ElevatedButton(
                    onPressed: savingProfile ? null : _saveProfile,
                    child: Text(savingProfile ? "Saving..." : "Save Profile"),
                  )
                : ElevatedButton(
                    child: const Text("Edit Profile"),
                    onPressed: () => setState(() => editingProfile = true),
                  ),
            const SizedBox(height: 16),

            _profileField("Name", nameCtrl),
            const SizedBox(height: 10),
            _profileField("Phone", phoneCtrl),
            const SizedBox(height: 10),
            _profileField("Vehicle Type", vehicleTypeCtrl),
            const SizedBox(height: 10),
            _profileField("Vehicle Number", vehicleNoCtrl),
            const SizedBox(height: 10),
            _profileField("License Number", licenseNoCtrl),
            const SizedBox(height: 10),
            _profileField("Area", areaCtrl),
            const SizedBox(height: 10),
            _profileField("Experience (years)", expCtrl),
            const SizedBox(height: 10),
            // 🔹 NEW: UPI input
            _profileField("UPI ID (for payments)", upiIdCtrl),
          ]),
        );
      },
    );
  }

  Widget _profileField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      enabled: editingProfile,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => savingProfile = true);

    await FirebaseFirestore.instance
        .collection("drivers")
        .doc(widget.driverId)
        .set({
      "name": nameCtrl.text.trim(),
      "phone": phoneCtrl.text.trim(),
      "vehicle_type": vehicleTypeCtrl.text.trim(),
      "vehicle_number": vehicleNoCtrl.text.trim(),
      "license_number": licenseNoCtrl.text.trim(),
      "area": areaCtrl.text.trim(),
      "experience_years": expCtrl.text.trim(),
      "upi_id": upiIdCtrl.text.trim(), // 🔹 save UPI
    }, SetOptions(merge: true));

    setState(() {
      savingProfile = false;
      editingProfile = false;
    });
  }

  // ---------------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------------
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
      (route) => false,
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT CARD TEMPLATE
  // ---------------------------------------------------------------------------
  Widget _reportCard({
    required String title,
    required String subtitle,
    required String timeAgo,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer, color: Colors.green.shade700),
            Text(timeAgo, style: const TextStyle(fontSize: 10)),
          ],
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}