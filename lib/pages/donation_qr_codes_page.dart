import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/drawer.dart';
import 'upload_clothes.dart';

class DonationQRCodesPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        backgroundColor: const Color(0xFFC8DFC3),
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
                  child: ExpansionTile(
                    leading: _buildImage(clothesData['imageUrl']),
                    title: Text(clothesData['title'] ?? 'Untitled Item'),
                    subtitle: Text(
                      'Status: ${clothesData['orderStatus']?.toUpperCase() ?? 'N/A'}',
                      style: TextStyle(
                        color: _getStatusColor(clothesData['orderStatus']),
                      ),
                    ),
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: _firestore
                            .collection('orders')
                            .doc(clothesData['orderId'])
                            .get(),
                        builder: (context, orderSnapshot) {
                          if (!orderSnapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final orderData = orderSnapshot.data?.data()
                              as Map<String, dynamic>?;
                          if (orderData == null) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Order data unavailable'),
                            );
                          }

                          final qrCode = orderData['qrCode'];
                          if (qrCode == null) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('QR Code not available'),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                QrImageView(
                                  data: qrCode,
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
                              ],
                            ),
                          );
                        },
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

  Widget _buildImage(String? imageUrl) {
    if (imageUrl == null) {
      return const Icon(
        Icons.image_not_supported,
        size: 50,
        color: Colors.grey,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.broken_image,
            size: 50,
            color: Colors.red,
          );
        },
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
