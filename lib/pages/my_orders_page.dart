import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/drawer.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class MyOrdersPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: DrawerMenu(),
        appBar: AppBar(
          title: const Text('My Orders'),
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontFamily: 'Cardo',
          ),
          backgroundColor: Colors.green.shade700,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Completed'),
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
            child: Text('No ${status} orders'),
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
                if (!clothesSnapshot.hasData) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final clothes = clothesSnapshot.data!
                    .map((doc) {
                      if (!doc.exists) return null;
                      return doc.data() as Map<String, dynamic>?;
                    })
                    .where((data) => data != null)
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
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: clothes.length,
                        itemBuilder: (context, index) {
                          final cloth = clothes[index];
                          return ListTile(
                            title: Text(cloth?['title'] ?? 'Untitled Item'),
                            trailing: (status == 'approved') // Buttons only visible for 'approved' status
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.directions),
                                        onPressed: () => _openGoogleMaps(cloth?['pickupLocation']),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.qr_code_scanner),
                                        onPressed: () => _showScanner(context, orderDoc.id),
                                      ),
                                    ],
                                  )
                                : null, // No buttons for 'pending' or 'completed'
                          );
                        },
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
      builder: (context) => Container(
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
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    _verifyQRCode(context, orderId, barcode.rawValue ?? '');
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
      // Get the order document
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data();

      if (orderData?['qrCode'] == scannedData) {
        // Update order status to completed
        await _firestore.collection('orders').doc(orderId).update({
          'status': 'completed',
          'pickedUpAt': FieldValue.serverTimestamp(), // Add pickup timestamp
        });

        // Update all clothes status to completed
        final clothesIds = orderData?['clothesIds'] as List?;
        if (clothesIds != null) {
          for (var clothesId in clothesIds) {
            await _firestore.collection('clothes').doc(clothesId.toString()).update({
              'orderStatus': 'completed',
              'pickedUpAt': FieldValue.serverTimestamp(), // Add pickup timestamp
            });
          }
        }

        if (!context.mounted) return;
        Navigator.pop(context); // Close scanner
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR code'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Widget _buildStatusChip(String status) {
    final color = status == 'pending'
        ? Colors.yellow
        : status == 'approved'
            ? Colors.green
            : Colors.grey;
    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openGoogleMaps(Map<String, dynamic> location) async {
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
}
