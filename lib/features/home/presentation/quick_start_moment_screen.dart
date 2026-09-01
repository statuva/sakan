import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/controls/app_pill_segmented_control.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../moments/presentation/live_moment_screen.dart';

class QuickStartMomentScreen extends StatefulWidget {
  const QuickStartMomentScreen({super.key});

  @override
  State<QuickStartMomentScreen> createState() => _QuickStartMomentScreenState();
}

class _QuickStartMomentScreenState extends State<QuickStartMomentScreen> {
  CurrentFamilyContext? _familyContext;
  Stream<List<FamilyMoment>>? _momentsStream;
  Stream<List<Member>>? _membersStream;

  bool _isLoading = true;
  bool _isStarting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (!familyContext.isAdult) {
        throw StateError(
          'Only an adult or family admin can start a shared Moment.',
        );
      }

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _momentsStream = AppDependencies.calendarRepository.watchMoments(
          familyId: familyContext.familyId,
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
            ? error.message.toString()
            : 'We could not prepare the quick-start flow.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Preparing your Family Moments…'),
        ),
      );
    }

    if (_familyContext == null ||
        _momentsStream == null ||
        _membersStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Start a Moment')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'Quick start is unavailable.',
            onRetry: _load,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Start a Moment')),
      body: SafeArea(
        child: StreamBuilder<List<Member>>(
          stream: _membersStream,
          builder: (context, memberSnapshot) {
            if (memberSnapshot.hasError) {
              return AppErrorState(
                message: 'We could not load the family members.',
                onRetry: _load,
              );
            }

            if (memberSnapshot.connectionState == ConnectionState.waiting &&
                !memberSnapshot.hasData) {
              return const AppLoadingState(message: 'Loading family members…');
            }

            final members =
                (memberSnapshot.data ?? <Member>[])
                    .where((member) => member.isActive)
                    .toList()
                  ..sort(
                    (first, second) =>
                        first.displayName.compareTo(second.displayName),
                  );

            return StreamBuilder<List<FamilyMoment>>(
              stream: _momentsStream,
              builder: (context, momentSnapshot) {
                if (momentSnapshot.hasError) {
                  return AppErrorState(
                    message: 'We could not load the Family Moments.',
                    onRetry: _load,
                  );
                }

                if (momentSnapshot.connectionState == ConnectionState.waiting &&
                    !momentSnapshot.hasData) {
                  return const AppLoadingState(
                    message: 'Loading Family Moments…',
                  );
                }

                final moments = _startableDefinitions(
                  momentSnapshot.data ?? <FamilyMoment>[],
                );

                return _buildContent(members: members, moments: moments);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent({
    required List<Member> members,
    required List<FamilyMoment> moments,
  }) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            108,
          ),
          children: [
            Text(
              'Begin something together',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose an existing Family Moment, or create a simple one-time Moment and begin immediately.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _isStarting || members.isEmpty
                  ? null
                  : () {
                      _openCreateNewMoment(members);
                    },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a New Moment'),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Existing Moments',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (moments.isEmpty)
              const AppCard(
                child: Text(
                  'There are no active Moment definitions to start yet.',
                ),
              )
            else
              ...moments.map(
                (moment) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ExistingMomentCard(
                    moment: moment,
                    onTap: _isStarting
                        ? null
                        : () {
                            _confirmAndStartExisting(moment);
                          },
                  ),
                ),
              ),
          ],
        ),
        if (_isStarting)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  List<FamilyMoment> _startableDefinitions(List<FamilyMoment> moments) {
    final result = moments.where((moment) {
      if (moment.isArchived) {
        return false;
      }

      if (moment.type == MomentType.recurring) {
        return true;
      }

      return moment.status == MomentStatus.scheduled;
    }).toList();

    result.sort((first, second) {
      if (first.type != second.type) {
        return first.type == MomentType.recurring ? -1 : 1;
      }

      return first.title.compareTo(second.title);
    });

    return result;
  }

  Future<void> _confirmAndStartExisting(FamilyMoment moment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start this Moment now?'),
          content: Text(
            'A new spontaneous occurrence of “${moment.title}” will begin. Any future scheduled occurrence will stay unchanged.',
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
              child: const Text('Start Now'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _startExistingMoment(moment);
  }

  Future<void> _startExistingMoment(FamilyMoment moment) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isStarting) {
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    MomentInstance? temporaryOccurrence;

    try {
      await _ensureNoActiveMoment(familyContext.familyId);

      final start = DateTime.now();
      final end = start.add(_durationFor(moment));

      temporaryOccurrence = await AppDependencies.momentInstanceRepository
          .scheduleOccurrence(
            moment: moment,
            scheduledStartAt: start,
            scheduledEndAt: end,
            createdBy: familyContext.userId,
            source: MomentInstanceSource.spontaneous,
          );

      final active = await AppDependencies.momentInstanceRepository
          .startMomentNow(
            moment: moment,
            startedBy: familyContext.userId,
            source: MomentInstanceSource.spontaneous,
            existingInstanceId: temporaryOccurrence.id,
          );

      if (!mounted) return;
      _openLiveMoment(active);
    } catch (error) {
      await _cancelTemporaryOccurrence(temporaryOccurrence);

      if (!mounted) return;
      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'We could not start this Moment.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _openCreateNewMoment(List<Member> members) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isStarting) {
      return;
    }

    final draft = await showModalBottomSheet<_QuickMomentDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return _CreateQuickMomentSheet(
          members: members,
          currentUserId: familyContext.userId,
        );
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    await _createAndStartMoment(draft);
  }

  Future<void> _createAndStartMoment(_QuickMomentDraft draft) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isStarting) {
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    final nowLocal = DateTime.now();
    final nowUtc = nowLocal.toUtc();
    final momentId =
        'moment_${familyContext.userId}_'
        '${DateTime.now().microsecondsSinceEpoch}';

    final moment = FamilyMoment(
      id: momentId,
      familyId: familyContext.familyId,
      title: draft.title,
      type: MomentType.singular,
      category: draft.category,
      importanceLevel: 3,
      expectedParticipantIds: draft.participantIds,
      startAt: nowUtc,
      endAt: nowLocal.add(Duration(minutes: draft.durationMinutes)).toUtc(),
      evidenceType: EvidenceType.manual,
      status: MomentStatus.scheduled,
      createdBy: familyContext.userId,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );

    var definitionSaved = false;
    MomentInstance? temporaryOccurrence;

    try {
      await _ensureNoActiveMoment(familyContext.familyId);

      await AppDependencies.calendarRepository.saveMoment(moment);
      definitionSaved = true;

      temporaryOccurrence = await AppDependencies.momentInstanceRepository
          .scheduleOccurrence(
            moment: moment,
            scheduledStartAt: nowLocal,
            scheduledEndAt: nowLocal.add(
              Duration(minutes: draft.durationMinutes),
            ),
            createdBy: familyContext.userId,
            source: MomentInstanceSource.spontaneous,
          );

      final active = await AppDependencies.momentInstanceRepository
          .startMomentNow(
            moment: moment,
            startedBy: familyContext.userId,
            source: MomentInstanceSource.spontaneous,
            existingInstanceId: temporaryOccurrence.id,
          );

      if (!mounted) return;
      _openLiveMoment(active);
    } catch (error) {
      await _cancelTemporaryOccurrence(temporaryOccurrence);

      if (definitionSaved) {
        try {
          await AppDependencies.calendarRepository.deleteMoment(
            familyId: moment.familyId,
            momentId: moment.id,
          );
        } catch (_) {
          // The user still receives the original start error. A leftover
          // definition can be safely removed from the Moment Library later.
        }
      }

      if (!mounted) return;
      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'We could not create and start this Moment.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _ensureNoActiveMoment(String familyId) async {
    final active = await AppDependencies.momentInstanceRepository
        .watchActiveInstance(familyId: familyId)
        .first;

    if (active != null) {
      throw StateError(
        '${active.titleSnapshot} is already live. End it before starting another Moment.',
      );
    }
  }

  Future<void> _cancelTemporaryOccurrence(MomentInstance? occurrence) async {
    final familyContext = _familyContext;

    if (occurrence == null || familyContext == null || occurrence.isActive) {
      return;
    }

    try {
      await AppDependencies.momentInstanceRepository.cancelInstance(
        familyId: occurrence.familyId,
        instanceId: occurrence.id,
        cancelledBy: familyContext.userId,
      );
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  Duration _durationFor(FamilyMoment moment) {
    final startMinutes = moment.resolvedPreferredStartMinutes;
    final endMinutes = moment.resolvedPreferredEndMinutes;

    if (endMinutes == null) {
      return const Duration(minutes: 60);
    }

    var durationMinutes = endMinutes - startMinutes;

    if (durationMinutes <= 0) {
      durationMinutes += 24 * 60;
    }

    if (durationMinutes < 15 || durationMinutes > 240) {
      return const Duration(minutes: 60);
    }

    return Duration(minutes: durationMinutes);
  }

  void _openLiveMoment(MomentInstance instance) {
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LiveMomentScreen(
          familyId: instance.familyId,
          instanceId: instance.id,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExistingMomentCard extends StatelessWidget {
  const _ExistingMomentCard({required this.moment, required this.onTap});

  final FamilyMoment moment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _categoryColor(moment.category).withAlpha(24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _categoryIcon(moment.category),
              color: _categoryColor(moment.category),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moment.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_categoryLabel(moment.category)} · '
                  '${moment.expectedParticipantIds.length} expected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_arrow_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _CreateQuickMomentSheet extends StatefulWidget {
  const _CreateQuickMomentSheet({
    required this.members,
    required this.currentUserId,
  });

  final List<Member> members;
  final String currentUserId;

  @override
  State<_CreateQuickMomentSheet> createState() =>
      _CreateQuickMomentSheetState();
}

class _CreateQuickMomentSheetState extends State<_CreateQuickMomentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  final Set<String> _participantIds = <String>{};

  MomentCategory _category = MomentCategory.familyTime;
  int _durationMinutes = 60;

  @override
  void initState() {
    super.initState();

    _participantIds.addAll(widget.members.map((member) => member.id));
    _participantIds.add(widget.currentUserId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create and Start',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This creates a simple one-time Family Moment and starts it immediately.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Moment Name',
                  hintText: 'Family Walk, Tea Together…',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a Moment name.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppPillSegmentedControl<MomentCategory>(
                segments: const [
                  AppPillSegment(
                    value: MomentCategory.familyTime,
                    label: 'Family Time',
                  ),
                  AppPillSegment(
                    value: MomentCategory.tradition,
                    label: 'Tradition',
                  ),
                ],
                selectedValue: _category,
                onChanged: (value) {
                  setState(() {
                    _category = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Expected participants',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: widget.members.map((member) {
                  final isCurrent = member.id == widget.currentUserId;
                  final selected = _participantIds.contains(member.id);

                  return FilterChip(
                    label: Text(member.displayName),
                    selected: selected,
                    onSelected: isCurrent
                        ? null
                        : (value) {
                            setState(() {
                              if (value) {
                                _participantIds.add(member.id);
                              } else {
                                _participantIds.remove(member.id);
                              }
                            });
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                decoration: const InputDecoration(
                  labelText: 'Expected Duration',
                ),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 minutes')),
                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                  DropdownMenuItem(value: 90, child: Text('1 hour 30 minutes')),
                  DropdownMenuItem(value: 120, child: Text('2 hours')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _durationMinutes = value;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: _submit, child: const Text('Start Now')),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _participantIds.add(widget.currentUserId);

    final minimumParticipants = widget.members.length >= 2 ? 2 : 1;

    if (_participantIds.length < minimumParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least two family members.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _QuickMomentDraft(
        title: _titleController.text.trim(),
        category: _category,
        participantIds: _participantIds.toList(growable: false),
        durationMinutes: _durationMinutes,
      ),
    );
  }
}

class _QuickMomentDraft {
  const _QuickMomentDraft({
    required this.title,
    required this.category,
    required this.participantIds,
    required this.durationMinutes,
  });

  final String title;
  final MomentCategory category;
  final List<String> participantIds;
  final int durationMinutes;
}

Color _categoryColor(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => AppColors.primary,
    MomentCategory.milestone => AppColors.accent,
    MomentCategory.responsibility => AppColors.info,
    MomentCategory.care => AppColors.secondary,
    MomentCategory.familyTime => AppColors.strengthening,
    MomentCategory.memory => AppColors.upcoming,
  };
}

IconData _categoryIcon(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => Icons.eco_outlined,
    MomentCategory.milestone => Icons.star_border_rounded,
    MomentCategory.responsibility => Icons.task_alt_outlined,
    MomentCategory.care => Icons.favorite_border_rounded,
    MomentCategory.familyTime => Icons.groups_2_outlined,
    MomentCategory.memory => Icons.auto_stories_outlined,
  };
}

String _categoryLabel(MomentCategory category) {
  return switch (category) {
    MomentCategory.tradition => 'Tradition',
    MomentCategory.milestone => 'Milestone',
    MomentCategory.responsibility => 'Responsibility',
    MomentCategory.care => 'Care',
    MomentCategory.familyTime => 'Family Time',
    MomentCategory.memory => 'Memory',
  };
}
