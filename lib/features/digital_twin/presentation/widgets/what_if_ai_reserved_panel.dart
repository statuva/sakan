import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../calendar/presentation/widgets/calendar_palette.dart';

class WhatIfAiReservedPanel extends StatelessWidget {
  const WhatIfAiReservedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CalendarPalette.mineSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_awesome_outlined,
            size: 19,
            color: CalendarPalette.mine,
          ),
        ),
        title: const Text('Describe another idea with AI'),
        subtitle: const Text('Reserved for the secure AI connection'),
        children: [
          TextField(
            enabled: false,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'Example: What if we had dinner with Grandma every second Friday?',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Interpret with AI'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The layout is ready, but no prompt leaves the phone and no API '
            'request runs in this version. Structured simulations above work '
            'fully without AI.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CalendarPalette.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
