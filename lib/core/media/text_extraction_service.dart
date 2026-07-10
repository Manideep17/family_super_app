import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR + entity extraction for vault photos (report cards, medical
/// bills, IDs, scanned notes). Runs fully on-device via Google ML Kit —
/// no network call, no API quota, free forever, and privacy-friendly since
/// the image never leaves the phone for this step.
///
/// Android/iOS only (ML Kit has no web implementation) — callers should
/// check [TextExtractionService.isSupported] first.
class TextExtractionResult {
  const TextExtractionResult({
    required this.text,
    required this.dates,
    required this.phoneNumbers,
  });

  /// Empty result — used when OCR isn't supported or finds nothing.
  static const empty = TextExtractionResult(text: '', dates: [], phoneNumbers: []);

  final String text;
  final List<String> dates;
  final List<String> phoneNumbers;

  bool get isEmpty => text.isEmpty;
}

class TextExtractionService {
  TextExtractionService._();
  static final TextExtractionService instance = TextExtractionService._();

  static bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  TextRecognizer? _recognizer;
  EntityExtractor? _entityExtractor;

  TextRecognizer get _textRecognizer =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  Future<EntityExtractor> _extractor() async {
    var e = _entityExtractor;
    if (e != null) return e;
    e = EntityExtractor(language: EntityExtractorLanguage.english);
    await e.downloadModelIfNeeded();
    _entityExtractor = e;
    return e;
  }

  /// Extracts raw text plus a light pass of dates/phone numbers found in it.
  /// Swallows all errors — OCR is a nice-to-have, never a blocker for an
  /// upload — and always returns [TextExtractionResult.empty] on failure.
  Future<TextExtractionResult> extractFrom(File imageFile) async {
    if (!isSupported) return TextExtractionResult.empty;
    try {
      final input = InputImage.fromFile(imageFile);
      final recognized = await _textRecognizer.processImage(input);
      final text = recognized.text.trim();
      if (text.isEmpty) return TextExtractionResult.empty;

      final dates = <String>[];
      final phones = <String>[];
      try {
        final extractor = await _extractor();
        final annotations = await extractor.annotateText(text);
        for (final a in annotations) {
          for (final entity in a.entities) {
            if (entity.type == EntityType.dateTime) {
              dates.add(text.substring(a.start, a.end));
            } else if (entity.type == EntityType.phone) {
              phones.add(text.substring(a.start, a.end));
            }
          }
        }
      } catch (_) {
        // Entity extraction model may not be downloaded yet on first run;
        // raw text is still useful on its own.
      }

      return TextExtractionResult(
        text: text,
        dates: dates.toSet().toList(),
        phoneNumbers: phones.toSet().toList(),
      );
    } catch (_) {
      return TextExtractionResult.empty;
    }
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    await _entityExtractor?.close();
    _recognizer = null;
    _entityExtractor = null;
  }
}
