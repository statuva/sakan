import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/ai/ai_models.dart';
import '../../../../shared/models/family_insight_report.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';
import '../../domain/twin_simulation_scenario.dart';
import '../../services/twin_ai_scenario_parser.dart';

class WhatIfAiConversationPanel extends StatefulWidget {
  const WhatIfAiConversationPanel({
    required this.report,
    required this.parser,
    required this.onScenarioReady,
    super.key,
  });

  final FamilyInsightReport report;
  final TwinAiScenarioParser parser;
  final ValueChanged<TwinSimulationScenario> onScenarioReady;

  @override
  State<WhatIfAiConversationPanel> createState() =>
      _WhatIfAiConversationPanelState();
}

class _WhatIfAiConversationPanelState extends State<WhatIfAiConversationPanel> {
  final TextEditingController _controller = TextEditingController();
  final List<_ConversationLine> _conversation = <_ConversationLine>[];

  bool _isSending = false;
  TwinSimulationScenario? _scenario;
  String? _summary;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _interpret() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _conversation.add(_ConversationLine(isUser: true, text: message));
      _isSending = true;
      _scenario = null;
      _summary = null;
      _errorMessage = null;
    });

    final recentConversation = _latestConversationLines();
    var prompt = recentConversation
        .map((line) => '${line.isUser ? 'Adult' : 'Sakan'}: ${line.text}')
        .join('\n');
    if (prompt.length > 2400) {
      prompt = prompt.substring(prompt.length - 2400);
    }

    try {
      final result = await widget.parser.parse(
        prompt: prompt,
        report: widget.report,
      );
      if (!mounted) return;
      setState(() {
        _summary = result.interpretedSummary;
        _scenario = result.scenario;
        final reply = result.clarificationQuestion ?? result.interpretedSummary;
        _conversation.add(_ConversationLine(isUser: false, text: reply));
      });
    } on SakanAiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  List<_ConversationLine> _latestConversationLines() {
    if (_conversation.length <= 6) {
      return _conversation;
    }
    return _conversation.sublist(_conversation.length - 6);
  }

  @override
  Widget build(BuildContext context) {
    final visibleConversation = _latestConversationLines();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: true,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CalendarPalette.mineSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_awesome_outlined,
            size: 19,
            color: CalendarPalette.mine,
          ),
        ),
        title: const Text('Describe a new or existing idea with AI'),
        subtitle: const Text('AI translates your idea; Sakan runs the math'),
        children: [
          if (visibleConversation.isNotEmpty) ...[
            ...visibleConversation.map(
              (line) => Align(
                alignment: line.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: line.isUser
                        ? CalendarPalette.mineSoft
                        : CalendarPalette.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(line.text),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextField(
            controller: _controller,
            enabled: !_isSending,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Example: What if we had a picnic this weekend?',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSending ? null : _interpret,
              icon: _isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isSending ? 'Understanding…' : 'Interpret with AI'),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (_scenario != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: CalendarPalette.forestSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ready to simulate',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_summary ?? _scenario!.type.label),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => widget.onScenarioReady(_scenario!),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Run This Simulation'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'AI-generated interpretation. The projection remains local, '
            'deterministic, hypothetical, and is not saved.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationLine {
  const _ConversationLine({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}
