import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

class InvoiceService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  /// Create invoice document + PDF upload
  static Future<String> createInvoice({
    required String uid,
    required String month,
    required double amount,
  }) async {
    final docRef = await _firestore.collection('invoices').add({
      'userId': uid,
      'month': month,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
      'paid': false,
    });

    final pdfUrl = await _generateAndUploadPdf(
      invoiceId: docRef.id,
      uid: uid,
      month: month,
      amount: amount,
    );

    await docRef.update({'pdfUrl': pdfUrl});
    return docRef.id;
  }

  static Future<void> markInvoicePaid({
    required String invoiceId,
    String? transactionId,
    String? upiId,
  }) async {
    await _firestore.collection('invoices').doc(invoiceId).update({
      'paid': true,
      'paidAt': FieldValue.serverTimestamp(),
      'paymentInfo': {
        'transactionId': transactionId,
        'upiId': upiId,
      }
    });
  }

  static Future<String> _generateAndUploadPdf({
    required String invoiceId,
    required String uid,
    required String month,
    required double amount,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (ctx) {
          return pw.Center(
            child: pw.Column(
              children: [
                pw.Text('Garbage Collection Invoice', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Invoice ID: $invoiceId'),
                pw.Text('User ID: $uid'),
                pw.Text('Month: $month'),
                pw.SizedBox(height: 20),
                pw.Text('Amount: ₹${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Thank you for keeping your area clean!'),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final ref = _storage.ref().child('invoices/$invoiceId.pdf');

    if (kIsWeb) {
      final metadata = SettableMetadata(contentType: 'application/pdf');
      await ref.putData(bytes, metadata);
    } else {
      final tempDir = Directory.systemTemp;
      final tempFile = File(p.join(tempDir.path, 'invoice_$invoiceId.pdf'));
      await tempFile.writeAsBytes(bytes);
      await ref.putFile(tempFile);
    }

    return await ref.getDownloadURL();
  }
}