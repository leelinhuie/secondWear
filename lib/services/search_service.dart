import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> searchClothes(String searchQuery) {
    // If search is empty, return all clothes
    if (searchQuery.isEmpty) {
      return _firestore
          .collection('clothes')
          .orderBy('uploadedAt', descending: true)
          .snapshots();
    }

    // Convert search query to lowercase for case-insensitive search
    searchQuery = searchQuery.toLowerCase();

    return _firestore
        .collection('clothes')
        .orderBy('title')
        .startAt([searchQuery])
        .endAt([searchQuery + '\uf8ff'])
        .snapshots();
  }
} 