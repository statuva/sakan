import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';
import 'package:sakan/shared/services/uae_rhythm_templates.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

import 'widgets/members_setup_step.dart';
import 'widgets/rhythm_configuration_step.dart';
import 'widgets/rhythm_library_step.dart';
import 'widgets/setup_review_step.dart';

class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  int _currentStep = 0;
  final Set<String> _selectedTemplateIds = <String>{};
  List<RhythmSetupDraft> _rhythmDrafts = <RhythmSetupDraft>[];

  String? _familyId;
  Stream<Family?>? _familyStream;
  Stream<List<Member>>? _membersStream;

  bool _isLoadingFamilyId = true;
  bool _isSaving = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _loadCurrentFamilyId();
  }

  Future<void> _loadCurrentFamilyId() async {
    if (mounted) {
      setState(() {
        _isLoadingFamilyId = true;
        _initializationError = null;
      });
    }

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        _redirectAfterBuild('/sign-in');
        return;
      }

      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final currentFamilyId =
          userDocument.data()?['currentFamilyId'] as String?;

      if (currentFamilyId == null || currentFamilyId.trim().isEmpty) {
        _redirectAfterBuild('/family-access');
        return;
      }

      final familyStream = AppDependencies.familySetupRepository.watchFamily(
        currentFamilyId,
      );
      final membersStream = AppDependencies.familySetupRepository.watchMembers(
        currentFamilyId,
      );

      if (!mounted) return;

      setState(() {
        _familyId = currentFamilyId;
        _familyStream = familyStream;
        _membersStream = membersStream;
        _isLoadingFamilyId = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingFamilyId = false;
        _initializationError =
            'We could not load your family setup. Check your connection and try again.';
      });
    }
  }

  void _redirectAfterBuild(String location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(location);
    });
  }

  void _nextStep() {
    if (_currentStep >= 3) return;
    setState(() => _currentStep++);
  }

  void _previousStep() {
    if (_currentStep <= 0) return;
    setState(() => _currentStep--);
  }

  void _updateSelectedTemplates(Set<String> templateIds, List<Member> members) {
    final rebuiltDrafts = _buildRhythmDrafts(
      templateIds: templateIds,
      members: members,
    );

    setState(() {
      _selectedTemplateIds
        ..clear()
        ..addAll(templateIds);
      _rhythmDrafts = rebuiltDrafts;
    });
  }

  List<RhythmSetupDraft> _buildRhythmDrafts({
    required Set<String> templateIds,
    required List<Member> members,
  }) {
    final existingDrafts = <String, RhythmSetupDraft>{
      for (final draft in _rhythmDrafts) draft.templateId: draft,
    };

    final defaultParticipantIds = members
        .where((member) => member.isActive)
        .map((member) => member.id)
        .toList(growable: false);

    final now = DateTime.now();
    final rebuiltDrafts = <RhythmSetupDraft>[];

    for (final templateId in templateIds) {
      final existingDraft = existingDrafts[templateId];
      if (existingDraft != null) {
        rebuiltDrafts.add(existingDraft);
        continue;
      }

      final matchingTemplates = UaeRhythmTemplates.all
          .where((template) => template.id == templateId)
          .toList(growable: false);

      if (matchingTemplates.isEmpty) continue;

      final template = matchingTemplates.first;
      rebuiltDrafts.add(
        RhythmSetupDraft(
          templateId: template.id,
          title: template.title,
          description: template.description,
          category: template.category,
          expectedIntervalDays: template.defaultIntervalDays,
          importanceLevel: template.defaultImportanceLevel,
          expectedParticipantIds: defaultParticipantIds,
          nextOccurrenceAt: now.add(
            Duration(days: template.defaultIntervalDays),
          ),
        ),
      );
    }

    rebuiltDrafts.sort((a, b) => a.title.compareTo(b.title));
    return rebuiltDrafts;
  }

  void _updateRhythmDraft(int index, RhythmSetupDraft updatedDraft) {
    if (index < 0 || index >= _rhythmDrafts.length) return;
    setState(() => _rhythmDrafts[index] = updatedDraft);
  }

  void _addCustomRhythm(RhythmSetupDraft draft, List<Member> members) {
    final defaultParticipantIds = members
        .where((member) => member.isActive)
        .map((member) => member.id)
        .toList(growable: false);

    final resolvedDraft = draft.expectedParticipantIds.isEmpty
        ? draft.copyWith(expectedParticipantIds: defaultParticipantIds)
        : draft;

    setState(() {
      _selectedTemplateIds.add(resolvedDraft.templateId);
      _rhythmDrafts.removeWhere(
        (item) => item.templateId == resolvedDraft.templateId,
      );
      _rhythmDrafts.add(resolvedDraft);
      _rhythmDrafts.sort((a, b) => a.title.compareTo(b.title));
    });
  }

  void _removeCustomRhythm(String templateId) {
    setState(() {
      _selectedTemplateIds.remove(templateId);
      _rhythmDrafts.removeWhere((draft) => draft.templateId == templateId);
    });
  }

  Future<void> _updateMemberRelationship({
    required String familyId,
    required String memberId,
    required FamilyRelationship relationship,
  }) async {
    try {
      await AppDependencies.familySetupRepository.updateMemberRelationship(
        familyId: familyId,
        memberId: memberId,
        relationship: relationship,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('We could not update this family member. Please try again.');
    }
  }

  Future<void> _completeSetup({
    required String familyId,
    required List<Member> members,
  }) async {
    if (_isSaving) return;

    if (_rhythmDrafts.isEmpty) {
      _showMessage('Choose at least one family tradition.');
      return;
    }

    final activeMemberIds = members
        .where((member) => member.isActive)
        .map((member) => member.id)
        .toSet();

    if (activeMemberIds.isEmpty) {
      _showMessage('At least one active family member is required.');
      return;
    }

    for (final draft in _rhythmDrafts) {
      if (draft.expectedIntervalDays <= 0) {
        _showMessage('${draft.title} needs a valid frequency.');
        return;
      }
      if (draft.importanceLevel < 1 || draft.importanceLevel > 5) {
        _showMessage('${draft.title} needs a valid importance level.');
        return;
      }
      final validParticipants = draft.expectedParticipantIds
          .where(activeMemberIds.contains)
          .toList(growable: false);
      if (validParticipants.isEmpty) {
        _showMessage('Choose at least one participant for ${draft.title}.');
        return;
      }
    }

    final resolvedDrafts = _rhythmDrafts
        .map(
          (draft) => draft.copyWith(
            expectedParticipantIds: draft.expectedParticipantIds
                .where(activeMemberIds.contains)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);

    setState(() {
      _isSaving = true;
      _rhythmDrafts = resolvedDrafts;
    });

    try {
      await AppDependencies.familySetupRepository.completeSetup(
        familyId: familyId,
        rhythms: resolvedDrafts,
      );

      if (!mounted) return;
      context.go('/home');
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'We could not save your family baseline. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Member? _findCurrentMember(List<Member> members) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return null;

    for (final member in members) {
      if (member.id == currentUserId) return member;
    }
    return null;
  }

  Widget _buildCurrentStep({
    required Family family,
    required String familyId,
    required List<Member> members,
  }) {
    switch (_currentStep) {
      case 0:
        return MembersSetupStep(
          family: family,
          members: members,
          onRelationshipChanged: (memberId, relationship) async {
            await _updateMemberRelationship(
              familyId: familyId,
              memberId: memberId,
              relationship: relationship,
            );
          },
          onContinue: _nextStep,
        );
      case 1:
        return RhythmLibraryStep(
          selectedTemplateIds: _selectedTemplateIds,
          customRhythms: _rhythmDrafts
              .where((draft) => draft.isCustom)
              .toList(growable: false),
          onSelectionChanged: (templateIds) {
            _updateSelectedTemplates(templateIds, members);
          },
          onCustomRhythmCreated: (draft) {
            _addCustomRhythm(draft, members);
          },
          onCustomRhythmRemoved: _removeCustomRhythm,
          onContinue: _nextStep,
          onBack: _previousStep,
        );
      case 2:
        return RhythmConfigurationStep(
          drafts: _rhythmDrafts,
          members: members,
          onDraftChanged: _updateRhythmDraft,
          onContinue: _nextStep,
          onBack: _previousStep,
        );
      case 3:
        return SetupReviewStep(
          family: family,
          members: members,
          rhythmDrafts: _rhythmDrafts,
          isSaving: _isSaving,
          onBack: _previousStep,
          onComplete: () {
            _completeSetup(familyId: familyId, members: members);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFamilyId) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading your family home...'),
        ),
      );
    }

    if (_initializationError != null) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: _initializationError!,
            onRetry: _loadCurrentFamilyId,
          ),
        ),
      );
    }

    final familyId = _familyId;
    final familyStream = _familyStream;
    final membersStream = _membersStream;

    if (familyId == null || familyStream == null || membersStream == null) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorState(
            message: 'Your selected family could not be found.',
            onRetry: _loadCurrentFamilyId,
          ),
        ),
      );
    }

    return StreamBuilder<Family?>(
      stream: familyStream,
      builder: (context, familySnapshot) {
        if (familySnapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: AppErrorState(
                message: 'We could not load your family details.',
                onRetry: _loadCurrentFamilyId,
              ),
            ),
          );
        }

        if (familySnapshot.connectionState == ConnectionState.waiting &&
            !familySnapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading family details...'),
            ),
          );
        }

        final family = familySnapshot.data;
        if (family == null) {
          return Scaffold(
            body: SafeArea(
              child: AppErrorState(
                message: 'This family is no longer available.',
                onRetry: _loadCurrentFamilyId,
              ),
            ),
          );
        }

        if (family.setupComplete) {
          _redirectAfterBuild('/home');
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Opening your family home...'),
            ),
          );
        }

        return StreamBuilder<List<Member>>(
          stream: membersStream,
          builder: (context, membersSnapshot) {
            if (membersSnapshot.hasError) {
              return Scaffold(
                body: SafeArea(
                  child: AppErrorState(
                    message: 'We could not load your family members.',
                    onRetry: _loadCurrentFamilyId,
                  ),
                ),
              );
            }

            if (membersSnapshot.connectionState == ConnectionState.waiting &&
                !membersSnapshot.hasData) {
              return const Scaffold(
                body: SafeArea(
                  child: AppLoadingState(message: 'Loading family members...'),
                ),
              );
            }

            final members = membersSnapshot.data ?? <Member>[];
            final currentMember = _findCurrentMember(members);

            if (currentMember == null) {
              return const Scaffold(
                body: SafeArea(
                  child: AppLoadingState(
                    message: 'Preparing your family membership...',
                  ),
                ),
              );
            }

            if (currentMember.role != FamilyRole.admin) {
              return Scaffold(
                appBar: AppBar(title: const Text('Family Setup')),
                body: SafeArea(
                  child: _WaitingForFamilyAdmin(familyName: family.name),
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(title: const Text('Family Setup')),
              body: SafeArea(
                child: Column(
                  children: [
                    _SetupProgress(currentStep: _currentStep),
                    if (_isSaving) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: _isSaving,
                        child: _buildCurrentStep(
                          family: family,
                          familyId: familyId,
                          members: members,
                        ),
                      ),
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
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['Members', 'Traditions', 'Configure', 'Review'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${currentStep + 1} of 4',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (currentStep + 1) / 4),
          const SizedBox(height: 8),
          Text(
            labels[currentStep],
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _WaitingForFamilyAdmin extends StatelessWidget {
  const _WaitingForFamilyAdmin({required this.familyName});

  final String familyName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Your family setup is in progress',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'You have joined $familyName. The family admin is choosing the traditions and preferences for your family home.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'This page will update automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
