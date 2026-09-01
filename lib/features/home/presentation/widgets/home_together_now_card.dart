import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/member.dart';
import '../../../../shared/models/moment_instance.dart';
import '../../../../shared/widgets/cards/app_card.dart';

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
                    fontWeight: FontWeight.w700,
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
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final member = visibleMembers[index];

                  return _MemberPresenceAvatar(
                    member: member,
                    checkedIn: checkedInIds.contains(member.id),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            activeInstance == null
                ? 'Nearby Bluetooth presence is not connected yet. Live Moment check-ins will appear here.'
                : checkedInCount == 0
                ? '${activeInstance!.titleSnapshot} is live. No member check-in has been recorded yet.'
                : '$checkedInCount ${checkedInCount == 1 ? 'member is' : 'members are'} checked in to ${activeInstance!.titleSnapshot}.',
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

class _MemberPresenceAvatar extends StatelessWidget {
  const _MemberPresenceAvatar({required this.member, required this.checkedIn});

  final Member member;
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _avatarColor(member.displayName),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: checkedIn ? AppColors.success : AppColors.surface,
                    width: checkedIn ? 2.5 : 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _avatarContent(context),
              ),
              Positioned(
                right: -1,
                bottom: 1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: checkedIn ? AppColors.success : AppColors.disabled,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _firstName(member.displayName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarContent(BuildContext context) {
    final photoUrl = member.photoUrl?.trim();

    if (photoUrl == null || photoUrl.isEmpty) {
      return Center(
        child: Text(
          _initial(member.displayName),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Center(
          child: Text(
            _initial(member.displayName),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  Color _avatarColor(String name) {
    const colors = <Color>[
      Color(0xFF607B63),
      Color(0xFF9B6858),
      Color(0xFF98855E),
      Color(0xFF7A6670),
      Color(0xFF5D7180),
      Color(0xFF7C745E),
    ];

    var hash = 0;

    for (final codeUnit in name.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return colors[hash % colors.length];
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? '?' : clean[0].toUpperCase();
  }

  String _firstName(String value) {
    final clean = value.trim();
    return clean.isEmpty ? 'Member' : clean.split(RegExp(r'\s+')).first;
  }
}
