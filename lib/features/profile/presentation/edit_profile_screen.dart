import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  String _selectedAgeGroup = 'Adult';

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Temporary demo values.
    // These will come from Firebase next.
    _nameController.text = 'Sara';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    // Firebase save will be connected next.

    await Future.delayed(
      const Duration(milliseconds: 600),
    );

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Profile updated successfully.',
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
            AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      const CircleAvatar(
                        radius: 48,
                        child: Icon(
                          Icons.person,
                          size: 48,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 16,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: const Icon(
                              Icons.edit,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: AppSpacing.xl,
                ),

                TextFormField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Display Name',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter your name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: AppSpacing.md,
                ),

                DropdownButtonFormField<String>(
                  initialValue:
                      _selectedAgeGroup,
                  decoration:
                      const InputDecoration(
                    labelText: 'Age Group',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Child',
                      child: Text('Child'),
                    ),
                    DropdownMenuItem(
                      value: 'Teen',
                      child: Text('Teen'),
                    ),
                    DropdownMenuItem(
                      value: 'Adult',
                      child: Text('Adult'),
                    ),
                    DropdownMenuItem(
                      value: 'Senior',
                      child: Text('Senior'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedAgeGroup = value;
                    });
                  },
                ),

                const SizedBox(
                  height: AppSpacing.xl,
                ),

                const ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: Icon(
                    Icons.family_restroom,
                  ),
                  title: Text(
                    'Family Role',
                  ),
                  subtitle: Text(
                    'Managed by the family administrator',
                  ),
                ),

                const SizedBox(
                  height: AppSpacing.xxl,
                ),

                AppPrimaryButton(
                  label: 'Save Changes',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}