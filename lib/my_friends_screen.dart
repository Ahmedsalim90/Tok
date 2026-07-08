import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'chat_screen.dart';

class MyFriendsScreen extends StatelessWidget {
  const MyFriendsScreen({super.key});

  String _pairKey(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('My Friends', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('friend_requests')
            .where('participants', arrayContains: currentUser?.uid)
            .where('status', isEqualTo: 'accepted')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kCoral));
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: kCoral.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.chat_bubble_outline, color: kCoral, size: 34),
                    ),
                    const SizedBox(height: 18),
                    Text('No friends yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      'Go to Discover Users to send\nsome friend requests.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          final friendUids = requests.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants']);
            return participants.firstWhere((id) => id != currentUser?.uid);
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: friendUids.length,
            separatorBuilder: (context, index) => Divider(height: 1, indent: 72, color: colors.fieldLine),
            itemBuilder: (context, index) {
              final otherUid = friendUids[index];
              final pairKey = _pairKey(currentUser!.uid, otherUid);

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(otherUid).snapshots(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final email = userData['email'] as String;
                  final displayName = (userData['displayName'] as String?)?.trim();
                  final name = (displayName != null && displayName.isNotEmpty) ? displayName : email.split('@').first;
                  final isOnline = userData['isOnline'] as bool? ?? false;

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('chats').doc(pairKey).snapshots(),
                    builder: (context, chatSnapshot) {
                      String? lastMessage;
                      DateTime? lastTime;
                      if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                        final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                        lastMessage = chatData['lastMessage'] as String?;
                        final ts = chatData['lastMessageTime'] as Timestamp?;
                        lastTime = ts?.toDate();
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .doc(pairKey)
                            .collection('messages')
                            .where('senderId', isEqualTo: otherUid)
                            .where('read', isEqualTo: false)
                            .snapshots(),
                        builder: (context, unreadSnapshot) {
                          final unreadCount = unreadSnapshot.hasData ? unreadSnapshot.data!.docs.length : 0;
                          final isUnread = unreadCount > 0;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: kCoral,
                                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                                if (isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: colors.background, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage ?? 'Say hello 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isUnread ? colors.textPrimary : colors.textSecondary,
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (lastTime != null)
                                  Text(
                                    '${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(fontSize: 10, color: colors.textSecondary),
                                  ),
                                const SizedBox(height: 4),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: kCoral, borderRadius: BorderRadius.circular(10)),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    otherUserId: otherUid,
                                    otherUserEmail: email,
                                    otherUserName: name,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}