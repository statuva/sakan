import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/models/moment_instance.dart';
import 'calendar_palette.dart';

class ActiveMomentBanner extends StatefulWidget {
  const ActiveMomentBanner({
    required this.instance,
    required this.onOpen,
    super.key,
  });

  final MomentInstance instance;
  final VoidCallback onOpen;

  @override
  State<ActiveMomentBanner> createState() => _ActiveMomentBannerState();
}

class _ActiveMomentBannerState extends State<ActiveMomentBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.instance.actualStartAt;

    final rawElapsed = start == null
        ? Duration.zero
        : DateTime.now().difference(start.toLocal());

    final elapsed = rawElapsed.isNegative ? Duration.zero : rawElapsed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: CalendarPalette.forestSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CalendarPalette.forest.withAlpha(80)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CalendarPalette.forestDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE FAMILY MOMENT',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: CalendarPalette.forestDark,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.instance.titleSnapshot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CalendarPalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDuration(elapsed)} · Tap to join',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CalendarPalette.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: CalendarPalette.forestDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(hours)}:'
        '${twoDigits(minutes)}:'
        '${twoDigits(seconds)}';
  }
}
