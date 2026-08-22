import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_memory.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';

class AddMemoryScreen extends StatefulWidget {
  const AddMemoryScreen({this.initialMoment, super.key});

  /// When this screen opens from a completed Moment,
  /// that Moment remains selected.
  ///
  /// When null, the user can choose from all completed
  /// Moments that belong to the current family.
  final FamilyMoment? initialMoment;

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _noteController = TextEditingController();

  CurrentFamilyContext? _familyContext;

  List<FamilyMoment> _completedMoments = <FamilyMoment>[];

  FamilyMoment? _selectedMoment;
  FamilyMemory? _existingMemory;

  bool _isLoading = true;
  bool _isLoadingExistingMemory = false;
  bool _isSaving = false;

  String? _errorMessage;

  int _memoryLoadRequestId = 0;

  bool get _isEditing => _existingMemory != null;

  bool get _momentIsLocked => widget.initialMoment != null;

  @override
  void initState() {
    super.initState();
    _loadMemoryData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMemoryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final familyContext = await AppDependencies.currentFamilyService.load();

      if (!familyContext.isAdult) {
        throw StateError(
          'Only an adult or family admin '
          'can add or edit a family memory.',
        );
      }

      final initialMoment = widget.initialMoment;

      if (initialMoment != null &&
          initialMoment.status != MomentStatus.completed) {
        throw StateError(
          'A Memory can be added only after '
          'the Moment is marked Completed.',
        );
      }

      final moments = await AppDependencies.calendarRepository
          .watchMoments(familyId: familyContext.familyId)
          .first;

      final completedMoments = moments
          .where((moment) => moment.status == MomentStatus.completed)
          .toList();

      if (initialMoment != null &&
          !completedMoments.any((moment) => moment.id == initialMoment.id)) {
        completedMoments.add(initialMoment);
      }

      completedMoments.sort(
        (first, second) => second.startAt.compareTo(first.startAt),
      );

      FamilyMoment? selectedMoment;

      if (initialMoment != null) {
        selectedMoment = _findMoment(completedMoments, initialMoment.id);
      }

      if (selectedMoment == null && completedMoments.isNotEmpty) {
        selectedMoment = completedMoments.first;
      }

      FamilyMemory? existingMemory;

      if (selectedMoment != null) {
        existingMemory = await AppDependencies.memoryRepository
            .getMemoryForMoment(
              familyId: familyContext.familyId,
              momentId: selectedMoment.id,
            );
      }

      if (!mounted) return;

      _noteController.text = existingMemory?.note ?? '';

      setState(() {
        _familyContext = familyContext;
        _completedMoments = completedMoments;
        _selectedMoment = selectedMoment;
        _existingMemory = existingMemory;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error is StateError
            ? error.message.toString()
            : 'We could not prepare '
                  'the Memory screen.';
      });
    }
  }

  FamilyMoment? _findMoment(List<FamilyMoment> moments, String momentId) {
    for (final moment in moments) {
      if (moment.id == momentId) {
        return moment;
      }
    }

    return null;
  }

  Future<void> _selectMoment(String momentId) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    final selectedMoment = _findMoment(_completedMoments, momentId);

    if (selectedMoment == null) {
      return;
    }

    final requestId = ++_memoryLoadRequestId;

    setState(() {
      _selectedMoment = selectedMoment;
      _existingMemory = null;
      _isLoadingExistingMemory = true;
      _errorMessage = null;
    });

    _noteController.clear();

    try {
      final existingMemory = await AppDependencies.memoryRepository
          .getMemoryForMoment(
            familyId: familyContext.familyId,
            momentId: selectedMoment.id,
          );

      if (!mounted || requestId != _memoryLoadRequestId) {
        return;
      }

      _noteController.text = existingMemory?.note ?? '';

      setState(() {
        _existingMemory = existingMemory;
        _isLoadingExistingMemory = false;
      });
    } catch (_) {
      if (!mounted || requestId != _memoryLoadRequestId) {
        return;
      }

      setState(() {
        _isLoadingExistingMemory = false;
        _errorMessage =
            'We could not check whether '
            'this Moment already has a Memory.';
      });
    }
  }

  Future<void> _saveMemory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final familyContext = _familyContext;

    final selectedMoment = _selectedMoment;

    if (familyContext == null ||
        selectedMoment == null ||
        _isSaving ||
        _isLoadingExistingMemory) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now().toUtc();

      final existingMemory = _existingMemory;

      final memory = FamilyMemory(
        // New Memories use the Moment ID.
        // Existing Memories preserve their
        // current Firestore document ID.
        id: existingMemory?.id ?? selectedMoment.id,

        familyId: familyContext.familyId,

        momentId: selectedMoment.id,

        title: selectedMoment.title,

        occurredAt: selectedMoment.startAt.toUtc(),

        // Preserve future photo data when an
        // existing Memory is edited.
        photoUrls: existingMemory?.photoUrls ?? const <String>[],

        participantIds: selectedMoment.expectedParticipantIds,

        note: _noteController.text.trim(),

        // Preserve any future AI reflection.
        // The app does not generate one yet.
        aiReflection: existingMemory?.aiReflection,

        createdAt: existingMemory?.createdAt ?? now,

        updatedAt: now,
      );

      await AppDependencies.memoryRepository.saveMemory(memory);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error is ArgumentError
            ? error.message.toString()
            : 'We could not save this '
                  'family Memory. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: AppLoadingState(message: 'Preparing your Memory…'),
        ),
      );
    }

    if (_familyContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Memory')),
        body: SafeArea(
          child: AppErrorState(
            message:
                _errorMessage ??
                'The Memory screen '
                    'is unavailable.',
            onRetry: _loadMemoryData,
          ),
        ),
      );
    }

    if (_completedMoments.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Family Memory')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 58,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'No completed Moments yet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Mark a family Moment as '
                      'Completed first. You can '
                      'then preserve its date, '
                      'participants, and family '
                      'note as a Memory.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selectedMoment = _selectedMoment;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Family Memory' : 'Add Family Memory'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                _isEditing
                    ? 'Update this Memory'
                    : 'Preserve a completed Moment',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: AppSpacing.xs),

              Text(
                _isEditing
                    ? 'This Moment already has a '
                          'Memory. Saving will update '
                          'its family note instead of '
                          'creating a duplicate.'
                    : 'Choose a completed family '
                          'Moment and write what your '
                          'family would like to remember.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: AppSpacing.xl),

              if (_momentIsLocked && selectedMoment != null)
                _SelectedMomentCard(moment: selectedMoment)
              else
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedMoment?.id),
                  initialValue: selectedMoment?.id,
                  decoration: const InputDecoration(
                    labelText: 'Completed Moment',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  items: _completedMoments
                      .map(
                        (moment) => DropdownMenuItem<String>(
                          value: moment.id,
                          child: Text(
                            moment.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving || _isLoadingExistingMemory
                      ? null
                      : (momentId) {
                          if (momentId == null) {
                            return;
                          }

                          _selectMoment(momentId);
                        },
                ),

              if (!_momentIsLocked && selectedMoment != null) ...[
                const SizedBox(height: AppSpacing.md),

                _SelectedMomentCard(moment: selectedMoment),
              ],

              if (_isLoadingExistingMemory) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Checking for an existing Memory…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              TextFormField(
                controller: _noteController,
                enabled: !_isSaving && !_isLoadingExistingMemory,
                minLines: 4,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Family Note',
                  hintText:
                      'What happened, and what '
                      'would your family like '
                      'to remember?',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Write a short family note.';
                  }

                  if (value.trim().length < 3) {
                    return 'The note is too short.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Photo upload is not '
                        'connected in this MVP. '
                        'This Memory preserves '
                        'the completed Moment, '
                        'date, participants, and '
                        'family note.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              AppPrimaryButton(
                label: _isEditing ? 'Update Memory' : 'Save Memory',
                icon: _isEditing
                    ? Icons.save_outlined
                    : Icons.bookmark_add_outlined,
                isLoading: _isSaving,
                onPressed: _isSaving || _isLoadingExistingMemory
                    ? null
                    : _saveMemory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedMomentCard extends StatelessWidget {
  const _SelectedMomentCard({required this.moment});

  final FamilyMoment moment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  moment.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            DateFormat('EEEE, d MMMM y').format(moment.startAt.toLocal()),
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 6),

          Text(
            '${moment.expectedParticipantIds.length} '
            'expected '
            '${moment.expectedParticipantIds.length == 1 ? 'participant' : 'participants'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 6),

          Text(
            'Status: Completed',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
