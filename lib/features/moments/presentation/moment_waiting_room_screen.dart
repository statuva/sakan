import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/member.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/models/moment_participant.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';
import '../../../shared/widgets/people/sakan_member_avatar.dart';
import '../services/moment_session_preparation_service.dart';

class MomentWaitingRoomScreen extends StatefulWidget {
  const MomentWaitingRoomScreen({
    required this.moment,
    required this.source,
    required this.preparedSession,
    this.saveDefinitionBeforeStart = false,
    super.key,
  });

  final FamilyMoment moment;
  final MomentInstanceSource source;
  final PreparedMomentSession preparedSession;
  final bool saveDefinitionBeforeStart;

  @override
  State<MomentWaitingRoomScreen> createState() =>
      _MomentWaitingRoomScreenState();
}

class _MomentWaitingRoomScreenState extends State<MomentWaitingRoomScreen> {
  final MomentSessionPreparationService _preparationService =
      MomentSessionPreparationService();

  CurrentFamilyContext? _familyContext;
  Stream<MomentInstance?>? _instanceStream;
  Stream<List<MomentParticipant>>? _participantsStream;
  Stream<List<Member>>? _membersStream;

  bool _isLoading = true;
  bool _isStarting = false;
  bool _isJoining = false;
  bool _isLeaving = false;
  bool _hasJoinedReadyRoom = false;
  bool _allowPop = false;
  bool _definitionSaved = false;
  bool _returnedActiveSession = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWaitingRoom();
  }

  Future<void> _loadWaitingRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (familyContext.familyId != widget.moment.familyId) {
        throw StateError('This Ready Room belongs to a different family.');
      }

      final existingParticipants = await AppDependencies
          .momentInstanceRepository
          .getParticipants(
            familyId: widget.preparedSession.instance.familyId,
            instanceId: widget.preparedSession.instance.id,
          );
      final alreadyJoined = existingParticipants.any((participant) {
        return participant.memberId == familyContext.userId &&
            participant.state == ParticipantMomentState.ready;
      });

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _hasJoinedReadyRoom = alreadyJoined;
        _instanceStream = AppDependencies.momentInstanceRepository
            .watchInstance(
              familyId: widget.preparedSession.instance.familyId,
              instanceId: widget.preparedSession.instance.id,
            );
        _participantsStream = AppDependencies.momentInstanceRepository
            .watchParticipants(
              familyId: widget.preparedSession.instance.familyId,
              instanceId: widget.preparedSession.instance.id,
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
            : 'We could not open the Ready Room.';
      });
    }
  }

  Future<void> _startSession(MomentInstance instance) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isStarting || _isLeaving) {
      return;
    }

    if (!familyContext.isAdult) {
      _showMessage('An adult or family admin must start the timer.');
      return;
    }

    setState(() {
      _isStarting = true;
    });

    try {
      if (widget.saveDefinitionBeforeStart && !_definitionSaved) {
        await AppDependencies.calendarRepository.saveMoment(widget.moment);
        _definitionSaved = true;
      }

      final active = await AppDependencies.momentInstanceRepository
          .startMomentNow(
            moment: widget.moment,
            startedBy: familyContext.userId,
            source: widget.source,
            existingInstanceId: instance.id,
          );

      try {
        await _preparationService.clearPreparationMetadata(
          familyId: active.familyId,
          instanceId: active.id,
        );
      } catch (_) {
        // Preparation metadata does not affect the active session. It can be
        // cleaned up later if the best-effort removal fails.
      }

      _returnActiveSession(active);
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'We could not start this Moment.',
      );
    } finally {
      if (mounted && !_returnedActiveSession) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _joinReadyRoom(MomentInstance instance) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isJoining || _isStarting || _isLeaving) {
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      await _preparationService.joinReadyRoom(
        familyId: instance.familyId,
        instanceId: instance.id,
        memberId: familyContext.userId,
      );

      if (mounted) {
        setState(() {
          _hasJoinedReadyRoom = true;
        });
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error is StateError
            ? error.message.toString()
            : 'We could not join this Ready Room.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _leaveReadyRoom() async {
    if (_isLeaving || _returnedActiveSession) {
      return;
    }

    setState(() {
      _isLeaving = true;
    });

    try {
      final familyContext = _familyContext;

      if (familyContext != null) {
        final isHost =
            familyContext.userId == widget.preparedSession.preparedBy;

        if (isHost) {
          await _preparationService.cancelPreparation(
            familyId: widget.preparedSession.instance.familyId,
            instanceId: widget.preparedSession.instance.id,
            cancelledBy: familyContext.userId,
          );
        } else {
          await _preparationService.leaveReadyRoom(
            familyId: widget.preparedSession.instance.familyId,
            instanceId: widget.preparedSession.instance.id,
            memberId: familyContext.userId,
          );
        }
      }

      if (widget.saveDefinitionBeforeStart && _definitionSaved) {
        try {
          await AppDependencies.calendarRepository.deleteMoment(
            familyId: widget.moment.familyId,
            momentId: widget.moment.id,
          );
        } catch (_) {
          // The unfinished quick-start definition can still be removed later
          // from the Moment Library. The Ready Room must remain closable.
        }
      }
    } catch (_) {
      if (mounted) {
        _showMessage('The Ready Room closed, but cleanup may finish later.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _allowPop = true;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  void _returnToPreviousScreen() {
    if (_returnedActiveSession || !mounted) {
      return;
    }

    _returnedActiveSession = true;

    setState(() {
      _allowPop = true;
    });

    Navigator.of(context).pop();
  }

  void _returnActiveSession(MomentInstance active) {
    if (_returnedActiveSession || !mounted) {
      return;
    }

    _returnedActiveSession = true;

    setState(() {
      _allowPop = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(active);
      }
    });
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
          child: AppLoadingState(message: 'Opening the Ready Room…'),
        ),
      );
    }

    if (_familyContext == null ||
        _instanceStream == null ||
        _participantsStream == null ||
        _membersStream == null) {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'The Ready Room is unavailable.',
            onRetry: _loadWaitingRoom,
          ),
        ),
      );
    }

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_leaveReadyRoom());
        }
      },
      child: StreamBuilder<MomentInstance?>(
        stream: _instanceStream,
        builder: (context, instanceSnapshot) {
          if (instanceSnapshot.hasError) {
            return _errorScaffold('We could not update this Ready Room.');
          }

          if (instanceSnapshot.connectionState == ConnectionState.waiting &&
              !instanceSnapshot.hasData) {
            return const Scaffold(
              body: SafeArea(
                child: AppLoadingState(message: 'Waiting for the family…'),
              ),
            );
          }

          final instance = instanceSnapshot.data;

          if (instance == null) {
            return _errorScaffold('This Ready Room no longer exists.');
          }

          if (instance.status == MomentInstanceStatus.active) {
            final isHost =
                _familyContext!.userId == widget.preparedSession.preparedBy;

            if (!_returnedActiveSession) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (isHost || _hasJoinedReadyRoom) {
                  _returnActiveSession(instance);
                } else {
                  _returnToPreviousScreen();
                }
              });
            }

            return Scaffold(
              body: SafeArea(
                child: AppLoadingState(
                  message: isHost || _hasJoinedReadyRoom
                      ? 'Opening the live Moment…'
                      : 'The session started. Join it from Home when ready.',
                ),
              ),
            );
          }

          if (instance.status == MomentInstanceStatus.cancelled ||
              instance.status == MomentInstanceStatus.missed) {
            return _errorScaffold('This Ready Room has been closed.');
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

                  return _buildWaitingRoom(
                    instance: instance,
                    members: members,
                    participants: participants,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Scaffold _buildWaitingRoom({
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

    final expectedMembers =
        instance.expectedParticipantIds
            .map((id) => membersById[id])
            .whereType<Member>()
            .toList()
          ..sort(
            (first, second) => first.displayName.compareTo(second.displayName),
          );

    final isHost = familyContext.userId == widget.preparedSession.preparedBy;
    final currentParticipant = participantsById[familyContext.userId];
    final currentUserJoined =
        _hasJoinedReadyRoom ||
        currentParticipant?.state == ParticipantMomentState.ready ||
        currentParticipant?.state == ParticipantMomentState.checkedIn;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back to preview',
          onPressed: _isLeaving || _isStarting ? null : _leaveReadyRoom,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Ready Room'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            116,
          ),
          children: [
            Text(
              'Ready to start?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Center(child: _ReadyPulseArtwork()),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.circle,
                      size: 11,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waiting for family',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The timer has not started yet. Begin whenever the family is ready.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expected members',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (expectedMembers.isEmpty)
                    const Text('No active family members could be loaded.')
                  else
                    ...expectedMembers.map((member) {
                      final participant = participantsById[member.id];
                      final visual = _statusFor(
                        member: member,
                        participant: participant,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
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
                              child: Text(
                                member.displayName,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(visual.icon, size: 17, color: visual.color),
                            const SizedBox(width: 6),
                            Text(
                              visual.label,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: visual.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: isHost
            ? FilledButton(
                onPressed: _isStarting || _isJoining || _isLeaving
                    ? null
                    : () {
                        _startSession(instance);
                      },
                child: _isStarting
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Start Session'),
              )
            : currentUserJoined
            ? FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Joined'),
              )
            : FilledButton.icon(
                onPressed: _isJoining || _isStarting || _isLeaving
                    ? null
                    : () {
                        _joinReadyRoom(instance);
                      },
                icon: _isJoining
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_isJoining ? 'Joining…' : 'Join Session'),
              ),
      ),
    );
  }

  _ReadyStatusVisual _statusFor({
    required Member member,
    required MomentParticipant? participant,
  }) {
    if (member.id == widget.preparedSession.preparedBy) {
      return const _ReadyStatusVisual(
        label: 'Host ready',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        presence: SakanMemberPresence.none,
      );
    }

    if (participant?.state == ParticipantMomentState.ready ||
        participant?.state == ParticipantMomentState.checkedIn) {
      return const _ReadyStatusVisual(
        label: 'Joined',
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        presence: SakanMemberPresence.ready,
      );
    }

    if (participant?.state == ParticipantMomentState.nearby ||
        participant?.nearbyDetectedAt != null) {
      return const _ReadyStatusVisual(
        label: 'Nearby',
        icon: Icons.bluetooth_connected_rounded,
        color: AppColors.info,
        presence: SakanMemberPresence.nearby,
      );
    }

    if (participant?.state == ParticipantMomentState.declined) {
      return const _ReadyStatusVisual(
        label: 'Unavailable',
        icon: Icons.remove_circle_outline_rounded,
        color: AppColors.secondary,
        presence: SakanMemberPresence.unknown,
      );
    }

    return const _ReadyStatusVisual(
      label: 'Waiting',
      icon: Icons.hourglass_empty_rounded,
      color: AppColors.textSecondary,
      presence: SakanMemberPresence.unknown,
    );
  }

  Scaffold _errorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _leaveReadyRoom,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: AppErrorState(message: message, onRetry: _loadWaitingRoom),
      ),
    );
  }
}

class _ReadyPulseArtwork extends StatefulWidget {
  const _ReadyPulseArtwork();

  @override
  State<_ReadyPulseArtwork> createState() => _ReadyPulseArtworkState();
}

class _ReadyPulseArtworkState extends State<_ReadyPulseArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SizedBox.square(
      dimension: 224,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (!animationsDisabled) ...[
                _PulseRing(progress: _phase(0)),
                _PulseRing(progress: _phase(0.34)),
                _PulseRing(progress: _phase(0.68)),
              ] else
                Container(
                  width: 205,
                  height: 205,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withAlpha(25),
                      width: 2,
                    ),
                  ),
                ),
              Container(
                width: 172,
                height: 172,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8EEDB),
                ),
                child: Image.asset(
                  'assets/images/sakan_birds.png',
                  width: 148,
                  height: 148,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) {
                    return const Icon(
                      Icons.flutter_dash_rounded,
                      size: 72,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _phase(double offset) {
    final value = _controller.value + offset;
    return value >= 1 ? value - 1 : value;
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = 174 + (46 * progress);
    final opacity = (1 - progress) * 0.22;

    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2.2 - progress),
        ),
      ),
    );
  }
}

class _ReadyStatusVisual {
  const _ReadyStatusVisual({
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
