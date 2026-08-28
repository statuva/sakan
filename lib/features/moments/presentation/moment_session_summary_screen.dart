import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_memory.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/moment_participant.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../memories/presentation/add_memory_screen.dart';
import '../../memories/presentation/memory_details_screen.dart';

class MomentSessionSummaryScreen extends StatefulWidget {
  const MomentSessionSummaryScreen({
    required this.familyId,
    required this.instanceId,
    super.key,
  });

  final String familyId;
  final String instanceId;

  @override
  State<MomentSessionSummaryScreen> createState() =>
      _MomentSessionSummaryScreenState();
}

class _MomentSessionSummaryScreenState
    extends State<MomentSessionSummaryScreen> {
  CurrentFamilyContext? _familyContext;
  FamilyMoment? _moment;
  FamilyMemory? _memory;

  Stream<MomentInstance?>? _instanceStream;
  Stream<List<MomentParticipant>>? _participantsStream;
  Stream<List<Member>>? _membersStream;

  bool _isLoading = true;
  bool _isOpeningMemory = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (familyContext.familyId != widget.familyId) {
        throw StateError('This Moment belongs to a different family.');
      }

      final instance = await AppDependencies.momentInstanceRepository
          .getInstance(
            familyId: widget.familyId,
            instanceId: widget.instanceId,
          );

      if (instance == null) {
        throw StateError('This Moment occurrence could not be found.');
      }

      final results = await Future.wait<Object?>([
        AppDependencies.calendarRepository.getMoment(
          familyId: widget.familyId,
          momentId: instance.momentId,
        ),
        AppDependencies.memoryRepository.getMemoryForInstance(
          familyId: widget.familyId,
          instanceId: widget.instanceId,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _moment = results[0] as FamilyMoment?;
        _memory = results[1] as FamilyMemory?;

        _instanceStream = AppDependencies.momentInstanceRepository
            .watchInstance(
              familyId: widget.familyId,
              instanceId: widget.instanceId,
            );

        _participantsStream = AppDependencies.momentInstanceRepository
            .watchParticipants(
              familyId: widget.familyId,
              instanceId: widget.instanceId,
            );

        _membersStream = AppDependencies.currentFamilyService
            .watchFamilyMembers(widget.familyId);

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not load the Moment summary.';
      });
    }
  }

  Future<void> _openMemory(MomentInstance instance) async {
    if (_isOpeningMemory) return;

    final memory = _memory;

    if (memory != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MemoryDetailsScreen(memory: memory)),
      );
      return;
    }

    final moment = _moment;

    if (_familyContext?.isAdult != true) {
      return;
    }

    setState(() {
      _isOpeningMemory = true;
    });

    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              AddMemoryScreen(initialMoment: moment, initialInstance: instance),
        ),
      );

      if (saved == true && mounted) {
        final savedMemory = await AppDependencies.memoryRepository
            .getMemoryForInstance(
              familyId: widget.familyId,
              instanceId: widget.instanceId,
            );

        if (!mounted) return;

        setState(() {
          _memory = savedMemory;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Family Memory saved.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningMemory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading Moment summary…'),
        ),
      );
    }

    if (_instanceStream == null ||
        _participantsStream == null ||
        _membersStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moment Summary')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The Moment summary is unavailable.',
            onRetry: _loadSummary,
          ),
        ),
      );
    }

    return StreamBuilder<MomentInstance?>(
      stream: _instanceStream,
      builder: (context, instanceSnapshot) {
        if (instanceSnapshot.hasError) {
          return _errorScaffold('We could not load this Moment occurrence.');
        }

        if (instanceSnapshot.connectionState == ConnectionState.waiting &&
            !instanceSnapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading Moment summary…'),
            ),
          );
        }

        final instance = instanceSnapshot.data;

        if (instance == null) {
          return _errorScaffold('This Moment occurrence no longer exists.');
        }

        return StreamBuilder<List<Member>>(
          stream: _membersStream,
          builder: (context, memberSnapshot) {
            final members = memberSnapshot.data ?? <Member>[];

            final membersById = <String, Member>{
              for (final member in members) member.id: member,
            };

            return StreamBuilder<List<MomentParticipant>>(
              stream: _participantsStream,
              builder: (context, participantSnapshot) {
                final participants =
                    participantSnapshot.data ?? <MomentParticipant>[];

                return _buildSummary(
                  instance: instance,
                  participants: participants,
                  membersById: membersById,
                );
              },
            );
          },
        );
      },
    );
  }

  Scaffold _buildSummary({
    required MomentInstance instance,
    required List<MomentParticipant> participants,
    required Map<String, Member> membersById,
  }) {
    final start = instance.actualStartAt?.toLocal();
    final end = instance.actualEndAt?.toLocal();

    final durationMinutes =
        instance.actualDurationMinutes ?? _durationMinutes(start, end);

    final checkedInParticipants = participants
        .where((participant) => participant.checkedInAt != null)
        .toList();

    final checkedInIds = checkedInParticipants
        .map((participant) => participant.memberId)
        .toSet();

    final reportedOnlyIds = instance.reportedParticipantIds
        .where((memberId) => !checkedInIds.contains(memberId))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Moment Summary')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            96,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(
                    instance.status == MomentInstanceStatus.completed
                        ? Icons.check_circle_rounded
                        : Icons.event_busy_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    instance.titleSnapshot,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusLabel(instance.status),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            _SummaryGrid(
              items: <_SummaryItem>[
                _SummaryItem(
                  label: 'Started',
                  value: start == null
                      ? 'Not recorded'
                      : DateFormat('h:mm a').format(start),
                  icon: Icons.play_circle_outline,
                ),
                _SummaryItem(
                  label: 'Ended',
                  value: end == null
                      ? 'Not recorded'
                      : DateFormat('h:mm a').format(end),
                  icon: Icons.stop_circle_outlined,
                ),
                _SummaryItem(
                  label: 'Duration',
                  value: _durationLabel(durationMinutes),
                  icon: Icons.timer_outlined,
                ),
                _SummaryItem(
                  label: 'Recorded',
                  value:
                      '${instance.allRecordedParticipantIds.length} of '
                      '${instance.expectedParticipantIds.length}',
                  icon: Icons.group_outlined,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            Text('Confirmation', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: _confirmationColor(
                  instance.confirmationLevel,
                ).withAlpha(24),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _confirmationColor(
                    instance.confirmationLevel,
                  ).withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: _confirmationColor(instance.confirmationLevel),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_confirmationLabel(instance.confirmationLevel)} confidence',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _confirmationExplanation(
                            instance: instance,
                            selfCheckInCount: checkedInParticipants.length,
                            durationMinutes: durationMinutes,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (instance.evidenceSignals.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Evidence Recorded',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: instance.evidenceSignals
                    .map(
                      (signal) => Chip(
                        avatar: Icon(_evidenceIcon(signal), size: 17),
                        label: Text(_evidenceLabel(signal)),
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            Text('Participants', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),

            if (checkedInParticipants.isEmpty && reportedOnlyIds.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('No participant evidence was recorded.'),
                ),
              )
            else ...[
              ...checkedInParticipants.map(
                (participant) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      membersById[participant.memberId]?.displayName ??
                          'Family member',
                    ),
                    subtitle: Text(_participantTimeText(participant)),
                    trailing: const Chip(label: Text('Self check-in')),
                  ),
                ),
              ),
              ...reportedOnlyIds.map(
                (memberId) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      membersById[memberId]?.displayName ?? 'Family member',
                    ),
                    subtitle: const Text('Reported during Today Review'),
                    trailing: const Chip(label: Text('Reported')),
                  ),
                ),
              ),
            ],

            if (instance.reviewNote?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Review Note',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(instance.reviewNote!),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            if (instance.status == MomentInstanceStatus.completed &&
                _familyContext?.isAdult == true)
              FilledButton.tonalIcon(
                onPressed: _isOpeningMemory
                    ? null
                    : () {
                        _openMemory(instance);
                      },
                icon: Icon(
                  _memory == null
                      ? Icons.bookmark_add_outlined
                      : Icons.auto_stories_outlined,
                ),
                label: Text(_memory == null ? 'Create Memory' : 'View Memory'),
              ),

            if (instance.status == MomentInstanceStatus.completed &&
                _familyContext?.isAdult != true &&
                _memory != null)
              FilledButton.tonalIcon(
                onPressed: () {
                  _openMemory(instance);
                },
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('View Memory'),
              ),

            const SizedBox(height: AppSpacing.sm),

            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moment Summary')),
      body: SafeArea(
        child: AppErrorState(message: message, onRetry: _loadSummary),
      ),
    );
  }

  int _durationMinutes(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return 0;
    }

    final minutes = end.difference(start).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    return remaining == 0 ? '$hours h' : '$hours h $remaining min';
  }

  String _participantTimeText(MomentParticipant participant) {
    final checkedIn = participant.checkedInAt?.toLocal();
    final checkedOut = participant.checkedOutAt?.toLocal();

    if (checkedIn == null) {
      return 'No check-in time recorded';
    }

    if (checkedOut == null) {
      return 'Checked in at '
          '${DateFormat('h:mm a').format(checkedIn)}';
    }

    return '${DateFormat('h:mm a').format(checkedIn)}–'
        '${DateFormat('h:mm a').format(checkedOut)}';
  }

  String _statusLabel(MomentInstanceStatus status) {
    return switch (status) {
      MomentInstanceStatus.completed => 'Completed',
      MomentInstanceStatus.cancelled => 'Cancelled',
      MomentInstanceStatus.missed => 'Missed',
      MomentInstanceStatus.active => 'Active',
      MomentInstanceStatus.inviting => 'Inviting',
      MomentInstanceStatus.scheduled => 'Scheduled',
      MomentInstanceStatus.proposed => 'Proposed',
    };
  }

  String _confirmationLabel(MomentConfirmationLevel level) {
    return switch (level) {
      MomentConfirmationLevel.low => 'Low',
      MomentConfirmationLevel.medium => 'Medium',
      MomentConfirmationLevel.high => 'High',
    };
  }

  Color _confirmationColor(MomentConfirmationLevel level) {
    return switch (level) {
      MomentConfirmationLevel.low => Theme.of(context).colorScheme.error,
      MomentConfirmationLevel.medium => Colors.orange,
      MomentConfirmationLevel.high => Colors.green,
    };
  }

  String _confirmationExplanation({
    required MomentInstance instance,
    required int selfCheckInCount,
    required int durationMinutes,
  }) {
    if (instance.confirmationLevel == MomentConfirmationLevel.high) {
      return 'Multiple self check-ins and recorded '
          'duration strongly support this occurrence.';
    }

    if (instance.evidenceSignals.contains(MomentEvidenceSignal.todayReview)) {
      return 'This occurrence was reported during '
          'Today Review. Reported participation is '
          'useful, but weaker than multiple self check-ins.';
    }

    if (instance.confirmationLevel == MomentConfirmationLevel.medium) {
      return '$selfCheckInCount self check-in(s) and '
          '$durationMinutes recorded minute(s) provide '
          'partial confirmation.';
    }

    return 'This occurrence currently has limited '
        'participation or duration evidence.';
  }

  String _evidenceLabel(MomentEvidenceSignal signal) {
    return switch (signal) {
      MomentEvidenceSignal.scheduled => 'Scheduled',
      MomentEvidenceSignal.hostStarted => 'Host started',
      MomentEvidenceSignal.manualCheckIn => 'Manual check-in',
      MomentEvidenceSignal.multipleCheckIns => 'Multiple check-ins',
      MomentEvidenceSignal.durationRecorded => 'Duration recorded',
      MomentEvidenceSignal.bluetoothNearby => 'Bluetooth nearby',
      MomentEvidenceSignal.qrCheckIn => 'QR check-in',
      MomentEvidenceSignal.todayReview => 'Today Review',
      MomentEvidenceSignal.familyNote => 'Family note',
      MomentEvidenceSignal.memoryCreated => 'Memory created',
    };
  }

  IconData _evidenceIcon(MomentEvidenceSignal signal) {
    return switch (signal) {
      MomentEvidenceSignal.scheduled => Icons.calendar_today_outlined,
      MomentEvidenceSignal.hostStarted => Icons.play_circle_outline,
      MomentEvidenceSignal.manualCheckIn => Icons.touch_app_outlined,
      MomentEvidenceSignal.multipleCheckIns => Icons.groups_outlined,
      MomentEvidenceSignal.durationRecorded => Icons.timer_outlined,
      MomentEvidenceSignal.bluetoothNearby => Icons.bluetooth_outlined,
      MomentEvidenceSignal.qrCheckIn => Icons.qr_code_rounded,
      MomentEvidenceSignal.todayReview => Icons.fact_check_outlined,
      MomentEvidenceSignal.familyNote => Icons.notes_outlined,
      MomentEvidenceSignal.memoryCreated => Icons.auto_stories_outlined,
    };
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpacing.sm) / 2;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.icon,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.value,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
