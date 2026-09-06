import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/member.dart';
import '../../../../shared/models/moment_instance.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/people/sakan_member_avatar.dart';

class HomeTogetherNowCard extends StatelessWidget {
  const HomeTogetherNowCard({
    required this.members,
    required this.activeInstance,
    super.key,
  });

  final List<Member> members;
  final MomentInstance? activeInstance;

  @override
  Widget build(BuildContext context) {
    final visibleMembers = members.where((member) => member.isActive).toList()
      ..sort(
        (first, second) => first.displayName.compareTo(second.displayName),
      );

    final checkedInIds =
        activeInstance?.allRecordedParticipantIds.toSet() ?? const <String>{};

    final checkedInCount = visibleMembers
        .where((member) => checkedInIds.contains(member.id))
        .length;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Together now',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: checkedInCount > 0
                      ? AppColors.primary.withAlpha(24)
                      : AppColors.linen,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  checkedInCount > 0
                      ? '$checkedInCount checked in'
                      : 'Presence pending',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: checkedInCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visibleMembers.isEmpty)
            Text(
              'No active family members are available yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: visibleMembers.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final member = visibleMembers[index];

                  return SakanMemberAvatar(
                    member: member,
                    diameter: 48,
                    width: 58,
                    presence: checkedInIds.contains(member.id)
                        ? SakanMemberPresence.checkedIn
                        : SakanMemberPresence.unknown,
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            activeInstance == null
                ? 'Live Moment check-ins will appear here.'
                : checkedInCount == 0
                ? '${activeInstance!.titleSnapshot} is live. '
                      'No member check-in has been recorded yet.'
                : '$checkedInCount '
                      '${checkedInCount == 1 ? 'member is' : 'members are'} '
                      'checked in to ${activeInstance!.titleSnapshot}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
