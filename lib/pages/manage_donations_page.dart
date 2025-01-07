import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Add this package to pubspec.yaml
import '../widgets/drawer.dart';

class ManageDonationsPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 144, 189, 134),
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Manage Donations",
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontFamily: 'Cardo',
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('clothes')
              .where('donorId', isEqualTo: _auth.currentUser?.uid)
              .where('orderStatus', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pending donation requests',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final clothesDoc = snapshot.data!.docs[index];
                final clothesData = clothesDoc.data() as Map<String, dynamic>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: Image.network(
                          clothesData['imageUrls']?.first ??
                              clothesData['imageUrl'] ??
                              'https://via.placeholder.com/400?text=No+Image',
                          height: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green.shade700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clothesData['title'] ?? 'Untitled Item',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Order ID: ${clothesData['orderId']?.toString() ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pickup Date: ${_formatDate(clothesData['pickupDate'] != null ? (clothesData['pickupDate'] as Timestamp).toDate() : DateTime.now())}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _approveOrder(
                                    context,
                                    clothesData['orderId']?.toString() ?? '',
                                    clothesDoc.id,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Color.fromARGB(255, 144, 189, 134),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Approve'),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => _rejectOrder(
                                    context,
                                    clothesData['orderId']?.toString() ?? '',
                                    clothesDoc.id,
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _approveOrder(
      BuildContext context, String orderId, String clothesId) async {
    try {
      // Generate a new order ID if one doesn't exist
      final String finalOrderId = orderId.isEmpty
          ? _firestore.collection('orders').doc().id
          : orderId;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Generate QR code in ORDER format: ORDER:timestamp:userId:orderId
      final qrData = 'ORDER:$timestamp:${_auth.currentUser!.uid}:$finalOrderId';

      // Update order status
      await _firestore.collection('orders').doc(finalOrderId).set({
        'status': 'approved',
        'completedAt': FieldValue.serverTimestamp(),
        'pointsAwarded': false,
        'clothesIds': [clothesId],
        'qrCode': qrData,
      }, SetOptions(merge: true));

      // Update clothes document
      await _firestore.collection('clothes').doc(clothesId).update({
        'orderStatus': 'approved',
        'orderId': finalOrderId,
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      // Show success dialog with QR code
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Donation Approved!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('QR code generated successfully'),
              const SizedBox(height: 20),
              QrImageView(
                data: qrData,
                size: 200,
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _rejectOrder(
      BuildContext context, String orderId, String clothesId) async {
    try {
      final batch = _firestore.batch();

      // Update order status to rejected
      if (orderId.isNotEmpty) {
        final orderRef = _firestore.collection('orders').doc(orderId);
        batch.update(orderRef, {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update clothes status to rejected
      final clothesRef = _firestore.collection('clothes').doc(clothesId);
      batch.update(clothesRef, {
        'orderStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!context.mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order Rejected'),
          content: const Text(
            'The order has been rejected. The user will be notified and can reschedule the pickup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
