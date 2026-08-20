import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/family_memory.dart';
import '../../calendar/presentation/widgets/calendar_palette.dart';

class MemoryDetailsScreen extends StatelessWidget {
  const MemoryDetailsScreen({required this.memory, super.key});

  final FamilyMemory memory;

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
            SizedBox(
              height: 270,
              child: PageView.builder(
                itemCount: memory.photoUrls.length,
                controller: PageController(viewportFraction: 0.94),
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
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: CalendarPalette.surfaceSoft,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            if (memory.note != null && memory.note!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Family Note',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MemorySection(icon: Icons.notes_outlined, text: memory.note!),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Why Sakan surfaced this',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            _MemorySection(
              icon: Icons.auto_awesome_outlined,
              text: memory.aiReflection?.trim().isNotEmpty == true
                  ? memory.aiReflection!
                  : _fallbackReflection(memory),
            ),
            const SizedBox(height: AppSpacing.xl),
            _MemorySection(
              icon: Icons.group_outlined,
              text:
                  '${memory.participantIds.length} family ${memory.participantIds.length == 1 ? 'member was' : 'members were'} included in this memory.',
            ),
          ],
        ),
      ),
    );
  }

  String _fallbackReflection(FamilyMemory memory) {
    return 'This memory records a completed family moment. Reviewing it can help the family prepare for a similar upcoming event using details that were already meaningful enough to preserve.';
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
