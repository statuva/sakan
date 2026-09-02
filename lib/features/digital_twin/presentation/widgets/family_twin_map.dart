import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/member.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/models/moment_instance.dart';
import '../../../../shared/models/rhythm_record.dart';
import '../../../../shared/widgets/people/sakan_member_avatar.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';
import '../../domain/twin_simulation_result.dart';
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
    this.simulation,
    super.key,
  });

  final FamilyInsightReport report;
  final DigitalTwinSimulationResult? simulation;
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

    widget.onMomentTap(node.moment, node.rhythm, node.instances);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.report.snapshot;
    final members = _visibleMembers();
    final moments = _visibleRecurringMoments();
    final displayMomentCount = _allDisplayMoments()
        .where((moment) => moment.type == MomentType.recurring)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.simulation == null
              ? CalendarPalette.border
              : CalendarPalette.milestone.withAlpha(95),
        ),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Family Moment Map',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: CalendarPalette.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (widget.simulation != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: CalendarPalette.milestoneSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'SIMULATED',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: CalendarPalette.milestone,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                    ),
                              ),
                            ),
                          ],
                        ],
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
                      final canvasSize = Size(constraints.maxWidth, 330);

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
                            transformationController: _transformationController,
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
                                      onTap: () => _selectMember(node.member),
                                    ),
                                  ),
                                  ...layout.momentNodes.map(
                                    (node) => _MomentNodeWidget(
                                      node: node,
                                      selectedNodeKey: _selectedNodeKey,
                                      connected: _momentIsConnected(
                                        node.moment,
                                      ),
                                      onTap: () => _selectMoment(node),
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
                  children: [
                    const _LegendDot(
                      color: CalendarPalette.stable,
                      label: 'Stable',
                    ),
                    const _LegendDot(
                      color: CalendarPalette.drifting,
                      label: 'Drifting',
                    ),
                    const _LegendDot(
                      color: CalendarPalette.recovering,
                      label: 'Recovering',
                    ),
                    const _LegendDot(
                      color: CalendarPalette.strengthening,
                      label: 'Strengthening',
                    ),
                    const _LegendDot(
                      color: CalendarPalette.slate,
                      label: 'Still Learning',
                    ),
                    if (widget.simulation != null)
                      const _LegendDashed(
                        color: CalendarPalette.milestone,
                        label: 'Simulated change',
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  widget.simulation == null
                      ? 'Connections stay quiet until a member or Moment is selected.'
                      : 'Gold outlines and dashed connections exist only in this simulation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CalendarPalette.inkSoft,
                  ),
                ),
                if (snapshot.activeMembers.length > members.length ||
                    displayMomentCount > moments.length) ...[
                  const SizedBox(height: 3),
                  Text(
                    'The map shows a focused set of nodes. Changed nodes are kept visible.',
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

  List<FamilyMoment> _allDisplayMoments() {
    return widget.simulation?.simulatedMoments ??
        widget.report.snapshot.moments;
  }

  List<Member> _visibleMembers() {
    final members = widget.report.snapshot.activeMembers.toList()
      ..sort(
        (first, second) => first.displayName.compareTo(second.displayName),
      );

    final simulation = widget.simulation;

    if (simulation == null) {
      return members.take(6).toList(growable: false);
    }

    final changed = members
        .where((member) => simulation.changedMemberIds.contains(member.id))
        .toList(growable: false);

    final unchanged = members
        .where((member) => !simulation.changedMemberIds.contains(member.id))
        .toList(growable: false);

    return <Member>[...changed, ...unchanged].take(6).toList(growable: false);
  }

  List<FamilyMoment> _visibleRecurringMoments() {
    final moments = _allDisplayMoments()
        .where((moment) => moment.type == MomentType.recurring)
        .toList();

    moments.sort((first, second) {
      final simulation = widget.simulation;
      final firstChanged =
          simulation?.changedMomentIds.contains(first.id) ?? false;
      final secondChanged =
          simulation?.changedMomentIds.contains(second.id) ?? false;

      if (firstChanged != secondChanged) {
        return firstChanged ? -1 : 1;
      }

      final statusResult = _rhythmRank(
        _displayStatus(first),
      ).compareTo(_rhythmRank(_displayStatus(second)));

      if (statusResult != 0) {
        return statusResult;
      }

      return first.title.compareTo(second.title);
    });

    return moments.take(8).toList(growable: false);
  }

  RhythmStatus _displayStatus(FamilyMoment moment) {
    final pattern = widget.simulation?.patternForMoment(moment.id);

    return pattern?.projectedStatus ??
        widget.report.snapshot.rhythmForMoment(moment.id)?.status ??
        RhythmStatus.stillLearning;
  }

  bool _memberIsConnected(Member member, List<_MomentNode> momentNodes) {
    final selected = _selectedNodeKey;

    if (selected == null || selected == 'member:${member.id}') {
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

    if (selected == null || selected == 'moment:${moment.id}') {
      return true;
    }

    if (!selected.startsWith('member:')) {
      return false;
    }

    final selectedMemberId = selected.substring('member:'.length);
    return moment.expectedParticipantIds.contains(selectedMemberId);
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
    final simulation = widget.simulation;

    final visibleMemberIndex = <String, int>{
      for (var index = 0; index < members.length; index++)
        members[index].id: index,
    };

    final orderedMoments = List<FamilyMoment>.from(moments)
      ..sort((first, second) {
        final firstChanged =
            simulation?.changedMomentIds.contains(first.id) ?? false;
        final secondChanged =
            simulation?.changedMomentIds.contains(second.id) ?? false;

        if (firstChanged != secondChanged) {
          return firstChanged ? -1 : 1;
        }

        final firstCenter = _connectionCenter(first, visibleMemberIndex);
        final secondCenter = _connectionCenter(second, visibleMemberIndex);
        final result = firstCenter.compareTo(secondCenter);

        return result != 0 ? result : first.title.compareTo(second.title);
      });

    final memberLeft = 38.0;
    final memberRight = size.width - 38.0;

    for (var index = 0; index < members.length; index++) {
      final member = members[index];

      memberNodes.add(
        _MemberNode(
          member: member,
          center: Offset(
            _distributedPosition(
              index: index,
              count: members.length,
              start: memberLeft,
              end: memberRight,
            ),
            74,
          ),
          color: sakanMemberAvatarColor(member),
          isChanged: simulation?.changedMemberIds.contains(member.id) ?? false,
        ),
      );
    }

    const columns = 4;

    for (var index = 0; index < orderedMoments.length; index++) {
      final row = index ~/ columns;
      final column = index % columns;
      final countInRow = math
          .min(columns, orderedMoments.length - row * columns)
          .toInt();
      final moment = orderedMoments[index];
      final rhythm = widget.report.snapshot.rhythmForMoment(moment.id);
      final instances = widget.report.snapshot.instancesForMoment(moment.id);
      final status = _displayStatus(moment);

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
            orderedMoments.length <= 4 ? 222.0 : 185.0 + row * 92.0,
          ),
          visual: twinRhythmVisual(status),
          isChanged: simulation?.changedMomentIds.contains(moment.id) ?? false,
          isHypothetical:
              simulation?.hypotheticalMomentIds.contains(moment.id) ?? false,
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
            isSimulated: _isSimulatedEdge(
              moment: momentNode.moment,
              memberId: memberId,
            ),
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

  bool _isSimulatedEdge({
    required FamilyMoment moment,
    required String memberId,
  }) {
    final simulation = widget.simulation;

    if (simulation == null) {
      return false;
    }

    final baseMoment = widget.report.snapshot.momentById(moment.id);

    if (baseMoment == null) {
      return true;
    }

    return !baseMoment.expectedParticipantIds.contains(memberId) &&
        moment.expectedParticipantIds.contains(memberId);
  }

  double _connectionCenter(FamilyMoment moment, Map<String, int> memberIndex) {
    final indexes = moment.expectedParticipantIds
        .map((id) => memberIndex[id])
        .whereType<int>()
        .toList(growable: false);

    if (indexes.isEmpty) {
      return 999;
    }

    final total = indexes.fold<int>(0, (sum, value) => sum + value);
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
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
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
    final selected = selectedNodeKey == 'member:${node.member.id}';
    final opacity = selectedNodeKey == null || connected ? 1.0 : 0.28;

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
                        color: node.isChanged
                            ? CalendarPalette.milestone
                            : selected
                            ? CalendarPalette.ink
                            : CalendarPalette.surface,
                        width: node.isChanged || selected ? 3 : 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(selected ? 34 : 18),
                          blurRadius: selected ? 10 : 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _initial(node.member.displayName),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
    final selected = selectedNodeKey == 'moment:${node.moment.id}';
    final opacity = selectedNodeKey == null || connected ? 1.0 : 0.24;

    return Positioned(
      left: node.center.dx - 42,
      top: node.center.dy - 21,
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
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CustomPaint(
                      painter: node.isHypothetical
                          ? const _DashedCirclePainter(
                              color: CalendarPalette.milestone,
                            )
                          : null,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: node.visual.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: node.isChanged && !node.isHypothetical
                                  ? CalendarPalette.milestone
                                  : selected
                                  ? CalendarPalette.ink
                                  : CalendarPalette.surface,
                              width: node.isChanged || selected ? 3 : 2.5,
                            ),
                          ),
                          child: Icon(
                            twinCategoryIcon(node.moment.category),
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    node.moment.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
      final vector = edge.end - edge.start;
      final distance = vector.distance;

      if (distance <= 1) {
        continue;
      }

      final direction = vector / distance;
      final start = edge.start + direction * 23;
      final end = edge.end - direction * 18;

      if (edge.isSimulated) {
        final paint = Paint()
          ..color = CalendarPalette.milestone.withAlpha(
            selectedNodeKey == null || selected ? 190 : 38,
          )
          ..strokeWidth = selected ? 2.2 : 1.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        _drawDashedLine(canvas, start, end, paint);
        continue;
      }

      final alpha = selectedNodeKey == null
          ? 28
          : selected
          ? 175
          : 8;

      final paint = Paint()
        ..color = edge.color.withAlpha(alpha)
        ..strokeWidth = selected ? 1.8 : 0.9
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final vector = end - start;
    final distance = vector.distance;

    if (distance <= 1) {
      return;
    }

    final direction = vector / distance;
    var drawn = 0.0;
    const dashLength = 6.0;
    const gapLength = 4.0;

    while (drawn < distance) {
      final dashEnd = math.min(drawn + dashLength, distance);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * dashEnd,
        paint,
      );
      drawn += dashLength + gapLength;
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
  bool shouldRepaint(covariant _FocusedEdgePainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.selectedNodeKey != selectedNodeKey;
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()..addOval(rect.deflate(1.5));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;

      while (distance < metric.length) {
        final end = math.min(distance + 5, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: CalendarPalette.inkSoft),
        ),
      ],
    );
  }
}

class _LegendDashed extends StatelessWidget {
  const _LegendDashed({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 8,
          child: CustomPaint(painter: _MiniDashedPainter(color: color)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: CalendarPalette.inkSoft),
        ),
      ],
    );
  }
}

class _MiniDashedPainter extends CustomPainter {
  const _MiniDashedPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(5, size.height / 2),
      paint,
    );
    canvas.drawLine(
      Offset(9, size.height / 2),
      Offset(15, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniDashedPainter oldDelegate) {
    return oldDelegate.color != color;
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
    required this.isChanged,
  });

  final Member member;
  final Offset center;
  final Color color;
  final bool isChanged;
}

class _MomentNode {
  const _MomentNode({
    required this.moment,
    required this.rhythm,
    required this.instances,
    required this.center,
    required this.visual,
    required this.isChanged,
    required this.isHypothetical,
  });

  final FamilyMoment moment;
  final RhythmRecord? rhythm;
  final List<MomentInstance> instances;
  final Offset center;
  final TwinStatusVisual visual;
  final bool isChanged;
  final bool isHypothetical;
}

class _TwinEdge {
  const _TwinEdge({
    required this.memberId,
    required this.momentId,
    required this.start,
    required this.end,
    required this.color,
    required this.isSimulated,
  });

  final String memberId;
  final String momentId;
  final Offset start;
  final Offset end;
  final Color color;
  final bool isSimulated;
}
