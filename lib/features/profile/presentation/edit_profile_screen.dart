import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  CurrentFamilyContext? _familyContext;

  AgeGroup _selectedAgeGroup = AgeGroup.adult;

  String? _photoUrl;
  String? _errorMessage;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;

        _nameController.text = familyContext.member.displayName;

        _selectedAgeGroup = familyContext.member.ageGroup;

        _photoUrl = familyContext.member.photoUrl;

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'We could not load your profile. '
            'Check your connection and try again.';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await AppDependencies.profileRepository.updateProfile(
        familyId: familyContext.familyId,
        memberId: familyContext.userId,
        displayName: _nameController.text,
        ageGroup: _selectedAgeGroup,
        photoUrl: _photoUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'We could not save your profile. '
            'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showPhotoMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Profile photo upload will be added '
          'before the final release.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading your profile…'),
        ),
      );
    }

    if (_errorMessage != null && _familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: SafeArea(
          child: AppErrorState(message: _errorMessage!, onRetry: _loadProfile),
        ),
      );
    }

    final familyContext = _familyContext;

    if (familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const SafeArea(
          child: AppErrorState(message: 'Your profile could not be found.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: _photoUrl == null || _photoUrl!.isEmpty
                            ? null
                            : NetworkImage(_photoUrl!),
                        child: _photoUrl == null || _photoUrl!.isEmpty
                            ? Text(
                                _initials(familyContext.member.displayName),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 18,
                          child: IconButton(
                            tooltip: 'Change profile photo',
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _showPhotoMessage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your display name.';
                    }

                    if (value.trim().length < 2) {
                      return 'Name must contain at least 2 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<AgeGroup>(
                  initialValue: _selectedAgeGroup,
                  decoration: const InputDecoration(
                    labelText: 'Age Group',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  items: AgeGroup.values
                      .map(
                        (ageGroup) => DropdownMenuItem(
                          value: ageGroup,
                          child: Text(_ageGroupLabel(ageGroup)),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _selectedAgeGroup = value;
                          });
                        },
                ),

                const SizedBox(height: AppSpacing.xl),

                AppCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.family_restroom_outlined),
                        title: const Text('Family Relationship'),
                        subtitle: Text(
                          _relationshipLabel(familyContext.member.relationship),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                        title: const Text('Permission Role'),
                        subtitle: Text(_roleLabel(familyContext.member.role)),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),

                AppPrimaryButton(
                  label: 'Save Changes',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _ageGroupLabel(AgeGroup ageGroup) {
    return switch (ageGroup) {
      AgeGroup.child => 'Child',
      AgeGroup.teen => 'Teen',
      AgeGroup.adult => 'Adult',
      AgeGroup.senior => 'Senior',
    };
  }

  String _relationshipLabel(FamilyRelationship relationship) {
    return switch (relationship) {
      FamilyRelationship.parent => 'Parent',
      FamilyRelationship.child => 'Child',
      FamilyRelationship.grandparent => 'Grandparent',
      FamilyRelationship.sibling => 'Sibling',
      FamilyRelationship.guardian => 'Guardian',
      FamilyRelationship.relative => 'Relative',
      FamilyRelationship.other => 'Other',
    };
  }

  String _roleLabel(FamilyRole role) {
    return switch (role) {
      FamilyRole.admin => 'Family Admin',
      FamilyRole.adult => 'Adult Member',
      FamilyRole.child => 'Child Member',
    };
  }
}
