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
          .limit(1)
          .get();

      if (existingItem.docs.isNotEmpty) {
        throw 'Item already saved';
      }

      // Check if the item still exists and is still approved
      final clothesDoc = await _firestore
          .collection('clothes')
          .doc(clothesId)
          .get();

      if (!clothesDoc.exists) {
        throw 'This item no longer exists';
      }

      final clothesDocData = clothesDoc.data() as Map<String, dynamic>;
      if (clothesDocData['isApproved'] != true) {
        throw 'This item is no longer available';
      }

      // Clean up image URLs before saving
      Map<String, dynamic> cleanedData = Map<String, dynamic>.from(clothesData);
      
      // Handle multiple images
      if (cleanedData.containsKey('imageUrls')) {
        List<String> imageUrls = List<String>.from(cleanedData['imageUrls']);
        // Filter out empty or invalid URLs
        imageUrls = imageUrls.where((url) => url.isNotEmpty && Uri.tryParse(url)?.hasAbsolutePath == true).toList();
        if (imageUrls.isEmpty) {
          throw 'No valid image URLs provided';
        }
        cleanedData['imageUrls'] = imageUrls;
      }
      // Handle single image
      else if (cleanedData.containsKey('imageUrl')) {
        String? imageUrl = cleanedData['imageUrl'] as String?;
        if (imageUrl == null || imageUrl.isEmpty || Uri.tryParse(imageUrl)?.hasAbsolutePath != true) {
          throw 'Invalid image URL provided';
        }
        cleanedData['imageUrls'] = [imageUrl];
      } else {
        throw 'No image URL provided';
      }

      // Add the clothes item to saved_clothes collection
      await _firestore.collection('saved_clothes').add({
        'clothesId': clothesId,
        'userId': user.uid,
        'savedAt': FieldValue.serverTimestamp(),
        'itemData': cleanedData,
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

  Future<void> removeMultipleSavedClothes(List<String> clothesIds) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'User must be logged in to remove saved clothes';
      }

      // Get all saved items that match the clothesIds
      final QuerySnapshot savedItems = await _firestore
          .collection('saved_clothes')
          .where('userId', isEqualTo: user.uid)
          .where('clothesId', whereIn: clothesIds)
          .get();

      if (savedItems.docs.isEmpty) {
        return; // No items to delete
      }

      // Create a batch to perform multiple deletes
      final batch = _firestore.batch();
      
      // Add each document deletion to the batch
      for (var doc in savedItems.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw 'Failed to remove saved clothes: $e';
    }
  }

  // Add method to check if an item is saved
  Future<bool> isClothingSaved(String clothesId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final QuerySnapshot existingItem = await _firestore
          .collection('saved_clothes')
          .where('userId', isEqualTo: user.uid)
          .where('clothesId', isEqualTo: clothesId)
          .limit(1)
          .get();

      return existingItem.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if clothing is saved: $e');
      return false;
    }
  }
}
