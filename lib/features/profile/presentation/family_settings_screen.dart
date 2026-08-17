import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class FamilySettingsScreen extends StatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  State<FamilySettingsScreen> createState() =>
      _FamilySettingsScreenState();
}

class _FamilySettingsScreenState
    extends State<FamilySettingsScreen> {
  final _familyNameController =
      TextEditingController(
    text: 'Al Mansoori Family',
  );

  bool _allowInvitations = true;

  final List<_FamilyMember> _members = [
    const _FamilyMember(
      name: 'Rahma',
      role: 'Admin',
    ),
    const _FamilyMember(
      name: 'Sara',
      role: 'Child',
    ),
    const _FamilyMember(
      name: 'Ahmed',
      role: 'Adult',
    ),
  ];

  @override
  void dispose() {
    _familyNameController.dispose();
    super.dispose();
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Family settings saved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Family Settings',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Text(
                'Family Information',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              TextField(
                controller:
                    _familyNameController,
                decoration:
                    const InputDecoration(
                  labelText: 'Family Name',
                ),
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),

              AppCard(
                child: ListTile(
                  leading: const Icon(
                    Icons.key,
                  ),
                  title:
                      const Text('Invitation Code'),
                  subtitle:
                      const Text('AB7K2M9Q'),
                  trailing: IconButton(
                    icon:
                        const Icon(Icons.copy),
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Invitation code copied.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),

              SwitchListTile(
                title: const Text(
                  'Allow New Members',
                ),
                subtitle: const Text(
                  'Disable this to stop new people from joining using the invitation code.',
                ),
                value: _allowInvitations,
                onChanged: (value) {
                  setState(() {
                    _allowInvitations = value;
                  });
                },
              ),

              const SizedBox(
                height: AppSpacing.xl,
              ),

              Text(
                'Family Members',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              ..._members.map(
                (member) => Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: AppSpacing.sm,
                  ),
                  child: AppCard(
                    child: ListTile(
                      leading:
                          const CircleAvatar(
                        child: Icon(
                          Icons.person,
                        ),
                      ),
                      title: Text(
                        member.name,
                      ),
                      subtitle:
                          Text(member.role),
                      trailing:
                          PopupMenuButton(
                        itemBuilder:
                            (context) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              'Remove Member',
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value ==
                              'remove') {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${member.name} removed (demo).',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: AppSpacing.xxl,
              ),

              AppPrimaryButton(
                label: 'Save Family Settings',
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyMember {
  const _FamilyMember({
    required this.name,
    required this.role,
  });

  final String name;
  final String role;
}