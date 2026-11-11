import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/upi_payment.dart';

class BillingPage extends StatelessWidget {
  final String uid;
  const BillingPage({super.key, required this.uid});

  // ---------------------------
  // MARK ALL BILLS AS PAID
  // ---------------------------
  Future<void> markAllBillsPaid(BuildContext context) async {
    final snap = await FirebaseFirestore.instance
        .collection("billing")
        .where("residentId", isEqualTo: uid)
        .where("paid", isEqualTo: false)
        .get();

    for (var d in snap.docs) {
      await d.reference.update({"paid": true});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment successful ✅")),
    );
  }

  // ---------------------------
  // PAYMENT CONFIRMATION POPUP
  // ---------------------------
  void showPaymentConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: const Text(
          "Did you complete the payment?\n\n(This is a simulation.)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await markAllBillsPaid(context);
            },
            child: const Text("Yes, Paid"),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // MAIN UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Billing Summary"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("billing")
            .where("residentId", isEqualTo: uid)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No billing records yet."));
          }

          double totalDue = 0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (!(data["paid"] ?? false)) {
              totalDue += (data["rate"] ?? 0).toDouble();
            }
          }

          return Column(
            children: [
              // ---------------------------
              // TOTAL DUE CARD
              // ---------------------------
              Card(
                margin: const EdgeInsets.all(14),
                child: ListTile(
                  title: const Text(
                    "Total Due",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("₹${totalDue.toStringAsFixed(2)}"),
                  trailing: ElevatedButton(
                    onPressed: totalDue == 0
                        ? null
                        : () async {
                            // ✅ WEB FIX: Direct confirmation
                            if (kIsWeb) {
                              showPaymentConfirmDialog(context);
                              return;
                            }

                            // ✅ ANDROID: Launch UPI
                            await UpiPayment.launchUPIPayment(
                              payeeAddress: "yourupiid@upi",
                              payeeName: "Garbage Collection",
                              amount: totalDue.toString(),
                              note: "Billing Payment",
                            );

                            await Future.delayed(
                              const Duration(seconds: 3),
                            );

                            if (context.mounted) {
                              showPaymentConfirmDialog(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Pay"),
                  ),
                ),
              ),

              // ---------------------------
              // BILL LIST
              // ---------------------------
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final paid = data["paid"] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(
                          "${data["trashType"]} • ₹${data["rate"]}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Report ID: ${data["reportId"]}"),
                        trailing: Chip(
                          label: Text(paid ? "Paid" : "Unpaid"),
                          backgroundColor: paid
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
