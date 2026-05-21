import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api/auth_api.dart';
import '../data/auth_controller.dart';
import '../theme/scenolytics_colors.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_flow_scaffold.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  var _obscure = true;
  var _submitting = false;
  var _touched = false;
  String? _formError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hintText,
    Widget? prefix,
    Widget? suffix,
  }) {
    final cs = Theme.of(context).colorScheme;
    final brightness = cs.brightness;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: brightness == Brightness.dark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.85),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ScenolyticsColors.outlineSoftFor(brightness)
              .withValues(alpha: 0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ScenolyticsColors.outlineSoftFor(brightness)
              .withValues(alpha: 0.55),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 1.6),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _touched = true;
      _formError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await widget.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // App shell opens the role dashboard (no profile redirect on login).
    } on AuthApiException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _formError = 'Could not sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openSignup() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignupPage(auth: widget.auth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final autovalidate =
        _touched ? AutovalidateMode.always : AutovalidateMode.disabled;

    return AuthFlowScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to your Scenolytics account',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_formError != null) ...[
                _AuthErrorBanner(message: _formError!),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                enabled: !_submitting,
                inputFormatters: const <TextInputFormatter>[],
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                decoration: _fieldDecoration(
                  context,
                  label: 'Email',
                  hintText: 'you@example.com',
                  prefix: Icon(Icons.alternate_email,
                      color: cs.onSurfaceVariant, size: 20),
                ),
                validator: validateEmailField,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                focusNode: _passwordFocus,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                enabled: !_submitting,
                onFieldSubmitted: (_) => _submit(),
                decoration: _fieldDecoration(
                  context,
                  label: 'Password',
                  prefix: Icon(Icons.lock_outline,
                      color: cs.onSurfaceVariant, size: 20),
                  suffix: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: cs.primary,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _GradientPrimaryButton(
                onPressed: _submitting ? null : _submit,
                label: 'Sign in',
                loading: _submitting,
              ),
              const SizedBox(height: 18),
              const _OrDivider(label: 'New to Scenolytics?'),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _submitting ? null : _openSignup,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: cs.primary.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  'Create an account',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientPrimaryButton extends StatelessWidget {
  const _GradientPrimaryButton({
    required this.onPressed,
    required this.label,
    required this.loading,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled && !loading ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ScenolyticsColors.heroBarGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
              ? const []
              : [
                  BoxShadow(
                    color: ScenolyticsColors.primaryDim.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final line = Expanded(
      child: Divider(
        color: ScenolyticsColors.outlineSoftFor(cs.brightness)
            .withValues(alpha: 0.55),
        thickness: 1,
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
