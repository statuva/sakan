import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';

import 'edit_profile_screen.dart';
import 'family_settings_screen.dart';
import 'my_reminders_screen.dart';
import 'notification_settings_screen.dart';
import 'preferences_screen.dart';
import 'privacy_settings_screen.dart';
import 'schedule_editor_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningOut = false;

  Future<void> _confirmSignOut() async {
    if (_isSigningOut) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Sign out of Sakan?'),
          content: const Text(
            'You will return to the sign-in screen. '
            'Your family, Moments, reminders, and history will stay saved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _signOut();
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      // Stop reminder notifications belonging to the previous account from
      // appearing after another family member signs in on the same phone.
      await AppDependencies.reminderNotificationService
          .cancelAllReminderNotifications();

      await AppDependencies.authRepository.signOut();

      if (!mounted) {
        return;
      }

      context.go('/sign-in');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSigningOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not sign you out. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No signed-in user')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return const Center(
              child: Text('We could not load your profile.'),
            );
          }

          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData =
              userSnapshot.data!.data() as Map<String, dynamic>?;

          final currentFamilyId = userData?['currentFamilyId'] as String?;

          if (currentFamilyId == null || currentFamilyId.trim().isEmpty) {
            return const Center(child: Text('No family selected.'));
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('families')
                .doc(currentFamilyId)
                .collection('members')
                .doc(user.uid)
                .snapshots(),
            builder: (context, memberSnapshot) {
              if (memberSnapshot.hasError) {
                return const Center(
                  child: Text('We could not load your family profile.'),
                );
              }

              if (!memberSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final memberData =
                  memberSnapshot.data!.data() as Map<String, dynamic>?;

              if (memberData == null) {
                return const Center(
                  child: Text('Your family membership was not found.'),
                );
              }

              final member = Member.fromMap(
                memberSnapshot.data!.id,
                memberData,
              );

              final isAdmin = member.role == FamilyRole.admin;

              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    112,
                  ),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 42,
                        child: Text(
                          member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      member.displayName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _ProfileTile(
                      icon: Icons.person_outline,
                      title: 'Personal Information',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
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
                            builder: (_) => const ScheduleEditorScreen(),
                          ),
                        );
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.checklist_rounded,
                      title: 'My Reminders',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyRemindersScreen(),
                          ),
                        );
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.favorite_outline,
                      title: 'Family Time Preferences',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PreferencesScreen(),
                          ),
                        );
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.notifications_none,
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
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy & AI',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacySettingsScreen(),
                          ),
                        );
                      },
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Administrator',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ProfileTile(
                        icon: Icons.family_restroom,
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
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed:
                          _isSigningOut ? null : _confirmSignOut,
                      icon: _isSigningOut
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context)
                                    .colorScheme
                                    .error,
                              ),
                            )
                          : const Icon(Icons.logout_rounded),
                      label: Text(
                        _isSigningOut
                            ? 'Signing out...'
                            : 'Sign out',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color:
                              Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
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
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
