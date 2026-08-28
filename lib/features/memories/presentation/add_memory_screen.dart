import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/models/current_family_context.dart';
import '../../../shared/models/family_memory.dart';
import '../../../shared/models/family_moment.dart';
import '../../../shared/models/model_enums.dart';
import '../../../shared/models/moment_instance.dart';
import '../../../shared/widgets/buttons/app_primary_button.dart';
import '../../../shared/widgets/cards/app_card.dart';
import '../../../shared/widgets/feedback/app_error_state.dart';
import '../../../shared/widgets/feedback/app_loading_state.dart';

class AddMemoryScreen extends StatefulWidget {
  const AddMemoryScreen({this.initialMoment, this.initialInstance, super.key});

  final FamilyMoment? initialMoment;
  final MomentInstance? initialInstance;

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  CurrentFamilyContext? _familyContext;

  List<MomentInstance> _completedInstances = <MomentInstance>[];

  Map<String, FamilyMoment> _momentsById = <String, FamilyMoment>{};

  MomentInstance? _selectedInstance;
  FamilyMoment? _selectedMoment;
  FamilyMemory? _existingMemory;

  bool _isLoading = true;
  bool _isLoadingExistingMemory = false;
  bool _isSaving = false;

  String? _errorMessage;
  int _loadRequestId = 0;

  bool get _isEditing => _existingMemory != null;

  bool get _selectionIsLocked {
    return widget.initialInstance != null || widget.initialMoment != null;
  }

  bool get _usesLegacyMomentOnly {
    return _selectedInstance == null && _selectedMoment != null;
  }

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
          'Only an adult or family admin can '
          'add or edit a family Memory.',
        );
      }

      final results = await Future.wait<Object>([
        AppDependencies.calendarRepository
            .watchMoments(familyId: familyContext.familyId)
            .first,
        AppDependencies.momentInstanceRepository
            .watchInstances(familyId: familyContext.familyId)
            .first,
      ]);

      final moments = results[0] as List<FamilyMoment>;
      final instances = results[1] as List<MomentInstance>;

      final momentsById = <String, FamilyMoment>{
        for (final moment in moments) moment.id: moment,
      };

      final completedInstances =
          instances
              .where(
                (instance) => instance.status == MomentInstanceStatus.completed,
              )
              .toList()
            ..sort(
              (first, second) =>
                  second.effectiveStartAt.compareTo(first.effectiveStartAt),
            );

      MomentInstance? selectedInstance;
      FamilyMoment? selectedMoment;

      final initialInstance = widget.initialInstance;

      if (initialInstance != null) {
        if (initialInstance.familyId != familyContext.familyId) {
          throw StateError(
            'This Memory occurrence belongs to '
            'a different family.',
          );
        }

        if (initialInstance.status != MomentInstanceStatus.completed) {
          throw StateError(
            'A Memory can be added only after '
            'the Moment occurrence is completed.',
          );
        }

        selectedInstance = initialInstance;
        selectedMoment =
            momentsById[initialInstance.momentId] ??
            _momentSnapshotFromInstance(initialInstance);
      } else if (widget.initialMoment != null) {
        final initialMoment = widget.initialMoment!;

        selectedMoment = initialMoment;

        final matching = completedInstances.where(
          (instance) => instance.momentId == initialMoment.id,
        );

        if (matching.isNotEmpty) {
          selectedInstance = matching.first;
        } else if (initialMoment.status != MomentStatus.completed) {
          throw StateError('This Moment has no completed occurrence yet.');
        }
      } else if (completedInstances.isNotEmpty) {
        selectedInstance = completedInstances.first;
        selectedMoment =
            momentsById[selectedInstance.momentId] ??
            _momentSnapshotFromInstance(selectedInstance);
      }

      FamilyMemory? existingMemory;

      if (selectedInstance != null) {
        existingMemory = await AppDependencies.memoryRepository
            .getMemoryForInstance(
              familyId: familyContext.familyId,
              instanceId: selectedInstance.id,
            );
      } else if (selectedMoment != null) {
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
        _completedInstances = completedInstances;
        _momentsById = momentsById;
        _selectedInstance = selectedInstance;
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
            : 'We could not prepare the Memory screen.';
      });
    }
  }

  FamilyMoment _momentSnapshotFromInstance(MomentInstance instance) {
    return FamilyMoment(
      id: instance.momentId,
      familyId: instance.familyId,
      title: instance.titleSnapshot,
      type: instance.typeSnapshot,
      category: instance.categorySnapshot,
      importanceLevel: instance.importanceLevelSnapshot,
      expectedParticipantIds: instance.expectedParticipantIds,
      startAt: instance.effectiveStartAt,
      endAt: instance.effectiveEndAt,
      evidenceType: EvidenceType.userConfirmed,
      status: MomentStatus.completed,
      createdBy: instance.createdBy,
      createdAt: instance.createdAt,
      updatedAt: instance.updatedAt,
    );
  }

  Future<void> _selectInstance(String instanceId) async {
    final familyContext = _familyContext;

    if (familyContext == null || _isSaving) {
      return;
    }

    MomentInstance? selected;

    for (final instance in _completedInstances) {
      if (instance.id == instanceId) {
        selected = instance;
        break;
      }
    }

    if (selected == null) {
      return;
    }

    final requestId = ++_loadRequestId;

    setState(() {
      _selectedInstance = selected;
      _selectedMoment =
          _momentsById[selected!.momentId] ??
          _momentSnapshotFromInstance(selected);
      _existingMemory = null;
      _isLoadingExistingMemory = true;
      _errorMessage = null;
    });

    _noteController.clear();

    try {
      final existing = await AppDependencies.memoryRepository
          .getMemoryForInstance(
            familyId: familyContext.familyId,
            instanceId: selected.id,
          );

      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      _noteController.text = existing?.note ?? '';

      setState(() {
        _existingMemory = existing;
        _isLoadingExistingMemory = false;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _isLoadingExistingMemory = false;
        _errorMessage = 'We could not check for an existing Memory.';
      });
    }
  }

  Future<void> _saveMemory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final familyContext = _familyContext;
    final selectedMoment = _selectedMoment;
    final selectedInstance = _selectedInstance;

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
      final existing = _existingMemory;

      final recordedParticipants =
          selectedInstance?.allRecordedParticipantIds ?? const <String>[];

      final participantIds = recordedParticipants.isNotEmpty
          ? recordedParticipants
          : selectedInstance?.expectedParticipantIds ??
                selectedMoment.expectedParticipantIds;

      final memory = FamilyMemory(
        id: existing?.id ?? selectedInstance?.id ?? selectedMoment.id,
        familyId: familyContext.familyId,
        momentId: selectedMoment.id,
        instanceId: selectedInstance?.id,
        title: selectedInstance?.titleSnapshot ?? selectedMoment.title,
        occurredAt:
            selectedInstance?.effectiveStartAt.toUtc() ??
            selectedMoment.startAt.toUtc(),
        photoUrls: existing?.photoUrls ?? const <String>[],
        participantIds: participantIds,
        note: _noteController.text.trim(),
        aiReflection: existing?.aiReflection,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await AppDependencies.memoryRepository.saveMemory(memory);

      if (selectedInstance != null) {
        await AppDependencies.momentInstanceRepository.addEvidenceSignals(
          familyId: familyContext.familyId,
          instanceId: selectedInstance.id,
          signals: const <MomentEvidenceSignal>[
            MomentEvidenceSignal.familyNote,
            MomentEvidenceSignal.memoryCreated,
          ],
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error is ArgumentError
            ? error.message?.toString()
            : 'We could not save this family Memory.';
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
            message: _errorMessage ?? 'The Memory screen is unavailable.',
            onRetry: _loadMemoryData,
          ),
        ),
      );
    }

    if (_selectedMoment == null && _completedInstances.isEmpty) {
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
                      Icons.auto_stories_outlined,
                      size: 58,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'No completed occurrences yet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Complete a Live Moment or confirm '
                      'one through Today Review first.',
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

    final selectedInstance = _selectedInstance;
    final selectedMoment = _selectedMoment!;

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
                    : 'Preserve a completed occurrence',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'A Memory now belongs to the specific '
                'occurrence, so recurring traditions can '
                'have more than one Memory over time.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_selectionIsLocked && _completedInstances.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedInstance?.id,
                  decoration: const InputDecoration(
                    labelText: 'Completed occurrence',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  items: _completedInstances
                      .map(
                        (instance) => DropdownMenuItem<String>(
                          value: instance.id,
                          child: Text(
                            '${instance.titleSnapshot} · '
                            '${DateFormat('d MMM y').format(instance.effectiveStartAt.toLocal())}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving || _isLoadingExistingMemory
                      ? null
                      : (value) {
                          if (value != null) {
                            _selectInstance(value);
                          }
                        },
                ),
              if (!_selectionIsLocked) const SizedBox(height: AppSpacing.md),
              _MemorySourceCard(
                moment: selectedMoment,
                instance: selectedInstance,
                isLegacy: _usesLegacyMomentOnly,
              ),
              if (_isLoadingExistingMemory) ...[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(),
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
                  hintText: 'What would your family like to remember?',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Write a short family note.';
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
                        'Photo upload is not connected in '
                        'this MVP. The occurrence, date, '
                        'participants, and family note are saved.',
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

class _MemorySourceCard extends StatelessWidget {
  const _MemorySourceCard({
    required this.moment,
    required this.instance,
    required this.isLegacy,
  });

  final FamilyMoment moment;
  final MomentInstance? instance;
  final bool isLegacy;

  @override
  Widget build(BuildContext context) {
    final date =
        instance?.effectiveStartAt.toLocal() ?? moment.startAt.toLocal();

    final participantCount =
        instance?.allRecordedParticipantIds.isNotEmpty == true
        ? instance!.allRecordedParticipantIds.length
        : instance?.expectedParticipantIds.length ??
              moment.expectedParticipantIds.length;

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
                  instance?.titleSnapshot ?? moment.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(DateFormat('EEEE, d MMMM y').format(date)),
          const SizedBox(height: 6),
          Text(
            '$participantCount recorded or expected '
            '${participantCount == 1 ? 'participant' : 'participants'}',
          ),
          if (isLegacy) ...[
            const SizedBox(height: 6),
            Text(
              'Legacy Memory source: no occurrence ID.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
