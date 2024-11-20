import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreServices {
  final CollectionReference posts = FirebaseFirestore.instance.collection("user posts");
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addPost(String user, String message) {
    if (message.trim().isEmpty) {
      return Future.value();
    }
    
    return posts.add({
      'email': user,
      'message': message.trim(),
      'timestamp': Timestamp.now(),
      'likes': 0,
      'likedBy': [],
    });
  }

  Stream<QuerySnapshot> getPostsStream() {
    return posts.orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> deletePost(String docID, String userEmail) {
    return posts.doc(docID).delete();
  }

  Future<void> likePost(String docID, String userID) async {
    await posts.doc(docID).update({
      'likes': FieldValue.increment(1),
      'likedBy': FieldValue.arrayUnion([userID]),
    });
  }

  Future<void> unlikePost(String docID, String userID) async {
    await posts.doc(docID).update({
      'likes': FieldValue.increment(-1),
      'likedBy': FieldValue.arrayRemove([userID]),
    });
  }

  Future<void> addComment(String postID, String comment, String user) {
    return posts.doc(postID).collection('comments').add({
      'comment': comment,
      'email': user,
      'timestamp': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot> getCommentsStream(String postID) {
    return posts.doc(postID).collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> addRewardPoints(String userId, int points) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw 'User document does not exist';
        }
        
        final currentPoints = userDoc.data()?['rewardPoints'] ?? 0;
        transaction.update(userRef, {
          'rewardPoints': currentPoints + points,
        });
      });
    } catch (e) {
      throw 'Failed to update reward points: $e';
    }
  }
}
