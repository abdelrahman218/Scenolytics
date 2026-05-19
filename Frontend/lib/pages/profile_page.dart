import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api/user_management_api.dart';
import '../data/models/auth_user.dart';
import '../theme/scenolytics_colors.dart';

/// Profile page for the signed-in user.
///
/// Loads the existing actor/director profile row from the User Management
/// service (`GET /api/v1/{actors|directors}/:user_id/profile`) and renders an
/// editable form covering every column in the corresponding schema. All fields
/// are optional. Saving will:
///   - `POST  /api/v1/{actors|directors}/profile`              if no row exists
///   - `PATCH /api/v1/{actors|directors}/profile/:profile_id`  otherwise
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.user,
    this.userManagementApi,
    this.userEmail,
    this.accountRoleLabel,
  });

  /// Signed-in identity. When null, the page falls back to the read-only header
  /// shown previously (used for legacy callers that haven't been wired yet).
  final AuthUser? user;

  /// Required for editing. When null the form is hidden and only the header
  /// shows.
  final UserManagementApi? userManagementApi;

  /// Optional override for the header email label (defaults to [user.email]).
  final String? userEmail;

  /// Optional override for the role label (defaults to [user.role] capitalized).
  final String? accountRoleLabel;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _genderOptions = <String>[
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
  static const _bodyTypeOptions = <String>[
    'Slim',
    'Athletic',
    'Average',
    'Muscular',
    'Curvy',
    'Plus size',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();

  // Actor controllers ---------------------------------------------------------
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  final _heightCm = TextEditingController();
  final _age = TextEditingController();
  final _ethnicity = TextEditingController();
  final _personalityTraits = TextEditingController();
  final _genres = TextEditingController();
  final _experienceYears = TextEditingController();
  final _portfolioUrl = TextEditingController();
  String? _gender;
  String? _bodyType;

  // Director controllers ------------------------------------------------------
  final _companyName = TextEditingController();
  final _companyBio = TextEditingController();
  final _website = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();

  // State ---------------------------------------------------------------------
  bool _loading = true;
  bool _saving = false;
  String? _profileId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    _heightCm.dispose();
    _age.dispose();
    _ethnicity.dispose();
    _personalityTraits.dispose();
    _genres.dispose();
    _experienceYears.dispose();
    _portfolioUrl.dispose();
    _companyName.dispose();
    _companyBio.dispose();
    _website.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  AuthUser? get _user => widget.user;
  UserManagementApi? get _api => widget.userManagementApi;
  bool get _isActor => _user?.isActor ?? false;
  bool get _isDirector => _user?.isDirector ?? false;
  bool get _canEdit => _user != null && _api != null && (_isActor || _isDirector);

  Future<void> _loadProfile() async {
    final user = _user;
    final api = _api;
    if (user == null || api == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = user.isActor
          ? await api.getActorProfile(user.userId, bearerToken: user.token)
          : user.isDirector
              ? await api.getDirectorProfile(
                  user.userId,
                  bearerToken: user.token,
                )
              : null;
      if (!mounted) return;
      if (profile != null) {
        _hydrateFromProfile(profile);
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load profile (${e.runtimeType}).';
      });
    }
  }

  void _hydrateFromProfile(Map<String, dynamic> p) {
    _profileId = p['id']?.toString().trim();

    _displayName.text = _str(p['display_name']);
    if (_isActor) {
      _bio.text = _str(p['bio']);
      _heightCm.text = _intStr(p['height_cm']);
      _age.text = _intStr(p['age']);
      final g = _str(p['gender']);
      _gender = g.isEmpty ? null : _matchOption(g, _genderOptions);
      _ethnicity.text = _str(p['ethnicity']);
      final bt = _str(p['body_type']);
      _bodyType = bt.isEmpty ? null : _matchOption(bt, _bodyTypeOptions);
      _personalityTraits.text = _csv(p['personality_traits']);
      _genres.text = _csv(p['genres']);
      _experienceYears.text = _intStr(p['experience_years']);
      _portfolioUrl.text = _str(p['portfolio_url']);
    } else if (_isDirector) {
      _companyName.text = _str(p['company_name']);
      _companyBio.text = _str(p['company_bio']);
      _website.text = _str(p['website']);
      _phone.text = _str(p['phone']);
      _location.text = _str(p['location']);
    }
  }

  String _str(Object? v) => (v?.toString().trim()) ?? '';

  String _intStr(Object? v) {
    if (v == null) return '';
    if (v is num) return v.toInt().toString();
    final s = v.toString().trim();
    final n = int.tryParse(s);
    return n?.toString() ?? '';
  }

  String _csv(Object? v) {
    if (v == null) return '';
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(', ');
    }
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return '';
      // Server may store JSON arrays as strings; tolerate both.
      if ((s.startsWith('[') && s.endsWith(']'))) {
        return s
            .substring(1, s.length - 1)
            .split(',')
            .map((e) => e.replaceAll(RegExp(r'^[\s"\u201C\u201D]+|[\s"\u201C\u201D]+$'), ''))
            .where((e) => e.isNotEmpty)
            .join(', ');
      }
      return s;
    }
    return v.toString();
  }

  String _matchOption(String value, List<String> options) {
    for (final opt in options) {
      if (opt.toLowerCase() == value.toLowerCase()) return opt;
    }
    return options.last;
  }

  Map<String, dynamic> _collectActorFields() {
    final fields = <String, dynamic>{};
    void putString(String key, String value) {
      final t = value.trim();
      if (t.isNotEmpty) fields[key] = t;
    }

    void putInt(String key, String value) {
      final t = value.trim();
      if (t.isEmpty) return;
      final n = int.tryParse(t);
      if (n != null) fields[key] = n;
    }

    void putList(String key, String value) {
      final parts = value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) fields[key] = parts;
    }

    putString('display_name', _displayName.text);
    putString('bio', _bio.text);
    putInt('height_cm', _heightCm.text);
    putInt('age', _age.text);
    if (_gender != null && _gender!.trim().isNotEmpty) fields['gender'] = _gender;
    putString('ethnicity', _ethnicity.text);
    if (_bodyType != null && _bodyType!.trim().isNotEmpty) fields['body_type'] = _bodyType;
    putList('personality_traits', _personalityTraits.text);
    putList('genres', _genres.text);
    putInt('experience_years', _experienceYears.text);
    putString('portfolio_url', _portfolioUrl.text);
    return fields;
  }

  Map<String, dynamic> _collectDirectorFields() {
    final fields = <String, dynamic>{};
    void putString(String key, String value) {
      final t = value.trim();
      if (t.isNotEmpty) fields[key] = t;
    }

    putString('display_name', _displayName.text);
    putString('company_name', _companyName.text);
    putString('company_bio', _companyBio.text);
    putString('website', _website.text);
    putString('phone', _phone.text);
    putString('location', _location.text);
    return fields;
  }

  Future<void> _save() async {
    final user = _user;
    final api = _api;
    if (user == null || api == null) return;
    if (!(_formKey.currentState?.validate() ?? true)) return;

    setState(() => _saving = true);
    try {
      final fields = _isActor ? _collectActorFields() : _collectDirectorFields();
      Map<String, dynamic> result;
      if (_profileId == null || _profileId!.isEmpty) {
        result = _isActor
            ? await api.createActorProfile(
                userId: user.userId,
                fields: fields,
                bearerToken: user.token,
              )
            : await api.createDirectorProfile(
                userId: user.userId,
                fields: fields,
                bearerToken: user.token,
              );
        final newId = result['id']?.toString().trim();
        if (newId != null && newId.isNotEmpty) _profileId = newId;
      } else {
        result = _isActor
            ? await api.updateActorProfile(
                profileId: _profileId!,
                fields: fields,
                bearerToken: user.token,
              )
            : await api.updateDirectorProfile(
                profileId: _profileId!,
                fields: fields,
                bearerToken: user.token,
              );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on UserManagementApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save profile (${e.runtimeType}).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // UI ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final headerEmail =
        (widget.userEmail?.trim().isNotEmpty ?? false)
            ? widget.userEmail!.trim()
            : (_user?.email.trim() ?? '');
    final headerRole = (widget.accountRoleLabel?.trim().isNotEmpty ?? false)
        ? widget.accountRoleLabel!.trim()
        : _defaultRoleLabel(_user?.role);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: cs.shadow.withValues(alpha: 0.12),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ProfileHeader(email: headerEmail, role: headerRole),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!_canEdit)
            Text(
              'Profile details will appear here when your account information is available.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          else ...[
            if (_loadError != null) ...[
              _InfoBanner(
                icon: Icons.info_outline,
                color: cs.tertiary,
                message: _loadError!,
              ),
              const SizedBox(height: 16),
            ],
            Form(
              key: _formKey,
              child: _isActor
                  ? _buildActorForm(context)
                  : _isDirector
                      ? _buildDirectorForm(context)
                      : const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving…' : 'Save changes'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActorForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('About you'),
        _textField(controller: _displayName, label: 'Display name'),
        _textField(
          controller: _bio,
          label: 'Bio',
          maxLines: 4,
          helper: 'A short personal blurb.',
        ),
        _SectionTitle('Personal details'),
        Row(
          children: [
            Expanded(
              child: _intField(
                controller: _age,
                label: 'Age',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _intField(
                controller: _heightCm,
                label: 'Height (cm)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Gender',
          value: _gender,
          options: _genderOptions,
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 12),
        _textField(controller: _ethnicity, label: 'Ethnicity'),
        const SizedBox(height: 12),
        _dropdown(
          label: 'Body type',
          value: _bodyType,
          options: _bodyTypeOptions,
          onChanged: (v) => setState(() => _bodyType = v),
        ),
        _SectionTitle('Acting'),
        _textField(
          controller: _personalityTraits,
          label: 'Personality traits',
          helper:
              'Comma-separated, e.g. confident, witty, calm. (Note: not yet persisted by backend.)',
        ),
        _textField(
          controller: _genres,
          label: 'Genres',
          helper: 'Comma-separated, e.g. drama, comedy, thriller.',
        ),
        _intField(controller: _experienceYears, label: 'Experience (years)'),
        _textField(
          controller: _portfolioUrl,
          label: 'Portfolio URL',
          keyboard: TextInputType.url,
          helper:
              'Saved on first profile creation. Editing the URL later is not '
              'supported by the current backend update endpoint.',
        ),
      ],
    );
  }

  Widget _buildDirectorForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('About you'),
        _textField(controller: _displayName, label: 'Display name'),
        _SectionTitle('Company'),
        _textField(controller: _companyName, label: 'Company name'),
        _textField(
          controller: _companyBio,
          label: 'Company bio',
          maxLines: 4,
        ),
        _textField(
          controller: _website,
          label: 'Website',
          keyboard: TextInputType.url,
        ),
        _SectionTitle('Contact'),
        _textField(
          controller: _phone,
          label: 'Phone',
          keyboard: TextInputType.phone,
        ),
        _textField(controller: _location, label: 'Location'),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboard,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: _decoration(label, helper: helper),
      ),
    );
  }

  Widget _intField({
    required TextEditingController controller,
    required String label,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: _decoration(label, helper: helper),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _decoration(label),
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(
          value: null,
          child: Text('—'),
        ),
        ...options.map(
          (g) => DropdownMenuItem<String>(value: g, child: Text(g)),
        ),
      ],
      onChanged: _saving ? null : onChanged,
    );
  }

  InputDecoration _decoration(String label, {String? helper}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
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
}

String _defaultRoleLabel(String? role) {
  switch (role) {
    case 'actor':
      return 'Actor';
    case 'director':
      return 'Director';
    case null:
    case '':
      return '';
    default:
      return role[0].toUpperCase() + role.substring(1);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.email, required this.role});

  final String email;
  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.person_rounded, size: 52, color: cs.primary),
        ),
        const SizedBox(height: 16),
        Text(
          email.isNotEmpty ? email : 'Signed in',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (role.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            role,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
