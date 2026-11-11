// lib/login_page.dart
//
// Final working version with:
// - Resident / Driver / Admin login
// - Email OTP (Brevo) + Phone OTP (Firebase)
// - Uses your verified sender: chaithanyashringar@gmail.com
// - OTP-based auth, SAME EMAIL → SAME USER (same UID for reports)

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController otpCtrl = TextEditingController();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool loading = false;
  bool otpSent = false;
  String? otpSentType; // "email" / "phone"

  String? verificationId;
  String? generatedEmailOtp;
  DateTime? emailOtpExpiry;

  String role = "resident";

  // YOUR WORKING BREVO API KEY
  static const String BREVO_API_KEY = ""; // Configure on a secure backend; never place Brevo keys in the app.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) role = arg;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addressCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    otpCtrl.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F3E8),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  "${role.toUpperCase()} LOGIN",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),

                buildField("Full Name", Icons.person, nameCtrl),
                const SizedBox(height: 14),

                buildField("Address", Icons.home, addressCtrl),
                const SizedBox(height: 14),

                buildField("Email (for OTP)", Icons.email, emailCtrl),
                const SizedBox(height: 14),

                buildField(
                  "Phone (+91...)",
                  Icons.phone,
                  phoneCtrl,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 20),

                if (otpSent)
                  buildField(
                    "Enter OTP",
                    Icons.lock,
                    otpCtrl,
                    keyboard: TextInputType.number,
                  ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: buildButton("Send Email OTP", sendEmailOtp),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: buildButton("Send Phone OTP", sendPhoneOtp),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                loading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: otpSent ? verifyOtp : null,
                          child: const Text(
                            "Verify & Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildField(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget buildButton(String text, Function() action) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : action,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // SEND EMAIL OTP
  // --------------------------------------------------------------------
  Future<void> sendEmailOtp() async {
    final email = emailCtrl.text.trim();
    final name = nameCtrl.text.trim().isEmpty ? "User" : nameCtrl.text.trim();

    if (email.isEmpty) return showSnack("Enter Email");

    setState(() => loading = true);

    try {
      final otp = generateOtp();
      generatedEmailOtp = otp;
      emailOtpExpiry = DateTime.now().add(const Duration(minutes: 5));
      otpSentType = "email";

      final response = await http.post(
        Uri.parse("https://api.brevo.com/v3/smtp/email"),
        headers: {
          "accept": "application/json",
          "api-key": BREVO_API_KEY,
          "content-type": "application/json",
        },
        body: jsonEncode({
          "sender": {
            "name": "TrashGO",
            "email": "chaithanyashringar@gmail.com",
          },
          "to": [
            {"email": email},
          ],
          "subject": "Your OTP Code",
          "htmlContent":
              "<p>Hello $name,<br>Your OTP is <b>$otp</b>. Valid for 5 minutes.</p>",
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        otpSent = true;
        showSnack("OTP sent to $email");
      } else {
        showSnack("Error: ${response.body}");
      }
    } catch (e) {
      showSnack("Email sending failed");
    } finally {
      setState(() => loading = false);
    }
  }

  // --------------------------------------------------------------------
  // SEND PHONE OTP
  // --------------------------------------------------------------------
  Future<void> sendPhoneOtp() async {
    final phone = phoneCtrl.text.trim();
    if (phone.isEmpty) return showSnack("Enter phone number");

    otpSentType = "phone";
    setState(() => loading = true);

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          final userCred = await auth.signInWithCredential(cred);
          await completeLogin(userCred);
        },
        verificationFailed: (e) {
          showSnack("Phone OTP failed");
          setState(() => loading = false);
        },
        codeSent: (id, _) {
          verificationId = id;
          otpSent = true;
          setState(() => loading = false);
          showSnack("OTP sent to phone");
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      showSnack("Phone OTP error");
      setState(() => loading = false);
    }
  }

  // --------------------------------------------------------------------
  // VERIFY OTP
  // --------------------------------------------------------------------
  Future<void> verifyOtp() async {
    final otp = otpCtrl.text.trim();
    if (otp.isEmpty) return showSnack("Enter OTP");

    // EMAIL OTP FLOW
    if (otpSentType == "email") {
      if (generatedEmailOtp == null ||
          emailOtpExpiry == null ||
          DateTime.now().isAfter(emailOtpExpiry!)) {
        return showSnack("OTP expired. Please request again.");
      }
      if (otp != generatedEmailOtp) return showSnack("Wrong OTP");

      // For email OTP: sign in anonymously, logical user is matched by EMAIL
      final cred = await auth.signInAnonymously();
      await completeLogin(cred);
      return;
    }

    // PHONE OTP FLOW
    if (otpSentType == "phone") {
      if (verificationId == null) return showSnack("Send OTP again");

      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId!,
          smsCode: otp,
        );
        final userCred = await auth.signInWithCredential(credential);
        await completeLogin(userCred);
      } catch (e) {
        showSnack("Incorrect phone OTP");
      }
    }
  }

  // --------------------------------------------------------------------
  // COMPLETE LOGIN (⭐ SAME EMAIL → SAME UID)
  // --------------------------------------------------------------------
  Future<void> completeLogin(UserCredential cred) async {
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    String uid;

    // STEP 1 — Check if user already exists by email (primary)
    QuerySnapshot<Map<String, dynamic>>? existing;

    if (email.isNotEmpty) {
      existing = await firestore
          .collection("users")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();
    }

    // If no email match, optionally match by phone
    if ((existing == null || existing.docs.isEmpty) && phone.isNotEmpty) {
      existing = await firestore
          .collection("users")
          .where("phone", isEqualTo: phone)
          .limit(1)
          .get();
    }

    if (existing != null && existing.docs.isNotEmpty) {
      // USER EXISTS → REUSE SAME UID
      uid = existing.docs.first.id;
    } else {
      // NEW USER → use current Firebase UID
      uid = cred.user!.uid;
    }

    // STEP 2 — Save / update user document
    await firestore.collection("users").doc(uid).set({
      "uid": uid,
      "role": role,
      "name": nameCtrl.text.trim(),
      "address": addressCtrl.text.trim(),
      "email": email,
      "phone": phone,
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // STEP 3 — Extra collection for drivers
    if (role == "driver") {
      await firestore.collection("drivers").doc(uid).set({
        "driver_id": uid,
        "name": nameCtrl.text.trim(),
        "phone": phone,
        "email": email,
        "created_at": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // STEP 4 — Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("uid", uid);
    await prefs.setString("role", role);
    await prefs.setBool("logged_in", true);

    if (!mounted) return;

    // STEP 5 — Navigate based on role
    if (role == "resident") {
      Navigator.pushNamedAndRemoveUntil(context, "/resident", (_) => false);
    } else if (role == "driver") {
      Navigator.pushNamedAndRemoveUntil(
        context,
        "/driver",
        (_) => false,
        arguments: uid,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(context, "/admin", (_) => false);
    }
  }

  // --------------------------------------------------------------------
  String generateOtp() => (100000 + Random().nextInt(900000)).toString();

  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
