import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/family_invitation.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  AgeGroup _selectedAgeGroup = AgeGroup.adult;

  FamilyInvitation? _invitation;

  bool _checkingCode = false;
  bool _joining = false;

  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Enter an invitation code';
      });
      return;
    }

    setState(() {
      _checkingCode = true;
      _errorMessage = null;
      _invitation = null;
    });

    try {
      final invitation = await AppDependencies.familyAccessRepository
          .getInvitation(_codeController.text);

      if (!mounted) return;

      if (invitation == null) {
        setState(() {
          _errorMessage = 'this invitation code is invalid';
        });
        return;
      }

      if (!invitation.isActive) {
        setState(() {
          _errorMessage = 'this invitation is no longer active';
        });
        return;
      }

      if (invitation.expiresAt.isBefore(DateTime.now().toUtc())) {
        setState(() {
          _errorMessage = 'this invitation is expirer';
        });
        return;
      }

      setState(() {
        _invitation = invitation;
      });
    } catch (_) {
      setState(() {
        _errorMessage = "we couldn;t verify the invitation. pleaste try again";
      });
    } finally {
      if (mounted) {
        setState(() => _checkingCode = false);
      }
    }
  }

  Future<void> _joinFamily() async {
    if (!_formKey.currentState!.validate()) return;

    if (_invitation == null) {
      setState(() {
        _errorMessage = 'Check the invitation code first.';
      });
      return;
    }

    setState(() {
      _joining = true;
      _errorMessage = null;
    });

    try {
      await AppDependencies.familyAccessRepository.joinFamily(
        code: _codeController.text,
        displayName: _nameController.text,
        role: FamilyRole.child,
        ageGroup: _selectedAgeGroup,
      );

      if (!mounted) return;

      context.go('/family-setup');
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join your family',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),

                Text(
                  'Enter the invitation code shared by your family.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Invitation code',
                    suffixIcon: IconButton(
                      onPressed: _checkingCode ? null : _checkCode,
                      icon: _checkingCode
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                    ),
                  ),
                ),

                if (_invitation != null) ...[
                  const SizedBox(height: 16),

                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('You are joining'),
                              const SizedBox(height: 4),
                              Text(
                                _invitation!.familyName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your name.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                const AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.verified_user_outlined),
                    title: Text('Role confirmed by the family admin'),
                    subtitle: Text(
                      'New members join with limited access. The family admin '
                      'can grant adult access after confirming who joined.',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<AgeGroup>(
                  initialValue: _selectedAgeGroup,
                  decoration: const InputDecoration(labelText: 'Age group'),
                  items: AgeGroup.values.map((ageGroup) {
                    return DropdownMenuItem(
                      value: ageGroup,
                      child: Text(_ageGroupLabel(ageGroup)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedAgeGroup = value);
                    }
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                AppPrimaryButton(
                  label: 'Join Family Home',
                  isLoading: _joining,
                  onPressed: _joining ? null : _joinFamily,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ageGroupLabel(AgeGroup ageGroup) {
    return switch (ageGroup) {
      AgeGroup.child => 'Child',
      AgeGroup.teen => 'Teen',
      AgeGroup.adult => 'Adult',
      AgeGroup.senior => 'Senior',
    };
  }
}
