import 'package:flutter/material.dart';
import 'package:untitled3/services/firestore.dart';

class EditPostDialog extends StatelessWidget {
  final String postID;
  final String currentMessage;
  final FirestoreServices firestoreServices;

  EditPostDialog({
    required this.postID,
    required this.currentMessage,
    required this.firestoreServices,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController editController = TextEditingController(text: currentMessage);

    return AlertDialog(
      title: const Text('Edit Post'),
      content: TextField(
        controller: editController,
        decoration: const InputDecoration(
          hintText: 'Edit your post...',
        ),
        maxLines: null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: Colors.green.shade700,
          ),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newMessage = editController.text.trim();
            if (newMessage.isNotEmpty) {
              firestoreServices.updatePost(postID, newMessage);
            }
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.green.shade700,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
} 