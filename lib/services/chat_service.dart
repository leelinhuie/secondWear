import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all users except current user
  Stream<QuerySnapshot> getUsers() {
    return _firestore
        .collection('users')
        .where('email', isNotEqualTo: _auth.currentUser?.email)
        .snapshots();
  }

  // Get or create chat room
  Future<String> createChatRoom(String otherUserEmail) async {
    final currentUserEmail = _auth.currentUser!.email!;
    final chatRoomId = getChatRoomId(currentUserEmail, otherUserEmail);

    // Check if chat room exists
    final chatRoom = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .get();

    if (!chatRoom.exists) {
      // Create new chat room
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'users': [currentUserEmail, otherUserEmail],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    return chatRoomId;
  }

  // Get messages stream
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Send message
  Future<void> sendMessage(String chatRoomId, String message) async {
    final user = _auth.currentUser!;
    
    // Add message to chat room
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId': user.uid,
      'senderEmail': user.email,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update chat room's last message
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  String getChatRoomId(String user1, String user2) {
    List<String> users = [user1, user2];
    users.sort(); // Sort to ensure consistent chat room IDs
    return users.join('_');
  }
}
