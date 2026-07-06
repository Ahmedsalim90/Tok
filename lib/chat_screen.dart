import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserEmail;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserEmail,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  String get _chatId {
    final ids = [currentUser!.uid, widget.otherUserId]..sort();
    return ids.join('_');
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .add({
      'senderId': currentUser!.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: kBackground,
        title: Text(widget.otherUserEmail),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: kCoral),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: kCoral.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.waving_hand_outlined,
                            color: kCoral,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: kNavy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Say hello to ${widget.otherUserEmail.split('@').first}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: kSubtitleGray,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index];
                    final isMe = data['senderId'] == currentUser!.uid;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? kCoral : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data['text'] as String,
                              style: TextStyle(
                                color: isMe ? kBackground : kNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(data['timestamp']),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? kBackground.withOpacity(0.7)
                                    : kNavy.withOpacity(0.5),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: kCoral,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: kBackground, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}