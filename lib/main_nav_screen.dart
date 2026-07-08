import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'home_screen.dart';
import 'discover_users_screen.dart';
import 'my_friends_screen.dart';
import 'profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateToTab: goToTab),
      const DiscoverUsersScreen(),
      const MyFriendsScreen(),
      const ProfileScreen(),
    ];
  }

  void goToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final colors = AppColors.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('friend_requests')
            .where('participants', arrayContains: currentUser?.uid)
            .snapshots(),
        builder: (context, reqSnapshot) {
          int pendingCount = 0;
          if (reqSnapshot.hasData) {
            pendingCount = reqSnapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'pending' && data['to'] == currentUser?.uid;
            }).length;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('messages')
                .where('participants', arrayContains: currentUser?.uid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, msgSnapshot) {
              int unreadCount = 0;
              if (msgSnapshot.hasData) {
                unreadCount = msgSnapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['senderId'] != currentUser?.uid;
                }).length;
              }

              return NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: goToTab,
                backgroundColor: colors.surface,
                indicatorColor: kCoral.withOpacity(0.15),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home, color: kCoral),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: _badgeIcon(Icons.search_outlined, pendingCount),
                    selectedIcon: _badgeIcon(Icons.search, pendingCount, color: kCoral),
                    label: 'Discover',
                  ),
                  NavigationDestination(
                    icon: _badgeIcon(Icons.chat_bubble_outline, unreadCount),
                    selectedIcon: _badgeIcon(Icons.chat_bubble, unreadCount, color: kCoral),
                    label: 'Friends',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person, color: kCoral),
                    label: 'Profile',
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _badgeIcon(IconData icon, int count, {Color? color}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: kCoral,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}