// lib/otp_screen.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:otp_pin_field/otp_pin_field.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late String phoneNumber;
  String verificationId = "";
  String smsOTP = "";
  bool loading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _otpPinFieldKey = GlobalKey<OtpPinFieldState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    phoneNumber = ModalRoute.of(context)?.settings.arguments as String;
    sendOtp();
  }

  // ---------------- SEND OTP ----------------
  Future<void> sendOtp() async {
    setState(() => loading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          onLoginSuccess();
        },

        verificationFailed: (FirebaseAuthException e) {
          showSnack("OTP Failed: ${e.message}");
          setState(() => loading = false);
        },

        codeSent: (String verId, int? resendToken) {
          verificationId = verId;
          showSnack("OTP sent to $phoneNumber");
          setState(() => loading = false);
        },

        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
      );
    } catch (e) {
      showSnack("Unexpected error: $e");
      setState(() => loading = false);
    }
  }

  // ---------------- VERIFY OTP ----------------
  Future<void> verifyOtp() async {
    if (smsOTP.length != 6) {
      showSnack("Enter 6-digit OTP");
      return;
    }

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsOTP,
      );

      await _auth.signInWithCredential(credential);
      onLoginSuccess();
    } catch (e) {
      showSnack("❌ Invalid OTP");
      setState(() => loading = false);
    }
  }

  // ---------------- AFTER SUCCESS ----------------
  void onLoginSuccess() {
    Navigator.pushNamedAndRemoveUntil(context, "/homeScreen", (_) => false);
  }

  // ---------------- Snack Msg ----------------
  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.black87),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: size.width * 0.85,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/images/registration.png", height: 150),
              const SizedBox(height: 20),

              Text(
                "Verify OTP",
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                "Sent to $phoneNumber",
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 25),

              OtpPinField(
                key: _otpPinFieldKey,
                maxLength: 6,
                onSubmit: (text) {
                  smsOTP = text;
                },
                onChange: (text) {},
              ),

              const SizedBox(height: 25),

              ElevatedButton(
                onPressed: loading ? null : verifyOtp,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(size.width * 0.8, 50),
                  backgroundColor: Colors.green,
                ),
                child: Text(loading ? "Verifying..." : "Verify"),
              ),

              TextButton(
                onPressed: loading ? null : sendOtp,
                child: const Text("Resend OTP"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
