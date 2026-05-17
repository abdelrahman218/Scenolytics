import 'dart:convert';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../config/casting_audition_form_constants.dart';

/// One script line for the casting API `script` array (`content` + `emotion`).
class DraftScriptLine {
  const DraftScriptLine({
    required this.content,
    required this.emotion,
  });

  final String content;
  final String emotion;
}

/// Reads printable text from PDF bytes using Syncfusion (pure Dart — no pdfium / CMake).
Future<String> extractPdfPlainText(Uint8List bytes) async {
  PdfDocument? doc;
  try {
    doc = PdfDocument(inputBytes: bytes);
    return PdfTextExtractor(doc).extractText();
  } finally {
    doc?.dispose();
  }
}

/// Plain UTF-8 script file (`.txt`) → same pipeline as PDF extraction.
String decodeUtf8ScriptFile(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('\uFEFF')) {
    text = text.substring(1);
  }
  return text;
}

final RegExp _lineBracketEmotion = RegExp(
  r'^\s*\[([^\]]+)\]\s*(.*)$',
);

/// Some PDF engines emit one space between every glyph (`H e l l o`). Merge
/// runs of single-character alphanumeric tokens; normal words stay spaced.
String normalizePdfInterLetterGlyphSpaces(String input) {
  final lines = input.replaceAll('\r\n', '\n').split('\n');
  return lines.map(_normalizePdfInterLetterGlyphSpacesLine).join('\n');
}

String _normalizePdfInterLetterGlyphSpacesLine(String line) {
  final parts = line.split(RegExp(r'\s+'));
  if (parts.length <= 1) return line;

  final merged = <String>[];
  var i = 0;
  while (i < parts.length) {
    final t = parts[i];
    if (t.isEmpty) {
      i++;
      continue;
    }
    if (t.length == 1 && RegExp(r'[A-Za-z0-9]').hasMatch(t)) {
      final start = i;
      i++;
      while (i < parts.length) {
        final u = parts[i];
        if (u.isEmpty) {
          i++;
          continue;
        }
        if (u.length == 1 && RegExp(r'[A-Za-z0-9]').hasMatch(u)) {
          i++;
        } else {
          break;
        }
      }
      final runLen = i - start;
      if (runLen >= 3) {
        merged.add(parts.sublist(start, i).join());
      } else {
        for (var j = start; j < i; j++) {
          if (parts[j].isNotEmpty) merged.add(parts[j]);
        }
      }
    } else {
      merged.add(t);
      i++;
    }
  }
  return merged.join(' ');
}

/// Turns extracted PDF/plain text into draft script rows for the form.
/// Supports optional `[emotion]` prefix per line or before each sentence chunk.
List<DraftScriptLine> draftScriptLinesFromPlainText(
  String text, {
  String defaultEmotion = 'neutral',
}) {
  final withFixedGlyphs = normalizePdfInterLetterGlyphSpaces(text);
  final normalized = withFixedGlyphs.replaceAll('\r\n', '\n');
  if (normalized.trim().isEmpty) return [];

  final chunks = <String>[];

  for (final rawLine in normalized.split('\n')) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) continue;
    chunks.addAll(_splitRoughSentences(line));
  }

  return chunks
      .map((c) {
        final trimmed = c.trimRight();
        if (trimmed.isEmpty || trimmed.trimLeft().isEmpty) return null;

        final m = _lineBracketEmotion.firstMatch(trimmed);
        if (m != null) {
          final tag = m.group(1)?.trim() ?? '';
          final body = (m.group(2) ?? '').trimRight();
          if (body.trimLeft().isEmpty) return null;
          return DraftScriptLine(
            content: body,
            emotion: coerceAuditionEmotion(tag),
          );
        }

        return DraftScriptLine(
          content: trimmed,
          emotion: defaultEmotion,
        );
      })
      .whereType<DraftScriptLine>()
      .where((d) => d.content.isNotEmpty)
      .toList();
}

List<String> _splitRoughSentences(String line) {
  final trimmed = line.trimRight();
  if (trimmed.isEmpty || trimmed.trimLeft().isEmpty) return [];

  // Preserve internal spacing; only split on sentence-ending punctuation.
  final parts = trimmed
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trimRight())
      .where((s) => s.isNotEmpty)
      .toList();

  return parts.isEmpty ? <String>[trimmed] : parts;
}
