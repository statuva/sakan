import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../app/app_dependencies.dart';
import '../../../shared/ai/ai_models.dart';
import '../../../shared/models/family_memory.dart';
import '../../calendar/presentation/widgets/calendar_palette.dart';

class MemoryDetailsScreen extends StatefulWidget {
  const MemoryDetailsScreen({required this.memory, super.key});

  final FamilyMemory memory;

  @override
  State<MemoryDetailsScreen> createState() => _MemoryDetailsScreenState();
}

class _MemoryDetailsScreenState extends State<MemoryDetailsScreen> {
  String? _reflection;
  bool _canUseAi = false;
  bool _isLoadingAiAccess = true;
  bool _isGenerating = false;
  String? _reflectionError;

  FamilyMemory get memory => widget.memory;

  @override
  void initState() {
    super.initState();
    _loadAiAccess();
  }

  Future<void> _loadAiAccess() async {
    try {
      final familyContext = await AppDependencies.currentFamilyService.load();
      if (!mounted) return;
      setState(() {
        _canUseAi =
            familyContext.familyId == memory.familyId && familyContext.canUseAi;
        _isLoadingAiAccess = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canUseAi = false;
        _isLoadingAiAccess = false;
      });
    }
  }

  Future<void> _generateReflection() async {
    if (!_canUseAi || _isGenerating || memory.note?.trim().isNotEmpty != true) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _reflectionError = null;
    });
    try {
      final result = await AppDependencies.sakanAiGateway.generate(
        feature: SakanAiFeature.memoryReflection,
        targetId: memory.id,
      );
      if (!mounted) return;
      setState(() => _reflection = result.text);
    } on SakanAiException catch (error) {
      if (!mounted) return;
      setState(() => _reflectionError = error.message);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Memory')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              memory.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const SizedBox(height: AppSpacing.xs),

            Text(
              DateFormat('EEEE, d MMMM y').format(memory.occurredAt.toLocal()),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CalendarPalette.inkSoft),
            ),

            const SizedBox(height: AppSpacing.lg),

            if (memory.photoUrls.isEmpty)
              Container(
                height: 210,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CalendarPalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: CalendarPalette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_stories_outlined,
                      size: 52,
                      color: CalendarPalette.inkSoft,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Family Memory',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Photo upload will be '
                      'available later.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 270,
                child: PageView.builder(
                  itemCount: memory.photoUrls.length,
                  itemBuilder: (context, index) {
                    final url = memory.photoUrls[index];

                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: CalendarPalette.surfaceSoft,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 44,
                                color: CalendarPalette.inkSoft,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            Text('Family Note', style: Theme.of(context).textTheme.titleLarge),

            const SizedBox(height: AppSpacing.sm),

            _MemorySection(
              icon: Icons.notes_outlined,
              text: memory.note?.trim().isNotEmpty == true
                  ? memory.note!
                  : 'No family note was added.',
            ),

            if (!_isLoadingAiAccess && _canUseAi) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Sakan Reflection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MemorySection(
                icon: Icons.auto_awesome_outlined,
                text: _reflection?.trim().isNotEmpty == true
                    ? _reflection!
                    : 'AI reflection has not '
                          'been generated yet. '
                          'The original family note '
                          'remains available above.',
              ),
              if (memory.note?.trim().isNotEmpty == true &&
                  _reflection == null) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isGenerating ? null : _generateReflection,
                    icon: _isGenerating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _isGenerating ? 'Reflecting…' : 'Create Sakan Reflection',
                    ),
                  ),
                ),
              ],
              if (_reflectionError != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _reflectionError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (_reflection != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'AI-generated from this Memory’s permitted family note.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CalendarPalette.inkSoft,
                  ),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.xl),

            _MemorySection(
              icon: Icons.group_outlined,
              text:
                  '${memory.participantIds.length} '
                  'family '
                  '${memory.participantIds.length == 1 ? 'member was' : 'members were'} '
                  'included in this memory.',
            ),
          ],
        ),
      ),
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CalendarPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CalendarPalette.forestSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: CalendarPalette.forestDark),
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
