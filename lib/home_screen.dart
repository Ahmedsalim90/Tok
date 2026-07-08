import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'theme.dart';
import 'chat_screen.dart';

class _ActivityItem {
  final String type; // 'message' | 'request' | 'accepted'
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? otherUserId;
  final DocumentReference? sourceRef;

  _ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.otherUserId,
    this.sourceRef,
  });
}

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigateToTab;
  const HomeScreen({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final colors = AppColors.of(context);
    final firestore = FirebaseFirestore.instance;

    final messagesStream = firestore
        .collectionGroup('messages')
        .where('participants', arrayContains: currentUser?.uid)
        .where('read', isEqualTo: false)
        .snapshots();

    final requestsStream = firestore
        .collection('friend_requests')
        .where('participants', arrayContains: currentUser?.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    final acceptedStream = firestore
        .collection('friend_requests')
        .where('participants', arrayContains: currentUser?.uid)
        .where('status', isEqualTo: 'accepted')
        .where('acceptedSeenByRequester', isEqualTo: false)
        .snapshots();

    final friendsCountStream = firestore
        .collection('friend_requests')
        .where('participants', arrayContains: currentUser?.uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots();

    final allMessagesStream = firestore
        .collectionGroup('messages')
        .where('participants', arrayContains: currentUser?.uid)
        .snapshots();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 12,
        title: const Row(
          children: [
            SizedBox(width: 34, height: 34, child: _AppBarLogo()),
            SizedBox(width: 10),
            Text('TOK', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: friendsCountStream,
                    builder: (context, snap) => _StatCard(
                      icon: Icons.people_outline,
                      value: snap.hasData ? snap.data!.docs.length : 0,
                      label: 'FRIENDS',
                      colors: colors,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: allMessagesStream,
                    builder: (context, snap) => _StatCard(
                      icon: Icons.chat_bubble_outline,
                      value: snap.hasData ? snap.data!.docs.length : 0,
                      label: 'MESSAGES',
                      colors: colors,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: messagesStream,
                    builder: (context, snap) {
                      final unread = snap.hasData
                          ? snap.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['senderId'] != currentUser?.uid;
                      }).length
                          : 0;
                      return _StatCard(
                        icon: Icons.mark_email_unread_outlined,
                        value: unread,
                        label: 'UNREAD',
                        colors: colors,
                        highlight: unread > 0,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: requestsStream,
                    builder: (context, snap) {
                      final count = snap.hasData
                          ? snap.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['to'] == currentUser?.uid;
                      }).length
                          : 0;
                      return _QuickCard(
                        icon: Icons.search,
                        label: 'Discover Users',
                        badge: count,
                        colors: colors,
                        onTap: () => onNavigateToTab(1),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: messagesStream,
                    builder: (context, snap) {
                      final count = snap.hasData
                          ? snap.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['senderId'] != currentUser?.uid;
                      }).length
                          : 0;
                      return _QuickCard(
                        icon: Icons.chat_bubble,
                        label: 'My Friends',
                        badge: count,
                        colors: colors,
                        onTap: () => onNavigateToTab(2),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Recent Activity',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          ),
          StreamBuilder<List<QuerySnapshot>>(
            stream: CombineLatestStream.list([messagesStream, requestsStream, acceptedStream]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: kCoral)),
                );
              }

              final msgDocs = snapshot.data![0].docs;
              final reqDocs = snapshot.data![1].docs;
              final accDocs = snapshot.data![2].docs;

              final items = <_ActivityItem>[];

              final Map<String, _ActivityItem> latestPerChat = {};
              for (final doc in msgDocs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['senderId'] == currentUser?.uid) continue;

                final participants = List<String>.from(data['participants'] ?? []);
                final otherId = participants.firstWhere(
                      (id) => id != currentUser?.uid,
                  orElse: () => '',
                );
                if (otherId.isEmpty) continue;

                final ts = data['timestamp'] as Timestamp?;
                if (ts == null) continue;

                final existing = latestPerChat[otherId];
                if (existing == null || ts.toDate().isAfter(existing.timestamp)) {
                  latestPerChat[otherId] = _ActivityItem(
                    type: 'message',
                    title: 'New message',
                    subtitle: data['text'] as String? ?? '',
                    timestamp: ts.toDate(),
                    otherUserId: otherId,
                  );
                }
              }
              items.addAll(latestPerChat.values);

              for (final doc in reqDocs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['to'] != currentUser?.uid) continue;
                final ts = data['timestamp'] as Timestamp?;
                items.add(_ActivityItem(
                  type: 'request',
                  title: 'Friend request',
                  subtitle: 'Tap to respond',
                  timestamp: ts?.toDate() ?? DateTime.now(),
                  otherUserId: data['from'] as String?,
                  sourceRef: doc.reference,
                ));
              }

              for (final doc in accDocs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['from'] != currentUser?.uid) continue;
                final ts = data['timestamp'] as Timestamp?;
                items.add(_ActivityItem(
                  type: 'accepted',
                  title: 'Request accepted',
                  subtitle: 'You are now friends',
                  timestamp: ts?.toDate() ?? DateTime.now(),
                  otherUserId: data['to'] as String?,
                  sourceRef: doc.reference,
                ));
              }

              items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              final capped = items.take(10).toList();

              if (capped.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
                  child: Center(
                    child: Text(
                      'Nothing new right now',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  ),
                );
              }

              return Column(
                children: capped.map((item) {
                  return _ActivityTile(
                    item: item,
                    colors: colors,
                    onTap: () async {
                      if (item.type == 'message' && item.otherUserId != null) {
                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(item.otherUserId)
                            .get();
                        final userData = userDoc.data();
                        if (userData == null || !context.mounted) return;
                        final email = userData['email'] as String;
                        final displayName = (userData['displayName'] as String?)?.trim();
                        final name = (displayName != null && displayName.isNotEmpty)
                            ? displayName
                            : email.split('@').first;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUserId: item.otherUserId!,
                              otherUserEmail: email,
                              otherUserName: name,
                            ),
                          ),
                        );
                      } else if (item.type == 'request') {
                        onNavigateToTab(1);
                      } else if (item.type == 'accepted') {
                        item.sourceRef?.update({'acceptedSeenByRequester': true});
                        onNavigateToTab(2);
                      }
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final AppColors colors;
  final bool highlight;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, size: 18, color: highlight ? kCoral : colors.textSecondary),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: highlight ? kCoral : colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final AppColors colors;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.badge,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: kCoral, size: 20),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: kCoral, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;
  final AppColors colors;
  final VoidCallback onTap;

  const _ActivityTile({required this.item, required this.colors, required this.onTap});

  Color get _iconBg {
    switch (item.type) {
      case 'message':
        return kCoral;
      case 'accepted':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData get _icon {
    switch (item.type) {
      case 'message':
        return Icons.chat_bubble;
      case 'accepted':
        return Icons.check;
      default:
        return Icons.person;
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: item.otherUserId != null
          ? FirebaseFirestore.instance.collection('users').doc(item.otherUserId).get()
          : null,
      builder: (context, snap) {
        String name = '...';
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          final displayName = (data['displayName'] as String?)?.trim();
          final email = data['email'] as String? ?? '';
          name = (displayName != null && displayName.isNotEmpty) ? displayName : email.split('@').first;
        }

        final titleText = item.type == 'message'
            ? 'New message from $name'
            : item.type == 'request'
            ? '$name sent you a friend request'
            : '$name accepted your request';

        return ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: _iconBg,
            child: Icon(_icon, color: Colors.white, size: 18),
          ),
          title: Text(
            titleText,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          subtitle: Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
          trailing: Text(
            _relativeTime(item.timestamp),
            style: TextStyle(fontSize: 10, color: colors.textSecondary),
          ),
        );
      },
    );
  }
}

class _AppBarLogo extends StatelessWidget {
  const _AppBarLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: kCoral, borderRadius: BorderRadius.circular(9)),
      padding: const EdgeInsets.all(6),
      child: CustomPaint(painter: _MiniBubblePainter()),
    );
  }
}

class _MiniBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 48;
    final scaleY = size.height / 48;
    final bubblePaint = Paint()..color = Colors.white;
    final dotPaint = Paint()..color = kCoral;

    final path = Path();
    path.moveTo(6 * scaleX, 12 * scaleY);
    path.cubicTo(6 * scaleX, 8.7 * scaleY, 8.7 * scaleX, 6 * scaleY, 12 * scaleX, 6 * scaleY);
    path.lineTo(36 * scaleX, 6 * scaleY);
    path.cubicTo(39.3 * scaleX, 6 * scaleY, 42 * scaleX, 8.7 * scaleY, 42 * scaleX, 12 * scaleY);
    path.lineTo(42 * scaleX, 28 * scaleY);
    path.cubicTo(42 * scaleX, 31.3 * scaleY, 39.3 * scaleX, 34 * scaleY, 36 * scaleX, 34 * scaleY);
    path.lineTo(16 * scaleX, 34 * scaleY);
    path.lineTo(8 * scaleX, 42 * scaleY);
    path.lineTo(8 * scaleX, 34 * scaleY);
    path.cubicTo(6.9 * scaleX, 34 * scaleY, 6 * scaleX, 33.1 * scaleY, 6 * scaleX, 32 * scaleY);
    path.close();

    canvas.drawPath(path, bubblePaint);
    canvas.drawCircle(Offset(17 * scaleX, 20 * scaleY), 3 * scaleX, dotPaint);
    canvas.drawCircle(Offset(24 * scaleX, 20 * scaleY), 3 * scaleX, dotPaint);
    canvas.drawCircle(Offset(31 * scaleX, 20 * scaleY), 3 * scaleX, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniBubblePainter oldDelegate) => false;
}