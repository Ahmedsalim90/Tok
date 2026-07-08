import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';

class DiscoverUsersScreen extends StatelessWidget {
  const DiscoverUsersScreen({super.key});

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
        title: const Text('Discover Users', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kCoral));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _EmptyState(colors: colors, title: 'No users yet', subtitle: 'Once other people sign up,\nyou\'ll see them here.');
          }

          final users = snapshot.data!.docs.where((doc) => doc['uid'] != currentUser?.uid).toList();

          if (users.isEmpty) {
            return _EmptyState(colors: colors, title: 'You\'re the only one here', subtitle: 'Invite a friend to sign up.');
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: users.map((userData) {
              final data = userData.data() as Map<String, dynamic>;
              final email = data['email'] as String;
              final displayName = (data['displayName'] as String?)?.trim();
              final name = (displayName != null && displayName.isNotEmpty) ? displayName : email.split('@').first;
              final isOnline = data['isOnline'] as bool? ?? false;
              final otherUid = userData['uid'] as String;
              final pairKey = _pairKey(currentUser!.uid, otherUid);

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('friend_requests').doc(pairKey).snapshots(),
                builder: (context, reqSnapshot) {
                  String status = 'none';
                  if (reqSnapshot.hasData && reqSnapshot.data!.exists) {
                    final reqData = reqSnapshot.data!.data() as Map<String, dynamic>;
                    final from = reqData['from'] as String;
                    final rawStatus = reqData['status'] as String;
                    if (rawStatus == 'accepted') {
                      status = 'accepted';
                    } else if (rawStatus == 'rejected') {
                      status = 'rejected';
                    } else if (rawStatus == 'pending') {
                      status = from == currentUser.uid ? 'pending_sent' : 'pending_received';
                    }
                  }

                  Widget trailingWidget;
                  switch (status) {
                    case 'accepted':
                      trailingWidget = const Icon(Icons.check_circle, color: Colors.green, size: 20);
                      break;
                    case 'pending_sent':
                      trailingWidget = Text('Request Sent', style: TextStyle(fontSize: 12, color: colors.textSecondary));
                      break;
                    case 'pending_received':
                      trailingWidget = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () {
                              FirebaseFirestore.instance.collection('friend_requests').doc(pairKey).update({
                                'status': 'accepted',
                                'acceptedSeenByRequester': false,
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.redAccent),
                            onPressed: () {
                              FirebaseFirestore.instance.collection('friend_requests').doc(pairKey).update({'status': 'rejected'});
                            },
                          ),
                        ],
                      );
                      break;
                    case 'rejected':
                      trailingWidget = Text('Declined', style: TextStyle(fontSize: 12, color: Colors.redAccent.withOpacity(0.8)));
                      break;
                    default:
                      trailingWidget = OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kCoral,
                          side: const BorderSide(color: kCoral),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: () {
                          FirebaseFirestore.instance.collection('friend_requests').doc(pairKey).set({
                            'from': currentUser.uid,
                            'to': otherUid,
                            'participants': [currentUser.uid, otherUid],
                            'status': 'pending',
                            'acceptedSeenByRequester': false,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                        },
                        child: const Text('Add Friend', style: TextStyle(fontSize: 12)),
                      );
                  }

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
                    title: Text(name, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                    subtitle: Text(email, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                    trailing: trailingWidget,
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppColors colors;
  final String title;
  final String subtitle;

  const _EmptyState({required this.colors, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.groups_outlined, color: kCoral, size: 34),
            ),
            const SizedBox(height: 18),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}