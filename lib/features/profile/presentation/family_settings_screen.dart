import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

class FamilySettingsScreen extends StatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  State<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends State<FamilySettingsScreen> {
  final _familyNameController = TextEditingController();

  CurrentFamilyContext? _familyContext;

  Stream<Family?>? _familyStream;
  Stream<List<Member>>? _membersStream;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadFamily() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (!familyContext.isAdmin) {
        throw StateError('Only the family admin can open this page.');
      }

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;

        _familyNameController.text = familyContext.family.name;

        _familyStream = AppDependencies.currentFamilyService.watchCurrentFamily(
          familyContext.familyId,
        );

        _membersStream = AppDependencies.currentFamilyService
            .watchFamilyMembers(familyContext.familyId);

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message
            : 'We could not load the family settings.';
      });
    }
  }

  Future<void> _saveFamilyName() async {
    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    final familyName = _familyNameController.text.trim();

    if (familyName.length < 2) {
      _showMessage('Enter a valid family name.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await AppDependencies.profileRepository.updateFamilyName(
        familyId: familyContext.familyId,
        familyName: familyName,
      );

      if (!mounted) return;

      _showMessage('Family settings saved.');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'We could not save the family settings.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _copyInvitationCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;

    _showMessage('Invitation code copied.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading family settings…'),
        ),
      );
    }

    if (_familyContext == null ||
        _familyStream == null ||
        _membersStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Settings')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'Family settings are unavailable.',
            onRetry: _loadFamily,
          ),
        ),
      );
    }

    return StreamBuilder<Family?>(
      stream: _familyStream,
      builder: (context, familySnapshot) {
        if (familySnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Family Settings')),
            body: SafeArea(
              child: AppErrorState(
                message: 'We could not load the family.',
                onRetry: _loadFamily,
              ),
            ),
          );
        }

        final family = familySnapshot.data;

        if (family == null) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading family information…'),
            ),
          );
        }

        final invitationCode = family.activeInvitationCode?.trim();

        return StreamBuilder<List<Member>>(
          stream: _membersStream,
          builder: (context, memberSnapshot) {
            if (memberSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Family Settings')),
                body: SafeArea(
                  child: AppErrorState(
                    message: 'We could not load the family members.',
                    onRetry: _loadFamily,
                  ),
                ),
              );
            }

            final members = memberSnapshot.data ?? <Member>[];

            return Scaffold(
              appBar: AppBar(title: const Text('Family Settings')),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    Text(
                      'Family Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    TextFormField(
                      controller: _familyNameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Family Name',
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.key_outlined),
                        title: const Text('Invitation Code'),
                        subtitle: SelectableText(
                          invitationCode == null || invitationCode.isEmpty
                              ? 'Unavailable'
                              : invitationCode,
                        ),
                        trailing: IconButton(
                          tooltip: 'Copy code',
                          onPressed:
                              invitationCode == null || invitationCode.isEmpty
                              ? null
                              : () {
                                  _copyInvitationCode(invitationCode);
                                },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      'Family Members',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    if (members.isEmpty)
                      const AppCard(
                        child: Text('No family members were found.'),
                      )
                    else
                      ...members.map(
                        (member) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text(
                                  member.displayName.isEmpty
                                      ? '?'
                                      : member.displayName[0].toUpperCase(),
                                ),
                              ),
                              title: Text(member.displayName),
                              subtitle: Text(
                                '${_roleLabel(member.role)} · '
                                '${_relationshipLabel(member.relationship)}',
                              ),
                            ),
                          ),
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
                      label: 'Save Family Settings',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _saveFamilyName,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _roleLabel(FamilyRole role) {
    return switch (role) {
      FamilyRole.admin => 'Admin',
      FamilyRole.adult => 'Adult',
      FamilyRole.child => 'Child',
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
}
