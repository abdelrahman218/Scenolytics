import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/casting_audition_form_constants.dart';
import '../data/api/casting_api.dart';
import '../data/repositories/auditions_repository.dart';
import '../theme/scenolytics_colors.dart';
import '../widgets/scenolytics_footer.dart';
import '../utils/pdf_audition_script_extractor.dart';

class DirectorAuditionCreationPage extends StatefulWidget {
  const DirectorAuditionCreationPage({
    super.key,
    required this.auditionsRepository,
    required this.directorToken,
    this.editAuditionId,
    this.onAuditionCreated,
    this.onAuditionUpdated,
  });

  final AuditionsRepository auditionsRepository;
  final String directorToken;

  final String? editAuditionId;

  final ValueChanged<Map<String, dynamic>>? onAuditionCreated;
  final ValueChanged<Map<String, dynamic>>? onAuditionUpdated;

  @override
  State<DirectorAuditionCreationPage> createState() =>
      _DirectorAuditionCreationPageState();
}

class _DirectorAuditionCreationPageState
    extends State<DirectorAuditionCreationPage> {
  static const double _wideBreakpoint = 900;
  static const double _xWide = 1280;
  static const double _maxContentWidth = 1240;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _minAgeController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  final TextEditingController _minHeightController = TextEditingController();
  final TextEditingController _maxHeightController = TextEditingController();

  String _mediaType = kAuditionMediaTypes[1];
  String _gender = kAuditionGenders[2];
  String _ethnicity = kAuditionEthnicities[4];
  String _bodyType = kAuditionBodyTypes[4];

  final List<_ScriptSentenceSlot> _lines = <_ScriptSentenceSlot>[
    _ScriptSentenceSlot(),
  ];

  bool _submitting = false;
  bool _pdfBusy = false;
  bool _loadingExisting = false;
  String? _loadExistingError;

  bool get _isEditMode =>
      (widget.editAuditionId?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExistingAudition();
    }
  }

  Future<void> _loadExistingAudition() async {
    final id = widget.editAuditionId?.trim() ?? '';
    if (id.isEmpty) return;
    setState(() {
      _loadingExisting = true;
      _loadExistingError = null;
    });
    try {
      final audition = await widget.auditionsRepository.fetchAuditionDetails(
        token: widget.directorToken,
        auditionId: id,
      );
      if (!mounted) return;
      _hydrateFromAudition(audition);
      setState(() => _loadingExisting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingExisting = false;
        _loadExistingError = 'Could not load audition (${e.runtimeType}).';
      });
    }
  }

  void _hydrateFromAudition(Map<String, dynamic> audition) {
    _titleController.text = audition['title']?.toString().trim() ?? '';
    _descriptionController.text =
        audition['description']?.toString().trim() ?? '';

    final type = audition['type']?.toString().trim() ?? '';
    if (kAuditionMediaTypes.contains(type)) {
      _mediaType = type;
    }

    _minAgeController.text = _intFieldText(audition['candidate_min_age']);
    _maxAgeController.text = _intFieldText(audition['candidate_max_age']);
    _minHeightController.text =
        _intFieldText(audition['candidate_min_height_cm']);
    _maxHeightController.text =
        _intFieldText(audition['candidate_max_height_cm']);

    _gender = _matchAuditionOption(
      audition['candidate_gender']?.toString() ?? '',
      kAuditionGenders,
      fallback: kAuditionGenders[2],
    );
    _ethnicity = _matchAuditionOption(
      audition['candidate_ethnicity']?.toString() ?? '',
      kAuditionEthnicities,
      fallback: kAuditionEthnicities[4],
    );
    _bodyType = _matchAuditionOption(
      audition['candidate_body_type']?.toString() ?? '',
      kAuditionBodyTypes,
      fallback: kAuditionBodyTypes[4],
    );

    final script = audition['script'];
    if (script is List && script.isNotEmpty) {
      final drafts = <DraftScriptLine>[];
      for (final row in script) {
        if (row is! Map) continue;
        drafts.add(
          DraftScriptLine(
            content: row['content']?.toString() ?? '',
            emotion: coerceAuditionEmotion(
              row['emotion']?.toString() ?? 'neutral',
            ),
          ),
        );
      }
      if (drafts.isNotEmpty) {
        _replaceLinesFromDrafts(drafts);
      }
    }
  }

  String _intFieldText(Object? value) {
    if (value == null) return '';
    if (value is num) return value.toInt().toString();
    return value.toString().trim();
  }

  String _matchAuditionOption(
    String value,
    List<String> options, {
    required String fallback,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    for (final opt in options) {
      if (opt.toLowerCase() == trimmed.toLowerCase()) return opt;
    }
    return options.contains(trimmed) ? trimmed : fallback;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    _minHeightController.dispose();
    _maxHeightController.dispose();
    for (final line in _lines) {
      line.controller.dispose();
    }
    super.dispose();
  }

  void _addSentenceRow() {
    setState(() {
      _lines.add(_ScriptSentenceSlot());
    });
  }

  void _removeSentenceRow(_ScriptSentenceSlot slot) {
    if (_lines.length <= 1) return;
    setState(() {
      slot.controller.dispose();
      _lines.remove(slot);
    });
  }

  void _replaceLinesFromDrafts(List<DraftScriptLine> drafts) {
    setState(() {
      for (final line in _lines) {
        line.controller.dispose();
      }
      _lines.clear();
      if (drafts.isEmpty) {
        _lines.add(_ScriptSentenceSlot());
      } else {
        for (final d in drafts) {
          final slot = _ScriptSentenceSlot();
          slot.emotion = d.emotion;
          slot.controller.text = d.content;
          _lines.add(slot);
        }
      }
    });
  }
  Future<void> _pickPdfAndMirrorScript() async {
    setState(() => _pdfBusy = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['pdf', 'txt'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Could not read file bytes in the browser. Try again or add lines manually.'
                  : 'Could not read file data.',
            ),
          ),
        );
        return;
      }

      final ext = _pickedExtensionLower(file);
      final String extracted;
      if (ext == 'txt') {
        extracted = decodeUtf8ScriptFile(bytes);
      } else if (ext == 'pdf') {
        extracted = await extractPdfPlainText(bytes);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Use a .pdf or .txt script export (got ${ext.isEmpty ? 'unknown type' : '.$ext'}).',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      final drafts = draftScriptLinesFromPlainText(extracted);

      if (drafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No readable sentences found. Try manual lines, a .txt export, or another PDF.',
            ),
          ),
        );
        return;
      }

      _replaceLinesFromDrafts(drafts);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${drafts.length} line(s) from "${file.name}". Adjust emotion labels if needed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Script import failed (${e.runtimeType}). '
            'Try saving as UTF-8 .txt or a simpler PDF export.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  String _pickedExtensionLower(PlatformFile file) {
    final raw = file.extension?.trim().toLowerCase() ?? '';
    final normalized =
        raw.isEmpty ? '' : (raw.startsWith('.') ? raw.substring(1) : raw);
    if (normalized.isNotEmpty) return normalized;

    final name = file.name.toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) {
      return name.substring(dot + 1);
    }
    return '';
  }

  int? _optionalPositiveInt(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }
  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (widget.directorToken.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Sign in as a director with a valid session.'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final minAge = int.tryParse(_minAgeController.text.trim());
    final maxAge = int.tryParse(_maxAgeController.text.trim());
    if (minAge == null || maxAge == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter valid integer ages.')),
      );
      return;
    }
    if (minAge > maxAge) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Minimum age cannot be greater than maximum age.'),
        ),
      );
      return;
    }

    final minH = _optionalPositiveInt(_minHeightController.text);
    final maxH = _optionalPositiveInt(_maxHeightController.text);
    if (minH != null && maxH != null && minH > maxH) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Minimum height cannot be greater than maximum height.'),
        ),
      );
      return;
    }

    final script = <Map<String, String>>[];
    for (final line in _lines) {
      final content = line.controller.text.trim();
      if (content.isEmpty) continue;
      script.add(<String, String>{
        'content': content,
        'emotion': line.emotion,
      });
    }
    if (script.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one script sentence with text before publishing.',
          ),
        ),
      );
      return;
    }

    final body = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'type': _mediaType,
      'candidate_min_age': minAge,
      'candidate_max_age': maxAge,
      'candidate_gender': _gender,
      'candidate_ethnicity': _ethnicity,
      'candidate_body_type': _bodyType,
      'script': script,
    };

    if (minH != null) body['candidate_min_height_cm'] = minH;
    if (maxH != null) body['candidate_max_height_cm'] = maxH;

    setState(() => _submitting = true);
    try {
      if (_isEditMode) {
        final id = widget.editAuditionId!.trim();
        final audition = await widget.auditionsRepository.updateDirectorAudition(
          directorToken: widget.directorToken,
          auditionId: id,
          body: body,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Audition updated successfully.')),
        );
        widget.onAuditionUpdated?.call(audition);
      } else {
        final audition = await widget.auditionsRepository.createDirectorAudition(
          directorToken: widget.directorToken,
          body: body,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Audition created successfully.')),
        );
        widget.onAuditionCreated?.call(audition);

        _titleController.clear();
        _descriptionController.clear();
        _minAgeController.clear();
        _maxAgeController.clear();
        _minHeightController.clear();
        _maxHeightController.clear();
        _replaceLinesFromDrafts(const <DraftScriptLine>[]);
        _mediaType = kAuditionMediaTypes[1];
        _gender = kAuditionGenders[2];
        _ethnicity = kAuditionEthnicities[4];
        _bodyType = kAuditionBodyTypes[4];
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Could not update audition. Try again.'
                : 'Could not create audition. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _labeledStringDropdown({
    required String label,
    required String selected,
    required List<String> options,
    String Function(String value)? optionLabel,
    required ValueChanged<String?> onChanged,
    IconData? prefixIcon,
    bool isRequired = false,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        label: _fieldLabel(label, isRequired: isRequired),
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          items: [
            for (final o in options)
              DropdownMenuItem<String>(
                value: o,
                child: Text(
                  optionLabel?.call(o) ?? o,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
  Widget _fieldLabel(String text, {bool isRequired = false}) {
    final cs = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        text: text,
        children: isRequired
            ? <InlineSpan>[
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ]
            : const <InlineSpan>[],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = theme.brightness;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: ScenolyticsColors.pageBackdropGradientFor(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final isWide = w >= _wideBreakpoint;
                final hPad = w >= _xWide
                    ? 56.0
                    : isWide
                        ? 28.0
                        : 16.0;
                final vTop = isWide ? 24.0 : 16.0;

                final kb = MediaQuery.viewInsetsOf(context).bottom;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(hPad, vTop, hPad, 28 + kb),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxContentWidth,
                      ),
                      child: Form(
                        key: _formKey,
                        child: _buildContent(theme, isWide),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const ScenolyticsFooter(),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isWide) {
    if (_loadingExisting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroHeader(theme: theme, isEditMode: _isEditMode),
          const SizedBox(height: 24),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    if (_loadExistingError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroHeader(theme: theme, isEditMode: _isEditMode),
          const SizedBox(height: 24),
          Icon(Icons.cloud_off_rounded,
              size: 40, color: theme.colorScheme.error),
          const SizedBox(height: 10),
          Text(
            _loadExistingError!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadExistingAudition,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      );
    }

    final basics = _SectionCard(
      icon: Icons.movie_creation_outlined,
      title: 'Basics',
      isRequired: true,
      child: _buildBasicsBody(theme),
    );
    final criteria = _SectionCard(
      icon: Icons.groups_2_outlined,
      title: 'Candidate criteria',
      subtitle: 'Filters help us match the right actors to your call. '
          'Ages are required, everything else has a sensible default.',
      child: _buildCriteriaBody(theme),
    );
    final script = _SectionCard(
      icon: Icons.menu_book_rounded,
      title: 'Script & emotions',
      isRequired: true,
      subtitle:
          'Each row is one sentence saved against the audition with an emotion label.',
      child: _buildScriptBody(theme, isWide),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroHeader(theme: theme, isEditMode: _isEditMode),
        const SizedBox(height: 18),
        if (isWide) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: basics),
                const SizedBox(width: 18),
                Expanded(child: criteria),
              ],
            ),
          ),
          const SizedBox(height: 18),
          script,
        ] else ...[
          basics,
          const SizedBox(height: 16),
          criteria,
          const SizedBox(height: 16),
          script,
        ],
        const SizedBox(height: 22),
        _PublishCta(
          submitting: _submitting,
          disabled: _submitting || _pdfBusy || _loadingExisting,
          isEditMode: _isEditMode,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildBasicsBody(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            label: _fieldLabel('Title', isRequired: true),
            hintText: 'e.g. Drama reel — hospital scene',
            prefixIcon: const Icon(Icons.title_rounded, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Required';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            alignLabelWithHint: true,
            labelText: 'Description (optional)',
            hintText: 'Tone, wardrobe, pacing notes for actors…',
          ),
          minLines: 4,
          maxLines: 6,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _AuditionTypeSegmented(
          selected: _mediaType,
          onChanged: (v) => setState(() => _mediaType = v),
        ),
      ],
    );
  }

  Widget _buildCriteriaBody(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _minAgeController,
                decoration: InputDecoration(
                  label: _fieldLabel('Min age', isRequired: true),
                  prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null ||
                      v.trim().isEmpty ||
                      int.tryParse(v.trim()) == null) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _maxAgeController,
                decoration: InputDecoration(
                  label: _fieldLabel('Max age', isRequired: true),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null ||
                      v.trim().isEmpty ||
                      int.tryParse(v.trim()) == null) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _minHeightController,
                decoration: const InputDecoration(
                  labelText: 'Min height (cm)',
                  hintText: 'e.g. 160',
                  prefixIcon: Icon(Icons.height_rounded, size: 20),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _maxHeightController,
                decoration: const InputDecoration(
                  labelText: 'Max height (cm)',
                  hintText: 'e.g. 188',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _labeledStringDropdown(
          label: 'Gender',
          selected: _gender,
          options: kAuditionGenders,
          prefixIcon: Icons.wc_outlined,
          onChanged: (v) {
            if (v != null) setState(() => _gender = v);
          },
        ),
        const SizedBox(height: 12),
        _labeledStringDropdown(
          label: 'Ethnicity',
          selected: _ethnicity,
          options: kAuditionEthnicities,
          prefixIcon: Icons.public_outlined,
          onChanged: (v) {
            if (v != null) setState(() => _ethnicity = v);
          },
        ),
        const SizedBox(height: 12),
        _labeledStringDropdown(
          label: 'Body type',
          selected: _bodyType,
          options: kAuditionBodyTypes,
          prefixIcon: Icons.accessibility_new_rounded,
          onChanged: (v) {
            if (v != null) setState(() => _bodyType = v);
          },
        ),
      ],
    );
  }

  Widget _buildScriptBody(ThemeData theme, bool isWide) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: (_pdfBusy || _submitting)
                  ? null
                  : _pickPdfAndMirrorScript,
              icon: _pdfBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(
                _pdfBusy ? 'Reading file…' : 'Import from PDF / TXT',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: (_submitting || _pdfBusy) ? null : _addSentenceRow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add sentence'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: BorderSide(color: cs.outlineVariant),
              ),
            ),
            Text(
              '${_lines.length} ${_lines.length == 1 ? 'sentence' : 'sentences'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...List<Widget>.generate(_lines.length, (index) {
          final line = _lines[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SentenceCard(
              index: index,
              line: line,
              isWide: isWide,
              // The first sentence is the one we hard-require (the publish
              // validator rejects an empty script). Subsequent sentences are
              // optional bonus material.
              isRequired: index == 0,
              canRemove: _lines.length > 1,
              onRemove: () => _removeSentenceRow(line),
              onEmotionChanged: (v) {
                setState(() => line.emotion = v);
              },
            ),
          );
        }),
      ],
    );
  }
}

class _ScriptSentenceSlot {
  _ScriptSentenceSlot();

  final TextEditingController controller = TextEditingController();
  String emotion = 'neutral';
}

/// Top hero card — same gradient family as the rest of the app.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.theme, required this.isEditMode});

  final ThemeData theme;
  final bool isEditMode;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ScenolyticsColors.heroBarGradientFor(theme.brightness),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  isEditMode
                      ? Icons.edit_note_rounded
                      : Icons.movie_filter_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditMode ? 'Edit audition' : 'New audition',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEditMode
                          ? 'Update the brief, candidate filters, and '
                              'emotion-tagged script actors will perform.'
                          : 'Define the brief, candidate filters, and emotion-tagged '
                              'script lines actors will perform.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '*',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'marks required fields',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.isRequired = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = theme.brightness;

    final cardColor = b == Brightness.dark
        ? const Color(0xFF0F1E2B).withValues(alpha: 0.92)
        : cs.surface.withValues(alpha: 0.96);

    return Material(
      color: cardColor,
      elevation: b == Brightness.dark ? 0 : 2,
      shadowColor: Colors.black.withValues(
        alpha: b == Brightness.dark ? 0 : 0.06,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: b == Brightness.dark
              ? cs.outline.withValues(alpha: 0.32)
              : cs.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isRequired) const _RequiredPill(),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Compact "Required *" pill shown beside section titles.
class _RequiredPill extends StatelessWidget {
  const _RequiredPill();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.error.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '*',
            style: TextStyle(
              color: cs.error,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              height: 1,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Required',
            style: TextStyle(
              color: cs.error,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Audio / Video toggle as a Material 3 SegmentedButton.
class _AuditionTypeSegmented extends StatelessWidget {
  const _AuditionTypeSegmented({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text.rich(
            TextSpan(
              text: 'Audition type',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'Audio',
                label: Text('Audio'),
                icon: Icon(Icons.mic_rounded, size: 18),
              ),
              ButtonSegment<String>(
                value: 'Video',
                label: Text('Video'),
                icon: Icon(Icons.videocam_rounded, size: 18),
              ),
            ],
            selected: <String>{selected},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) onChanged(set.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.standard,
              padding: WidgetStatePropertyAll<EdgeInsets>(
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single script sentence editor: numbered badge + text + emotion pill chips.
class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.index,
    required this.line,
    required this.isWide,
    required this.canRemove,
    required this.onRemove,
    required this.onEmotionChanged,
    this.isRequired = false,
  });

  final int index;
  final _ScriptSentenceSlot line;
  final bool isWide;
  final bool canRemove;
  final bool isRequired;
  final VoidCallback onRemove;
  final ValueChanged<String> onEmotionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = emotionAccent(line.emotion);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SentenceNumberBadge(index: index + 1, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: line.controller,
                  decoration: InputDecoration(
                    label: Text.rich(
                      TextSpan(
                        text: 'Sentence ${index + 1}',
                        children: isRequired
                            ? <InlineSpan>[
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: cs.error,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ]
                            : const <InlineSpan>[],
                      ),
                    ),
                    hintText: 'Line or stage direction',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  minLines: 2,
                  maxLines: 5,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: canRemove ? 'Remove sentence' : 'At least one sentence',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
                color: cs.error,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _EmotionPickerWrap(
              selected: line.emotion,
              onChanged: onEmotionChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceNumberBadge extends StatelessWidget {
  const _SentenceNumberBadge({required this.index, required this.accent});

  final int index;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: accent,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Wrap of emoji-leading pill chips, one per backend emotion enum.
class _EmotionPickerWrap extends StatelessWidget {
  const _EmotionPickerWrap({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emotion',
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in kAuditionScriptEmotions)
              _EmotionPillChip(
                value: e,
                isSelected: e == selected,
                onTap: () => onChanged(e),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmotionPillChip extends StatelessWidget {
  const _EmotionPillChip({
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = emotionAccent(value);

    final bg = isSelected
        ? accent.withValues(alpha: 0.22)
        : cs.surface.withValues(alpha: 0.7);
    final border = isSelected
        ? accent
        : cs.outlineVariant.withValues(alpha: 0.85);
    final fg = isSelected ? accent : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: border,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emotionEmoji(value),
                style: const TextStyle(fontSize: 16, height: 1),
              ),
              const SizedBox(width: 6),
              Text(
                emotionLabelForUi(value),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width gradient publish button (matches the hero header family).
class _PublishCta extends StatelessWidget {
  const _PublishCta({
    required this.submitting,
    required this.disabled,
    required this.isEditMode,
    required this.onPressed,
  });

  final bool submitting;
  final bool disabled;
  final bool isEditMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: disabled
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF6B8794),
                            Color(0xFF6B8794),
                          ],
                        )
                      : ScenolyticsColors.heroBarGradient,
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: disabled ? null : onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (submitting)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      else
                        Icon(
                          isEditMode
                              ? Icons.save_rounded
                              : Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        submitting
                            ? (isEditMode ? 'Saving…' : 'Publishing…')
                            : (isEditMode ? 'Save changes' : 'Create audition'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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
    );
  }
}
