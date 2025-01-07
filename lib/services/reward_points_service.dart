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
          'rewardPointsHistory': [
            {
              'points': points,
              'timestamp': FieldValue.serverTimestamp(),
              'reason': 'Initial points'
            }
          ]
        }, SetOptions(merge: true));
      } else {
        // If document exists, update the points and add to history
        await userRef.update({
          'rewardPoints': FieldValue.increment(points),
          'rewardPointsHistory': FieldValue.arrayUnion([
            {
              'points': points,
              'timestamp': FieldValue.serverTimestamp(),
              'reason': 'QR Code Scan Reward'
            }
          ])
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

  // Retrieve reward points history
  Stream<List<Map<String, dynamic>>> getRewardPointsHistory() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data?['rewardPointsHistory'] is List 
              ? List<Map<String, dynamic>>.from(data?['rewardPointsHistory'] ?? [])
              : [];
        });
  }

  // Handle QR code scanning
  Future<bool> handleQRCodeScan(String qrData) async {
    try {
      // Validate current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Clean and validate QR data
      final cleanedData = qrData.trim();
      if (cleanedData.isEmpty) {
        throw Exception('Invalid QR code data');
      }

      // Extract order ID (assuming the QR code contains the order ID)
      final orderId = cleanedData;

      // Fetch the order document
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      
      // Check if the order is valid for points
      if (orderData['pointsAwarded'] == true) {
        print('Points already awarded for this order');
        return false;
      }

      // Verify the order status or other conditions if needed
      if (orderData['orderStatus'] != 'completed') {
        throw Exception('Order is not in a valid state for points');
      }

      // Verify the receiver is not the donor
      if (orderData['receiverId'] == currentUser.uid) {
        throw Exception('Receiver cannot scan their own donation QR');
      }

      // Add points to user
      await addPoints(10);

      // Add points to donor
      final donorId = orderData['donorId'];
      if (donorId != null) {
        await _firestore.collection('users').doc(donorId).update({
          'rewardPoints': FieldValue.increment(10),
          'rewardPointsHistory': FieldValue.arrayUnion([
            {
              'points': 10,
              'timestamp': FieldValue.serverTimestamp(),
              'reason': 'Donor QR Code Scan Reward'
            }
          ])
        });
      }
      
      // Update order to mark points as awarded
      await _firestore.collection('orders').doc(orderId).update({
        'pointsAwarded': true,
        'pointsAwardedAt': FieldValue.serverTimestamp(),
        'pointsAwardedTo': currentUser.uid,
      });
      
      return true;

    } catch (e) {
      print('Error processing QR code: $e');
      rethrow; // Rethrow to handle in UI
    }
  }
}