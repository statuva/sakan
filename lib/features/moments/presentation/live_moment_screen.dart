import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/moment_participant.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import 'moment_session_summary_screen.dart';

class LiveMomentScreen extends StatefulWidget {
  const LiveMomentScreen({
    required this.familyId,
    required this.instanceId,
    super.key,
  });

  final String familyId;
  final String instanceId;

  @override
  State<LiveMomentScreen> createState() => _LiveMomentScreenState();
}

class _LiveMomentScreenState extends State<LiveMomentScreen> {
  CurrentFamilyContext? _familyContext;

  Stream<MomentInstance?>? _instanceStream;
  Stream<List<MomentParticipant>>? _participantsStream;
  Stream<List<Member>>? _membersStream;

  Timer? _timer;

  bool _isLoading = true;
  bool _isUpdating = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSession();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (familyContext.familyId != widget.familyId) {
        throw StateError('This live Moment belongs to a different family.');
      }

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;

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
            : 'We could not open the live Moment.';
      });
    }
  }

  Future<void> _checkIn() async {
    final contextData = _familyContext;

    if (contextData == null || _isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await AppDependencies.momentInstanceRepository.checkIn(
        familyId: widget.familyId,
        instanceId: widget.instanceId,
        memberId: contextData.userId,
        method: MomentCheckInMethod.manual,
      );

      if (!mounted) return;

      _showMessage('You are checked in.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'We could not check you in.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _checkOut() async {
    final contextData = _familyContext;

    if (contextData == null || _isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await AppDependencies.momentInstanceRepository.checkOut(
        familyId: widget.familyId,
        instanceId: widget.instanceId,
        memberId: contextData.userId,
      );

      if (!mounted) return;

      _showMessage('You left the live Moment.');
    } catch (_) {
      if (!mounted) return;

      _showMessage('We could not update your participation.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _endMoment(MomentInstance instance) async {
    final contextData = _familyContext;

    if (contextData == null || _isUpdating) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End this Moment?'),
          content: Text(
            'Sakan will record the duration and '
            'participant check-ins for '
            '“${instance.titleSnapshot}”.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Keep Going'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('End Moment'),
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
      await AppDependencies.momentOutcomeService.endLiveMoment(
        familyId: widget.familyId,
        instanceId: widget.instanceId,
        endedBy: contextData.userId,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'We could not end this Moment.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _cancelMoment(MomentInstance instance) async {
    final contextData = _familyContext;

    if (contextData == null || _isUpdating) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel live Moment?'),
          content: Text(
            '“${instance.titleSnapshot}” will be '
            'closed without being recorded as completed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Keep Going'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Cancel Moment'),
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
      await AppDependencies.momentInstanceRepository.cancelInstance(
        familyId: widget.familyId,
        instanceId: widget.instanceId,
        cancelledBy: contextData.userId,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage('We could not cancel this Moment.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
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
          child: AppLoadingState(message: 'Opening the live Moment…'),
        ),
      );
    }

    if (_familyContext == null ||
        _instanceStream == null ||
        _participantsStream == null ||
        _membersStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Moment')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The live Moment is unavailable.',
            onRetry: _loadSession,
          ),
        ),
      );
    }

    return StreamBuilder<MomentInstance?>(
      stream: _instanceStream,
      builder: (context, instanceSnapshot) {
        if (instanceSnapshot.hasError) {
          return _errorScaffold('We could not load this live Moment.');
        }

        if (instanceSnapshot.connectionState == ConnectionState.waiting &&
            !instanceSnapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading live Moment…'),
            ),
          );
        }

        final instance = instanceSnapshot.data;

        if (instance == null) {
          return _errorScaffold('This live Moment no longer exists.');
        }

        if (instance.status == MomentInstanceStatus.completed) {
          return MomentSessionSummaryScreen(
            familyId: widget.familyId,
            instanceId: widget.instanceId,
          );
        }

        if (instance.status == MomentInstanceStatus.cancelled ||
            instance.status == MomentInstanceStatus.missed) {
          return _closedScaffold(instance);
        }

        if (!instance.isActive) {
          return _notActiveScaffold(instance);
        }

        return StreamBuilder<List<Member>>(
          stream: _membersStream,
          builder: (context, memberSnapshot) {
            final members = memberSnapshot.data ?? <Member>[];

            return StreamBuilder<List<MomentParticipant>>(
              stream: _participantsStream,
              builder: (context, participantSnapshot) {
                final participants =
                    participantSnapshot.data ?? <MomentParticipant>[];

                return _buildLiveScaffold(
                  instance: instance,
                  members: members,
                  participants: participants,
                );
              },
            );
          },
        );
      },
    );
  }

  Scaffold _buildLiveScaffold({
    required MomentInstance instance,
    required List<Member> members,
    required List<MomentParticipant> participants,
  }) {
    final contextData = _familyContext!;

    final membersById = <String, Member>{
      for (final member in members) member.id: member,
    };

    final participantsById = <String, MomentParticipant>{
      for (final participant in participants) participant.memberId: participant,
    };

    final visibleMemberIds = <String>{
      ...instance.expectedParticipantIds,
      ...participantsById.keys,
    }.toList();

    visibleMemberIds.sort((first, second) {
      final firstName = membersById[first]?.displayName ?? first;
      final secondName = membersById[second]?.displayName ?? second;

      return firstName.compareTo(secondName);
    });

    final currentParticipant = participantsById[contextData.userId];

    final currentCheckedIn =
        currentParticipant?.state == ParticipantMomentState.checkedIn;

    final elapsed = instance.actualStartAt == null
        ? Duration.zero
        : DateTime.now().difference(instance.actualStartAt!.toLocal());

    final canEnd = contextData.isAdult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Moment'),
        actions: [
          if (canEnd)
            PopupMenuButton<String>(
              enabled: !_isUpdating,
              onSelected: (value) {
                if (value == 'cancel') {
                  _cancelMoment(instance);
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined),
                        SizedBox(width: 10),
                        Text('Cancel Moment'),
                      ],
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            120,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 9, color: Colors.redAccent),
                        SizedBox(width: 7),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    instance.titleSnapshot,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (instance.locationSnapshot?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      instance.locationSnapshot!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    _formatDuration(elapsed),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Started '
                    '${DateFormat('h:mm a').format(instance.actualStartAt!.toLocal())}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Participants',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${participants.where((item) => item.state == ParticipantMomentState.checkedIn).length} checked in',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            ...visibleMemberIds.map((memberId) {
              final member = membersById[memberId];
              final participant = participantsById[memberId];

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ParticipantCard(
                  name: member?.displayName ?? 'Family member',
                  isCurrentUser: memberId == contextData.userId,
                  participant: participant,
                ),
              );
            }),

            const SizedBox(height: AppSpacing.lg),

            if (!currentCheckedIn)
              FilledButton.icon(
                onPressed: _isUpdating ? null : _checkIn,
                icon: const Icon(Icons.touch_app_outlined),
                label: const Text('I’m Here'),
              )
            else
              OutlinedButton.icon(
                onPressed: _isUpdating ? null : _checkOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave Moment'),
              ),

            if (canEnd) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: _isUpdating
                    ? null
                    : () {
                        _endMoment(instance);
                      },
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End Moment'),
              ),
            ],

            if (_isUpdating) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Scaffold _closedScaffold(MomentInstance instance) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Moment')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_busy_outlined, size: 62),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  instance.titleSnapshot,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  instance.status == MomentInstanceStatus.cancelled
                      ? 'This Moment was cancelled.'
                      : 'This Moment was marked as missed.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Scaffold _notActiveScaffold(MomentInstance instance) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Moment')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_outlined, size: 62),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  instance.titleSnapshot,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'This occurrence has not started yet.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Moment')),
      body: SafeArea(
        child: AppErrorState(message: message, onRetry: _loadSession),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final safeDuration = duration.isNegative ? Duration.zero : duration;

    final hours = safeDuration.inHours;
    final minutes = safeDuration.inMinutes.remainder(60);
    final seconds = safeDuration.inSeconds.remainder(60);

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(hours)}:'
        '${twoDigits(minutes)}:'
        '${twoDigits(seconds)}';
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.name,
    required this.isCurrentUser,
    required this.participant,
  });

  final String name;
  final bool isCurrentUser;
  final MomentParticipant? participant;

  @override
  Widget build(BuildContext context) {
    final state = participant?.state ?? ParticipantMomentState.invited;

    final status = _statusVisual(state);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase()),
        ),
        title: Row(
          children: [
            Flexible(child: Text(name)),
            if (isCurrentUser) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'You',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ],
        ),
        subtitle: participant?.checkedInAt == null
            ? null
            : Text(
                'Checked in '
                '${DateFormat('h:mm a').format(participant!.checkedInAt!.toLocal())}',
              ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: status.color.withAlpha(20),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: 15, color: status.color),
              const SizedBox(width: 5),
              Text(
                status.label,
                style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ParticipantStatusVisual _statusVisual(ParticipantMomentState state) {
    return switch (state) {
      ParticipantMomentState.checkedIn => const _ParticipantStatusVisual(
        label: 'Here',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      ),
      ParticipantMomentState.nearby => const _ParticipantStatusVisual(
        label: 'Nearby',
        icon: Icons.bluetooth_connected_rounded,
        color: Colors.blue,
      ),
      ParticipantMomentState.left => const _ParticipantStatusVisual(
        label: 'Left',
        icon: Icons.logout_rounded,
        color: Colors.orange,
      ),
      ParticipantMomentState.declined => const _ParticipantStatusVisual(
        label: 'Declined',
        icon: Icons.cancel_outlined,
        color: Colors.redAccent,
      ),
      ParticipantMomentState.invited => const _ParticipantStatusVisual(
        label: 'Invited',
        icon: Icons.schedule_outlined,
        color: Colors.grey,
      ),
    };
  }
}

class _ParticipantStatusVisual {
  const _ParticipantStatusVisual({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
