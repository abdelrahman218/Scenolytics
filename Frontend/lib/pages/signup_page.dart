import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api/auth_api.dart';
import '../data/auth_controller.dart';
import '../theme/scenolytics_colors.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_flow_scaffold.dart';

/// Sign-up form. Fields adapt to the selected role:
///  - Director: name, email, password, confirm password.
///  - Actor:    name, age, gender, email, password, confirm password.
///
/// On success the controller signs the user in and the app shell redirects to
/// the profile page.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  /// Identity `signUpValuesValidator` only accepts **Male** and **Female** for gender.
  static const _genderOptions = <String>['Male', 'Female'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _gender;
  var _role = 'actor';
  var _obscure = true;
  var _obscure2 = true;
  var _submitting = false;
  var _touched = false;

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _isActor => _role == 'actor';

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? errorText,
    Widget? suffix,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      suffixIcon: suffix,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ScenolyticsColors.outlineSoftFor(cs.brightness)
              .withValues(alpha: 0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: ScenolyticsColors.outlineSoftFor(cs.brightness)
              .withValues(alpha: 0.55),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.4),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      int? age;
      if (_isActor) {
        age = int.parse(_age.text.trim());
      }
      await widget.auth.signUpAndSignIn(
        email: _email.text,
        password: _password.text,
        role: _role,
        name: _name.text,
        age: age,
        gender: _isActor ? _gender : null,
      );
      final profileMsg = widget.auth.consumeProfileBootstrapMessage();
      if (mounted && profileMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileMsg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create account (${e.runtimeType}).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final autovalidate = _touched
        ? AutovalidateMode.always
        : AutovalidateMode.disabled;

    return AuthFlowScaffold(
      title: 'Create an account',
      subtitle: 'Join as an actor or a director',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'I am a',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'actor',
                    label: Text('Actor'),
                    icon: Icon(Icons.person_outline, size: 20),
                  ),
                  ButtonSegment<String>(
                    value: 'director',
                    label: Text('Director'),
                    icon: Icon(Icons.movie_creation_outlined, size: 20),
                  ),
                ],
                selected: <String>{_role},
                onSelectionChanged: (Set<String> next) {
                  if (next.isNotEmpty) {
                    setState(() => _role = next.first);
                  }
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: _fieldDecoration(context, label: 'Name'),
                validator: validateNameField,
              ),
              if (_isActor) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration(context, label: 'Age'),
                  validator: validateAgeField,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  isExpanded: true,
                  decoration: _fieldDecoration(context, label: 'Gender'),
                  items: _genderOptions
                      .map(
                        (g) => DropdownMenuItem<String>(
                          value: g,
                          child: Text(g),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _gender = v),
                  validator: validateGenderField,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(context, label: 'Email'),
                validator: validateEmailField,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_touched) {
                    _formKey.currentState?.validate();
                  }
                },
                decoration: _fieldDecoration(
                  context,
                  label: 'Password',
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: cs.primary,
                    ),
                  ),
                ),
                validator: validatePasswordField,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure2,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: _fieldDecoration(
                  context,
                  label: 'Confirm password',
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(
                      _obscure2
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: cs.primary,
                    ),
                  ),
                ),
                validator: (v) => validateConfirmPassword(_password.text, v),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop<void>(),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
