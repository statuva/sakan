import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/models/family.dart';
import 'package:sakan/shared/models/member.dart';
import 'package:sakan/shared/models/model_enums.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class MembersSetupStep extends StatelessWidget {
  const MembersSetupStep({
    required this.family,
    required this.members,
    required this.onRelationshipChanged,
    required this.onContinue,
    super.key,
  });

  final Family family;
  final List<Member> members;
  final Future<void> Function(String memberId, FamilyRelationship relationship)
  onRelationshipChanged;
  final VoidCallback onContinue;

  Future<void> _copyInvitationCode(BuildContext context) async {
    final invitationCode = family.activeInvitationCode?.trim();
    if (invitationCode == null || invitationCode.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: invitationCode));

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invitation code copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your family members',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Review everyone who has joined your family home and assign their family relationship.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          _InvitationCard(
            family: family,
            onCopy: () => _copyInvitationCode(context),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Members',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${members.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (members.isEmpty)
            const AppCard(child: Text('No joined members were found.'))
          else
            ...members.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MemberCard(
                  member: member,
                  onRelationshipChanged: onRelationshipChanged,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
          AppPrimaryButton(
            label: 'Continue',
            onPressed: members.isEmpty ? null : onContinue,
          ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.family, required this.onCopy});

  final Family family;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final invitationCode = family.activeInvitationCode?.trim();
    final displayCode = invitationCode == null || invitationCode.isEmpty
        ? 'Unavailable'
        : invitationCode;
    final hasInvitationCode = displayCode != 'Unavailable';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.group_add_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Invite family members',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Share this invitation code so your family members can join before setup is completed.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Invitation code',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  displayCode,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: hasInvitationCode ? onCopy : null,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy invitation code'),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onRelationshipChanged,
  });

  final Member member;
  final Future<void> Function(String memberId, FamilyRelationship relationship)
  onRelationshipChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: Text(
                  member.displayName.isEmpty
                      ? '?'
                      : member.displayName[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleLabel(member.role),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<FamilyRelationship>(
            key: ValueKey('${member.id}-${member.relationship.name}'),
            initialValue: member.relationship,
            decoration: const InputDecoration(labelText: 'Family relationship'),
            items: FamilyRelationship.values
                .map(
                  (relationship) => DropdownMenuItem(
                    value: relationship,
                    child: Text(_relationshipLabel(relationship)),
                  ),
                )
                .toList(),
            onChanged: (relationship) async {
              if (relationship == null || relationship == member.relationship) {
                return;
              }
              await onRelationshipChanged(member.id, relationship);
            },
          ),
        ],
      ),
    );
  }

  static String _roleLabel(FamilyRole role) {
    return switch (role) {
      FamilyRole.admin => 'Family Admin',
      FamilyRole.adult => 'Adult Member',
      FamilyRole.child => 'Child Member',
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
