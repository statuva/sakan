import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class FamilyAccessScreen extends StatelessWidget {
  const FamilyAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('sakan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'How would you like to continue?',
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 8),

              Text(
                'Create a new family home or join one that already exists.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 32),

              AppCard(
                onTap: () {
                  context.push('/create-family');
                },
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(Icons.family_restroom_outlined),
                  ),
                  title: Text('create a family home'),
                  subtitle: Text('build a shared space for yout family'),
                  trailing: Icon(Icons.arrow_forward_ios_rounded),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              AppCard(
                onTap: () {
                  context.push('/join-family');
                },

                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(Icons.group_add_outlined)),

                  title: Text('join a family home'),
                  subtitle: Text('Enter the invitation code shared with you'),

                  trailing: Icon(Icons.arrow_back_ios_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
