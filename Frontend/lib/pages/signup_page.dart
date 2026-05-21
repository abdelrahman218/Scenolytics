import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/profile_field_options.dart';
import '../data/api/auth_api.dart';
import '../data/auth_controller.dart';
import '../theme/scenolytics_colors.dart';
import '../utils/auth_validators.dart';
import '../utils/profile_validators.dart';
import '../widgets/auth_flow_scaffold.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _nameFocus = FocusNode();
  final _ageFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  String? _gender;
  var _role = 'actor';
  var _obscure = true;
  var _obscure2 = true;
  var _submitting = false;
  var _touched = false;
  String? _formError;

  PasswordRequirements _passwordReqs =
      const PasswordRequirements(
        minLength: false,
        hasLetter: false,
        hasDigit: false,
        withinMaxLength: false,
      );

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _name.dispose();
    _age.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool get _isActor => _role == 'actor';

  void _onPasswordChanged() {
    final next = PasswordRequirements.of(_password.text);
    if (next.minLength != _passwordReqs.minLength ||
        next.hasLetter != _passwordReqs.hasLetter ||
        next.hasDigit != _passwordReqs.hasDigit ||
        next.withinMaxLength != _passwordReqs.withinMaxLength) {
      setState(() => _passwordReqs = next);
    }
    if (_touched) {
      _formKey.currentState?.validate();
    }
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
      int? age;
      if (_isActor) {
        age = int.parse(_age.text.trim());
      }
      await widget.auth.signUpAndSignIn(
        email: _email.text.trim(),
        password: _password.text,
        role: _role,
        name: _name.text.trim(),
        age: age,
        gender: _isActor ? _gender : null,
      );
      if (!mounted) return;
      if (widget.auth.isAuthenticated) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
      if (mounted) setState(() => _formError = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _formError =
            'Could not create your account. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final autovalidate =
        _touched ? AutovalidateMode.always : AutovalidateMode.disabled;

    return AuthFlowScaffold(
      title: 'Create an account',
      subtitle: 'Join as an actor or a director',
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
              Text(
                'I am a…',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.person_outline,
                      label: 'Actor',
                      description: 'Find roles, submit auditions, get insights.',
                      selected: _isActor,
                      onTap: _submitting
                          ? null
                          : () => setState(() => _role = 'actor'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.movie_creation_outlined,
                      label: 'Director',
                      description: 'Create castings, review the best talent.',
                      selected: !_isActor,
                      onTap: _submitting
                          ? null
                          : () => setState(() => _role = 'director'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                enabled: !_submitting,
                onFieldSubmitted: (_) {
                  (_isActor ? _ageFocus : _emailFocus).requestFocus();
                },
                decoration: _fieldDecoration(
                  context,
                  label: 'Name',
                  hintText: 'Mohammed',
                  prefix: Icon(Icons.badge_outlined,
                      color: cs.onSurfaceVariant, size: 20),
                ),
                validator: validateDisplayNameField,
              ),
              if (_isActor) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _age,
                        focusNode: _ageFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        textInputAction: TextInputAction.next,
                        enabled: !_submitting,
                        onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                        decoration: _fieldDecoration(
                          context,
                          label: 'Age',
                          hintText: 'e.g. 24',
                          prefix: Icon(Icons.cake_outlined,
                              color: cs.onSurfaceVariant, size: 20),
                        ),
                        validator: validateAgeField,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        isExpanded: true,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Gender',
                          prefix: Icon(Icons.wc_outlined,
                              color: cs.onSurfaceVariant, size: 20),
                        ),
                        items: ActorProfileOptions.genderOptions
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
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                enabled: !_submitting,
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
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                enabled: !_submitting,
                onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
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
                validator: validatePasswordField,
              ),
              const SizedBox(height: 10),
              _PasswordStrengthMeter(reqs: _passwordReqs),
              const SizedBox(height: 8),
              _PasswordRulesChecklist(reqs: _passwordReqs),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                focusNode: _confirmFocus,
                obscureText: _obscure2,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                enabled: !_submitting,
                onFieldSubmitted: (_) => _submit(),
                decoration: _fieldDecoration(
                  context,
                  label: 'Confirm password',
                  prefix: Icon(Icons.lock_reset_outlined,
                      color: cs.onSurfaceVariant, size: 20),
                  suffix: IconButton(
                    tooltip: _obscure2 ? 'Show password' : 'Hide password',
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _obscure2 = !_obscure2),
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
              _GradientPrimaryButton(
                onPressed: _submitting ? null : _submit,
                label: _isActor ? 'Create actor account' : 'Create director account',
                loading: _submitting,
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop<void>(),
                  child: Text.rich(
                    TextSpan(
                      text: 'Already have an account?  ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign in',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = cs.brightness;
    final selectedBg = brightness == Brightness.dark
        ? cs.primaryContainer.withValues(alpha: 0.18)
        : cs.primaryContainer.withValues(alpha: 0.5);
    final unselectedBg = brightness == Brightness.dark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.85);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: selected ? selectedBg : unselectedBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? cs.primary
                    : ScenolyticsColors.outlineSoftFor(brightness)
                        .withValues(alpha: 0.6),
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : cs.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.reqs});

  final PasswordRequirements reqs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final value = reqs.strength.clamp(0.0, 1.0);
    final (String label, Color color) = switch (reqs.satisfiedCount) {
      0 => ('Enter a password', cs.outline),
      1 => ('Too weak', ScenolyticsColors.error),
      2 => ('Weak', ScenolyticsColors.warning),
      3 => ('Good', ScenolyticsColors.info),
      _ => ('Strong', ScenolyticsColors.success),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value == 0 ? null : value,
            minHeight: 6,
            backgroundColor: ScenolyticsColors.outlineSoftFor(cs.brightness)
                .withValues(alpha: 0.35),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Password strength: $label',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PasswordRulesChecklist extends StatelessWidget {
  const _PasswordRulesChecklist({required this.reqs});

  final PasswordRequirements reqs;

  @override
  Widget build(BuildContext context) {
    final rules = <(String, bool)>[
      ('At least 8 characters', reqs.minLength),
      ('At least one letter', reqs.hasLetter),
      ('At least one number', reqs.hasDigit),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final (label, ok) in rules) _RulePill(label: label, satisfied: ok),
      ],
    );
  }
}

class _RulePill extends StatelessWidget {
  const _RulePill({required this.label, required this.satisfied});

  final String label;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = satisfied ? ScenolyticsColors.success : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: satisfied
            ? ScenolyticsColors.successContainer.withValues(alpha: 0.6)
            : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: satisfied
              ? ScenolyticsColors.success.withValues(alpha: 0.4)
              : ScenolyticsColors.outlineSoftFor(cs.brightness)
                  .withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            satisfied ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
