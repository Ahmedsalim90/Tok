import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserEmail;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserEmail,
    required this.otherUserName,
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

    final chatRef =
    FirebaseFirestore.instance.collection('chats').doc(_chatId);

    await chatRef.collection('messages').add({
      'senderId': currentUser!.uid,
      'participants': [currentUser!.uid, widget.otherUserId],
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    await chatRef.set({
      'participants': [currentUser!.uid, widget.otherUserId],
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUser!.uid,
    }, SetOptions(merge: true));
  }

  Future<void> _markMessagesAsRead(List<QueryDocumentSnapshot> messages) async {
    final batch = FirebaseFirestore.instance.batch();
    bool hasUnread = false;

    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderId'] != currentUser!.uid && data['read'] == false) {
        batch.update(doc.reference, {'read': true});
        hasUnread = true;
      }
    }

    if (hasUnread) {
      await batch.commit();
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatLastSeen(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'last seen today at $hour:$minute';
    }
    return 'last seen ${date.day}/${date.month} at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    // Guard: only allow the chat UI if this pair's friend_requests doc is 'accepted'
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(_chatId)
          .snapshots(),
      builder: (context, friendSnapshot) {
        if (friendSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kCoral)),
          );
        }

        final isFriend = friendSnapshot.hasData &&
            friendSnapshot.data!.exists &&
            (friendSnapshot.data!.data() as Map<String, dynamic>)['status'] ==
                'accepted';

        if (!isFriend) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.otherUserName)),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You need to be friends to chat with this person.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return _buildChatUI(context);
      },
    );
  }

  Widget _buildChatUI(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.otherUserName),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.otherUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final isOnline = data['isOnline'] as bool? ?? false;

                return Text(
                  isOnline ? 'Online' : _formatLastSeen(data['lastSeen']),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: isOnline ? Colors.greenAccent : Colors.white70,
                  ),
                );
              },
            ),
          ],
        ),
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
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Say hello to ${widget.otherUserName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead(messages);
                });

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index];
                    final msgData = data.data() as Map<String, dynamic>;
                    final isMe = msgData['senderId'] == currentUser!.uid;
                    final isRead = msgData['read'] as bool? ?? false;

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
                          color: isMe ? kCoral : colors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msgData['text'] as String,
                              style: TextStyle(
                                color: isMe ? Colors.white : colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTimestamp(msgData['timestamp']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white70
                                        : colors.textSecondary,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    isRead ? Icons.done_all : Icons.done,
                                    size: 14,
                                    color: isRead
                                        ? Colors.lightBlueAccent
                                        : Colors.white70,
                                  ),
                                ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      hintStyle: TextStyle(color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surface,
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
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
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