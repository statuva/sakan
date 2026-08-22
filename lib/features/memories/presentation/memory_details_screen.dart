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

            const SizedBox(height: AppSpacing.xl),

            Text(
              'Sakan Reflection',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: AppSpacing.sm),

            _MemorySection(
              icon: Icons.auto_awesome_outlined,
              text: memory.aiReflection?.trim().isNotEmpty == true
                  ? memory.aiReflection!
                  : 'AI reflection has not '
                        'been generated yet. '
                        'The original family note '
                        'remains available above.',
            ),

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
