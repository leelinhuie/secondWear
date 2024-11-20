import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled3/services/firestore.dart';

class LikeButton extends StatefulWidget {
  final String postID;
  final int likes;
  final List<dynamic> likedBy;

  const LikeButton({
    Key? key,
    required this.postID,
    required this.likes,
    required this.likedBy,
  }) : super(key: key);

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final FirestoreServices firestoreServices = FirestoreServices();

  @override
  Widget build(BuildContext context) {
    bool isLiked = widget.likedBy.contains(currentUser.uid);

    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.favorite,
            color: isLiked ? Colors.red : Colors.grey,
          ),
          onPressed: () async {
            if (isLiked) {
              // Remove like
              await firestoreServices.unlikePost(widget.postID, currentUser.uid);
            } else {
              // Add like
              await firestoreServices.likePost(widget.postID, currentUser.uid);
            }
            setState(() {}); // Refresh the UI
          },
        ),
        Text('${widget.likes} Likes'),
      ],
    );
  }
}
