import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/daily_review.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import 'log_unplanned_moment_screen.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/services/moment_review_question_builder.dart';
import '../../../shared/services/personalized_today_review_policy.dart';
import '../../../shared/services/calendar_occurrence_label.dart';

class TodayReviewScreen extends StatefulWidget {
  const TodayReviewScreen({super.key});

  @override
  State<TodayReviewScreen> createState() => _TodayReviewScreenState();
}

class _TodayReviewScreenState extends State<TodayReviewScreen> {
  CurrentFamilyContext? _familyContext;

  Stream<List<MomentInstance>>? _instancesStream;
  Stream<List<Member>>? _membersStream;
  Stream<List<FamilyMoment>>? _momentsStream;

  final Set<String> _resolvedInstanceIds = <String>{};

  final Set<String> _loggedInstanceIds = <String>{};

  DailyReview? _existingReview;

  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isSavingReview = false;

  String? _errorMessage;

  DateTime get _reviewDate => DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (!familyContext.isAdult) {
        throw StateError(
          'Today Review is currently available to '
          'adult family members and admins.',
        );
      }

      final existingReview = await AppDependencies.dailyReviewRepository
          .getReview(familyId: familyContext.familyId, reviewDate: _reviewDate);

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _existingReview = existingReview;

        _resolvedInstanceIds
          ..clear()
          ..addAll(existingReview?.resolvedInstanceIds ?? const <String>[]);

        _loggedInstanceIds
          ..clear()
          ..addAll(existingReview?.loggedInstanceIds ?? const <String>[]);

        _instancesStream = AppDependencies.momentInstanceRepository
            .watchInstances(familyId: familyContext.familyId);

        _membersStream = AppDependencies.currentFamilyService
            .watchFamilyMembers(familyContext.familyId);
        _momentsStream = AppDependencies.calendarRepository.watchMoments(
          familyId: familyContext.familyId,
        );

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not prepare Today Review.';
      });
    }
  }

  List<MomentInstance> _reviewableInstances(List<MomentInstance> instances) {
    final now = DateTime.now();
    final start = _reviewDate.subtract(const Duration(days: 1));

    final result = instances.where((instance) {
      final statusIsReviewable =
          instance.status == MomentInstanceStatus.proposed ||
          instance.status == MomentInstanceStatus.scheduled ||
          instance.status == MomentInstanceStatus.inviting;

      final scheduledLocal = instance.scheduledStartAt.toLocal();

      return statusIsReviewable &&
          !scheduledLocal.isBefore(start) &&
          !scheduledLocal.isAfter(now);
    }).toList();

    result.sort(
      (first, second) =>
          first.scheduledStartAt.compareTo(second.scheduledStartAt),
    );

    return result;
  }

  Future<void> _markHappened({
    required MomentInstance instance,
    required List<Member> members,
  }) async {
    if (_isUpdating) return;

    final draft = await showDialog<_HappenedDraft>(
      context: context,
      builder: (dialogContext) {
        return _HappenedDialog(instance: instance, members: members);
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await AppDependencies.momentOutcomeService.completeFromTodayReview(
        familyId: instance.familyId,
        instanceId: instance.id,
        reviewedBy: _familyContext!.userId,
        actualStartAt: draft.actualStartAt,
        durationMinutes: draft.durationMinutes,
        reportedParticipantIds: draft.participantIds,
        note: draft.note,
        isPartial: draft.isPartial,
      );

      if (!mounted) return;

      setState(() {
        _resolvedInstanceIds.add(instance.id);
      });

      _showMessage(
        draft.isPartial
            ? 'The partial Moment was recorded.'
            : 'The Moment was recorded as happened.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError || error is ArgumentError
            ? _readableError(error)
            : 'We could not record this Moment.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _markMissed(MomentInstance instance) async {
    if (_isUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark as not happened?'),
          content: Text(
            '“${instance.titleSnapshot}” will be '
            'recorded as missed for this occurrence. '
            'The recurring Moment definition remains.',
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
              child: const Text('Didn’t Happen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await AppDependencies.momentOutcomeService.markMissed(
        familyId: instance.familyId,
        instanceId: instance.id,
        updatedBy: _familyContext!.userId,
      );

      if (!mounted) return;

      setState(() {
        _resolvedInstanceIds.add(instance.id);
      });

      _showMessage('This occurrence was recorded as missed.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'We could not update this Moment.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _reschedule(MomentInstance instance) async {
    if (_isUpdating) return;

    final draft = await showDialog<_RescheduleDraft>(
      context: context,
      builder: (dialogContext) {
        return _RescheduleDialog(instance: instance);
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await AppDependencies.momentOutcomeService.reschedule(
        familyId: instance.familyId,
        instanceId: instance.id,
        updatedBy: _familyContext!.userId,
        scheduledStartAt: draft.startAt,
        scheduledEndAt: draft.endAt,
      );

      if (!mounted) return;

      setState(() {
        _resolvedInstanceIds.add(instance.id);
      });

      _showMessage('The Moment was rescheduled.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError || error is ArgumentError
            ? _readableError(error)
            : 'We could not reschedule this Moment.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _logUnplannedMoment() async {
    final instanceId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LogUnplannedMomentScreen()),
    );

    if (instanceId == null || !mounted) {
      return;
    }

    setState(() {
      _loggedInstanceIds.add(instanceId);
    });

    _showMessage('The unplanned Moment was recorded.');
  }

  Future<void> _finishReview(List<MomentInstance> reviewable) async {
    if (_isSavingReview || _isUpdating) {
      return;
    }

    if (reviewable.isNotEmpty) {
      _showMessage('Resolve each planned Moment before finishing.');
      return;
    }

    final familyContext = _familyContext!;
    final now = DateTime.now().toUtc();
    final existing = _existingReview;

    final review = DailyReview(
      id: DailyReview.documentIdFor(_reviewDate),
      familyId: familyContext.familyId,
      dateKey: DailyReview.dateKeyFor(_reviewDate),
      reviewDate: DailyReview.normalizedReviewDate(_reviewDate),
      reviewedBy: familyContext.userId,
      resolvedInstanceIds: _resolvedInstanceIds.toList()..sort(),
      loggedInstanceIds: _loggedInstanceIds.toList()..sort(),
      confirmedNoOtherMoments: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _isSavingReview = true;
    });

    try {
      await AppDependencies.dailyReviewRepository.saveReview(review);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      _showMessage('We could not finish Today Review.');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingReview = false;
        });
      }
    }
  }

  String _readableError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is ArgumentError) {
      return error.message?.toString() ??
          'The submitted information is invalid.';
    }

    return 'Something went wrong.';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Preparing Today Review…'),
        ),
      );
    }

    if (_familyContext == null ||
        _instancesStream == null ||
        _membersStream == null ||
        _momentsStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Today Review')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'Today Review is unavailable.',
            onRetry: _loadReview,
          ),
        ),
      );
    }

    return StreamBuilder<List<Member>>(
      stream: _membersStream,
      builder: (context, memberSnapshot) {
        if (memberSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Today Review')),
            body: SafeArea(
              child: AppErrorState(
                message: 'We could not load your family members.',
                onRetry: _loadReview,
              ),
            ),
          );
        }

        if (memberSnapshot.connectionState == ConnectionState.waiting &&
            !memberSnapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading family members…'),
            ),
          );
        }

        final members = memberSnapshot.data ?? <Member>[];

        final currentMember = members
            .where((member) => member.id == _familyContext!.userId)
            .firstOrNull;

        if (currentMember == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Today Review')),
            body: SafeArea(
              child: AppErrorState(
                message: 'Your family profile could not be found.',
                onRetry: _loadReview,
              ),
            ),
          );
        }

        return StreamBuilder<List<FamilyMoment>>(
          stream: _momentsStream,
          builder: (context, momentSnapshot) {
            if (momentSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Today Review')),
                body: SafeArea(
                  child: AppErrorState(
                    message: 'We could not load your Family Moments.',
                    onRetry: _loadReview,
                  ),
                ),
              );
            }

            if (momentSnapshot.connectionState == ConnectionState.waiting &&
                !momentSnapshot.hasData) {
              return const Scaffold(
                body: SafeArea(
                  child: AppLoadingState(message: 'Loading Family Moments…'),
                ),
              );
            }

            final moments = momentSnapshot.data ?? <FamilyMoment>[];

            final momentsById = <String, FamilyMoment>{
              for (final moment in moments) moment.id: moment,
            };

            return StreamBuilder<List<MomentInstance>>(
              stream: _instancesStream,
              builder: (context, instanceSnapshot) {
                if (instanceSnapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Today Review')),
                    body: SafeArea(
                      child: AppErrorState(
                        message: 'We could not load recent Moments.',
                        onRetry: _loadReview,
                      ),
                    ),
                  );
                }

                if (instanceSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !instanceSnapshot.hasData) {
                  return const Scaffold(
                    body: SafeArea(
                      child: AppLoadingState(
                        message: 'Loading recent Moments…',
                      ),
                    ),
                  );
                }

                final allInstances =
                    instanceSnapshot.data ?? <MomentInstance>[];

                final reviewable =
                    PersonalizedTodayReviewPolicy.filter(
                      instances: allInstances,
                      momentsById: momentsById,
                      currentMember: currentMember,
                    ).where((instance) {
                      return !_resolvedInstanceIds.contains(instance.id);
                    }).toList();

                return Scaffold(
                  appBar: AppBar(title: const Text('Today Review')),
                  body: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.xl,
                        104,
                      ),
                      children: [
                        AppCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.fact_check_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'A few Moments still need an outcome',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Sakan only asks about past occurrences '
                                      'that still need confirmation. '
                                      'Live sessions already recorded in Sakan '
                                      'do not need to be reviewed again.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Needs Review',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              '${reviewable.length}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        if (reviewable.isEmpty)
                          AppCard(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 52,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Nothing unresolved',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Sakan has a clear outcome for '
                                  'the recent Moments relevant to you.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          )
                        else
                          ...reviewable.map((instance) {
                            final moment = momentsById[instance.momentId];

                            if (moment == null) {
                              return const SizedBox.shrink();
                            }

                            final reviewCopy =
                                MomentReviewQuestionBuilder.build(
                                  moment: moment,
                                  currentMember: currentMember,
                                );

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _ReviewInstanceCard(
                                instance: instance,
                                question: reviewCopy.question,
                                positiveLabel: reviewCopy.positiveLabel,
                                negativeLabel: reviewCopy.negativeLabel,
                                allowReschedule: reviewCopy.allowReschedule,
                                isDisabled: _isUpdating,
                                onHappened: () {
                                  _markHappened(
                                    instance: instance,
                                    members: members,
                                  );
                                },
                                onMissed: () {
                                  _markMissed(instance);
                                },
                                onReschedule: () {
                                  _reschedule(instance);
                                },
                              ),
                            );
                          }),

                        const SizedBox(height: AppSpacing.xl),

                        OutlinedButton.icon(
                          onPressed: _isUpdating ? null : _logUnplannedMoment,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Log Something Else We Did'),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        AppPrimaryButton(
                          label: 'Finish Today Review',
                          icon: Icons.done_all_rounded,
                          isLoading: _isSavingReview,
                          onPressed: _isSavingReview || _isUpdating
                              ? null
                              : () {
                                  _finishReview(reviewable);
                                },
                        ),

                        if (_existingReview != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'This review was previously saved. '
                            'Saving again updates it.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReviewInstanceCard extends StatelessWidget {
  const _ReviewInstanceCard({
    required this.instance,
    required this.question,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.allowReschedule,
    required this.isDisabled,
    required this.onHappened,
    required this.onMissed,
    required this.onReschedule,
  });

  final MomentInstance instance;

  final String question;
  final String positiveLabel;
  final String negativeLabel;
  final bool allowReschedule;

  final bool isDisabled;

  final VoidCallback onHappened;
  final VoidCallback onMissed;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final start = instance.scheduledStartAt.toLocal();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            instance.titleSnapshot,
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 6),

          Text(
            DateFormat('EEEE, d MMMM · h:mm a').format(start),
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(question, style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: AppSpacing.md),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: isDisabled ? null : onHappened,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(positiveLabel),
              ),

              OutlinedButton.icon(
                onPressed: isDisabled ? null : onMissed,
                icon: const Icon(Icons.close_rounded),
                label: Text(negativeLabel),
              ),

              if (allowReschedule)
                TextButton.icon(
                  onPressed: isDisabled ? null : onReschedule,
                  icon: const Icon(Icons.event_repeat_outlined),
                  label: const Text('Reschedule'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HappenedDialog extends StatefulWidget {
  const _HappenedDialog({required this.instance, required this.members});

  final MomentInstance instance;
  final List<Member> members;

  @override
  State<_HappenedDialog> createState() => _HappenedDialogState();
}

class _HappenedDialogState extends State<_HappenedDialog> {
  final _noteController = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  late int _durationMinutes;
  late Set<String> _participantIds;
  bool _isPartial = false;

  @override
  void initState() {
    super.initState();

    final scheduled = widget.instance.scheduledStartAt.toLocal();

    _date = DateUtils.dateOnly(scheduled);
    _time = TimeOfDay.fromDateTime(scheduled);

    final scheduledEnd = widget.instance.scheduledEndAt?.toLocal();

    final duration = scheduledEnd == null
        ? 60
        : scheduledEnd.difference(scheduled).inMinutes;

    _durationMinutes = _durationOptions.contains(duration) ? duration : 60;

    _participantIds = widget.instance.expectedParticipantIds.toSet();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  static const List<int> _durationOptions = <int>[15, 30, 45, 60, 90, 120];

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 7)),
      lastDate: today,
    );

    if (selected == null) return;

    setState(() {
      _date = DateUtils.dateOnly(selected);
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);

    if (selected == null) return;

    setState(() {
      _time = selected;
    });
  }

  void _submit() {
    if (_participantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one reported participant.'),
        ),
      );
      return;
    }

    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    Navigator.of(context).pop(
      _HappenedDraft(
        actualStartAt: start,
        durationMinutes: _durationMinutes,
        participantIds: _participantIds.toList()..sort(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        isPartial: _isPartial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberById = <String, Member>{
      for (final member in widget.members) member.id: member,
    };

    return AlertDialog(
      title: Text('How did ${widget.instance.titleSnapshot} go?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(DateFormat('EEEE, d MMMM y').format(_date)),
                onTap: _pickDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_outlined),
                title: const Text('Approximate start'),
                subtitle: Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(_time),
                ),
                onTap: _pickTime,
              ),
              DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                decoration: const InputDecoration(
                  labelText: 'Approximate duration',
                ),
                items: _durationOptions
                    .map(
                      (minutes) => DropdownMenuItem<int>(
                        value: minutes,
                        child: Text(
                          minutes < 60
                              ? '$minutes minutes'
                              : minutes == 60
                              ? '1 hour'
                              : '${minutes ~/ 60} h '
                                    '${minutes % 60} min',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _durationMinutes = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Who participated?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.instance.expectedParticipantIds.map((
                  memberId,
                ) {
                  final member = memberById[memberId];
                  final selected = _participantIds.contains(memberId);

                  return FilterChip(
                    label: Text(member?.displayName ?? 'Family member'),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _participantIds.add(memberId);
                        } else {
                          _participantIds.remove(memberId);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Partly happened'),
                subtitle: const Text(
                  'Use this when the family met, '
                  'but the Moment was shorter or '
                  'different from the plan.',
                ),
                value: _isPartial,
                onChanged: (value) {
                  setState(() {
                    _isPartial = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  hintText: 'What should Sakan know?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Participants selected here are '
                'reported by the reviewer. Live '
                'self check-ins remain stronger evidence.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Record Moment')),
      ],
    );
  }
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.instance});

  final MomentInstance instance;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late DateTime _date;
  late TimeOfDay _time;
  late int _durationMinutes;

  @override
  void initState() {
    super.initState();

    final current = widget.instance.scheduledStartAt.toLocal();
    final today = DateUtils.dateOnly(DateTime.now());

    _date = current.isAfter(DateTime.now())
        ? DateUtils.dateOnly(current)
        : today.add(const Duration(days: 1));

    _time = TimeOfDay.fromDateTime(current);

    final end = widget.instance.scheduledEndAt?.toLocal();

    final duration = end == null ? 60 : end.difference(current).inMinutes;

    _durationMinutes = duration > 0 ? duration : 60;
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
    );

    if (selected == null) return;

    setState(() {
      _date = DateUtils.dateOnly(selected);
    });
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);

    if (selected == null) return;

    setState(() {
      _time = selected;
    });
  }

  void _submit() {
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    if (!start.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _RescheduleDraft(
        startAt: start,
        endAt: start.add(Duration(minutes: _durationMinutes)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reschedule ${widget.instance.titleSnapshot}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('New date'),
            subtitle: Text(DateFormat('EEEE, d MMMM y').format(_date)),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time_outlined),
            title: const Text('New time'),
            subtitle: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(_time),
            ),
            onTap: _pickTime,
          ),
          DropdownButtonFormField<int>(
            initialValue: _durationMinutes,
            decoration: const InputDecoration(labelText: 'Expected duration'),
            items: const <int>[30, 45, 60, 90, 120]
                .map(
                  (minutes) => DropdownMenuItem<int>(
                    value: minutes,
                    child: Text('$minutes minutes'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _durationMinutes = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Reschedule')),
      ],
    );
  }
}

class _HappenedDraft {
  const _HappenedDraft({
    required this.actualStartAt,
    required this.durationMinutes,
    required this.participantIds,
    required this.note,
    required this.isPartial,
  });

  final DateTime actualStartAt;
  final int durationMinutes;
  final List<String> participantIds;
  final String? note;
  final bool isPartial;
}

class _RescheduleDraft {
  const _RescheduleDraft({required this.startAt, required this.endAt});

  final DateTime startAt;
  final DateTime endAt;
}
