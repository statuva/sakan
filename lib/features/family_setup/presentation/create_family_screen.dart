import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});
  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _cityController = TextEditingController(text: 'Abu Dhabi');

  String _countryCode = 'AE';
  String _language = 'en';

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _familyNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AppDependencies.familyAccessRepository.createFamily(
        name: _familyNameController.text,
        countryCode: _countryCode,
        city: _cityController.text,
        preferredLanguage: _language,
      );

      if (!mounted) return;
      context.go(
        '/family-created?code=${Uri.encodeComponent(result.invitationCode)}',
      );
    } catch (error) {
      setState(() {
        _errorMessage = 'We couldn’t create your family. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Let’s start with your family',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),

                Text(
                  'You can change these details later.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _familyNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Family name',
                    hintText: 'Al Mansoori Family',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your family name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<String>(
                  initialValue: _countryCode,
                  decoration: const InputDecoration(
                    labelText: 'Country / Region',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'AE',
                      child: Text('United Arab Emirates'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _countryCode = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your city.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: const InputDecoration(
                    labelText: 'Preferred language',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                AppPrimaryButton(
                  label: 'Create Family Home',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _createFamily,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
