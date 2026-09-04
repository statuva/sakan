import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/ai/ai_models.dart';
import '../../../shared/widgets/branding/sakan_brand.dart';

class SakanAssistantScreen extends StatefulWidget {
  const SakanAssistantScreen({super.key});

  @override
  State<SakanAssistantScreen> createState() => _SakanAssistantScreenState();
}

class _SakanAssistantScreenState extends State<SakanAssistantScreen> {
  static const _starterQuestions = <String>[
    'What matters most today?',
    'Help me plan a Family Moment',
    'Explain our current rhythms',
    'What pattern should I notice?',
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<SakanAiMessage> _messages = <SakanAiMessage>[
    const SakanAiMessage(
      role: SakanAiMessageRole.assistant,
      text:
          'Ask about your family’s recorded Moments, rhythms, reminders, or '
          'Memories. I will explain the evidence without changing anything.',
    ),
  ];

  List<String> _quickReplies = _starterQuestions;
  bool _isCheckingAccess = true;
  bool _isSending = false;
  String? _accessError;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      await AppDependencies.sakanAiGateway.ensureAuthorized();
    } on SakanAiException catch (error) {
      _accessError = error.message;
    } catch (_) {
      _accessError = 'Sakan AI access could not be checked right now.';
    } finally {
      if (mounted) setState(() => _isCheckingAccess = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedMessage]) async {
    final message = (suggestedMessage ?? _controller.text).trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    final priorMessages = List<SakanAiMessage>.from(_messages);
    _controller.clear();
    setState(() {
      _messages.add(
        SakanAiMessage(role: SakanAiMessageRole.user, text: message),
      );
      _isSending = true;
      _errorMessage = null;
      _quickReplies = const <String>[];
    });
    _scrollToBottom();

    try {
      final result = await AppDependencies.sakanAiGateway.chat(
        message: message,
        recentMessages: priorMessages,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          SakanAiMessage(
            role: SakanAiMessageRole.assistant,
            text: result.text,
          ),
        );
        _quickReplies = result.quickReplies.take(3).toList(growable: false);
      });
    } on SakanAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _quickReplies = _starterQuestions;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess || _accessError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Ask Sakan'),
          actions: [
            IconButton(
              onPressed: () => context.pushNamed('privacyAi'),
              tooltip: 'Privacy & AI',
              icon: const Icon(Icons.privacy_tip_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _isCheckingAccess
                  ? const CircularProgressIndicator()
                  : Text(
                      _accessError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          children: [
            SakanAiStar(size: 34, selected: true),
            SizedBox(width: AppSpacing.sm),
            Text('Ask Sakan'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed('privacyAi'),
            tooltip: 'Privacy & AI',
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const _ThinkingBubble();
                  }
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(18),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            if (_quickReplies.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: _quickReplies
                      .map(
                        (question) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: ActionChip(
                            label: Text(question),
                            onPressed: _isSending ? null : () => _send(question),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isSending,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your family patterns…',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _isSending ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SakanAiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == SakanAiMessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isUser ? Colors.white : AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'AI-generated · based on permitted Sakan data',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
