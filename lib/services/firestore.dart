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

  Future<void> deletePost(String postId, String userEmail) async {
    try {
      // Get the post document reference
      final postRef = posts.doc(postId);
      
      // Get all comments for this post
      final commentsSnapshot = await postRef.collection('comments').get();
      
      // Use a batch to delete all comments and the post
      final batch = _firestore.batch();
      
      // Add comment deletions to batch
      for (var comment in commentsSnapshot.docs) {
        batch.delete(comment.reference);
      }
      
      // Add post deletion to batch
      batch.delete(postRef);
      
      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw 'Failed to delete post: $e';
    }
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

  Future<Map<String, dynamic>> getContent(String contentId, String contentType) async {
    try {
      print('DEBUG: Attempting to get content - ID: $contentId, Type: $contentType');
      
      DocumentSnapshot doc;
      if (contentType == 'post') {
        // Use the correct collection name "user posts"
        doc = await _firestore.collection("user posts").doc(contentId).get();
        print('DEBUG: Post document exists: ${doc.exists}');
        if (doc.exists) {
          print('DEBUG: Post data: ${doc.data()}');
        }
      } else {
        // For comments
        final commentQuery = await _firestore
            .collectionGroup('comments')
            .where(FieldPath.documentId, isEqualTo: contentId)
            .get();
        
        print('DEBUG: Comment query results: ${commentQuery.docs.length}');
        if (commentQuery.docs.isNotEmpty) {
          doc = commentQuery.docs.first;
          print('DEBUG: Comment data: ${doc.data()}');
        } else {
          return {};
        }
      }

      if (!doc.exists) {
        print('DEBUG: Document does not exist');
        return {};
      }

      final data = doc.data() as Map<String, dynamic>;
      print('DEBUG: Retrieved content successfully: $data');
      return data;
      
    } catch (e) {
      print('DEBUG: Error getting content: $e');
      throw 'Failed to get content: $e';
    }
  }

  Future<void> flagContent(String contentId, String contentType) async {
    try {
      await _firestore
          .collection(contentType == 'post' ? 'posts' : 'comments')
          .doc(contentId)
          .update({
        'flagged': true,
        'flaggedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to flag content: $e';
    }
  }

  Future<void> addReport({
    required String contentId,
    required String contentType,
    required String reportType,
    required String reportedBy,
    required String reportedUser,
    bool? aiVerified,
    String? severity,
    String? action,
  }) async {
    await _firestore.collection('reports').add({
      'contentId': contentId,
      'contentType': contentType,
      'reportType': reportType,
      'reportedBy': reportedBy,
      'reportedUser': reportedUser,
      'timestamp': FieldValue.serverTimestamp(),
      'status': action == 'deleted' ? 'resolved' : 'pending',
      'aiVerified': aiVerified,
      'severity': severity,
      'action': action,
      'actionTimestamp': action != null ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<void> deleteComment(String commentId) async {
    // Find the parent post document
    final commentDoc = await _firestore
        .collectionGroup('comments')
        .where(FieldPath.documentId, isEqualTo: commentId)
        .get();
    
    if (commentDoc.docs.isNotEmpty) {
      await commentDoc.docs.first.reference.delete();
    }
  }
}
