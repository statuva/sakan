import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class FamilyCreatedScreen extends StatelessWidget {
  const FamilyCreatedScreen({required this.invitationCode, super.key});

  final String invitationCode;
  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: invitationCode));

    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invitation code copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              Icon(
                Icons.home_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 24),
              Text(
                'your family home is ready',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 8),

              Text(
                'share this invitation with your family so they can join sakan',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              AppCard(
                child: Column(
                  children: [
                    const Text('invitation code'),

                    const SizedBox(height: 12),

                    SelectableText(
                      invitationCode,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),

                    const SizedBox(height: 24),

                    QrImageView(
                      data: 'sakan://join/$invitationCode',
                      version: QrVersions.auto,
                      size: 220,
                    ),

                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: () => _copyCode(context),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('copy code'),
                    ),

                    const SizedBox(height: 32),

                    AppPrimaryButton(
                      label: 'contionue to family setup',
                      onPressed: () {
                        context.go('/family-setup');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
