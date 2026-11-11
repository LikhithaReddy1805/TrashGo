// File path: lib/dashboards/resident_dashboard.dart
//
// UPDATED VERSION WITH OTP SUPPORT
// - Listens for OTP from driver_dashboard
// - Shows popup when OTP arrives
// - Marks notifyResident = false to prevent repeat popups
// - No UI changes, only added OTP logic

import 'dart:io';
import 'dart:async'; // ⭐ ADDED
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dump_page.dart';
import 'live_map_page.dart';
import 'billing_page.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kPrimaryGreen = Color(0xFF2E7D32);
const double _kBottomNavHeight = 60.0;

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  int _selectedIndex = 0;
  static const String driverId = 'driver_01';

  late List<Widget> _pages = [];
  String uid = "";

  // ⭐ OTP listener
  StreamSubscription<QuerySnapshot>? _otpListener;

  @override
  void initState() {
    super.initState();
    _loadUserUID();
  }

  @override
  void dispose() {
    _otpListener?.cancel(); // ⭐ Stop OTP listener
    super.dispose();
  }

  // -----------------------------------------------------------------------------
  // LOAD UID + START OTP LISTENER
  // -----------------------------------------------------------------------------
  Future<void> _loadUserUID() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && !user.isAnonymous) {
      uid = user.uid;
    }

    if (uid.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('uid') ?? "";
    }

    if (uid.isEmpty) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, "/role", (r) => false);
      return;
    }

    // ⭐ Start OTP listener
    _startOtpListener(uid);

    _pages = [
      HomePage(uid: uid),
      DumpDashboard(uid: uid),
      const ReportPage(),
      const ProfilePage(),
      LiveMapPage(driverId: driverId),
      BillingPage(uid: uid),
    ];

    if (mounted) setState(() {});
  }

  // -----------------------------------------------------------------------------
  // ⭐ LISTEN FOR OTP FROM DRIVER
  // -----------------------------------------------------------------------------
  void _startOtpListener(String uid) {
    _otpListener = FirebaseFirestore.instance
        .collection("reports")
        .where("residentId", isEqualTo: uid)
        .where("notifyResident", isEqualTo: true)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) return;

      for (var doc in snap.docs) {
        final data = doc.data();
        final otp = data["collectionOtp"] ?? "";
        final reportId = doc.id;

        if (otp.isNotEmpty) {
          _showOtpPopup(otp);

          // Mark OTP as shown
          FirebaseFirestore.instance
              .collection("reports")
              .doc(reportId)
              .update({"notifyResident": false});
        }
      }
    });
  }

  // -----------------------------------------------------------------------------
  // ⭐ POPUP TO SHOW OTP
  // -----------------------------------------------------------------------------
  void _showOtpPopup(String otp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Pickup OTP"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Driver has arrived.\nPlease share this OTP:",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              otp,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------------
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, "/role");
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,

        body: _pages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(index: _selectedIndex, children: _pages),

        bottomNavigationBar: BottomNavigationBar(
          elevation: 10,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: kPrimaryGreen,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          showUnselectedLabels: true,

          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.delete), label: "Dump"),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Reports"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: "Live Map"),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Billing"),
          ],
        ),
      ),
    );
  }
}
class HomePage extends StatefulWidget {
  final String uid;
  const HomePage({super.key, required this.uid});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String userName = "Resident";
  String? userPhotoUrl;
  bool _dataLoaded = false;

  int totalReports = 0;
  int pendingReports = 0;
  int completedReports = 0;

  final String logoUrl = 'sandbox:/mnt/data/Screenshot 2025-10-30 221309.png';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats(); // ⭐ load stats here (now uses SharedPreferences fallback)
  }

  //---------------------------------------------------------------------------
  // LOAD USER DATA FROM FIRESTORE + SharedPrefs
  //---------------------------------------------------------------------------

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cachedName = prefs.getString('name');
      final cachedPhoto = prefs.getString('photoUrl');

      if (cachedName != null) userName = cachedName;
      if (cachedPhoto != null) userPhotoUrl = cachedPhoto;

      if (mounted) setState(() => _dataLoaded = true);

      // Use widget.uid (loaded from dashboard), but still defensive
      final effectiveUid = widget.uid.isNotEmpty
          ? widget.uid
          : (prefs.getString('uid') ?? "");

      if (effectiveUid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(effectiveUid)
            .get();

        if (snap.exists) {
          final data = snap.data()!;
          userName = data['name'] ?? userName;
          userPhotoUrl = data['photoUrl'] ?? userPhotoUrl;

          await prefs.setString('name', userName);
          if (userPhotoUrl != null) {
            await prefs.setString('photoUrl', userPhotoUrl!);
          }

          if (mounted) {
            setState(() {
              _dataLoaded = true;
            });
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  //---------------------------------------------------------------------------
  // LOAD REPORT STATS FROM FIRESTORE
  //---------------------------------------------------------------------------

  Future<void> _loadStats() async {
    // Determine effective UID (prefer widget.uid, fallback to SharedPreferences)
    String effectiveUid = widget.uid;
    if (effectiveUid.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      effectiveUid = prefs.getString('uid') ?? "";
    }

    if (effectiveUid.isEmpty) return;

    try {
      // NOTE: DumpDashboard stores reports with field 'residentId'
      final snap = await FirebaseFirestore.instance
          .collection("reports")
          .where("residentId", isEqualTo: effectiveUid)
          .get();

      totalReports = snap.docs.length;
      pendingReports = snap.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)["status"] == "pending",
          )
          .length;
      completedReports = snap.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)["status"] == "completed",
          )
          .length;

      if (mounted) setState(() {});
    } catch (_) {}
  }

  String greetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning 👋";
    if (hour < 17) return "Good Afternoon 👋";
    return "Good Evening 👋";
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: accent.withOpacity(0.16),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //---------------------------------------------------------------------------
  // UI
  //---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final double maxTileWidth = width > 1400
            ? 300
            : (width > 1100 ? 260 : (width > 700 ? 220 : 180));

        return SafeArea(
          child: Column(
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.all(16),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _dataLoaded ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1B5E20),
                          Color(0xFF2E7D32),
                          Color(0xFF66BB6A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greetingMessage(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Quick actions and latest status at a glance",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withOpacity(0.18),
                          backgroundImage: userPhotoUrl != null
                              ? NetworkImage(userPhotoUrl!)
                              : null,
                          child: userPhotoUrl == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // STATS ROW
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        "Total Reports",
                        totalReports.toString(),
                        Icons.list_alt,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        "Pending",
                        pendingReports.toString(),
                        Icons.pending_actions,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        "Completed",
                        completedReports.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ACTION GRID
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: maxTileWidth,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      childAspectRatio: width < 500 ? 1.05 : 1.3,
                    ),
                    children: [
                      _actionCard(
                        icon: Icons.delete,
                        label: "Report Garbage",
                        accent: Colors.redAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DumpDashboard(uid: widget.uid),
                          ),
                        ),
                      ),
                      _actionCard(
                        icon: Icons.list_alt,
                        label: "My Reports",
                        accent: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportPage()),
                        ),
                      ),
                      _actionCard(
                        icon: Icons.map,
                        label: "Live Map",
                        accent: Colors.orange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveMapPage(driverId: 'driver_01'),
                          ),
                        ),
                      ),
                      _actionCard(
                        icon: Icons.person,
                        label: "Profile",
                        accent: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- REPORT PAGE (FULLY FIXED) ----------------
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with TickerProviderStateMixin {
  static String _formatTimestamp(dynamic ts) {
    try {
      if (ts is Timestamp) {
        final dt = ts.toDate();
        return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
      }
      return "";
    } catch (_) {
      return "";
    }
  }

  // Show details popup
  void _showReportDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
  ) {
    final width = MediaQuery.of(context).size.width;

    if (width < 900) {
      // mobile bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, controller) => Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      height: 5,
                      width: 45,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      data['trashType'] ?? "Report",
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: data["photo_url"] != null
                        ? Image.network(
                            data["photo_url"],
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : _noImageBox(),
                  ),

                  const SizedBox(height: 16),
                  _detailsRow("Size", data['trashSize'] ?? "-"),
                  const SizedBox(height: 8),
                  _detailsRow(
                    "Status",
                    data['status'] ?? "-",
                    color: _statusColor(data['status']),
                  ),
                  const SizedBox(height: 8),
                  _detailsRow("Date", _formatTimestamp(data['timestamp'])),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit),
                          label: const Text("Edit"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection("reports")
                                .doc(id)
                                .delete();
                            if (!mounted) return;
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text("Delete"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // desktop full page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportDetailsPage(id: id, data: data),
        ),
      );
    }
  }

  Widget _detailsRow(String title, String value, {Color? color}) {
    return Row(
      children: [
        Text("$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(value, style: TextStyle(color: color ?? Colors.black87)),
        ),
      ],
    );
  }

  static Color _statusColor(dynamic s) {
    final status = (s ?? "").toString().toLowerCase();
    if (status == "completed") return Colors.green;
    if (status == "pending") return Colors.orange;
    return Colors.grey;
  }

  Widget _noImageBox() {
    return Container(
      height: 220,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 45, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final prefs = snap.data as SharedPreferences;
        final uid = prefs.getString("uid") ?? "";

        // debug prints (remove in production if desired)
        // print("REPORT PAGE USING UID = $uid");

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: const Text("My Reports"),
            backgroundColor: Colors.green,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("reports")
                .where("residentId", isEqualTo: uid)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text("Error loading reports"));
              }

              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text("No reports yet."));
              }

              docs.sort((a, b) {
                final ta = (a["timestamp"] as Timestamp).millisecondsSinceEpoch;
                final tb = (b["timestamp"] as Timestamp).millisecondsSinceEpoch;
                return tb.compareTo(ta);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data()! as Map<String, dynamic>;
                  final status = data["status"] ?? "-";

                  return GestureDetector(
                    onTap: () => _showReportDetails(context, data, doc.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // thumbnail
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: data["photo_url"] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      data["photo_url"],
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _noThumb(),
                          ),

                          const SizedBox(width: 16),

                          // text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data["trashType"] ?? "Unknown",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text("Size: ${data['trashSize'] ?? '-'}"),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: _statusColor(status),
                                    ),
                                    const SizedBox(width: 6),
                                    Text("Status: $status"),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // date
                          Text(
                            _formatTimestamp(data["timestamp"]),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _noThumb() {
    return const Icon(Icons.delete, color: Colors.red, size: 28);
  }
}

// ---------------- DESKTOP FULL REPORT DETAILS ----------------
class ReportDetailsPage extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  const ReportDetailsPage({super.key, required this.id, required this.data});

  static String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return "${dt.day}-${dt.month}-${dt.year}";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final status = data["status"] ?? "-";

    return Scaffold(
      appBar: AppBar(
        title: Text(data["trashType"] ?? "Report Details"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IMAGE OR PLACEHOLDER
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: data["photo_url"] != null
                      ? Image.network(
                          data["photo_url"],
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),

                const SizedBox(height: 22),

                Text(
                  data["trashType"] ?? "Unknown",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Chip(label: Text("Size: ${data['trashSize'] ?? '-'}")),
                    const SizedBox(width: 8),
                    Chip(label: Text("Status: $status")),
                    const SizedBox(width: 8),
                    Text(_formatTimestamp(data["timestamp"])),
                  ],
                ),

                const SizedBox(height: 18),

                if (data["notes"] != null) ...[
                  const Text(
                    "Notes",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(data["notes"]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 55, color: Colors.grey),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  // profile fields
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  String? _role;
  String? _photoUrl;
  File? _localImageFile;

  // stats
  int _totalReports = 0;
  int _pendingReports = 0;
  int _completedReports = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileAndStats();
  }

  // --------------------------------------------------------------
  // LOAD PROFILE + STATS (USES SHARED PREFERENCES UID - FIXED)
  // --------------------------------------------------------------
  Future<void> _loadProfileAndStats() async {
    final prefs = await SharedPreferences.getInstance();

    // ⭐ THE REAL UID OF USER (NOT FirebaseAuth UID)
    final String? uid = prefs.getString('uid');
    _role = prefs.getString('role') ?? 'resident';

    if (uid == null || uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _nameCtrl.text = data['name'] ?? '';
        _addressCtrl.text = data['address'] ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
        _photoUrl = data['photoUrl'];
      }
    } catch (_) {}

    try {
      final totalSnap = await _firestore
          .collection('reports')
          .where('residentId', isEqualTo: uid)
          .get();
      _totalReports = totalSnap.docs.length;

      final pendingSnap = await _firestore
          .collection('reports')
          .where('residentId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();
      _pendingReports = pendingSnap.docs.length;

      final completedSnap = await _firestore
          .collection('reports')
          .where('residentId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .get();
      _completedReports = completedSnap.docs.length;
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  // --------------------------------------------------------------
  // PICK PROFILE IMAGE
  // --------------------------------------------------------------
  Future<void> _pickProfileImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _localImageFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Image pick failed: $e")));
    }
  }

  // --------------------------------------------------------------
  // UPLOAD PROFILE IMAGE
  // --------------------------------------------------------------
  Future<String?> _uploadProfileImage(String uid) async {
    if (_localImageFile == null) return null;
    final ref = _storage.ref().child('profile_images/$uid.jpg');
    await ref.putFile(_localImageFile!);
    return await ref.getDownloadURL();
  }

  // --------------------------------------------------------------
  // SAVE PROFILE CHANGES
  // --------------------------------------------------------------
  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('uid');

    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot save: No UID")));
      return;
    }

    setState(() => _saving = true);

    try {
      String? uploadedUrl;
      if (_localImageFile != null) {
        uploadedUrl = await _uploadProfileImage(uid);
      }

      final updateData = {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (uploadedUrl != null) 'photoUrl': uploadedUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(uid)
          .set(updateData, SetOptions(merge: true));

      setState(() {
        _editing = false;
        _saving = false;
        if (uploadedUrl != null) _photoUrl = uploadedUrl;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile saved")));
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }
  }

  // --------------------------------------------------------------
  // LOGOUT
  // --------------------------------------------------------------
  Future<void> _logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/role', (route) => false);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // UI
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.save : Icons.edit),
            onPressed: _saving
                ? null
                : () {
                    if (_editing) {
                      _saveProfile();
                    } else {
                      setState(() => _editing = true);
                    }
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------------- PROFILE HEADER CARD ----------------
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _editing ? _pickProfileImage : null,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: _localImageFile != null
                          ? FileImage(_localImageFile!)
                          : (_photoUrl != null
                                    ? NetworkImage(_photoUrl!)
                                    : null)
                                as ImageProvider<Object>?,
                      child: _photoUrl == null && _localImageFile == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameCtrl.text.isEmpty ? "Resident" : _nameCtrl.text,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Chip(
                          label: Text(_role ?? "resident"),
                          avatar: const Icon(Icons.verified_user),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _statCard(
                              "Total",
                              "$_totalReports",
                              Icons.list_alt,
                              Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            _statCard(
                              "Pending",
                              "$_pendingReports",
                              Icons.pending_actions,
                              Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ---------------- EDITABLE FIELDS ----------------
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    enabled: _editing,
                    decoration: const InputDecoration(labelText: "Full Name"),
                  ),
                  TextField(
                    controller: _addressCtrl,
                    enabled: _editing,
                    decoration: const InputDecoration(labelText: "Address"),
                  ),
                  TextField(
                    controller: _phoneCtrl,
                    enabled: _editing,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: "Phone"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ---------------- ROLE + LOGOUT ----------------
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.verified_user,
                      color: Colors.green,
                    ),
                    title: Text("Role: ${_role ?? 'resident'}"),
                    subtitle: const Text(
                      "Role is determined during login/registration",
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout & Select Role"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}