import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../../shared/models/family_moment.dart';
import '../../../../shared/models/member.dart';
import '../../../../shared/models/model_enums.dart';
import '../../../../shared/widgets/controls/app_pill_segmented_control.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';
import '../../domain/twin_simulation_scenario.dart';
import '../../services/twin_ai_scenario_parser.dart';
import 'what_if_ai_conversation_panel.dart';

Future<TwinSimulationScenario?> showWhatIfScenarioSheet({
  required BuildContext context,
  required FamilyInsightReport report,
  required TwinAiScenarioParser parser,
}) {
  return showModalBottomSheet<TwinSimulationScenario>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.64,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return WhatIfScenarioSheet(
            report: report,
            parser: parser,
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

enum _ScenarioBuilderMode { existingMoment, newMoment }

class WhatIfScenarioSheet extends StatefulWidget {
  const WhatIfScenarioSheet({
    required this.report,
    required this.parser,
    required this.scrollController,
    super.key,
  });

  final FamilyInsightReport report;
  final TwinAiScenarioParser parser;
  final ScrollController scrollController;

  @override
  State<WhatIfScenarioSheet> createState() => _WhatIfScenarioSheetState();
}

class _WhatIfScenarioSheetState extends State<WhatIfScenarioSheet> {
  final TextEditingController _newTitleController = TextEditingController();

  _ScenarioBuilderMode _mode = _ScenarioBuilderMode.existingMoment;
  TwinSimulationType _type = TwinSimulationType.addParticipant;
  TwinSimulationScope _scope = TwinSimulationScope.futureOccurrences;

  String? _selectedMomentId;
  String? _selectedParticipantId;

  TimeOfDay _newTime = const TimeOfDay(hour: 18, minute: 0);
  int _newWeekday = DateTime.friday;
  int _newIntervalDays = 7;
  int _assumedDurationMinutes = 60;

  MomentCategory _newCategory = MomentCategory.familyTime;
  bool _newIsDayFlexible = false;
  int _newDayOfMonth = 1;
  int _newMonth = 1;
  final Set<String> _newParticipantIds = <String>{};

  List<FamilyMoment> get _recurringMoments {
    final result = widget.report.snapshot.moments
        .where(
          (moment) => moment.type == MomentType.recurring && !moment.isArchived,
        )
        .toList();

    result.sort((first, second) => first.title.compareTo(second.title));
    return result;
  }

  List<Member> get _members {
    final result = widget.report.snapshot.activeMembers.toList();
    result.sort(
      (first, second) => first.displayName.compareTo(second.displayName),
    );
    return result;
  }

  bool get _canUseAi {
    final currentMember = widget.report.snapshot.currentMember;

    if (currentMember == null || !currentMember.isActive) {
      return false;
    }

    final hasAdultRole =
        currentMember.role == FamilyRole.admin ||
        currentMember.role == FamilyRole.adult;
    final hasAdultAge =
        currentMember.ageGroup == AgeGroup.adult ||
        currentMember.ageGroup == AgeGroup.senior;
    return hasAdultRole && hasAdultAge;
  }

  FamilyMoment? get _selectedMoment {
    final id = _selectedMomentId;

    if (id == null) {
      return null;
    }

    for (final moment in _recurringMoments) {
      if (moment.id == id) {
        return moment;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    final moments = _recurringMoments;
    final members = _members;

    if (moments.isNotEmpty) {
      _selectedMomentId = moments.first.id;
      _newTime = _timeFromMinutes(moments.first.resolvedPreferredStartMinutes);
      _newWeekday =
          moments.first.preferredWeekday ??
          moments.first.startAt.toLocal().weekday;
      _newIntervalDays = _supportedInterval(moments.first.expectedIntervalDays);
    }

    _newParticipantIds.addAll(members.take(2).map((member) => member.id));
    _resetParticipantSelection();
  }

  @override
  void dispose() {
    _newTitleController.dispose();
    super.dispose();
  }

  void _resetParticipantSelection() {
    final options = _participantOptions();
    _selectedParticipantId = options.isEmpty ? null : options.first.id;
  }

  List<Member> _participantOptions() {
    final moment = _selectedMoment;

    if (moment == null) {
      return const <Member>[];
    }

    return switch (_type) {
      TwinSimulationType.addParticipant =>
        _members
            .where(
              (member) => !moment.expectedParticipantIds.contains(member.id),
            )
            .toList(growable: false),
      TwinSimulationType.removeParticipant =>
        _members
            .where(
              (member) => moment.expectedParticipantIds.contains(member.id),
            )
            .toList(growable: false),
      TwinSimulationType.assumeParticipantJoins => _members,
      _ => const <Member>[],
    };
  }

  bool get _showsParticipantPicker {
    return _type == TwinSimulationType.addParticipant ||
        _type == TwinSimulationType.removeParticipant ||
        _type == TwinSimulationType.assumeParticipantJoins;
  }

  bool get _showsScope {
    return _type == TwinSimulationType.addParticipant ||
        _type == TwinSimulationType.removeParticipant ||
        _type == TwinSimulationType.changeTime ||
        _type == TwinSimulationType.changeWeekday ||
        _type == TwinSimulationType.changeDayOfMonth ||
        _type == TwinSimulationType.changeFrequency;
  }

  bool get _supportsFlexibleNewDay {
    return _newIntervalDays == 7 ||
        _newIntervalDays == 14 ||
        _newIntervalDays == 30 ||
        _newIntervalDays == 90;
  }

  Future<void> _pickTime({required bool forNewMoment}) async {
    final initial = forNewMoment
        ? _newTime
        : _timeFromMinutes(
            _selectedMoment?.resolvedPreferredStartMinutes ??
                (_newTime.hour * 60 + _newTime.minute),
          );

    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _newTime = selected;
    });
  }

  void _runSimulation() {
    final scenario = _buildScenario();

    if (scenario == null) {
      return;
    }

    final error = scenario.validate();

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pop(scenario);
  }

  TwinSimulationScenario? _buildScenario() {
    final id = 'what_if_${DateTime.now().microsecondsSinceEpoch}';

    if (_mode == _ScenarioBuilderMode.newMoment) {
      if (_newParticipantIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose at least one participant.')),
        );
        return null;
      }

      return TwinSimulationScenario(
        id: id,
        type: TwinSimulationType.createMoment,
        newTitle: _newTitleController.text,
        newCategory: _newCategory,
        newIntervalDays: _newIntervalDays,
        newStartMinutes: _minutesFromTime(_newTime),
        newWeekday: _newIntervalDays == 7 || _newIntervalDays == 14
            ? _newWeekday
            : null,
        newDayOfMonth:
            _newIntervalDays == 30 ||
                _newIntervalDays == 90 ||
                _newIntervalDays == 365
            ? _newDayOfMonth
            : null,
        newMonth: _newIntervalDays == 365 ? _newMonth : null,
        newIsDayFlexible: _supportsFlexibleNewDay && _newIsDayFlexible,
        participantIds: _newParticipantIds.toList(growable: false),
        scope: TwinSimulationScope.futureOccurrences,
        assumedDurationMinutes: _assumedDurationMinutes,
      );
    }

    if (_selectedMoment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a recurring Family Moment.')),
      );
      return null;
    }

    if (_showsParticipantPicker && _selectedParticipantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No eligible family member is available for this change.',
          ),
        ),
      );
      return null;
    }

    return TwinSimulationScenario(
      id: id,
      type: _type,
      targetMomentId: _selectedMomentId,
      participantIds: _selectedParticipantId == null
          ? const <String>[]
          : <String>[_selectedParticipantId!],
      newStartMinutes: _type == TwinSimulationType.changeTime
          ? _minutesFromTime(_newTime)
          : null,
      newWeekday: _type == TwinSimulationType.changeWeekday
          ? _newWeekday
          : null,
      newDayOfMonth: _type == TwinSimulationType.changeDayOfMonth
          ? _newDayOfMonth
          : null,
      newIntervalDays: _type == TwinSimulationType.changeFrequency
          ? _newIntervalDays
          : null,
      scope: _type.isOutcomeAssumption
          ? TwinSimulationScope.nextOccurrence
          : _scope,
      assumedDurationMinutes:
          _type == TwinSimulationType.assumeNextCompleted ||
              _type == TwinSimulationType.assumeParticipantJoins
          ? _assumedDurationMinutes
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CalendarPalette.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: CalendarPalette.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Ask “What if…?”',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Change one assumption and preview how the Digital Twin could look. '
            'Nothing is saved.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPillSegmentedControl<_ScenarioBuilderMode>(
            segments: const <AppPillSegment<_ScenarioBuilderMode>>[
              AppPillSegment<_ScenarioBuilderMode>(
                value: _ScenarioBuilderMode.existingMoment,
                label: 'Existing Moment',
              ),
              AppPillSegment<_ScenarioBuilderMode>(
                value: _ScenarioBuilderMode.newMoment,
                label: 'New Moment',
              ),
            ],
            selectedValue: _mode,
            onChanged: (value) {
              setState(() {
                _mode = value;
              });
            },
            backgroundColor: CalendarPalette.surfaceSoft,
            selectedColor: CalendarPalette.forestSoft,
            selectedTextColor: CalendarPalette.forestDark,
            unselectedTextColor: CalendarPalette.inkSoft,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_mode == _ScenarioBuilderMode.existingMoment)
            _buildExistingMomentForm(context)
          else
            _buildNewMomentForm(context),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _runSimulation,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Run Simulation'),
              style: FilledButton.styleFrom(
                backgroundColor: CalendarPalette.ink,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (_canUseAi) ...[
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            WhatIfAiConversationPanel(
              report: widget.report,
              parser: widget.parser,
              onScenarioReady: (scenario) {
                Navigator.of(context).pop(scenario);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingMomentForm(BuildContext context) {
    final moments = _recurringMoments;

    if (moments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: CalendarPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CalendarPalette.border),
        ),
        child: const Text(
          'Add a recurring Family Moment before running an existing-Moment simulation.',
        ),
      );
    }

    final participantOptions = _participantOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey<String?>('moment-$_selectedMomentId'),
          initialValue: _selectedMomentId,
          decoration: const InputDecoration(labelText: 'Which Moment?'),
          isExpanded: true,
          items: moments
              .map(
                (moment) => DropdownMenuItem<String>(
                  value: moment.id,
                  child: Text(moment.title),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedMomentId = value;
              final moment = _selectedMoment;

              if (moment != null) {
                _newTime = _timeFromMinutes(
                  moment.resolvedPreferredStartMinutes,
                );
                _newWeekday =
                    moment.preferredWeekday ?? moment.startAt.toLocal().weekday;
                _newIntervalDays = _supportedInterval(
                  moment.expectedIntervalDays,
                );

                final availableTypes = _availableExistingTypes(moment);
                if (!availableTypes.contains(_type)) {
                  _type = TwinSimulationType.changeTime;
                }
              }

              _resetParticipantSelection();
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<TwinSimulationType>(
          key: ValueKey<TwinSimulationType>(_type),
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'What should change?'),
          isExpanded: true,
          items: _availableExistingTypes(_selectedMoment)
              .map(
                (type) => DropdownMenuItem<TwinSimulationType>(
                  value: type,
                  child: Text(type.label),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _type = value;
              _resetParticipantSelection();
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _type.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: CalendarPalette.inkSoft,
            height: 1.4,
          ),
        ),
        if (_showsParticipantPicker) ...[
          const SizedBox(height: AppSpacing.lg),
          if (participantOptions.isEmpty)
            _InlineNotice(
              text: _type == TwinSimulationType.addParticipant
                  ? 'Every active member is already connected to this Moment.'
                  : 'No eligible member is available for this change.',
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(
                'participant-${_type.name}-$_selectedParticipantId',
              ),
              initialValue: _selectedParticipantId,
              decoration: const InputDecoration(labelText: 'Family member'),
              isExpanded: true,
              items: participantOptions
                  .map(
                    (member) => DropdownMenuItem<String>(
                      value: member.id,
                      child: Text(member.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _selectedParticipantId = value;
                });
              },
            ),
        ],
        if (_type == TwinSimulationType.changeTime) ...[
          const SizedBox(height: AppSpacing.lg),
          _SelectionTile(
            icon: Icons.access_time_outlined,
            title: 'Simulated time',
            value: MaterialLocalizations.of(context).formatTimeOfDay(_newTime),
            onTap: () => _pickTime(forNewMoment: false),
          ),
        ],
        if (_type == TwinSimulationType.changeWeekday) ...[
          const SizedBox(height: AppSpacing.lg),
          _weekdayDropdown(),
        ],
        if (_type == TwinSimulationType.changeDayOfMonth) ...[
          const SizedBox(height: AppSpacing.lg),
          _dayOfMonthDropdown(),
        ],
        if (_type == TwinSimulationType.changeFrequency) ...[
          const SizedBox(height: AppSpacing.lg),
          _frequencyDropdown(),
        ],
        if (_type == TwinSimulationType.assumeNextCompleted ||
            _type == TwinSimulationType.assumeParticipantJoins) ...[
          const SizedBox(height: AppSpacing.lg),
          _durationDropdown(),
        ],
        if (_showsScope) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Apply the change to',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPillSegmentedControl<TwinSimulationScope>(
            segments: const <AppPillSegment<TwinSimulationScope>>[
              AppPillSegment<TwinSimulationScope>(
                value: TwinSimulationScope.nextOccurrence,
                label: 'Next only',
              ),
              AppPillSegment<TwinSimulationScope>(
                value: TwinSimulationScope.futureOccurrences,
                label: 'All future',
              ),
            ],
            selectedValue: _scope,
            onChanged: (value) {
              setState(() {
                _scope = value;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildNewMomentForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _newTitleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Hypothetical Moment name',
            hintText: 'Example: Monthly family walk',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<MomentCategory>(
          key: ValueKey<MomentCategory>(_newCategory),
          initialValue: _newCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items:
              const <MomentCategory>[
                    MomentCategory.tradition,
                    MomentCategory.familyTime,
                    MomentCategory.care,
                  ]
                  .map(
                    (category) => DropdownMenuItem<MomentCategory>(
                      value: category,
                      child: Text(_categoryLabel(category)),
                    ),
                  )
                  .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _newCategory = value;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _frequencyDropdown(),
        if (_supportsFlexibleNewDay) ...[
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Flexible day'),
            subtitle: const Text(
              'Let the simulation use the best recorded shared window.',
            ),
            value: _newIsDayFlexible,
            onChanged: (value) {
              setState(() {
                _newIsDayFlexible = value;
              });
            },
          ),
        ],
        if (!_newIsDayFlexible &&
            (_newIntervalDays == 7 || _newIntervalDays == 14)) ...[
          const SizedBox(height: AppSpacing.sm),
          _weekdayDropdown(),
        ],
        if (!_newIsDayFlexible &&
            (_newIntervalDays == 30 || _newIntervalDays == 90)) ...[
          const SizedBox(height: AppSpacing.lg),
          _dayOfMonthDropdown(),
        ],
        if (_newIntervalDays == 365) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _monthDropdown()),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _dayOfMonthDropdown()),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _SelectionTile(
          icon: Icons.access_time_outlined,
          title: 'Usual time',
          value: MaterialLocalizations.of(context).formatTimeOfDay(_newTime),
          onTap: () => _pickTime(forNewMoment: true),
        ),
        const SizedBox(height: AppSpacing.lg),
        _durationDropdown(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Participants',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: CalendarPalette.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _members
              .map((member) {
                final selected = _newParticipantIds.contains(member.id);

                return FilterChip(
                  label: Text(member.displayName),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _newParticipantIds.add(member.id);
                      } else {
                        _newParticipantIds.remove(member.id);
                      }
                    });
                  },
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'This creates only a temporary node in the simulation. It does not '
          'add a real Family Moment.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: CalendarPalette.inkSoft,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _frequencyDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey<int>(_newIntervalDays),
      initialValue: _newIntervalDays,
      decoration: const InputDecoration(labelText: 'Frequency'),
      items: _frequencyOptions.entries
          .map(
            (entry) => DropdownMenuItem<int>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _newIntervalDays = value;

          if (!_supportsFlexibleNewDay) {
            _newIsDayFlexible = false;
          }
        });
      },
    );
  }

  Widget _weekdayDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey<int>(_newWeekday),
      initialValue: _newWeekday,
      decoration: const InputDecoration(labelText: 'Weekday'),
      items: List<DropdownMenuItem<int>>.generate(7, (index) {
        final weekday = index + 1;
        return DropdownMenuItem<int>(
          value: weekday,
          child: Text(_weekdayLabel(weekday)),
        );
      }),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _newWeekday = value;
        });
      },
    );
  }

  Widget _dayOfMonthDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey<int>(_newDayOfMonth),
      initialValue: _newDayOfMonth,
      decoration: const InputDecoration(labelText: 'Day of month'),
      items: List<DropdownMenuItem<int>>.generate(31, (index) {
        final day = index + 1;
        return DropdownMenuItem<int>(value: day, child: Text('$day'));
      }),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _newDayOfMonth = value;
        });
      },
    );
  }

  Widget _monthDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey<int>(_newMonth),
      initialValue: _newMonth,
      decoration: const InputDecoration(labelText: 'Month'),
      items: List<DropdownMenuItem<int>>.generate(12, (index) {
        final month = index + 1;
        return DropdownMenuItem<int>(
          value: month,
          child: Text(_monthLabel(month)),
        );
      }),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _newMonth = value;
        });
      },
    );
  }

  Widget _durationDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey<int>(_assumedDurationMinutes),
      initialValue: _assumedDurationMinutes,
      decoration: const InputDecoration(labelText: 'Assumed duration'),
      items: const <int>[30, 45, 60, 90, 120]
          .map(
            (minutes) => DropdownMenuItem<int>(
              value: minutes,
              child: Text('$minutes minutes'),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _assumedDurationMinutes = value;
        });
      },
    );
  }

  TimeOfDay _timeFromMinutes(int minutes) {
    final safe = minutes.clamp(0, 1439).toInt();
    return TimeOfDay(hour: safe ~/ 60, minute: safe % 60);
  }

  int _minutesFromTime(TimeOfDay value) {
    return value.hour * 60 + value.minute;
  }

  String _weekdayLabel(int weekday) {
    return const <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][weekday.clamp(1, 7).toInt() - 1];
  }

  String _monthLabel(int month) {
    return const <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month.clamp(1, 12).toInt() - 1];
  }

  String _categoryLabel(MomentCategory category) {
    return switch (category) {
      MomentCategory.tradition => 'Tradition',
      MomentCategory.familyTime => 'Family Time',
      MomentCategory.care => 'Care',
      MomentCategory.milestone => 'Milestone',
      MomentCategory.responsibility => 'Responsibility',
      MomentCategory.memory => 'Memory',
    };
  }

  List<TwinSimulationType> _availableExistingTypes(FamilyMoment? moment) {
    final result = <TwinSimulationType>[
      TwinSimulationType.addParticipant,
      TwinSimulationType.removeParticipant,
      TwinSimulationType.changeTime,
      TwinSimulationType.changeFrequency,
      TwinSimulationType.assumeNextCompleted,
      TwinSimulationType.assumeNextMissed,
      TwinSimulationType.assumeParticipantJoins,
    ];

    final interval = moment?.expectedIntervalDays;

    if (interval == 7 || interval == 14) {
      result.insert(3, TwinSimulationType.changeWeekday);
    }

    if (interval == 30 || interval == 90) {
      result.insert(3, TwinSimulationType.changeDayOfMonth);
    }

    return result;
  }

  int _supportedInterval(int? value) {
    return _frequencyOptions.containsKey(value) ? value! : 7;
  }

  static const Map<int, String> _frequencyOptions = <int, String>{
    1: 'Daily',
    7: 'Weekly',
    14: 'Every 2 weeks',
    30: 'Monthly',
    90: 'Every 3 months',
    365: 'Yearly',
  };
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CalendarPalette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CalendarPalette.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: CalendarPalette.forestDark),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: CalendarPalette.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CalendarPalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: CalendarPalette.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: CalendarPalette.milestoneSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: CalendarPalette.inkSoft,
          height: 1.4,
        ),
      ),
    );
  }
}
