import 'package:flutter/material.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/cards/app_card.dart';

class FamilySetupScreen extends StatelessWidget {
  const FamilySetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('family setup')),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              Icon(
                Icons.home_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 24),

              Text(
                'your family is connected',
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 8),

              Text(
                "next, we'll help sakan understands the rhytms and prefernces that matter to your family",
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              const AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.group_outlined),
                  title: Text('Add family details'),
                  subtitle: Text('Set up your members and their roles.'),
                ),
              ),
              const SizedBox(height: 12),

              const AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.favorite_border_rounded),
                  title: Text('Choose family traditions'),
                  subtitle: Text(
                    'Tell Sakan which recurring moments matter to your family.',
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule_outlined),
                  title: Text('Add schedules'),
                  subtitle: Text(
                    'Help Sakan find times when your family is available.',
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune_rounded),
                  title: Text('Set preferences'),
                  subtitle: Text(
                    'Choose preferred times, activities, and reminders.',
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'The full family setup flow will be added next.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
