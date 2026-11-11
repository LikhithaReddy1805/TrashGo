import 'package:url_launcher/url_launcher.dart';

class UpiPayment {
  /// Launch UPI Payment on Android (Google Pay / PhonePe / Paytm)
  static Future<bool> launchUPIPayment({
    required String payeeAddress,
    required String payeeName,
    required String amount,
    String note = "",
  }) async {
    final encodedName = Uri.encodeComponent(payeeName);
    final encodedNote = Uri.encodeComponent(note);

    // ⭐ Build clean UPI link
    final upiUrl =
        """
upi://pay?
pa=$payeeAddress&
pn=$encodedName&
am=$amount&
cu=INR&
tn=$encodedNote
"""
            .replaceAll("\n", "");

    final uri = Uri.parse(upiUrl);

    try {
      // Try launching UPI app
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }

      // ⭐ Google Pay fallback link
      final webUri = Uri.parse(
        "https://pay.google.com/gp/p/ui/pay"
        "?pa=$payeeAddress"
        "&pn=$encodedName"
        "&am=$amount"
        "&cu=INR"
        "&tn=$encodedNote",
      );

      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      print("UPI Error: $e");
    }

    return false;
  }
}