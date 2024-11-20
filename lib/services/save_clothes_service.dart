import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SaveClothesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveClothes(String clothesId, Map<String, dynamic> clothesData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'User must be logged in to save clothes';
      }

      // Check if the user is the donor of this item
      if (clothesData['donorId'] == user.uid) {
        throw 'You cannot save your own donations';
      }

      // Check if item is already saved
      final QuerySnapshot existingItem = await _firestore
          .collection('saved_clothes')
          .where('userId', isEqualTo: user.uid)
          .where('clothesId', isEqualTo: clothesId)
          .get();

      if (existingItem.docs.isNotEmpty) {
        throw 'Item already saved';
      }

      // Generate a unique ID for the saved item
      String savedItemId = _firestore.collection('saved_clothes').doc().id;

      // Add the clothes item to saved_clothes collection
      await _firestore.collection('saved_clothes').doc(savedItemId).set({
        'id': savedItemId,
        'clothesId': clothesId,
        'userId': user.uid,
        'savedAt': FieldValue.serverTimestamp(),
        'itemData': clothesData,
      });
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> removeSavedClothes(String clothesId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'User must be logged in to remove saved clothes';
      }

      final QuerySnapshot savedItem = await _firestore
          .collection('saved_clothes')
          .where('userId', isEqualTo: user.uid)
          .where('clothesId', isEqualTo: clothesId)
          .get();

      if (savedItem.docs.isNotEmpty) {
        await savedItem.docs.first.reference.delete();
      }
    } catch (e) {
      throw 'Failed to remove saved clothes: $e';
    }
  }

  Stream<QuerySnapshot> getSavedClothes() {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'User must be logged in to view saved clothes';
    }

    return _firestore
        .collection('saved_clothes')
        .where('userId', isEqualTo: user.uid)
        .orderBy('savedAt', descending: true)
        .snapshots();
  }
}
