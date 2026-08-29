import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/member.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/models/moment_instance.dart';
import '../../../../shared/models/rhythm_record.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';

typedef TwinMomentTap = void Function(
  FamilyMoment moment,
  RhythmRecord? rhythm,
  List<MomentInstance> instances,
);

class FamilyTwinMap extends StatefulWidget {
  const FamilyTwinMap({
    required this.report,
    required this.onMemberTap,
    required this.onMomentTap,
    super.key,
  });

  final FamilyInsightReport report;
  final ValueChanged<Member> onMemberTap;
  final TwinMomentTap onMomentTap;

  @override
  State<FamilyTwinMap> createState() => _FamilyTwinMapState();
}

class _FamilyTwinMapState extends State<FamilyTwinMap> {
  final TransformationController _transformationController =
      TransformationController();

  final Map<String, Offset> _positionOverrides = <String, Offset>{};

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetView() {
    setState(() {
      _positionOverrides.clear();
      _transformationController.value = Matrix4.identity();
    });
  }

  void _moveNode({
    required String key,
    required Offset currentCenter,
    required Offset screenDelta,
    required Size canvasSize,
  }) {
    final scale = math
        .max(
          0.01,
          _transformationController.value.getMaxScaleOnAxis(),
        )
        .toDouble();

    final candidate = currentCenter + screenDelta / scale;

    final clamped = Offset(
      candidate.dx.clamp(34.0, canvasSize.width - 34.0).toDouble(),
      candidate.dy.clamp(30.0, canvasSize.height - 58.0).toDouble(),
    );

    setState(() {
      _positionOverrides[key] = clamped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.report.snapshot;
    final members = snapshot.activeMembers;
    final moments = _visibleMoments(widget.report);

    return Container(
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Moment Map',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: CalendarPalette.ink,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Drag circles to rearrange, drag the map to move, and pinch to zoom.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: CalendarPalette.inkSoft),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Reset map',
                  onPressed: _resetView,
                  icon: const Icon(Icons.center_focus_strong_outlined),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: CalendarPalette.border),
          SizedBox(
            height: 355,
            child: members.isEmpty || moments.isEmpty
                ? const _EmptyMap()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasWidth = math.max(
                        constraints.maxWidth,
                        620.0,
                      );

                      const canvasHeight = 355.0;

                      final layout = _buildLayout(
                        size: Size(canvasWidth, canvasHeight),
                        members: members,
                        moments: moments,
                      );

                      return ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(21),
                        ),
                        child: InteractiveViewer(
                          transformationController:
                              _transformationController,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(110),
                          minScale: 0.72,
                          maxScale: 2.6,
                          panEnabled: true,
                          scaleEnabled: true,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: canvasWidth,
                            height: canvasHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _TwinGraphPainter(
                                      edges: layout.edges,
                                    ),
                                  ),
                                ),
                                ...layout.memberNodes.map(
                                  (node) => _MemberNodeWidget(
                                    node: node,
                                    onTap: () {
                                      widget.onMemberTap(node.member);
                                    },
                                    onMove: (delta) {
                                      _moveNode(
                                        key: 'member:${node.member.id}',
                                        currentCenter: node.center,
                                        screenDelta: delta,
                                        canvasSize: Size(
                                          canvasWidth,
                                          canvasHeight,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                ...layout.momentNodes.map(
                                  (node) => _MomentNodeWidget(
                                    node: node,
                                    onTap: () {
                                      widget.onMomentTap(
                                        node.moment,
                                        node.rhythm,
                                        node.instances,
                                      );
                                    },
                                    onMove: (delta) {
                                      _moveNode(
                                        key: 'moment:${node.moment.id}',
                                        currentCenter: node.center,
                                        screenDelta: delta,
                                        canvasSize: Size(
                                          canvasWidth,
                                          canvasHeight,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: const [
                    _LegendDot(
                      color: CalendarPalette.stable,
                      label: 'Stable',
                    ),
                    _LegendDot(
                      color: CalendarPalette.drifting,
                      label: 'Drifting',
                    ),
                    _LegendDot(
                      color: CalendarPalette.recovering,
                      label: 'Recovering',
                    ),
                    _LegendDot(
                      color: CalendarPalette.strengthening,
                      label: 'Strengthening',
                    ),
                    _LegendDot(
                      color: CalendarPalette.slate,
                      label: 'Still Learning',
                    ),
                    _LegendDot(
                      color: CalendarPalette.upcoming,
                      label: 'Upcoming',
                    ),
                    _LegendDot(
                      color: CalendarPalette.missed,
                      label: 'Missed',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Solid lines show expected participation. Dashed lines mark a drifting recurring Moment.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: CalendarPalette.inkSoft),
                ),
                if (snapshot.moments.length > moments.length) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Showing ${moments.length} of ${snapshot.moments.length} Moments to keep the map readable.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: CalendarPalette.inkSoft),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FamilyMoment> _visibleMoments(
    FamilyInsightReport report,
  ) {
    final snapshot = report.snapshot;

    final recurring = snapshot.moments
        .where((moment) => moment.type == MomentType.recurring)
        .toList()
      ..sort((first, second) {
        final firstRhythm = snapshot.rhythmForMoment(first.id);
        final secondRhythm = snapshot.rhythmForMoment(second.id);

        final statusResult = _rhythmRank(
          firstRhythm?.status ?? RhythmStatus.stillLearning,
        ).compareTo(
          _rhythmRank(
            secondRhythm?.status ?? RhythmStatus.stillLearning,
          ),
        );

        if (statusResult != 0) {
          return statusResult;
        }

        return first.title.compareTo(second.title);
      });

    final oneTime = snapshot.moments
        .where((moment) => moment.type == MomentType.singular)
        .toList()
      ..sort((first, second) {
        final firstInstance = _nearestInstanceForMoment(
          report,
          first.id,
        );
        final secondInstance = _nearestInstanceForMoment(
          report,
          second.id,
        );

        final firstDate = firstInstance?.effectiveStartAt ?? first.startAt;
        final secondDate =
            secondInstance?.effectiveStartAt ?? second.startAt;

        return firstDate.compareTo(secondDate);
      });

    return <FamilyMoment>[
      ...recurring,
      ...oneTime,
    ].take(12).toList(growable: false);
  }

  MomentInstance? _nearestInstanceForMoment(
    FamilyInsightReport report,
    String momentId,
  ) {
    final instances = report.snapshot.instancesForMoment(momentId);

    if (instances.isEmpty) {
      return null;
    }

    final now = report.snapshot.generatedAt.toLocal();
    final open = instances.where((instance) => instance.isOpen).toList()
      ..sort((first, second) {
        final firstDistance = first.effectiveStartAt
            .toLocal()
            .difference(now)
            .inMilliseconds
            .abs();
        final secondDistance = second.effectiveStartAt
            .toLocal()
            .difference(now)
            .inMilliseconds
            .abs();
        return firstDistance.compareTo(secondDistance);
      });

    if (open.isNotEmpty) {
      return open.first;
    }

    final newest = List<MomentInstance>.from(instances)
      ..sort(
        (first, second) =>
            second.effectiveStartAt.compareTo(first.effectiveStartAt),
      );

    return newest.first;
  }

  int _rhythmRank(RhythmStatus status) {
    return switch (status) {
      RhythmStatus.drifting => 0,
      RhythmStatus.recovering => 1,
      RhythmStatus.stillLearning => 2,
      RhythmStatus.stable => 3,
      RhythmStatus.strengthening => 4,
    };
  }

  _TwinMapLayout _buildLayout({
    required Size size,
    required List<Member> members,
    required List<FamilyMoment> moments,
  }) {
    final memberNodes = <_MemberNode>[];
    final momentNodes = <_MomentNode>[];

    final center = Offset(size.width / 2, size.height / 2 - 4);
    final memberRadiusX = size.width * 0.39;
    final memberRadiusY = size.height * 0.34;

    for (var index = 0; index < members.length; index++) {
      final angle = -math.pi / 2 +
          (2 * math.pi * index / math.max(1, members.length));

      final defaultPosition = Offset(
        center.dx + math.cos(angle) * memberRadiusX,
        center.dy + math.sin(angle) * memberRadiusY,
      );

      final position =
          _positionOverrides['member:${members[index].id}'] ??
          defaultPosition;

      memberNodes.add(
        _MemberNode(
          member: members[index],
          center: position,
          color: _memberColor(index),
        ),
      );
    }

    final innerCount = math.min(6, moments.length).toInt();
    final outerCount = moments.length - innerCount;

    for (var index = 0; index < moments.length; index++) {
      final isInner = index < innerCount;
      final ringIndex = isInner ? index : index - innerCount;
      final ringCount = isInner ? innerCount : outerCount;
      final angleOffset = isInner ? 0.35 : 0.05;
      final angle = -math.pi / 2 +
          angleOffset +
          (2 * math.pi * ringIndex / math.max(1, ringCount));

      final radiusX = isInner ? size.width * 0.16 : size.width * 0.27;
      final radiusY = isInner ? size.height * 0.19 : size.height * 0.28;

      final moment = moments[index];
      final instances = widget.report.snapshot.instancesForMoment(moment.id);
      final rhythm = widget.report.snapshot.rhythmForMoment(moment.id);
      final visual = _momentVisual(
        moment: moment,
        rhythm: rhythm,
        instances: instances,
      );

      final defaultPosition = Offset(
        center.dx + math.cos(angle) * radiusX,
        center.dy + math.sin(angle) * radiusY,
      );

      momentNodes.add(
        _MomentNode(
          moment: moment,
          rhythm: rhythm,
          instances: instances,
          center:
              _positionOverrides['moment:${moment.id}'] ?? defaultPosition,
          visual: visual,
        ),
      );
    }

    final membersById = <String, _MemberNode>{
      for (final node in memberNodes) node.member.id: node,
    };

    final edges = <_TwinEdge>[];

    for (final momentNode in momentNodes) {
      for (final memberId in momentNode.moment.expectedParticipantIds) {
        final memberNode = membersById[memberId];

        if (memberNode == null) {
          continue;
        }

        edges.add(
          _TwinEdge(
            start: memberNode.center,
            end: momentNode.center,
            color: momentNode.visual.color,
            dashed: momentNode.rhythm?.status == RhythmStatus.drifting,
          ),
        );
      }
    }

    return _TwinMapLayout(
      memberNodes: memberNodes,
      momentNodes: momentNodes,
      edges: edges,
    );
  }

  Color _memberColor(int index) {
    const colors = <Color>[
      CalendarPalette.forestDark,
      Color(0xFF2F6FD8),
      Color(0xFF6C3CC8),
      Color(0xFFC32967),
      Color(0xFFA95B00),
      Color(0xFF17877F),
    ];

    return colors[index % colors.length];
  }

  _MomentVisual _momentVisual({
    required FamilyMoment moment,
    required RhythmRecord? rhythm,
    required List<MomentInstance> instances,
  }) {
    if (moment.type == MomentType.recurring) {
      return switch (rhythm?.status ?? RhythmStatus.stillLearning) {
        RhythmStatus.stillLearning => const _MomentVisual(
            color: CalendarPalette.slate,
          ),
        RhythmStatus.stable => const _MomentVisual(
            color: CalendarPalette.stable,
          ),
        RhythmStatus.drifting => const _MomentVisual(
            color: CalendarPalette.drifting,
          ),
        RhythmStatus.recovering => const _MomentVisual(
            color: CalendarPalette.recovering,
          ),
        RhythmStatus.strengthening => const _MomentVisual(
            color: CalendarPalette.strengthening,
          ),
      };
    }

    final newest = List<MomentInstance>.from(instances)
      ..sort(
        (first, second) =>
            second.effectiveStartAt.compareTo(first.effectiveStartAt),
      );

    final status = newest.isEmpty
        ? MomentInstanceStatus.scheduled
        : newest.first.status;

    return switch (status) {
      MomentInstanceStatus.active => const _MomentVisual(
          color: CalendarPalette.strengthening,
        ),
      MomentInstanceStatus.completed => const _MomentVisual(
          color: CalendarPalette.stable,
        ),
      MomentInstanceStatus.missed => const _MomentVisual(
          color: CalendarPalette.missed,
        ),
      _ => const _MomentVisual(
          color: CalendarPalette.upcoming,
        ),
    };
  }
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Add family members and Moments to build the map.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: CalendarPalette.inkSoft),
        ),
      ),
    );
  }
}

class _MemberNodeWidget extends StatelessWidget {
  const _MemberNodeWidget({
    required this.node,
    required this.onTap,
    required this.onMove,
  });

  final _MemberNode node;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: node.center.dx - 43,
      top: node.center.dy - 25,
      width: 86,
      child: Semantics(
        button: true,
        label: 'Open ${node.member.displayName}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onPanUpdate: (details) {
            onMove(details.delta);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: node.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CalendarPalette.surface,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  _initial(node.member.displayName),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                node.member.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                      color: CalendarPalette.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 9.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}

class _MomentNodeWidget extends StatelessWidget {
  const _MomentNodeWidget({
    required this.node,
    required this.onTap,
    required this.onMove,
  });

  final _MomentNode node;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: node.center.dx - 48,
      top: node.center.dy - 18,
      width: 96,
      child: Semantics(
        button: true,
        label: 'Open ${node.moment.title}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onPanUpdate: (details) {
            onMove(details.delta);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: node.visual.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CalendarPalette.surface,
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  _categoryIcon(node.moment.category),
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                node.moment.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                      color: CalendarPalette.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                      height: 1.1,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
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
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: CalendarPalette.inkSoft),
        ),
      ],
    );
  }
}

class _TwinGraphPainter extends CustomPainter {
  const _TwinGraphPainter({required this.edges});

  final List<_TwinEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final vector = edge.end - edge.start;
      final distance = vector.distance;

      if (distance <= 1) {
        continue;
      }

      final direction = vector / distance;
      final start = edge.start + direction * 27;
      final end = edge.end - direction * 20;

      final paint = Paint()
        ..color = edge.color.withAlpha(155)
        ..strokeWidth = 1.45
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (edge.dashed) {
        _drawDashedLine(
          canvas: canvas,
          start: start,
          end: end,
          paint: paint,
        );
      } else {
        canvas.drawLine(start, end, paint);
      }
    }
  }

  void _drawDashedLine({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required Paint paint,
  }) {
    final vector = end - start;
    final distance = vector.distance;

    if (distance <= 1) {
      return;
    }

    final direction = vector / distance;
    const dashLength = 5.0;
    const gapLength = 4.0;

    var travelled = 0.0;

    while (travelled < distance) {
      final dashEnd = math
          .min(
            travelled + dashLength,
            distance,
          )
          .toDouble();

      canvas.drawLine(
        start + direction * travelled,
        start + direction * dashEnd,
        paint,
      );

      travelled += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _TwinGraphPainter oldDelegate) {
    return oldDelegate.edges != edges;
  }
}

class _TwinMapLayout {
  const _TwinMapLayout({
    required this.memberNodes,
    required this.momentNodes,
    required this.edges,
  });

  final List<_MemberNode> memberNodes;
  final List<_MomentNode> momentNodes;
  final List<_TwinEdge> edges;
}

class _MemberNode {
  const _MemberNode({
    required this.member,
    required this.center,
    required this.color,
  });

  final Member member;
  final Offset center;
  final Color color;
}

class _MomentNode {
  const _MomentNode({
    required this.moment,
    required this.rhythm,
    required this.instances,
    required this.center,
    required this.visual,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final List<MomentInstance> instances;
  final Offset center;
  final _MomentVisual visual;
}

class _TwinEdge {
  const _TwinEdge({
    required this.start,
    required this.end,
    required this.color,
    required this.dashed,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final bool dashed;
}

class _MomentVisual {
  const _MomentVisual({required this.color});

  final Color color;
}
