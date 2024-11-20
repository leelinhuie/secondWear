// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
//
// class PhotoOperationsService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final CollectionReference photos = FirebaseFirestore.instance.collection(
//       "clothes photos");
//
//   Future<void> addClothes(String title, String content) {
//     return photos.add({
//       'title': _titleController.text,
//       'category': _category,
//       'description': _descriptionController.text,
//       'imageUrl': downloadUrl,
//       'uploadedAt': Timestamp.now(),
//     });
//   }
//
//   // Get a stream of photos for a specific user
//   Stream<QuerySnapshot> getUserPhotosStream(String userId) {
//     return photos
//         .where('userId', isEqualTo: userId)
//         .orderBy('uploadedAt', descending: true)
//         .snapshots();
//   }
//
//   Stream<QuerySnapshot> getAllPhotosStream() {
//     return photos
//         .orderBy('uploadedAt', descending: true)
//         .snapshots();
//   }
// }