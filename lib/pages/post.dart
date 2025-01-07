import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled3/services/firestore.dart';
import 'package:untitled3/widgets/like_button.dart';
import 'package:untitled3/widgets/drawer.dart';
import 'package:untitled3/widgets/comments.dart';
import 'package:untitled3/widgets/report_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:untitled3/widgets/edit_post.dart';

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
      await firestoreServices.addPost(
          currentUser.email ?? 'Anonymous', message);
      textController.clear();
      setState(() {}); // Ensures the UI updates after clearing the text
    }
  }

  void deletePost(String postID) async {
    await firestoreServices.deletePost(
        postID, currentUser.email ?? 'Anonymous');
  }

  final FocusNode _focusNode = FocusNode();
  int _maxLines = 1;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _maxLines = _focusNode.hasFocus ? 5 : 1; // Expand when focused
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 144, 189, 134),
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Community",
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontFamily: 'Cardo',
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Focus(
                onFocusChange: (hasFocus) {
                  setState(() {});
                },
                child: TextField(
                  controller: textController,
                  onTap: () => setState(() {}),
                  focusNode: _focusNode,
                  maxLines: _maxLines,
                  decoration: InputDecoration(
                    hintText: 'Say something...',
                    suffixIcon: IconButton(
                      onPressed: postMessage,
                      icon: Icon(Icons.send, color: Colors.green.shade700),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: FocusScope.of(context).hasFocus
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.green),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
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
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      data['email'] ?? 'Anonymous',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (data['email'] == currentUser.email)
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return EditPostDialog(
                                                  postID: postID,
                                                  currentMessage: message,
                                                  firestoreServices:
                                                      firestoreServices,
                                                );
                                              },
                                            );
                                          } else if (value == 'delete') {
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: const Text(
                                                      'Confirm Delete'),
                                                  content: const Text(
                                                      'Are you sure you want to delete this post?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(),
                                                      style:
                                                          TextButton.styleFrom(
                                                        foregroundColor: Colors
                                                            .green.shade700,
                                                      ),
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        deletePost(postID);
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      style:
                                                          TextButton.styleFrom(
                                                        foregroundColor: Colors.red,
                                                      ),
                                                      child:
                                                          const Text('Delete'),
                                                          
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          }
                                        },
                                        itemBuilder: (BuildContext context) =>
                                            <PopupMenuEntry<String>>[
                                          const PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      )
                                    else
                                      ReportButton(
                                        contentId: postID,
                                        contentType: 'post',
                                        reportedUserEmail:
                                            data['email'] ?? 'Anonymous',
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(message),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  LikeButton(
                                    postID: postID,
                                    likes: likes,
                                    likedBy: likedBy,
                                  ),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: firestoreServices
                                        .getCommentsStream(postID),
                                    builder: (context, snapshot) {
                                      int commentCount = snapshot.hasData
                                          ? snapshot.data!.docs.length
                                          : 0;
                                      return TextButton.icon(
                                        onPressed: () {
                                          showCommentsDialog(context, postID);
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              Colors.green.shade700,
                                        ),
                                        icon:
                                            const Icon(Icons.comment_outlined),
                                        label: Text('$commentCount'),
                                      );
                                    },
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
