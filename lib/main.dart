// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Pages
import 'splash_screen.dart';
import 'role_selection_page.dart';
import 'login_page.dart';
import 'dashboards/resident_dashboard.dart';
import 'dashboards/driver_dashboard.dart';
import 'dashboards/admin_dashboard.dart';

// ------------------------------------------------------------------
// 🔹 Background FCM handler (NO Firebase.initializeApp HERE!)
// ------------------------------------------------------------------
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("📩 Background FCM: ${message.data}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------
  // 🔹 FIX: Prevent Firebase from initializing twice
  // ------------------------------------------------------------
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyC0bdOYCD6HwoJpCEMCoG3H-4574Z6l7Mw",
        authDomain: "garbage-collection-application.firebaseapp.com",
        projectId: "garbage-collection-application",
        storageBucket: "garbage-collection-application.appspot.com",
        messagingSenderId: "852007500280",
        appId: "1:852007500280:web:33a785fb3b81973de5be0d",
      ),
    );
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission();

  runApp(const GarbageCollectionApp());
}

// ------------------------------------------------------------------
// APP ROOT
// ------------------------------------------------------------------
class GarbageCollectionApp extends StatelessWidget {
  const GarbageCollectionApp({super.key});

  Future<Widget> _getStartPage() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool("logged_in") ?? false;

    if (!loggedIn) return const RoleSelectionPage();

    final role = prefs.getString("role");
    final uid = prefs.getString("uid");

    print("🔥 Auto-login → Role: $role | UID: $uid");

    switch (role) {
      case "resident":
        return const ResidentDashboard();
      case "driver":
        return DriverDashboard(driverId: uid ?? "driver_01");
      case "admin":
        return const AdminDashboard();
      default:
        return const RoleSelectionPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrashGO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: FutureBuilder(
        future: _getStartPage(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snap.data!;
        },
      ),
      routes: {
        '/role': (_) => const RoleSelectionPage(),
        '/login': (_) => const LoginPage(),
        '/resident': (_) => const ResidentDashboard(),
        '/admin': (_) => const AdminDashboard(),
        '/driver': (context) {
          final driverId =
              ModalRoute.of(context)?.settings.arguments as String?;
          return DriverDashboard(driverId: driverId ?? "driver_01");
        },
      },
    );
  }
}
