import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../models/member.dart';

enum SakanMemberPresence { none, unknown, ready, nearby, checkedIn }

Color sakanMemberAvatarColor(Member member) {
  final key = member.id.trim().isNotEmpty ? member.id : member.displayName;

  return sakanMemberAvatarColorForKey(key);
}

Color sakanMemberAvatarColorForKey(String key) {
  const colors = <Color>[
    Color(0xFF607B63),
    Color(0xFF9B6858),
    Color(0xFF98855E),
    Color(0xFF7A6670),
    Color(0xFF5D7180),
    Color(0xFF7C745E),
  ];

  var hash = 0;

  for (final codeUnit in key.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }

  return colors[hash % colors.length];
}

class SakanMemberAvatar extends StatelessWidget {
  const SakanMemberAvatar({
    required this.member,
    this.diameter = 48,
    this.showName = true,
    this.presence = SakanMemberPresence.none,
    this.width,
    this.nameMaxLines = 1,
    super.key,
  });

  final Member member;
  final double diameter;
  final bool showName;
  final SakanMemberPresence presence;
  final double? width;
  final int nameMaxLines;

  @override
  Widget build(BuildContext context) {
    final statusColor = _presenceColor(presence);
    final showIndicator = presence != SakanMemberPresence.none;

    return Semantics(
      label: _semanticLabel(),
      child: SizedBox(
        width: width ?? diameter + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: diameter,
                  height: diameter,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: sakanMemberAvatarColor(member),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: presence == SakanMemberPresence.checkedIn
                          ? AppColors.success
                          : AppColors.surface,
                      width: presence == SakanMemberPresence.checkedIn
                          ? 2.6
                          : 2,
                    ),
                  ),
                  child: _avatarContent(context),
                ),
                if (showIndicator)
                  Positioned(
                    right: -1,
                    bottom: 1,
                    child: Container(
                      width: diameter * 0.27,
                      height: diameter * 0.27,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            if (showName) ...[
              const SizedBox(height: 5),
              Text(
                _firstName(member.displayName),
                maxLines: nameMaxLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatarContent(BuildContext context) {
    final photoUrl = member.photoUrl?.trim();

    if (photoUrl == null || photoUrl.isEmpty) {
      return Center(
        child: Text(
          _initial(member.displayName),
          style: TextStyle(
            fontFamily: 'Satoshi',
            color: Colors.white,
            fontSize: diameter * 0.37,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      );
    }

    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Center(
          child: Text(
            _initial(member.displayName),
            style: TextStyle(
              fontFamily: 'Satoshi',
              color: Colors.white,
              fontSize: diameter * 0.37,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        );
      },
    );
  }

  Color _presenceColor(SakanMemberPresence value) {
    return switch (value) {
      SakanMemberPresence.none => Colors.transparent,
      SakanMemberPresence.unknown => AppColors.disabled,
      SakanMemberPresence.ready => AppColors.success,
      SakanMemberPresence.nearby => AppColors.info,
      SakanMemberPresence.checkedIn => AppColors.success,
    };
  }

  String _semanticLabel() {
    final name = _firstName(member.displayName);

    return switch (presence) {
      SakanMemberPresence.none => name,
      SakanMemberPresence.unknown => '$name, presence unknown',
      SakanMemberPresence.ready => '$name, joined the Ready Room',
      SakanMemberPresence.nearby => '$name, detected nearby',
      SakanMemberPresence.checkedIn => '$name, checked in',
    };
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
