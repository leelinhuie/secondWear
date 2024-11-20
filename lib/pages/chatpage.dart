import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../widgets/drawer.dart';

class ChatPage extends StatefulWidget {
  final String? otherUserEmail;

  const ChatPage({Key? key, this.otherUserEmail}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  String? _selectedUserEmail;
  String? _chatRoomId;

  @override
  void initState() {
    super.initState();
    if (widget.otherUserEmail != null) {
      _initializeChat(widget.otherUserEmail!);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat(String userEmail) async {
    _selectedUserEmail = userEmail;
    _chatRoomId = await _chatService.createChatRoom(userEmail);
    setState(() {});
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _chatRoomId == null) return;

    try {
      await _chatService.sendMessage(_chatRoomId!, messageText);
      _messageController.clear();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        title: _selectedUserEmail != null
            ? Text('Chat with $_selectedUserEmail')
            : const Text('Select a user to chat'),
        actions: [
          if (_selectedUserEmail != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedUserEmail = null;
                  _chatRoomId = null;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_selectedUserEmail == null)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No users found'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final userData = snapshot.data!.docs[index].data() 
                            as Map<String, dynamic>;
                        final userEmail = userData['email'] as String;
                        final userName = userData['name'] ?? userEmail.split('@')[0];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade700,
                            child: Text(
                              userName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(userName),
                          subtitle: Text(userEmail),
                          onTap: () => _initializeChat(userEmail),
                        );
                      },
                    );
                  },
                ),
              ),
            if (_selectedUserEmail != null && _chatRoomId != null) ...[
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMessages(_chatRoomId!),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Something went wrong'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return ListView.builder(
                      reverse: true,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final message = snapshot.data!.docs[index];
                        final isMe = message['senderId'] == _auth.currentUser!.uid;
                        final timestamp = message['timestamp'] as Timestamp?;

                        return Align(
                          alignment: isMe 
                              ? Alignment.centerRight 
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[100] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message['message']),
                                if (timestamp != null)
                                  Text(
                                    DateFormat('HH:mm')
                                        .format(timestamp.toDate()),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
