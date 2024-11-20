import 'package:flutter/material.dart';
import 'package:untitled3/services/firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firestoreServices = FirestoreServices();
final currentUser = FirebaseAuth.instance.currentUser;

void showCommentsDialog(BuildContext context, String postID) {
  final TextEditingController commentController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6, // Make dialog size more reasonable
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              // Comments list
              Expanded(
                child: StreamBuilder(
                  stream: firestoreServices.getCommentsStream(postID),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final comment = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        final email = comment['email'] ?? 'Unknown';  // Fallback to 'Unknown' if email is null
                        return ListTile(
                          title: Text(email),
                          subtitle: Text(comment['comment']),
                        );
                      },
                    );
                  },
                ),
              ),
              // Comment input
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        if (commentController.text.isNotEmpty) {
                          firestoreServices.addComment(
                            postID, 
                            commentController.text, 
                            currentUser?.email ?? 'Anonymous'
                          );
                          commentController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
