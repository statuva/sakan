import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/moment_participant.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../../shared/widgets/people/sakan_member_avatar.dart';
import 'moment_session_summary_screen.dart';
import 'widgets/moment_session_visuals.dart';

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

      final instance = await AppDependencies.momentInstanceRepository
          .getInstance(
            familyId: widget.familyId,
            instanceId: widget.instanceId,
          );

      if (instance == null) {
        throw StateError('This live Moment no longer exists.');
      }

      if (instance.status == MomentInstanceStatus.active) {
        await _joinCurrentUserIfNeeded(
          familyContext: familyContext,
          instance: instance,
        );
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

  Future<void> _joinCurrentUserIfNeeded({
    required CurrentFamilyContext familyContext,
    required MomentInstance instance,
  }) async {
    final participants = await AppDependencies.momentInstanceRepository
        .getParticipants(familyId: instance.familyId, instanceId: instance.id);

    MomentParticipant? currentParticipant;

    for (final participant in participants) {
      if (participant.memberId == familyContext.userId) {
        currentParticipant = participant;
        break;
      }
    }

    if (currentParticipant?.state == ParticipantMomentState.checkedIn) {
      return;
    }

    await AppDependencies.momentInstanceRepository.checkIn(
      familyId: instance.familyId,
      instanceId: instance.id,
      memberId: familyContext.userId,
      method: MomentCheckInMethod.manual,
    );
  }

  Future<void> _checkOut() async {
    final familyContext = _familyContext;

    if (familyContext == null || _isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await AppDependencies.momentInstanceRepository.checkOut(
        familyId: widget.familyId,
        instanceId: widget.instanceId,
        memberId: familyContext.userId,
      );

      if (!mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      context.go('/home');

      if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('We could not leave this Moment. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _endMoment(MomentInstance instance) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isUpdating) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End this Moment?'),
          content: Text(
            'Sakan will record the elapsed time and family check-ins for “${instance.titleSnapshot}”.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Going'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
        endedBy: familyContext.userId,
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is StateError
              ? error.message.toString()
              : 'We could not end this Moment.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _cancelMoment(MomentInstance instance) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isUpdating) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel live Moment?'),
          content: Text(
            '“${instance.titleSnapshot}” will close without being recorded as completed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Going'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
        cancelledBy: familyContext.userId,
      );
    } catch (_) {
      if (mounted) {
        _showMessage('We could not cancel this Moment.');
      }
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
            final members = memberSnapshot.data ?? const <Member>[];

            return StreamBuilder<List<MomentParticipant>>(
              stream: _participantsStream,
              builder: (context, participantSnapshot) {
                final participants =
                    participantSnapshot.data ?? const <MomentParticipant>[];

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
    final familyContext = _familyContext!;
    final membersById = <String, Member>{
      for (final member in members) member.id: member,
    };
    final participantsById = <String, MomentParticipant>{
      for (final participant in participants) participant.memberId: participant,
    };

    final visibleMemberIds =
        <String>{
          ...instance.expectedParticipantIds,
          ...participantsById.keys,
        }.toList()..sort((first, second) {
          final firstName = membersById[first]?.displayName ?? first;
          final secondName = membersById[second]?.displayName ?? second;
          return firstName.compareTo(secondName);
        });

    final checkedInCount = participants
        .where((item) => item.state == ParticipantMomentState.checkedIn)
        .length;
    final elapsed = instance.actualStartAt == null
        ? Duration.zero
        : DateTime.now().difference(instance.actualStartAt!.toLocal());
    final categoryColor = momentSessionCategoryColor(instance.categorySnapshot);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: () {
                      _showParticipantsSheet(
                        instance: instance,
                        membersById: membersById,
                        visibleMemberIds: visibleMemberIds,
                        participantsById: participantsById,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.group_outlined,
                            size: 17,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$checkedInCount/${visibleMemberIds.length}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    enabled: !_isUpdating,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) {
                      switch (value) {
                        case 'checkOut':
                          _checkOut();
                          break;
                        case 'end':
                          _endMoment(instance);
                          break;
                        case 'cancel':
                          _cancelMoment(instance);
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem<String>(
                          value: 'checkOut',
                          child: Text('Leave Moment'),
                        ),
                        if (familyContext.isAdult)
                          const PopupMenuItem<String>(
                            value: 'end',
                            child: Text('End Moment'),
                          ),
                        if (familyContext.isAdult)
                          const PopupMenuItem<String>(
                            value: 'cancel',
                            child: Text('Cancel Moment'),
                          ),
                      ];
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: categoryColor.withAlpha(22),
                shape: BoxShape.circle,
              ),
              child: Icon(
                momentSessionCategoryIcon(instance.categorySnapshot),
                color: categoryColor,
                size: 29,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                instance.titleSnapshot,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Session active',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _formatElapsed(elapsed),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 48,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'elapsed',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 18,
                      color: AppColors.secondary.withAlpha(190),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                'Enjoy this Moment.\nSakan is recording only time and check-ins.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: SizedBox.expand(
                  child: Image.asset(
                    'assets/images/sakan_tree.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (_, _, _) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: AppSpacing.md),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              AppColors.background,
                              Color(0xFFE7E0CC),
                              Color(0xFFD8C8A5),
                            ],
                          ),
                        ),
                        child: const Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.xl),
                            child: Icon(
                              Icons.park_outlined,
                              size: 96,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showParticipantsSheet({
    required MomentInstance instance,
    required Map<String, Member> membersById,
    required List<String> visibleMemberIds,
    required Map<String, MomentParticipant> participantsById,
  }) async {
    final familyContext = _familyContext!;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.88,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.disabled,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Participants',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${instance.titleSnapshot} · ${visibleMemberIds.length} expected',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ...visibleMemberIds.map((memberId) {
                  final member = membersById[memberId];
                  final participant = participantsById[memberId];
                  final visual = _participantVisual(participant);

                  if (member == null) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          SakanMemberAvatar(
                            member: member,
                            diameter: 42,
                            width: 46,
                            showName: false,
                            presence: visual.presence,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.displayName,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  memberId == familyContext.userId
                                      ? '${visual.label} · You'
                                      : visual.label,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: visual.color),
                                ),
                              ],
                            ),
                          ),
                          Icon(visual.icon, color: visual.color, size: 19),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _isUpdating
                      ? null
                      : () async {
                          Navigator.of(sheetContext).pop();
                          await _checkOut();
                        },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Leave Moment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _ParticipantVisual _participantVisual(MomentParticipant? participant) {
    if (participant?.state == ParticipantMomentState.checkedIn) {
      return const _ParticipantVisual(
        label: 'Checked in',
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        presence: SakanMemberPresence.checkedIn,
      );
    }

    if (participant?.state == ParticipantMomentState.ready) {
      return const _ParticipantVisual(
        label: 'Joined the Ready Room',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        presence: SakanMemberPresence.ready,
      );
    }

    if (participant?.state == ParticipantMomentState.nearby ||
        participant?.nearbyDetectedAt != null) {
      return const _ParticipantVisual(
        label: 'Detected nearby',
        icon: Icons.bluetooth_connected_rounded,
        color: AppColors.info,
        presence: SakanMemberPresence.nearby,
      );
    }

    if (participant?.state == ParticipantMomentState.left) {
      return const _ParticipantVisual(
        label: 'Left the Moment',
        icon: Icons.logout_rounded,
        color: AppColors.textSecondary,
        presence: SakanMemberPresence.unknown,
      );
    }

    if (participant?.state == ParticipantMomentState.declined) {
      return const _ParticipantVisual(
        label: 'Not joining',
        icon: Icons.remove_circle_outline_rounded,
        color: AppColors.secondary,
        presence: SakanMemberPresence.unknown,
      );
    }

    return const _ParticipantVisual(
      label: 'Waiting',
      icon: Icons.hourglass_empty_rounded,
      color: AppColors.textSecondary,
      presence: SakanMemberPresence.unknown,
    );
  }

  String _formatElapsed(Duration elapsed) {
    final safeSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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
                const Icon(
                  Icons.hourglass_empty_rounded,
                  size: 58,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  instance.status == MomentInstanceStatus.inviting
                      ? 'The Ready Room is still open.'
                      : 'This Moment has not started yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Scaffold _closedScaffold(MomentInstance instance) {
    final missed = instance.status == MomentInstanceStatus.missed;

    return Scaffold(
      appBar: AppBar(title: const Text('Family Moment')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  missed ? Icons.event_busy_outlined : Icons.cancel_outlined,
                  size: 58,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  missed
                      ? 'This Moment was recorded as missed.'
                      : 'This Moment was cancelled.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
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
}

class _ParticipantVisual {
  const _ParticipantVisual({
    required this.label,
    required this.icon,
    required this.color,
    required this.presence,
  });

  final String label;
  final IconData icon;
  final Color color;
  final SakanMemberPresence presence;
}
