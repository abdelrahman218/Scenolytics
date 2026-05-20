import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/profile_field_options.dart';
import '../data/api/user_management_api.dart';
import '../data/models/auth_user.dart';
import '../theme/scenolytics_colors.dart';
import '../utils/actor_profile_completion.dart';
import '../utils/director_profile_completion.dart';
import '../utils/auth_validators.dart' show validateAgeField;
import '../utils/profile_validators.dart';

/// Profile page for the signed-in user.
///
/// Loads the existing actor/director profile row from the User Management
/// service (`GET /api/v1/{actors|directors}/:user_id/profile`) and renders an
/// editable form. **Required:** actors — display name, age, height, gender,
/// body type, ethnicity; directors — display name, phone. All other fields are
/// optional. Saving will:
///   - `POST  /api/v1/{actors|directors}/profile`              if no row exists
///   - `PATCH /api/v1/{actors|directors}/profile/:profile_id`  otherwise
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.user,
    this.userManagementApi,
    this.userEmail,
    this.accountRoleLabel,
    this.profileSetupRole,
    this.mandatorySetup = false,
    this.embeddedInShell = false,
    this.onSetupComplete,
    this.onLogout,
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

  /// When set (e.g. mandatory sign-up setup), drives which profile form to show.
  final String? profileSetupRole;

  /// When true (first-time sign-up setup), back navigation is blocked until the
  /// profile is saved with all required fields.
  final bool mandatorySetup;

  /// When true, rendered inside [MainShell] (no duplicate app bar).
  final bool embeddedInShell;

  /// Called after a successful save while [mandatorySetup] is active.
  final VoidCallback? onSetupComplete;

  /// Optional sign-out while the setup gate is shown.
  final Future<void> Function()? onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _wideBreakpoint = 640.0;
  static const _maxContentWidth = 720.0;

  final _formKey = GlobalKey<FormState>();

  // Actor controllers ---------------------------------------------------------
  final _displayName = TextEditingController();
  final _bio = TextEditingController();
  final _heightCm = TextEditingController();
  final _age = TextEditingController();
  final _personalityTraits = TextEditingController();
  final _genres = TextEditingController();
  final _experienceYears = TextEditingController();
  final _portfolioUrl = TextEditingController();
  String? _gender;
  String? _bodyType;
  String? _ethnicity;

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
    _displayName.addListener(_onHeaderFieldsChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _displayName.removeListener(_onHeaderFieldsChanged);
    _displayName.dispose();
    _bio.dispose();
    _heightCm.dispose();
    _age.dispose();
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

  void _onHeaderFieldsChanged() {
    if (mounted) setState(() {});
  }

  AuthUser? get _user => widget.user;
  UserManagementApi? get _api => widget.userManagementApi;

  String? get _effectiveRole {
    final setup = widget.profileSetupRole?.trim().toLowerCase();
    if (setup == 'actor' || setup == 'director') return setup;
    return _user?.normalizedRole;
  }

  bool get _isActor => _effectiveRole == 'actor';
  bool get _isDirector => _effectiveRole == 'director';
  bool get _canEdit => _user != null && _api != null && (_isActor || _isDirector);

  Future<void> _loadProfile() async {
    final user = _user;
    final api = _api;
    if (user == null || api == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = _isActor
          ? await api.getActorProfile(user.userId, bearerToken: user.token)
          : _isDirector
              ? await api.getDirectorProfile(
                  user.userId,
                  bearerToken: user.token,
                )
              : null;
      if (!mounted) return;
      if (profile != null) {
        _hydrateFromProfile(profile);
        if (widget.mandatorySetup) {
          final complete = _isActor
              ? isActorProfileComplete(profile)
              : _isDirector && isDirectorProfileComplete(profile);
          if (complete) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onSetupComplete?.call();
            });
          }
        }
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
      _gender = g.isEmpty ? null : _matchOption(g, ActorProfileOptions.genderOptions);
      final eth = _str(p['ethnicity']);
      _ethnicity =
          eth.isEmpty ? null : _matchOption(eth, ActorProfileOptions.ethnicityOptions);
      final bt = _str(p['body_type']);
      _bodyType =
          bt.isEmpty ? null : _matchOption(bt, ActorProfileOptions.bodyTypeOptions);
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

  String? _matchOption(String value, List<String> options) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    for (final opt in options) {
      if (opt.toLowerCase() == trimmed.toLowerCase()) return opt;
    }
    // Preserve server values not in the preset list (dropdown adds them).
    return trimmed;
  }

  Map<String, dynamic> _collectActorFields() {
    final fields = <String, dynamic>{
      'display_name': _displayName.text.trim(),
      'age': int.parse(_age.text.trim()),
      'height_cm': int.parse(_heightCm.text.trim()),
      'gender': _gender!.trim(),
      'body_type': _bodyType!.trim(),
      'ethnicity': _ethnicity!.trim(),
    };

    void putOptionalString(String key, String value) {
      final t = value.trim();
      if (t.isNotEmpty) fields[key] = t;
    }

    void putOptionalInt(String key, String value) {
      final t = value.trim();
      if (t.isEmpty) return;
      final n = int.tryParse(t);
      if (n != null) fields[key] = n;
    }

    void putOptionalList(String key, String value) {
      final parts = value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) fields[key] = parts;
    }

    putOptionalString('bio', _bio.text);
    putOptionalList('personality_traits', _personalityTraits.text);
    putOptionalList('genres', _genres.text);
    putOptionalInt('experience_years', _experienceYears.text);
    putOptionalString('portfolio_url', _portfolioUrl.text);
    return fields;
  }

  Map<String, dynamic> _collectDirectorFields() {
    return <String, dynamic>{
      'display_name': _displayName.text.trim(),
      'phone': _phone.text.trim(),
      'company_name': _optionalStringOrNull(_companyName.text),
      'company_bio': _optionalStringOrNull(_companyBio.text),
      'website': _optionalStringOrNull(_website.text),
      'location': _optionalStringOrNull(_location.text),
    };
  }

  /// Empty optional fields are sent as JSON `null` (not omitted) so the API
  /// does not pass `undefined` into MySQL on PATCH.
  String? _optionalStringOrNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
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
      if (_isActor) {
        result = await api.saveActorProfile(
          userId: user.userId,
          fields: fields,
          bearerToken: user.token,
          existingProfileId: _profileId,
          // Avoid PATCH on first-time setup (broken on older User Management builds).
          preferCreate: widget.mandatorySetup,
        );
        final newId = result['id']?.toString().trim();
        if (newId != null && newId.isNotEmpty) _profileId = newId;
      } else if (_profileId == null || _profileId!.isEmpty) {
        result = await api.createDirectorProfile(
          userId: user.userId,
          fields: fields,
          bearerToken: user.token,
        );
        final newId = result['id']?.toString().trim();
        if (newId != null && newId.isNotEmpty) _profileId = newId;
      } else {
        result = await api.updateDirectorProfile(
          profileId: _profileId!,
          fields: fields,
          bearerToken: user.token,
        );
      }
      if (!mounted) return;
      if (widget.mandatorySetup) {
        widget.onSetupComplete?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Profile saved successfully.'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ScenolyticsColors.success,
          ),
        );
      }
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

  String get _headerEmail {
    if (widget.userEmail?.trim().isNotEmpty ?? false) {
      return widget.userEmail!.trim();
    }
    return _user?.email.trim() ?? '';
  }

  String get _headerRole {
    if (widget.accountRoleLabel?.trim().isNotEmpty ?? false) {
      return widget.accountRoleLabel!.trim();
    }
    return _defaultRoleLabel(_user?.role);
  }

  String get _headerTitle {
    final name = _displayName.text.trim();
    if (name.isNotEmpty) return name;
    if (_headerEmail.isNotEmpty) return _headerEmail.split('@').first;
    return 'Your profile';
  }

  // UI ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brightness = theme.brightness;

    final pageBody = DecoratedBox(
        decoration: BoxDecoration(
          gradient: ScenolyticsColors.pageBackdropGradientFor(brightness),
        ),
        child: SafeArea(
          top: !widget.embeddedInShell,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideBreakpoint;
              final hPad = isWide ? 28.0 : 16.0;
              final layoutW = constraints.maxWidth;
              final sidePad = hPad +
                  (layoutW > _maxContentWidth + hPad * 2
                      ? (layoutW - _maxContentWidth - hPad * 2) / 2
                      : 0.0);

              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(sidePad, 16, sidePad, 0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _maxContentWidth),
                          child: _ProfileHeroBanner(
                            title: _headerTitle,
                            email: _headerEmail,
                            role: _headerRole,
                            isActor: _isActor,
                            isDirector: _isDirector,
                            profileExists: _profileId != null &&
                                _profileId!.isNotEmpty,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(sidePad, 20, sidePad, 28),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _maxContentWidth),
                          child: _buildContent(context, isWide: isWide),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    );

    if (widget.embeddedInShell) {
      return PopScope(
        canPop: !widget.mandatorySetup,
        child: pageBody,
      );
    }

    return PopScope(
      canPop: !widget.mandatorySetup,
      child: Scaffold(
        backgroundColor: brightness == Brightness.dark
            ? ScenolyticsColors.darkPageBackground
            : ScenolyticsColors.pageBackground,
        appBar: AppBar(
          title:
              Text(widget.mandatorySetup ? 'Complete your profile' : 'Profile'),
          automaticallyImplyLeading: !widget.mandatorySetup,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: cs.shadow.withValues(alpha: 0.12),
          iconTheme: IconThemeData(color: cs.onSurface),
          actions: widget.mandatorySetup && widget.onLogout != null
              ? [
                  TextButton(
                    onPressed: _saving ? null : () => widget.onLogout!(),
                    child: Text(
                      'Log out',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]
              : null,
        ),
        body: pageBody,
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isWide}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return _ProfileLoadingCard();
    }

    if (!_canEdit) {
      return _ProfileSectionCard(
        icon: Icons.info_outline_rounded,
        title: 'Profile unavailable',
        subtitle: 'Sign in with an actor or director account to edit details.',
        child: Text(
          'Profile details will appear here when your account information is available.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mandatorySetup) ...[
          _MandatorySetupBanner(
            theme: theme,
            colorScheme: cs,
            isDirector: _isDirector,
            onLogout: widget.embeddedInShell ? widget.onLogout : null,
            logoutEnabled: !_saving,
          ),
          const SizedBox(height: 16),
        ],
        if (_loadError != null) ...[
          _InfoBanner(
            icon: Icons.info_outline,
            color: theme.colorScheme.tertiary,
            message: _loadError!,
          ),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: _isActor
              ? _buildActorForm(context, isWide: isWide)
              : _isDirector
                  ? _buildDirectorForm(context, isWide: isWide)
                  : const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        _SaveButton(
          saving: _saving,
          onPressed: _save,
          isWide: isWide,
          label: widget.mandatorySetup ? 'Save and continue' : 'Save profile',
        ),
      ],
    );
  }

  Widget _buildActorForm(BuildContext context, {required bool isWide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileSectionCard(
          icon: Icons.badge_outlined,
          title: 'About you',
          subtitle: 'Required: display name. Bio is optional.',
          child: Column(
            children: [
              _textField(
                controller: _displayName,
                label: 'Display name',
                required: true,
                validator: validateDisplayNameField,
              ),
              _textField(
                controller: _bio,
                label: 'Bio (optional)',
                maxLines: 4,
                helper: 'A short personal blurb for your casting profile.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ProfileSectionCard(
          icon: Icons.person_outline_rounded,
          title: 'Personal details',
          subtitle: 'Required for casting match: age, height, gender, body type, ethnicity.',
          child: Column(
            children: [
              _responsiveRow(
                isWide: isWide,
                children: [
                  _intField(
                    controller: _age,
                    label: 'Age',
                    required: true,
                    validator: validateAgeField,
                  ),
                  _intField(
                    controller: _heightCm,
                    label: 'Height (cm)',
                    required: true,
                    validator: validateHeightCmField,
                  ),
                ],
              ),
              _responsiveRow(
                isWide: isWide,
                children: [
                  _dropdown(
                    label: 'Gender',
                    value: _gender,
                    options: ActorProfileOptions.genderOptions,
                    required: true,
                    validator: validateActorGenderField,
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  _dropdown(
                    label: 'Body type',
                    value: _bodyType,
                    options: ActorProfileOptions.bodyTypeOptions,
                    required: true,
                    validator: validateBodyTypeField,
                    onChanged: (v) => setState(() => _bodyType = v),
                  ),
                ],
              ),
              _dropdown(
                label: 'Ethnicity',
                value: _ethnicity,
                options: ActorProfileOptions.ethnicityOptions,
                required: true,
                validator: validateEthnicityField,
                onChanged: (v) => setState(() => _ethnicity = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ProfileSectionCard(
          icon: Icons.theater_comedy_outlined,
          title: 'Acting profile',
          subtitle: 'Skills, genres, and experience.',
          child: Column(
            children: [
              _responsiveRow(
                isWide: isWide,
                children: [
                  _textField(
                    controller: _personalityTraits,
                    label: 'Personality traits',
                    helper:
                        'Comma-separated, e.g. confident, witty, calm. (Not yet persisted by backend.)',
                  ),
                  _textField(
                    controller: _genres,
                    label: 'Genres',
                    helper: 'Comma-separated, e.g. drama, comedy, thriller.',
                  ),
                ],
              ),
              _responsiveRow(
                isWide: isWide,
                children: [
                  _intField(
                    controller: _experienceYears,
                    label: 'Experience (years)',
                  ),
                  _textField(
                    controller: _portfolioUrl,
                    label: 'Portfolio URL',
                    keyboard: TextInputType.url,
                    helper:
                        'Saved on first profile creation. Editing the URL later is not '
                        'supported by the current backend update endpoint.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectorForm(BuildContext context, {required bool isWide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileSectionCard(
          icon: Icons.badge_outlined,
          title: 'About you',
          subtitle: 'Required: display name.',
          child: _textField(
            controller: _displayName,
            label: 'Display name',
            required: true,
            validator: validateDisplayNameField,
          ),
        ),
        const SizedBox(height: 14),
        _ProfileSectionCard(
          icon: Icons.business_outlined,
          title: 'Company',
          subtitle: 'Production company or studio details.',
          child: Column(
            children: [
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
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ProfileSectionCard(
          icon: Icons.contact_mail_outlined,
          title: 'Contact',
          subtitle: 'Required: phone. Location is optional.',
          child: _responsiveRow(
            isWide: isWide,
            children: [
              _textField(
                controller: _phone,
                label: 'Phone',
                required: true,
                keyboard: TextInputType.phone,
                validator: validatePhoneField,
              ),
              _textField(
                controller: _location,
                label: 'Location (optional)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _responsiveRow({
    required bool isWide,
    required List<Widget> children,
  }) {
    if (!isWide || children.length == 1) {
      return Column(children: children);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboard,
    String? helper,
    bool required = false,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        enabled: !_saving,
        validator: validator,
        decoration: _decoration(label, helper: helper, required: required),
      ),
    );
  }

  Widget _intField({
    required TextEditingController controller,
    required String label,
    String? helper,
    bool required = false,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        enabled: !_saving,
        validator: validator,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: _decoration(label, helper: helper, required: required),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool required = false,
    FormFieldValidator<String>? validator,
  }) {
    final menuOptions = <String>[...options];
    if (value != null &&
        value.trim().isNotEmpty &&
        !menuOptions.any((o) => o.toLowerCase() == value.toLowerCase())) {
      menuOptions.insert(0, value);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: _decoration(label, required: required),
        validator: validator,
        items: <DropdownMenuItem<String>>[
          if (!required)
            const DropdownMenuItem<String>(
              value: null,
              child: Text('—'),
            ),
          ...menuOptions.map(
            (g) => DropdownMenuItem<String>(value: g, child: Text(g)),
          ),
        ],
        onChanged: _saving ? null : onChanged,
      ),
    );
  }

  InputDecoration _decoration(
    String label, {
    String? helper,
    bool required = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final b = cs.brightness;
    return InputDecoration(
      labelText: required ? '$label *' : label,
      helperText: helper,
      helperMaxLines: 3,
      filled: true,
      fillColor: b == Brightness.dark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
          : ScenolyticsColors.surfaceMuted.withValues(alpha: 0.65),
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

String _profileInitials(String title, String email) {
  final source = title.trim().isNotEmpty ? title.trim() : email.trim();
  if (source.isEmpty) return '?';
  final parts = source.split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
}

class _ProfileHeroBanner extends StatelessWidget {
  const _ProfileHeroBanner({
    required this.title,
    required this.email,
    required this.role,
    required this.isActor,
    required this.isDirector,
    required this.profileExists,
  });

  final String title;
  final String email;
  final String role;
  final bool isActor;
  final bool isDirector;
  final bool profileExists;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;
    const onHero = ScenolyticsColors.onPrimary;

    final roleIcon = isActor
        ? Icons.theater_comedy_outlined
        : isDirector
            ? Icons.movie_creation_outlined
            : Icons.person_outline_rounded;

    return Container(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.heroBarGradientFor(b),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: onHero.withValues(alpha: ScenolyticsColors.heroBorderAlpha(b)),
        ),
        boxShadow: [
          BoxShadow(
            color: ScenolyticsColors.heroGradientStart.withValues(
              alpha: ScenolyticsColors.heroGlowShadowAlpha(b),
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onHero.withValues(alpha: 0.18),
                  border: Border.all(
                    color: onHero.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _profileInitials(title, email),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: onHero,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onHero.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (role.isNotEmpty)
                          _HeroChip(
                            icon: roleIcon,
                            label: role,
                          ),
                        _HeroChip(
                          icon: profileExists
                              ? Icons.verified_outlined
                              : Icons.edit_note_outlined,
                          label: profileExists
                              ? 'Profile saved'
                              : 'Complete your profile',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    const onHero = ScenolyticsColors.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onHero.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onHero.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: onHero),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: onHero,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ScenolyticsColors.outlineSoftFor(brightness)
              .withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(
              alpha: brightness == Brightness.dark ? 0.28 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cs.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfileLoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.cardSheenFor(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ScenolyticsColors.outlineSoftFor(brightness)
              .withValues(alpha: 0.55),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.8),
          ),
        ),
      ),
    );
  }
}

class _MandatorySetupBanner extends StatelessWidget {
  const _MandatorySetupBanner({
    required this.theme,
    required this.colorScheme,
    required this.isDirector,
    this.onLogout,
    this.logoutEnabled = true,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final bool isDirector;
  final Future<void> Function()? onLogout;
  final bool logoutEnabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDirector
                        ? 'Finish your director profile'
                        : 'Finish your actor profile',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isDirector
                        ? 'Add your display name and phone, then tap Save and continue. '
                            'You cannot use the app until those required fields are saved.'
                        : 'Fill in every required field below and tap Save and continue. '
                            'You cannot use the app until your profile is complete.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (onLogout != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: logoutEnabled ? () => onLogout!() : null,
                child: Text(
                  'Log out',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.onPressed,
    required this.isWide,
    this.label = 'Save profile',
  });

  final bool saving;
  final VoidCallback onPressed;
  final bool isWide;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.heroBarGradientFor(brightness),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: ScenolyticsColors.primary.withValues(
              alpha: brightness == Brightness.dark ? 0.35 : 0.25,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: saving ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (saving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: ScenolyticsColors.onPrimary,
                    ),
                  )
                else
                  const Icon(
                    Icons.save_rounded,
                    color: ScenolyticsColors.onPrimary,
                  ),
                const SizedBox(width: 10),
                Text(
                  saving ? 'Saving…' : label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: ScenolyticsColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isWide) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
          child: button,
        ),
      );
    }
    return button;
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
