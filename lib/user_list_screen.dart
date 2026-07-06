import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';

class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: kBackground,
        centerTitle: true,
        title: const Text(
          'TOK',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingState();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyState(
              icon: Icons.groups_outlined,
              title: 'No users yet',
              subtitle: 'Once other people sign up,\nyou\'ll see them here.',
            );
          }

          final users = snapshot.data!.docs
              .where((doc) => doc['uid'] != currentUser?.uid)
              .toList();

          if (users.isEmpty) {
            return const _EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'You\'re the only one here',
              subtitle: 'Invite a friend to sign up\nand start chatting.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 72,
              color: kFieldLine,
            ),
            itemBuilder: (context, index) {
              final userData = users[index];
              final email = userData['email'] as String;

              return ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: kCoral,
                  child: Text(
                    email[0].toUpperCase(),
                    style: const TextStyle(
                      color: kBackground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(
                  email,
                  style: const TextStyle(
                    color: kNavy,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: kSubtitleGray,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        otherUserId: userData['uid'] as String,
                        otherUserEmail: email,
                      ),
                    ),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: kCoral),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

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
              decoration: BoxDecoration(
                color: kCoral.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kCoral, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kSubtitleGray),
            ),
          ],
        ),
      ),
    );
  }
}