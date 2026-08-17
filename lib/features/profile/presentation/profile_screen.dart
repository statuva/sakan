import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'preferences_screen.dart';
import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'family_settings_screen.dart';
import 'hub_settings_screen.dart';
import 'schedule_editor_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/member.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

if (user == null) {
  return const Scaffold(
    body: Center(
      child: Text('No signed in user'),
    ),
  );
}

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      
      body: FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get(),
  builder: (context, userSnapshot) {
    if (!userSnapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final currentFamilyId =
        (userSnapshot.data!.data()
            as Map<String, dynamic>)['currentFamilyId'];

    if (currentFamilyId == null) {
      return const Center(
        child: Text(
          'No family selected.',
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .doc(currentFamilyId)
          .collection('members')
          .doc(user.uid)
          .snapshots(),
      builder: (context, memberSnapshot) {
        if (!memberSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final member = Member.fromMap(
          memberSnapshot.data!.id,
          memberSnapshot.data!.data()
              as Map<String, dynamic>,
        );

        final isAdmin =
            member.role == FamilyRole.admin;

        return SafeArea(
          child: ListView(
            padding:
                const EdgeInsets.all(AppSpacing.xl),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 42,
                  child: Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0]
                            .toUpperCase()
                        : '?',
                  ),
                ),
              ),

              const SizedBox(
                  height: AppSpacing.md),

              Text(
                member.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium,
              ),

              const SizedBox(height: 4),

              Text(
                user.email ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),

              const SizedBox(
                  height: AppSpacing.xl),

              _ProfileTile(
                icon: Icons.person_outline,
                title: 'Personal Information',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const EditProfileScreen(),
                    ),
                  );
                },
              ),

              _ProfileTile(
                icon: Icons.schedule,
                title: 'My Schedule',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const ScheduleEditorScreen(),
                    ),
                  );
                },
              ),

              _ProfileTile(
                icon: Icons.favorite_outline,
                title:
                    'Family Time Preferences',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PreferencesScreen(),
                    ),
                  );
                },
              ),

              _ProfileTile(
                icon:
                    Icons.notifications_none,
                title: 'Notifications',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),

              _ProfileTile(
                icon:
                    Icons.privacy_tip_outlined,
                title: 'Privacy & AI',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PrivacySettingsScreen(),
                    ),
                  );
                },
              ),

              if (isAdmin) ...[
                const SizedBox(
                    height: AppSpacing.lg),

                const Divider(),

                const SizedBox(
                    height: AppSpacing.md),

                Text(
                  'Administrator',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),

                const SizedBox(
                    height: AppSpacing.md),

                _ProfileTile(
                  icon:
                      Icons.family_restroom,
                  title: 'Family Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const FamilySettingsScreen(),
                      ),
                    );
                  },
                ),

                _ProfileTile(
                  icon: Icons.nfc,
                  title: 'Hub Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const HubSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  },
)
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing:
            const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}