import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/drawer.dart';
import 'upload_clothes.dart';

class DonationQRCodesPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _showImageGallery(BuildContext context, List<String> imageUrls) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              backgroundColor: const Color.fromARGB(255, 144, 189, 134),
              titleTextStyle: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontFamily: 'Cardo',
              ),
              iconTheme: const IconThemeData(color: Colors.black),
            ),
            SizedBox(
              height: 300,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        title: const Text('Donation QR Codes'),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontFamily: 'Cardo',
        ),
        backgroundColor: Color.fromARGB(255, 144, 189, 134),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('clothes')
              .where('donorId', isEqualTo: _auth.currentUser?.uid)
              .where('orderStatus', whereIn: ['approved', 'completed'])
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'No approved donations yet. Upload clothes to generate QR codes for donations.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green[800],
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UploadClothesPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Upload Clothes',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final clothesDoc = snapshot.data!.docs[index];
                final clothesData = clothesDoc.data() as Map<String, dynamic>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection('orders')
                        .doc(clothesData['orderId'])
                        .get(),
                    builder: (context, orderSnapshot) {
                      if (!orderSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final orderDoc = orderSnapshot.data!;
                      final orderData = orderDoc.data() as Map<String, dynamic>?;

                      return ExpansionTile(
                        
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${orderDoc.id.substring(0, 8)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Order ID: ${clothesData['orderId'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Status: ${clothesData['orderStatus']?.toUpperCase() ?? 'N/A'}',
                          style: TextStyle(
                            color: _getStatusColor(clothesData['orderStatus']),
                          ),
                        ),
                        children: [
                          if (orderData != null) ...[
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  if (orderData['qrCode'] != null) ...[
                                    QrImageView(
                                      data: orderData['qrCode'],
                                      size: 200,
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Show this QR code to the recipient when they pick up the item',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ] else
                                    const Text('QR Code not available'),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.grey;
      case 'approved':
        return Colors.green;
      default:
        return Colors.orange; // Default color for unknown statuses
    }
  }
}