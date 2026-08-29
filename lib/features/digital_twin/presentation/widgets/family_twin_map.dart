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
import '../digital_twin_visuals.dart';

typedef TwinMomentTap =
    void Function(
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

  String? _selectedNodeKey;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetMap() {
    _transformationController.value = Matrix4.identity();

    setState(() {
      _selectedNodeKey = null;
    });
  }

  void _selectMember(Member member) {
    setState(() {
      _selectedNodeKey = 'member:${member.id}';
    });

    widget.onMemberTap(member);
  }

  void _selectMoment(_MomentNode node) {
    setState(() {
      _selectedNodeKey = 'moment:${node.moment.id}';
    });

    widget.onMomentTap(
      node.moment,
      node.rhythm,
      node.instances,
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.report.snapshot;
    final members = snapshot.activeMembers.take(6).toList();
    final moments = _visibleRecurringMoments(widget.report);

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
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Moment Map',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: CalendarPalette.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap a circle to explore. Pinch to zoom and drag to move.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: CalendarPalette.inkSoft,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Reset map',
                  onPressed: _resetMap,
                  icon: const Icon(Icons.center_focus_strong_outlined),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: CalendarPalette.border),
          SizedBox(
            height: 330,
            child: members.isEmpty || moments.isEmpty
                ? const _EmptyMap()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasSize = Size(
                        constraints.maxWidth,
                        330,
                      );

                      final layout = _buildLayout(
                        size: canvasSize,
                        members: members,
                        moments: moments,
                      );

                      return ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(21),
                        ),
                        child: RepaintBoundary(
                          child: InteractiveViewer(
                            transformationController:
                                _transformationController,
                            boundaryMargin: const EdgeInsets.all(70),
                            minScale: 0.9,
                            maxScale: 2.4,
                            panEnabled: true,
                            scaleEnabled: true,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: canvasSize.width,
                              height: canvasSize.height,
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _FocusedEdgePainter(
                                        edges: layout.edges,
                                        selectedNodeKey: _selectedNodeKey,
                                      ),
                                    ),
                                  ),
                                  ...layout.memberNodes.map(
                                    (node) => _MemberNodeWidget(
                                      node: node,
                                      selectedNodeKey: _selectedNodeKey,
                                      connected: _memberIsConnected(
                                        node.member,
                                        layout.momentNodes,
                                      ),
                                      onTap: () {
                                        _selectMember(node.member);
                                      },
                                    ),
                                  ),
                                  ...layout.momentNodes.map(
                                    (node) => _MomentNodeWidget(
                                      node: node,
                                      selectedNodeKey: _selectedNodeKey,
                                      connected:
                                          _momentIsConnected(node.moment),
                                      onTap: () {
                                        _selectMoment(node);
                                      },
                                    ),
                                  ),
                                ],
                              ),
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
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Connections stay quiet until a member or Moment is selected.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CalendarPalette.inkSoft,
                      ),
                ),
                if (snapshot.activeMembers.length > members.length ||
                    snapshot.moments
                            .where(
                              (moment) =>
                                  moment.type == MomentType.recurring,
                            )
                            .length >
                        moments.length) ...[
                  const SizedBox(height: 3),
                  Text(
                    'The map shows a focused set of nodes. All recurring Moment patterns remain listed below.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CalendarPalette.inkSoft,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _memberIsConnected(
    Member member,
    List<_MomentNode> momentNodes,
  ) {
    final selected = _selectedNodeKey;

    if (selected == null) {
      return true;
    }

    if (selected == 'member:${member.id}') {
      return true;
    }

    if (!selected.startsWith('moment:')) {
      return false;
    }

    final selectedMomentId = selected.substring('moment:'.length);

    for (final node in momentNodes) {
      if (node.moment.id == selectedMomentId) {
        return node.moment.expectedParticipantIds.contains(member.id);
      }
    }

    return false;
  }

  bool _momentIsConnected(FamilyMoment moment) {
    final selected = _selectedNodeKey;

    if (selected == null) {
      return true;
    }

    if (selected == 'moment:${moment.id}') {
      return true;
    }

    if (!selected.startsWith('member:')) {
      return false;
    }

    final selectedMemberId = selected.substring('member:'.length);

    return moment.expectedParticipantIds.contains(selectedMemberId);
  }

  List<FamilyMoment> _visibleRecurringMoments(
    FamilyInsightReport report,
  ) {
    final snapshot = report.snapshot;

    final moments = snapshot.moments
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

    return moments.take(8).toList(growable: false);
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

    final visibleMemberIndex = <String, int>{
      for (var index = 0; index < members.length; index++)
        members[index].id: index,
    };

    final orderedMoments = List<FamilyMoment>.from(moments)
      ..sort((first, second) {
        final firstCenter = _connectionCenter(
          first,
          visibleMemberIndex,
        );

        final secondCenter = _connectionCenter(
          second,
          visibleMemberIndex,
        );

        final result = firstCenter.compareTo(secondCenter);

        if (result != 0) {
          return result;
        }

        return first.title.compareTo(second.title);
      });

    final memberLeft = 38.0;
    final memberRight = size.width - 38.0;

    for (var index = 0; index < members.length; index++) {
      memberNodes.add(
        _MemberNode(
          member: members[index],
          center: Offset(
            _distributedPosition(
              index: index,
              count: members.length,
              start: memberLeft,
              end: memberRight,
            ),
            74,
          ),
          color: _memberColor(index),
        ),
      );
    }

    const columns = 4;

    for (var index = 0; index < orderedMoments.length; index++) {
      final row = index ~/ columns;
      final column = index % columns;

      final countInRow = math.min(
        columns,
        orderedMoments.length - row * columns,
      ).toInt();

      final moment = orderedMoments[index];
      final rhythm =
          widget.report.snapshot.rhythmForMoment(moment.id);
      final instances =
          widget.report.snapshot.instancesForMoment(moment.id);

      momentNodes.add(
        _MomentNode(
          moment: moment,
          rhythm: rhythm,
          instances: instances,
          center: Offset(
            _distributedPosition(
              index: column,
              count: countInRow,
              start: 46,
              end: size.width - 46,
            ),
            orderedMoments.length <= 4
                ? 222.0
                : 185.0 + row * 92.0,
          ),
          visual: twinRhythmVisual(
            rhythm?.status ?? RhythmStatus.stillLearning,
          ),
        ),
      );
    }

    final memberById = <String, _MemberNode>{
      for (final node in memberNodes) node.member.id: node,
    };

    final edges = <_TwinEdge>[];

    for (final momentNode in momentNodes) {
      for (final memberId in momentNode.moment.expectedParticipantIds) {
        final memberNode = memberById[memberId];

        if (memberNode == null) {
          continue;
        }

        edges.add(
          _TwinEdge(
            memberId: memberId,
            momentId: momentNode.moment.id,
            start: memberNode.center,
            end: momentNode.center,
            color: momentNode.visual.color,
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

  double _connectionCenter(
    FamilyMoment moment,
    Map<String, int> memberIndex,
  ) {
    final indexes = moment.expectedParticipantIds
        .map((id) => memberIndex[id])
        .whereType<int>()
        .toList(growable: false);

    if (indexes.isEmpty) {
      return 999;
    }

    final total = indexes.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    return total / indexes.length;
  }

  double _distributedPosition({
    required int index,
    required int count,
    required double start,
    required double end,
  }) {
    if (count <= 1) {
      return (start + end) / 2;
    }

    return start + ((end - start) * index / (count - 1));
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
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Add recurring Family Moments and members to build the map.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CalendarPalette.inkSoft,
              ),
        ),
      ),
    );
  }
}

class _MemberNodeWidget extends StatelessWidget {
  const _MemberNodeWidget({
    required this.node,
    required this.selectedNodeKey,
    required this.connected,
    required this.onTap,
  });

  final _MemberNode node;
  final String? selectedNodeKey;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected =
        selectedNodeKey == 'member:${node.member.id}';

    final opacity =
        selectedNodeKey == null || connected ? 1.0 : 0.28;

    return Positioned(
      left: node.center.dx - 34,
      top: node.center.dy - 23,
      width: 68,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Semantics(
            button: true,
            label: 'Open ${node.member.displayName}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: node.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? CalendarPalette.ink
                            : CalendarPalette.surface,
                        width: selected ? 3 : 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(
                            selected ? 34 : 18,
                          ),
                          blurRadius: selected ? 10 : 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _initial(node.member.displayName),
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
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
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: CalendarPalette.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                  ),
                ],
              ),
            ),
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
    required this.selectedNodeKey,
    required this.connected,
    required this.onTap,
  });

  final _MomentNode node;
  final String? selectedNodeKey;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected =
        selectedNodeKey == 'moment:${node.moment.id}';

    final opacity =
        selectedNodeKey == null || connected ? 1.0 : 0.24;

    return Positioned(
      left: node.center.dx - 42,
      top: node.center.dy - 18,
      width: 84,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Semantics(
            button: true,
            label: 'Open ${node.moment.title}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: node.visual.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? CalendarPalette.ink
                            : CalendarPalette.surface,
                        width: selected ? 3 : 2.5,
                      ),
                    ),
                    child: Icon(
                      twinCategoryIcon(node.moment.category),
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    node.moment.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: CalendarPalette.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 8.8,
                              height: 1.08,
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusedEdgePainter extends CustomPainter {
  const _FocusedEdgePainter({
    required this.edges,
    required this.selectedNodeKey,
  });

  final List<_TwinEdge> edges;
  final String? selectedNodeKey;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final selected = _edgeIsSelected(edge);

      final alpha = selectedNodeKey == null
          ? 28
          : selected
              ? 175
              : 8;

      final width = selected ? 1.8 : 0.9;
      final vector = edge.end - edge.start;
      final distance = vector.distance;

      if (distance <= 1) {
        continue;
      }

      final direction = vector / distance;
      final start = edge.start + direction * 23;
      final end = edge.end - direction * 18;

      final paint = Paint()
        ..color = edge.color.withAlpha(alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, end, paint);
    }
  }

  bool _edgeIsSelected(_TwinEdge edge) {
    final selected = selectedNodeKey;

    if (selected == null) {
      return false;
    }

    return selected == 'member:${edge.memberId}' ||
        selected == 'moment:${edge.momentId}';
  }

  @override
  bool shouldRepaint(
    covariant _FocusedEdgePainter oldDelegate,
  ) {
    return oldDelegate.edges != edges ||
        oldDelegate.selectedNodeKey != selectedNodeKey;
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: CalendarPalette.inkSoft,
              ),
        ),
      ],
    );
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
  final TwinStatusVisual visual;
}

class _TwinEdge {
  const _TwinEdge({
    required this.memberId,
    required this.momentId,
    required this.start,
    required this.end,
    required this.color,
  });

  final String memberId;
  final String momentId;
  final Offset start;
  final Offset end;
  final Color color;
}
