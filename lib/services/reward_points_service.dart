import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RewardPointsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add points to user's account
  Future<void> addPoints(int points) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Get the user document reference
      final userRef = _firestore.collection('users').doc(userId);
      
      // Get the current document
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        // If document doesn't exist, create it with initial points
        await userRef.set({
          'rewardPoints': points,
        }, SetOptions(merge: true));
      } else {
        // If document exists, update the points
        await userRef.update({
          'rewardPoints': FieldValue.increment(points),
        });
      }
    } catch (e) {
      throw Exception('Failed to add reward points: $e');
    }
  }

  // Get user's current points
  Stream<int> getUserPoints() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['rewardPoints'] ?? 0);
  }

  // Add this method to handle QR code scanning
  Future<bool> handleQRCodeScan(String qrData) async {
    try {
      print('Raw QR Data received: [$qrData]'); // Debug the exact raw data
      
      // Clean the data - remove any whitespace and special characters
      String cleanedData = qrData.trim();
      print('Cleaned QR Data: [$cleanedData]');

      // Try to extract orderId directly if the format is different
      String? orderId;
      
      if (cleanedData.contains('ORDER:')) {
        // Try original format
        final parts = cleanedData.split(':');
        print('Split parts: $parts');
        orderId = parts.length >= 2 ? parts[1] : null;
      } else {
        // Assume the entire string might be the orderId
        orderId = cleanedData;
      }

      print('Extracted OrderId: $orderId');

      if (orderId == null || orderId.isEmpty) {
        throw Exception('Could not extract valid order ID from QR code');
      }

      // Get the order document
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      
      if (!orderDoc.exists) {
        throw Exception('Order not found: $orderId');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      print('Found order data: $orderData');
      
      // Check if points were already awarded
      if (orderData['pointsAwarded'] == true) {
        print('Points already awarded for this order');
        return false;
      }

      // Add points to user
      await addPoints(10);
      
      // Update order to mark points as awarded
      await _firestore.collection('orders').doc(orderId).update({
        'pointsAwarded': true,
        'pointsAwardedAt': FieldValue.serverTimestamp(),
      });
      
      print('Successfully processed QR code and awarded points');
      return true;

    } catch (e) {
      print('Error processing QR code: $e');
      rethrow; // Rethrow to handle in UI
    }
  }
}