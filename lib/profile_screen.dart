import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          String name = user?.email?.split('@').first ?? 'User';
          String email = user?.email ?? '';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final displayName = (data['displayName'] as String?)?.trim();
            if (displayName != null && displayName.isNotEmpty) {
              name = displayName;
            }
            email = (data['email'] as String?) ?? email;
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: kCoral,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Dark mode toggle
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark ||
                        (mode == ThemeMode.system &&
                            MediaQuery.platformBrightnessOf(context) ==
                                Brightness.dark);

                    return SwitchListTile(
                      value: isDark,
                      onChanged: (value) {
                        themeNotifier.value =
                        value ? ThemeMode.dark : ThemeMode.light;
                      },
                      activeColor: kCoral,
                      title: Text(
                        'Dark mode',
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      secondary: Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: kCoral,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}