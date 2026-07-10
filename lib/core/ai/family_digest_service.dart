import 'package:firebase_ai/firebase_ai.dart';

/// Free-tier "intelligence" layer for FAM.
///
/// Uses Firebase AI Logic's *Gemini Developer API* backend
/// (`FirebaseAI.googleAI()`), which runs on the free Spark plan — unlike
/// the Vertex AI backend, it does **not** require the Blaze billing plan.
/// It does need a one-time setup step in the Firebase console (AI Logic ->
/// Get started) before it will respond; see docs/AI_LOGIC_SETUP.md.
///
/// Gated behind `AppFlags.aiDigestEnabled` at the call site so a fresh
/// install that hasn't done that setup step doesn't hit an avoidable error.
class FamilyDigestService {
  FamilyDigestService();

  static const _modelName = 'gemini-2.5-flash';

  GenerativeModel? _model;

  GenerativeModel _ensureModel() {
    return _model ??= FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        temperature: 0.6,
        maxOutputTokens: 400,
      ),
    );
  }

  /// Summarizes a family's week into a short, warm digest. Throws on
  /// failure — the caller (a screen, not a repository) is expected to show
  /// the error directly since this is a best-effort, gated feature.
  Future<String> generateWeeklyDigest({
    required List<String> storySnippets,
    required List<String> completedTaskTitles,
    required List<String> upcomingEventTitles,
    required List<String> memberNames,
  }) async {
    final prompt = _buildPrompt(
      storySnippets: storySnippets,
      completedTaskTitles: completedTaskTitles,
      upcomingEventTitles: upcomingEventTitles,
      memberNames: memberNames,
    );
    final model = _ensureModel();
    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Gemini returned an empty response — try again.');
    }
    return text;
  }

  String _buildPrompt({
    required List<String> storySnippets,
    required List<String> completedTaskTitles,
    required List<String> upcomingEventTitles,
    required List<String> memberNames,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'You write short, warm weekly recap notes for a private family app '
        'used by an Indian family (mixed generations — grandparents to '
        'kids). Tone: affectionate, plain language, no corporate speak, '
        'no emoji spam (one or two is fine). 4-6 sentences total.',
      )
      ..writeln()
      ..writeln('Family members: ${memberNames.isEmpty ? "the family" : memberNames.join(", ")}');

    if (storySnippets.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Diary moments from this week:')
        ..writeln(storySnippets.map((s) => '- $s').join('\n'));
    }
    if (completedTaskTitles.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Things the family got done this week:')
        ..writeln(completedTaskTitles.map((t) => '- $t').join('\n'));
    }
    if (upcomingEventTitles.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Coming up next week:')
        ..writeln(upcomingEventTitles.map((e) => '- $e').join('\n'));
    }
    buffer
      ..writeln()
      ..writeln(
        'Write the recap now. Mention at least one specific moment or name '
        'if the data allows it — avoid being generic. End with one small, '
        'gentle nudge for next week (e.g. a suggestion tied to what\'s '
        'coming up), not a demand.',
      );
    return buffer.toString();
  }
}
