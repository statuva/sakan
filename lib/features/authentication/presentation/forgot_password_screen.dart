import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakan/app/app_dependencies.dart';
import 'package:sakan/core/theme/app_spacing.dart';
import 'package:sakan/shared/widgets/buttons/app_primary_button.dart';
import 'package:sakan/features/authentication/utils/auth_error_message.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppDependencies.authRepository.sendPasswordResetEmail(
        _emailController.text,
      );

      if (!mounted) return;

      setState(() {
        _sent = true;
      });
    } catch (error) {
      setState(() {
        _errorMessage = authErrorMessage(error);
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _sent ? _buildSuccess(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset your password',
            style: Theme.of(context).textTheme.headlineLarge,
          ),

          const SizedBox(height: 8),

          Text(
            "Enter your email and we'll send you instructions to reset your password",
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty || !email.contains('@')) {
                return ' Enter a valid email address';
              }

              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 32),

          AppPrimaryButton(
            label: 'Send reset email',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _sendReset,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),

        const SizedBox(height: 24),

        Text(
          'check your email',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),

        Text(
          'If an account exists for this email, a password-reset message has been sent.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: 32),

        AppPrimaryButton(
          label: 'Back to sign in',
          onPressed: () {
            context.go('/sign-in');
          },
        ),
      ],
    );
  }
}
