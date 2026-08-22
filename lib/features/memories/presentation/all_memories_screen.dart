import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/current_family_context.dart';
import 'package:sakan/shared/models/family_memory.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';
import 'package:sakan/shared/widgets/feedback/app_error_state.dart';
import 'package:sakan/shared/widgets/feedback/app_loading_state.dart';

import 'add_memory_screen.dart';
import 'memory_details_screen.dart';

class AllMemoriesScreen extends StatefulWidget {
  const AllMemoriesScreen({super.key});

  @override
  State<AllMemoriesScreen> createState() => _AllMemoriesScreenState();
}

class _AllMemoriesScreenState extends State<AllMemoriesScreen> {
  CurrentFamilyContext? _familyContext;
  Stream<List<FamilyMemory>>? _memoriesStream;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      final memoriesStream = AppDependencies.memoryRepository.watchMemories(
        familyId: familyContext.familyId,
      );

      if (!mounted) return;

      setState(() {
        _familyContext = familyContext;
        _memoriesStream = memoriesStream;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your family memories.';
      });
    }
  }

  Future<void> _openAddMemory() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddMemoryScreen()));

    if (saved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Family Memory saved.')));
  }

  Future<void> _openMemory(FamilyMemory memory) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemoryDetailsScreen(memory: memory)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Loading family memories…'),
        ),
      );
    }

    if (_familyContext == null || _memoriesStream == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Memories')),
        body: SafeArea(
          child: AppErrorState(
            message: _errorMessage ?? 'Family Memories are unavailable.',
            onRetry: _loadMemories,
          ),
        ),
      );
    }

    final canAddMemory = _familyContext!.isAdult;

    return StreamBuilder<List<FamilyMemory>>(
      stream: _memoriesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Family Memories')),
            body: SafeArea(
              child: AppErrorState(
                message: 'We could not load family memories.',
                onRetry: _loadMemories,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              child: AppLoadingState(message: 'Loading family memories…'),
            ),
          );
        }

        final memories = snapshot.data ?? <FamilyMemory>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Family Memories'),
            actions: [
              if (canAddMemory)
                IconButton(
                  tooltip: 'Add Memory',
                  onPressed: _openAddMemory,
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                96,
              ),
              children: [
                Text(
                  memories.isEmpty
                      ? 'No saved memories yet'
                      : '${memories.length} saved '
                            '${memories.length == 1 ? 'Memory' : 'Memories'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: AppSpacing.lg),

                if (memories.isEmpty)
                  _EmptyMemoriesState(
                    canAddMemory: canAddMemory,
                    onAddMemory: _openAddMemory,
                  )
                else
                  ...memories.map(
                    (memory) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _MemoryListCard(
                        memory: memory,
                        onTap: () {
                          _openMemory(memory);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyMemoriesState extends StatelessWidget {
  const _EmptyMemoriesState({
    required this.canAddMemory,
    required this.onAddMemory,
  });

  final bool canAddMemory;
  final VoidCallback onAddMemory;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'No family memories yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            canAddMemory
                ? 'Complete a family Moment, '
                      'then preserve its date, '
                      'participants, and family note.'
                : 'Memories will appear here after '
                      'an adult preserves a completed '
                      'family Moment.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          if (canAddMemory) ...[
            const SizedBox(height: AppSpacing.xl),

            AppPrimaryButton(
              label: 'Add Memory',
              icon: Icons.bookmark_add_outlined,
              onPressed: onAddMemory,
            ),
          ],
        ],
      ),
    );
  }
}

class _MemoryListCard extends StatelessWidget {
  const _MemoryListCard({required this.memory, required this.onTap});

  final FamilyMemory memory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final note = memory.note?.trim();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MemoryThumbnail(memory: memory),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  note == null || note.isEmpty
                      ? 'No family note was added.'
                      : note,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: AppSpacing.sm),

                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: 5,
                  children: [
                    _MemoryMetadata(
                      icon: Icons.calendar_today_outlined,
                      label: DateFormat(
                        'd MMM y',
                      ).format(memory.occurredAt.toLocal()),
                    ),
                    _MemoryMetadata(
                      icon: Icons.group_outlined,
                      label:
                          '${memory.participantIds.length} '
                          '${memory.participantIds.length == 1 ? 'member' : 'members'}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _MemoryThumbnail extends StatelessWidget {
  const _MemoryThumbnail({required this.memory});

  final FamilyMemory memory;

  @override
  Widget build(BuildContext context) {
    const size = 92.0;

    if (memory.photoUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            memory.photoUrls.first,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const _MemoryPlaceholder(size: size);
            },
          ),
        ),
      );
    }

    return const _MemoryPlaceholder(size: size);
  }
}

class _MemoryPlaceholder extends StatelessWidget {
  const _MemoryPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.photo_outlined,
        size: 34,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _MemoryMetadata extends StatelessWidget {
  const _MemoryMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
