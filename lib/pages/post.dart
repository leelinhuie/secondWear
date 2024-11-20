import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled3/services/firestore.dart';
import 'package:untitled3/widgets/like_button.dart';
import 'package:untitled3/widgets/drawer.dart';
import 'package:untitled3/widgets/comments.dart';

class Post extends StatefulWidget {
  const Post({super.key});

  @override
  State<Post> createState() => _PostState();
}

class _PostState extends State<Post> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final textController = TextEditingController();
  final FirestoreServices firestoreServices = FirestoreServices();

  void postMessage() async {
    final message = textController.text;
    if (message.isNotEmpty) {
      await firestoreServices.addPost(currentUser.email ?? 'Anonymous', message);
      textController.clear();
    }
  }

  void deletePost(String postID) async {
    await firestoreServices.deletePost(postID, currentUser.email ?? 'Anonymous');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Community",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Add padding to the top of the input section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        hintText: 'Say something...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: postMessage,
                    icon: Icon(Icons.send, color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10), // Optional spacing

            // Posts List
            Expanded(
              child: StreamBuilder(
                stream: firestoreServices.getPostsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final post = snapshot.data!.docs[index];
                      final postID = post.id;
                      final data = post.data() as Map<String, dynamic>;
                      final likes = data['likes'] ?? 0;
                      final List<dynamic> likedBy = data['likedBy'] ?? [];
                      final message = data['message'] ?? 'No message';

                      return Card(
                        margin: const EdgeInsets.all(10),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title (email)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                                child: Text(
                                  data['email'] ?? 'Anonymous',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              // Content (message)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(message),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  LikeButton(
                                    postID: postID,
                                    likes: likes,
                                    likedBy: likedBy,
                                  ),
                                  Row(
                                    children: [
                                      // Delete button
                                      IconButton(
                                        icon: Icon(Icons.delete, color: Colors.green.shade700),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: const Text('Confirm Delete'),
                                                content: const Text('Are you sure you want to delete this post?'),
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
                                                      deletePost(postID);
                                                      Navigator.of(context).pop();
                                                    },
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.green.shade700,
                                                    ),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      // Comment button changed to TextButton
                                      TextButton(
                                        onPressed: () {
                                          showCommentsDialog(context, postID);
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.green.shade700,
                                        ),
                                        child: const Text('Reply'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Helper function to safely get email from comment data
String getEmailFromComment(Map<String, dynamic> commentData) {
  return commentData['email'] ?? 'Unknown';
}
