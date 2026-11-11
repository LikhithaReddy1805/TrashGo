// lib/dashboards/admin_dashboard.dart
// Rewritten & optimized admin dashboard — full access to drivers, residents & reports.
// Matches data structure used by driver_dashboard.dart and resident_dashboard.dart

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    AdminOverviewPage(),
    AdminDriversPage(),
    AdminResidentsPage(),
    AdminReportsPage(),
    AdminLiveMapPage(),
    AdminSettingsPage(),
  ];

  void _onTap(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_selectedIndex)),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out & role select',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/role', (_) => false);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide) SizedBox(width: 260, child: _sideMenu()),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onTap,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.green,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Overview',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.drive_eta),
                  label: 'Drivers',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Residents',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.report),
                  label: 'Reports',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: 'Live Map',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  Widget _sideMenu() {
    return Material(
      color: Colors.grey.shade100,
      child: ListView(
        children: [
          Container(
            height: 120,
            color: Colors.green,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Admin Panel',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          for (var i = 0; i < _pages.length; i++)
            ListTile(
              leading: _iconForIndex(i),
              title: Text(_titleForIndex(i)),
              selected: _selectedIndex == i,
              onTap: () => setState(() => _selectedIndex = i),
            ),
        ],
      ),
    );
  }

  String _titleForIndex(int i) {
    switch (i) {
      case 0:
        return 'Overview';
      case 1:
        return 'Drivers';
      case 2:
        return 'Residents';
      case 3:
        return 'Reports';
      case 4:
        return 'Live Map';
      case 5:
      default:
        return 'Settings';
    }
  }

  Icon _iconForIndex(int i) {
    switch (i) {
      case 1:
        return const Icon(Icons.drive_eta);
      case 2:
        return const Icon(Icons.people);
      case 3:
        return const Icon(Icons.report);
      case 4:
        return const Icon(Icons.map);
      case 5:
        return const Icon(Icons.settings);
      default:
        return const Icon(Icons.dashboard);
    }
  }
}

// ----------------- Overview -----------------
class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key});

  Future<Map<String, int>> _loadCounts() async {
    final db = FirebaseFirestore.instance;
    final allReports = await db.collection('reports').get();
    final pending = await db
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .get();
    final assigned = await db
        .collection('reports')
        .where('status', isEqualTo: 'assigned')
        .get();
    final completed = await db
        .collection('reports')
        .where('status', isEqualTo: 'completed')
        .get();
    final drivers = await db.collection('drivers').get();
    final residents =
        await db.collection('users').where('role', isEqualTo: 'resident').get();

    return {
      'reports': allReports.docs.length,
      'pending': pending.docs.length,
      'assigned': assigned.docs.length,
      'completed': completed.docs.length,
      'drivers': drivers.docs.length,
      'residents': residents.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _loadCounts(),
      builder: (c, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statCard(
                    'Total Reports',
                    d['reports']!,
                    Icons.report,
                    Colors.blue,
                  ),
                  _statCard(
                    'Pending',
                    d['pending']!,
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                  _statCard(
                    'Assigned',
                    d['assigned']!,
                    Icons.delivery_dining,
                    Colors.purple,
                  ),
                  _statCard(
                    'Completed',
                    d['completed']!,
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _statCard(
                    'Drivers',
                    d['drivers']!,
                    Icons.drive_eta,
                    Colors.teal,
                  ),
                  _statCard(
                    'Residents',
                    d['residents']!,
                    Icons.people,
                    Colors.indigo,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Recent Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reports')
                      .orderBy('timestamp', descending: true)
                      .limit(6)
                      .snapshots(),
                  builder: (c2, snap2) {
                    if (!snap2.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap2.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('No recent reports'));
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final ts = data['timestamp'];
                        final tsText = ts != null && ts is Timestamp
                            ? (ts.toDate().toString().split('.').first)
                            : '';
                        return ListTile(
                          leading: data['photo_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    data['photo_url'],
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.report, color: Colors.red),
                          title: Text(data['trashType'] ?? 'Report'),
                          subtitle: Text(
                            'Status: ${data['status'] ?? '-'} • $tsText',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(title, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- Drivers -----------------
class AdminDriversPage extends StatefulWidget {
  const AdminDriversPage({super.key});

  @override
  State<AdminDriversPage> createState() => _AdminDriversPageState();
}

class _AdminDriversPageState extends State<AdminDriversPage> {
  final CollectionReference driversRef =
      FirebaseFirestore.instance.collection('drivers');
  String _search = '';

  void _openDriverEditor({Map<String, dynamic>? data, String? id}) {
    final nameCtrl = TextEditingController(text: data?['name']);
    final phoneCtrl = TextEditingController(text: data?['phone']);
    final vehicleCtrl = TextEditingController(text: data?['vehicle_number']);
    final areaCtrl = TextEditingController(text: data?['area']);
    final licenseCtrl = TextEditingController(text: data?['license_number']);
    final experienceCtrl =
        TextEditingController(text: data?['experience_years']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(id == null ? 'Add Driver' : 'Edit Driver'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: vehicleCtrl,
                decoration: const InputDecoration(labelText: 'Vehicle Number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: licenseCtrl,
                decoration: const InputDecoration(labelText: 'License No'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: areaCtrl,
                decoration: const InputDecoration(labelText: 'Area/Zone'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: experienceCtrl,
                decoration:
                    const InputDecoration(labelText: 'Experience (yrs)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = {
                'name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'vehicle_number': vehicleCtrl.text.trim(),
                'license_number': licenseCtrl.text.trim(),
                'area': areaCtrl.text.trim(),
                'experience_years': experienceCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              if (id == null) {
                final newDoc = driversRef.doc();
                payload['driverId'] = newDoc.id;
                await newDoc.set(payload);
              } else {
                await driversRef.doc(id).set(payload, SetOptions(merge: true));
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Driver?'),
        content: const Text(
          'This will remove the driver from the system. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await driversRef.doc(id).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _search.trim().isEmpty
        ? driversRef.orderBy('name').snapshots()
        : driversRef
            .where('name', isGreaterThanOrEqualTo: _search)
            .where('name', isLessThanOrEqualTo: '$_search\uf8ff')
            .snapshots();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Drivers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Driver'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => _openDriverEditor(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search drivers by name',
            ),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (c, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No drivers found'));
                }
                return ListView.separated(
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final id = docs[i].id;
                    final d = docs[i].data() as Map<String, dynamic>;
                    return ListTile(
                      leading:
                          const Icon(Icons.drive_eta, color: Colors.green),
                      title: Text(d['name'] ?? 'Driver'),
                      subtitle: Text(
                        'Phone: ${d['phone'] ?? '-'}\nVehicle: ${d['vehicle_number'] ?? '-'}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _openDriverEditor(data: d, id: id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _confirmDelete(id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Residents -----------------
class AdminResidentsPage extends StatefulWidget {
  const AdminResidentsPage({super.key});

  @override
  State<AdminResidentsPage> createState() => _AdminResidentsPageState();
}

class _AdminResidentsPageState extends State<AdminResidentsPage> {
  final CollectionReference usersRef =
      FirebaseFirestore.instance.collection('users');

  String _search = '';

  void _openResidentEditor({Map<String, dynamic>? data, required String id}) {
    final nameCtrl = TextEditingController(text: data?['name']);
    final addressCtrl = TextEditingController(text: data?['address']);
    final phoneCtrl = TextEditingController(text: data?['phone']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Resident'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = {
                'name': nameCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              };
              await usersRef.doc(id).set(payload, SetOptions(merge: true));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Resident?'),
        content: const Text(
          'This will remove resident data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await usersRef.doc(id).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // single, simple stream (no composite index needed)
    final stream =
        usersRef.where('role', isEqualTo: 'resident').snapshots();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Residents Using App',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search residents by name',
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (c, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data!.docs;

                if (allDocs.isEmpty) {
                  return const Center(child: Text('No residents found'));
                }

                // local filtering by name – avoids Firestore index issues
                final docs = allDocs.where((doc) {
                  if (_search.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                      (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(_search);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No matching residents'));
                }

                return ListView.separated(
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final id = docs[i].id;
                    final d = docs[i].data() as Map<String, dynamic>;

                    final lastLogin = d['lastLogin'] != null
                        ? (d['lastLogin'] as Timestamp)
                            .toDate()
                            .toString()
                            .split(".")
                            .first
                        : "Never";

                    return ListTile(
                      leading: const Icon(Icons.person, color: Colors.blue),
                      title: Text(d['name'] ?? 'Resident'),
                      subtitle: Text(
                        'Phone: ${d['phone'] ?? '-'}\n'
                        'Address: ${d['address'] ?? '-'}\n'
                        'Last Login: $lastLogin',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _openResidentEditor(data: d, id: id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _confirmDelete(id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Reports -----------------
class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final CollectionReference reportsRef =
      FirebaseFirestore.instance.collection('reports');
  final CollectionReference driversRef =
      FirebaseFirestore.instance.collection('drivers');
  String _filterStatus = 'all';

  Future<String> _getUserName(String uid) async {
    if (uid.isEmpty) return 'Resident';
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return 'Resident';
    final data = doc.data();
    return (data != null && data['name'] != null)
        ? data['name'] as String
        : 'Resident';
  }

  void _assignDriver(String reportId) async {
    final drivers = await driversRef.get();
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final docs = drivers.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No drivers available. Add drivers from Drivers tab.'),
          );
        }
        return SafeArea(
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              return ListTile(
                leading: const Icon(Icons.drive_eta),
                title: Text(d['name'] ?? 'Driver'),
                subtitle: Text(d['phone'] ?? '-'),
                onTap: () async {
                  await reportsRef.doc(reportId).update({
                    'driver_id': id,
                    'status': 'assigned',
                    'assigned_at': FieldValue.serverTimestamp(),
                  });
                  if (mounted) Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text('This will permanently delete the report.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await reportsRef.doc(id).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query q = reportsRef.orderBy('timestamp', descending: true);
    if (_filterStatus != 'all') {
      q = q.where('status', isEqualTo: _filterStatus);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Reports',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              const Spacer(),
              DropdownButton<String>(
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                ],
                onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: q.snapshots(),
              builder: (c, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No reports'));
                }
                return ListView.separated(
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final id = docs[i].id;
                    final d = docs[i].data() as Map<String, dynamic>;
                    final status = d['status'] ?? 'pending';
                    final residentId = d['residentId'] ?? '';
                    return ListTile(
                      leading: d['photo_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                d['photo_url'],
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.report, color: Colors.red),
                      title: FutureBuilder<String>(
                        future: _getUserName(residentId),
                        builder: (context, snapName) {
                          final name = snapName.data ?? 'Resident';
                          return Text(
                            '$name',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      subtitle: Text(
                        'Type: ${d['trashType'] ?? '-'}\nStatus: $status\nLat: ${_nice(d['latitude'])}, Lon: ${_nice(d['longitude'])}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          if (status == 'pending')
                            ElevatedButton(
                              onPressed: () => _assignDriver(id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('Assign'),
                            ),
                          if (status == 'assigned')
                            ElevatedButton(
                              onPressed: () async {
                                await reportsRef.doc(id).update({
                                  'status': 'completed',
                                  'completed_at':
                                      FieldValue.serverTimestamp(),
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: const Text('Mark Completed'),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _confirmDelete(id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _nice(dynamic v) {
    if (v == null) return '-';
    if (v is num) return v.toStringAsFixed(4);
    return v.toString();
  }
}

// ----------------- Live Map -----------------
class AdminLiveMapPage extends StatelessWidget {
  const AdminLiveMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mapController = MapController();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Map - Drivers',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('drivers').snapshots(),
              builder: (c, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                final markers = <Marker>[];

                for (var doc in docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final lat = d['latitude'];
                  final lon = d['longitude'];
                  final name = d['name'] ?? 'Driver';
                  final vehicle = d['vehicle_number'] ?? '-';
                  if (lat == null || lon == null) continue;

                  markers.add(
                    Marker(
                      point: LatLng(
                        (lat is num)
                            ? lat.toDouble()
                            : double.tryParse(lat.toString()) ?? 0.0,
                        (lon is num)
                            ? lon.toDouble()
                            : double.tryParse(lon.toString()) ?? 0.0,
                      ),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(name),
                            content: Text(
                              'Phone: ${d['phone'] ?? '-'}\nVehicle: $vehicle',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child:
                              const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                }

                final center = markers.isEmpty
                    ? LatLng(17.3850, 78.4867)
                    : markers.first.point;

                return FlutterMap(
                  mapController: mapController,
                  options: MapOptions(initialCenter: center, initialZoom: 12),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    ),
                    MarkerLayer(markers: markers),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Settings -----------------
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Admin Info'),
            subtitle: const Text('Manage admin settings'),
            onTap: () {},
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Export Data'),
            subtitle: const Text('Export reports/drivers/residents'),
            onTap: () {},
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),
        ),
      ],
    );
  }
}

// ----------------- Small sparkline painter (optional) -----------------
class _SparklinePainter extends CustomPainter {
  final List<int> data;
  _SparklinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (data.isEmpty) return;
    final maxVal = data.reduce(max).toDouble();
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height -
          ((maxVal == 0 ? 0 : (data[i] / maxVal)) * size.height);
      points.add(Offset(x, y));
    }
    final ui.Path path = ui.Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
