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
          color: Colors.white,
          fontSize: 20,
        ),
        backgroundColor: Colors.green.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
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
                    const Text('No approved donations yet'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => UploadClothesPage()),
                        );
                      },
                      child: const Text('Upload Clothes'),
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
                    leading: clothesData['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              clothesData['imageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : null,
                    title: Text(clothesData['title'] ?? 'Untitled Item'),
                    subtitle: Text(
                      'Status: ${clothesData['orderStatus']?.toUpperCase() ?? 'N/A'}',
                      style: TextStyle(
                        color: clothesData['orderStatus'] == 'completed' 
                            ? Colors.grey 
                            : Colors.green,
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
                          final qrCode = orderData?['qrCode'];

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
} 