import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/drawer.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:lottie/lottie.dart';
import 'package:untitled3/pages/checkout_page.dart';

class MyOrdersPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        drawer: DrawerMenu(),
        appBar: AppBar(
          title: const Text('My Orders'),
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontFamily: 'Cardo',
          ),
          backgroundColor: const Color.fromARGB(255, 144, 189, 134),
          iconTheme: const IconThemeData(color: Colors.black),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Completed'),
              Tab(text: 'Rejected'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList('pending'),
            _buildOrdersList('approved'),
            _buildOrdersList('completed'),
            _buildOrdersList('rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('status', isEqualTo: status)
          .orderBy('orderedAt', descending: true)
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
            child: Text('No $status orders'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final orderDoc = snapshot.data!.docs[index];
            final orderData = orderDoc.data() as Map<String, dynamic>;

            return FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait(
                ((orderData['clothesIds'] as List?) ?? [])
                    .map((id) => _firestore.collection('clothes').doc(id.toString()).get())
                    .toList(),
              ),
              builder: (context, clothesSnapshot) {
                if (clothesSnapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (!clothesSnapshot.hasData) {
                  return const Center(
                    child: Text('Error loading clothes details'),
                  );
                }

                final clothes = clothesSnapshot.data!
                    .where((doc) => doc.exists)
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList();

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order #${orderDoc.id.substring(0, 8)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                _buildStatusChip(status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pickup Date: ${_formatDate(orderData['deliveryDate'] is Timestamp 
                                ? orderData['deliveryDate'].toDate() 
                                : DateTime.now())}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: clothes.length,
                        itemBuilder: (context, index) {
                          final cloth = clothes[index];
                          return ListTile(
                            title: Text(cloth['title'] ?? 'Untitled Item'),
                            trailing: (status == 'approved')
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.directions),
                                        onPressed: () => _openGoogleMaps(cloth['pickupLocation']),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.qr_code_scanner),
                                        onPressed: () => _showScanner(context, orderDoc.id),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
                      if (status == 'rejected')
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: () => _rescheduleOrder(context, orderDoc.id, orderData),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 144, 189, 134),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            child: const Text(
                              'Reschedule Pickup',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Cardo',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showScanner(BuildContext context, String orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              title: const Text('Scan QR Code'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: MobileScanner(
                controller: MobileScannerController(),
                onDetect: (capture) {
                  final barcode = capture.barcodes.first;
                  if (barcode.rawValue != null) {
                    _verifyQRCode(context, orderId, barcode.rawValue!);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

void _verifyQRCode(BuildContext context, String orderId, String scannedData) async {
    try {
        print('Starting QR verification...');
        print('Order ID: $orderId');
        print('Scanned Data: $scannedData');

        final orderDoc = await _firestore.collection('orders').doc(orderId).get();
        if (!orderDoc.exists) {
            print('Order document not found!');
            return;
        }

        final orderData = orderDoc.data() as Map<String, dynamic>;
        final clothesIds = List<String>.from(orderData['clothesIds'] ?? []);
        print('Clothes IDs in order: $clothesIds');

        bool qrCodeMatched = false;
        final clothesDocs = await Future.wait(
            clothesIds.map((id) => _firestore.collection('clothes').doc(id).get())
        );

        for (var clothesDoc in clothesDocs) {
            if (clothesDoc.exists) {
                final clothesData = clothesDoc.data() as Map<String, dynamic>;
                print('Comparing:');
                print('Stored  QR: ${clothesData['qrCode']}');
                print('Scanned QR: $scannedData');
                if (clothesData['qrCode'] == scannedData) {
                    print('Match found!');
                    qrCodeMatched = true;
                    
                    // Update both the clothes and order status
                    await Future.wait([
                        clothesDoc.reference.update({
                            'orderStatus': 'completed',
                            'pickedUpAt': FieldValue.serverTimestamp(),
                        }),
                        orderDoc.reference.update({
                            'status': 'completed',
                            'pickedUpAt': FieldValue.serverTimestamp(),
                        })
                    ]);

                    if (context.mounted) {
                        Navigator.pop(context); // Close scanner
                        _showSuccessDialog(context); // Show success animation
                    }
                    break; // Exit loop after successful match
                }
            }
        }

        if (!qrCodeMatched) {
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid QR code'), backgroundColor: Colors.red),
                );
            }
        }
    } catch (e) {
        print('Error during verification: $e');
        if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
        }
    }
}



  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'lib/assets/successfully.json',
              width: 130,
              height: 130,
              repeat: false,
            ),
            const Text('Pickup verified successfully!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = status == 'pending'
        ? Colors.yellow
        : status == 'approved'
            ? Colors.green
            : status == 'rejected'
                ? Colors.red
                : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openGoogleMaps(Map<String, dynamic>? location) async {
    if (location == null) return;
    final lat = location['latitude'];
    final lng = location['longitude'];
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  void _rescheduleOrder(BuildContext context, String orderId, Map<String, dynamic> orderData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          selectedClothesIds: List<String>.from(orderData['clothesIds'] ?? []),
          isRescheduling: true,
          originalOrderData: orderData,
        ),
      ),
    );
  }
}
