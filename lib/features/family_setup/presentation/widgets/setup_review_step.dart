import 'package:flutter/material.dart';

import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/models/rhythm_setup_draft.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class SetupReviewStep extends StatelessWidget {
  const SetupReviewStep({
    required this.family,
    required this.members,
    required this.rhythmDrafts,
    required this.isSaving,
    required this.onBack,
    required this.onComplete,
    super.key,
  });

  final Family family;
  final List<Member> members;
  final List<RhythmSetupDraft> rhythmDrafts;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review your family setup',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Check everything before Sakan creates your initial family rhythm baseline.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Family', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${members.length} joined ${members.length == 1 ? 'member' : 'members'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (family.city.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${family.city}, ${family.countryCode}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Members', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: members.isEmpty
                ? const Text('No family members found.')
                : Column(
                    children: List.generate(members.length, (index) {
                      final member = members[index];
                      return Column(
                        children: [
                          _ReviewMemberRow(member: member),
                          if (index != members.length - 1) const Divider(),
                        ],
                      );
                    }),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Selected rhythms',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: rhythmDrafts.isEmpty
                ? const Text('No family rhythms selected.')
                : Column(
                    children: List.generate(rhythmDrafts.length, (index) {
                      final rhythm = rhythmDrafts[index];
                      return Column(
                        children: [
                          _ReviewRhythmRow(
                            rhythm: rhythm,
                            participantNames: _participantNames(
                              rhythm: rhythm,
                              members: members,
                            ),
                          ),
                          if (index != rhythmDrafts.length - 1) const Divider(),
                        ],
                      );
                    }),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How your baseline starts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'All selected rhythms will begin as “Still Learning”. Their confidence will improve as your family completes real moments together.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : onBack,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Complete Setup',
                  isLoading: isSaving,
                  onPressed: isSaving ? null : onComplete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _participantNames({
    required RhythmSetupDraft rhythm,
    required List<Member> members,
  }) {
    final names = members
        .where((member) => rhythm.expectedParticipantIds.contains(member.id))
        .map((member) => member.displayName)
        .toList(growable: false);

    return names.isEmpty ? 'No participants selected' : names.join(', ');
  }
}

class _ReviewMemberRow extends StatelessWidget {
  const _ReviewMemberRow({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_roleLabel(member.role)} · ${_relationshipLabel(member.relationship)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(FamilyRole role) {
    return switch (role) {
      FamilyRole.admin => 'Admin',
      FamilyRole.adult => 'Adult',
      FamilyRole.child => 'Child',
    };
  }

  static String _relationshipLabel(FamilyRelationship relationship) {
    return switch (relationship) {
      FamilyRelationship.parent => 'Parent',
      FamilyRelationship.child => 'Child',
      FamilyRelationship.grandparent => 'Grandparent',
      FamilyRelationship.sibling => 'Sibling',
      FamilyRelationship.guardian => 'Guardian',
      FamilyRelationship.relative => 'Relative',
      FamilyRelationship.other => 'Other',
    };
  }
}

class _ReviewRhythmRow extends StatelessWidget {
  const _ReviewRhythmRow({
    required this.rhythm,
    required this.participantNames,
  });

  final RhythmSetupDraft rhythm;
  final String participantNames;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rhythm.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_frequencyLabel(rhythm.expectedIntervalDays)} · ${_importanceLabel(rhythm.importanceLevel)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  participantNames,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Next: ${_formatDate(rhythm.nextOccurrenceAt)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _frequencyLabel(int days) {
    return switch (days) {
      1 => 'Daily',
      7 => 'Weekly',
      14 => 'Every 2 weeks',
      30 => 'Monthly',
      90 => 'Every 3 months',
      365 => 'Yearly',
      _ => 'Every $days days',
    };
  }

  static String _importanceLabel(int level) {
    if (level >= 5) return 'Essential';
    if (level >= 4) return 'Important';
    if (level >= 3) return 'Moderate';
    if (level >= 2) return 'Low';
    return 'Minimal';
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
