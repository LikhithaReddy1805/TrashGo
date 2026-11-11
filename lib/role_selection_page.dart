import 'package:flutter/material.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Auto responsive width (Mobile/Tablets/Large Screens)
    final double cardWidth = size.width < 600
        ? size.width * 0.85
        : size.width * 0.35;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/logo.png", height: 60),
                const SizedBox(height: 15),

                const Text(
                  "Select Your Role",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B5E20),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 30),

                _buildRoleButton(
                  context,
                  "Resident",
                  Icons.home_rounded,
                  const Color(0xFF1B5E20),
                ),
                const SizedBox(height: 15),
                _buildRoleButton(
                  context,
                  "Driver",
                  Icons.local_shipping_rounded,
                  const Color(0xFF1565C0),
                ),
                const SizedBox(height: 15),
                _buildRoleButton(
                  context,
                  "Admin",
                  Icons.admin_panel_settings_rounded,
                  const Color(0xFF6A1B9A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/login',
            arguments: title.toLowerCase(), // "resident", "driver", "admin"
          );
        },
      ),
    );
  }
}