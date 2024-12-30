import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:lottie/lottie.dart';

class CheckoutPage extends StatefulWidget {
  final List<String> selectedClothesIds;

  const CheckoutPage({Key? key, required this.selectedClothesIds}) : super(key: key);

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontFamily: 'Cardo',
        ),
        backgroundColor: const Color(0xFFC8DFC3),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Pickup Date:',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                  fontFamily: 'Cardo',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Colors.green.shade700,
                      onPrimary: Colors.white,
                      onSurface: Colors.green.shade900,
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onDateChanged: (date) {
                      setState(() {
                        selectedDate = date;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Stack(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBDC29A),
                       
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _scheduleDelivery,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Confirm Order',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cardo',
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Lottie.asset(
                              'lib/assets/checkout.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleDelivery() async {
    try {
      final uuid = Uuid();
      final String orderId = uuid.v4();
      
      // Create a batch for atomic operations
      final batch = _firestore.batch();
      
      // First, verify all clothes exist and are available
      List<DocumentSnapshot> clothesDocs = [];
      for (String clothesId in widget.selectedClothesIds) {
        final clothesDoc = await _firestore.collection('clothes').doc(clothesId).get();
        if (!clothesDoc.exists) {
          throw 'One or more selected items no longer exist';
        }
        if (clothesDoc.data()?['orderStatus'] != null) {
          throw 'One or more items are no longer available';
        }
        clothesDocs.add(clothesDoc);
      }
      
      // Add order document to batch
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.set(orderRef, {
        'orderId': orderId,
        'userId': _auth.currentUser?.uid,
        'clothesIds': widget.selectedClothesIds,
        'deliveryDate': Timestamp.fromDate(selectedDate),
        'orderedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'qrCode': null,
      });

      // Update all clothes documents in batch
      for (String clothesId in widget.selectedClothesIds) {
        final clothesRef = _firestore.collection('clothes').doc(clothesId);
        batch.update(clothesRef, {
          'orderStatus': 'pending',
          'orderId': orderId,
        });
      }

      // Commit all changes atomically
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup scheduled successfully! Waiting for donor approval.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 