import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class MembersSetupStep extends StatelessWidget {
  const MembersSetupStep({required this.onContinue, super.key});

  final VoidCallback onContinue;

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
            'Review the people who have joined your family home.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: AppSpacing.xl),

          const _InvitationCard(),

          const SizedBox(height: AppSpacing.xl),

          Text('Members', style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: AppSpacing.sm),

          const _MemberCard(
            name: 'Family Admin',
            role: 'Admin',
            relationship: 'Parent',
            icon: Icons.person_rounded,
          ),

          const SizedBox(height: AppSpacing.sm),

          const _MemberCard(
            name: 'Family Member',
            role: 'Member',
            relationship: 'Not set yet',
            icon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: AppSpacing.xxl),

          AppPrimaryButton(label: 'Continue', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard();

  @override
  Widget build(BuildContext context) {
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
            'Share your invitation code with family members so they can join before setup is completed.',
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
                  'Invitation code',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'AB7K2M9Q',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invitation code copied.')),
              );
            },
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
    required this.name,
    required this.role,
    required this.relationship,
    required this.icon,
  });

  final String name;
  final String role;
  final String relationship;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(radius: 24, child: Icon(icon)),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),

                const SizedBox(height: 4),

                Text(
                  '$role · $relationship',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
