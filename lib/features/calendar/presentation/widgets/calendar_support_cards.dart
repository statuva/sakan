import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/family_memory.dart';
import 'calendar_palette.dart';

class CalendarSupportCards extends StatelessWidget {
  const CalendarSupportCards({
    required this.memories,
    required this.onMemoryTap,
    required this.onAllMemoriesTap,
    super.key,
  });

  final List<FamilyMemory> memories;
  final ValueChanged<FamilyMemory> onMemoryTap;
  final VoidCallback onAllMemoriesTap;

  @override
  Widget build(BuildContext context) {
    final orderedMemories = List<FamilyMemory>.from(memories)
      ..sort((first, second) => second.occurredAt.compareTo(first.occurredAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onAllMemoriesTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Memories',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: CalendarPalette.ink,
                      fontWeight: FontWeight.w700,
                    ),
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
        const SizedBox(height: AppSpacing.sm),
        if (orderedMemories.isEmpty)
          const _EmptyMemoryHighlight()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = orderedMemories.length == 1
                  ? constraints.maxWidth
                  : constraints.maxWidth * 0.88;

              return SizedBox(
                height: 286,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: orderedMemories.take(6).length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final memory = orderedMemories[index];

                    return SizedBox(
                      width: cardWidth,
                      child: _MemoryHighlightCard(
                        memory: memory,
                        onTap: () {
                          onMemoryTap(memory);
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _MemoryHighlightCard extends StatelessWidget {
  const _MemoryHighlightCard({required this.memory, required this.onTap});

  final FamilyMemory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = memory.photoUrls.isEmpty ? null : memory.photoUrls.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: CalendarPalette.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl == null)
                  const _MemoryFallback()
                else
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return const _MemoryFallback();
                    },
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x10000000),
                        Color(0x24000000),
                        Color(0xD9000000),
                      ],
                      stops: [0.25, 0.55, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memory.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        DateFormat(
                          'd MMMM y',
                        ).format(memory.occurredAt.toLocal()).toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Colors.white.withAlpha(225),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryFallback extends StatelessWidget {
  const _MemoryFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CalendarPalette.forestDark,
            CalendarPalette.forest,
            Color(0xFF879B75),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -48,
            right: -34,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -28,
            bottom: 28,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.auto_stories_outlined,
              size: 58,
              color: Color(0xCCFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMemoryHighlight extends StatelessWidget {
  const _EmptyMemoryHighlight();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: CalendarPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CalendarPalette.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            size: 38,
            color: CalendarPalette.milestone,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No Memories yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: CalendarPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Memories saved from completed family Moments will appear here.',
            textAlign: TextAlign.center,
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
