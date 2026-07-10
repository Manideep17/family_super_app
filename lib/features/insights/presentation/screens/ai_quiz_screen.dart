import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/config/app_flags.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';

/// AI quiz from real diary memories. The quiz is generated server-side by
/// the `aiQuizFromMemories` callable function (heuristic for now, swappable
/// for an LLM later) and then pulled live from `ai_quizzes/{quizId}`.
class AiQuizScreen extends ConsumerStatefulWidget {
  const AiQuizScreen({super.key});

  @override
  ConsumerState<AiQuizScreen> createState() => _AiQuizScreenState();
}

class _AiQuizScreenState extends ConsumerState<AiQuizScreen> {
  static const _rng = 7919;
  bool _loading = false;
  String? _error;
  String? _quizId;
  List<_Question> _questions = const [];
  final Map<int, int> _picked = {};
  bool _submitted = false;
  int _score = 0;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _questions = const [];
      _picked.clear();
      _submitted = false;
      _score = 0;
    });
    try {
      final fid = ref.read(currentFamilyIdProvider).valueOrNull;
      if (fid == null || fid.isEmpty) {
        throw StateError('No family selected.');
      }
      if (AppFlags.functionsEnabled) {
        try {
          final res = await FirebaseFunctions.instance
              .httpsCallable('aiQuizFromMemories')
              .call(<String, dynamic>{'familyId': fid});
          final data = res.data as Map<Object?, Object?>;
          final id = data['quizId']?.toString() ?? '';
          if (id.isEmpty) throw StateError('No quiz id returned');
          final snap = await FirebaseFirestore.instance
              .collection('families')
              .doc(fid)
              .collection('ai_quizzes')
              .doc(id)
              .get();
          final raw = snap.data();
          if (raw == null) throw StateError('Quiz doc missing');
          final qs = (raw['questions'] as List<dynamic>? ?? [])
              .map((e) => _Question.fromAnyMap(e))
              .where((q) => q.options.length >= 2)
              .toList();
          if (qs.isEmpty) throw StateError('Quiz has no valid questions.');
          setState(() {
            _quizId = id;
            _questions = qs;
          });
          return;
        } catch (_) {}
      }
      // Spark-safe fallback: generate a quiz directly from recent stories.
      final fallback = await _buildLocalQuiz(fid);
      setState(() {
        _quizId = 'local-${DateTime.now().millisecondsSinceEpoch}';
        _questions = fallback;
        _error = null;
      });
      await AppAnalytics.logEvent(
        'quiz_generated',
        params: {
          'mode': AppFlags.functionsEnabled ? 'function_or_fallback' : 'local',
          'question_count': fallback.length,
        },
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<_Question>> _buildLocalQuiz(String familyId) async {
    final snap = await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('stories')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .get();
    if (snap.docs.length < 3) {
      throw StateError(
        'Need at least 3 diary memories before generating a quiz.',
      );
    }

    final stories = snap.docs
        .map((d) => d.data())
        .where((m) => (m['title']?.toString().trim().isNotEmpty ?? false))
        .toList();
    if (stories.length < 3) {
      throw StateError(
        'Not enough memory data yet. Add a few diary entries and try again.',
      );
    }

    final authors = stories
        .map((m) => m['authorName']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    final moods = stories
        .map((m) => m['mood']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    final titles = stories
        .map((m) => m['title']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    final dayBuckets = stories
        .map((m) {
          final ts = m['createdAt'];
          if (ts is Timestamp) {
            final d = ts.toDate();
            return _weekdayName(d.weekday);
          }
          return '';
        })
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    final tagPool = <String>{};
    for (final s in stories) {
      final tags = s['taggedEmails'] as List<dynamic>? ?? const [];
      for (final t in tags) {
        final v = t.toString().trim();
        if (v.isNotEmpty) tagPool.add(v);
      }
    }
    final tags = tagPool.toList();

    final questions = <_Question>[];
    for (var i = 0; i < stories.length && questions.length < 5; i++) {
      final s = stories[i];
      final title = s['title']?.toString().trim() ?? '';
      final body = s['body']?.toString().trim() ?? '';
      final author = s['authorName']?.toString().trim() ?? '';
      final mood = s['mood']?.toString().trim() ?? '';
      if (title.isEmpty) continue;

      if (author.isNotEmpty && authors.length >= 2 && questions.length < 5) {
        final options = _buildOptions(correct: author, pool: authors);
        questions.add(
          _Question(
            prompt: 'Who wrote "$title"?',
            options: options,
            answerIndex: options.indexOf(author),
          ),
        );
      }

      if (mood.isNotEmpty && moods.length >= 2 && questions.length < 5) {
        final options = _buildOptions(correct: mood, pool: moods);
        questions.add(
          _Question(
            prompt: 'What mood was tagged for "$title"?',
            options: options,
            answerIndex: options.indexOf(mood),
          ),
        );
      }

      if (body.length >= 20 && titles.length >= 2 && questions.length < 5) {
        final options = _buildOptions(correct: title, pool: titles);
        final snippet = body.length > 70 ? '${body.substring(0, 70)}...' : body;
        questions.add(
          _Question(
            prompt: 'Which memory matches this line: "$snippet"',
            options: options,
            answerIndex: options.indexOf(title),
          ),
        );
      }

      final ts = s['createdAt'];
      if (ts is Timestamp && dayBuckets.length >= 2 && questions.length < 5) {
        final day = _weekdayName(ts.toDate().weekday);
        final options = _buildOptions(correct: day, pool: dayBuckets);
        questions.add(
          _Question(
            prompt: 'On which weekday was "$title" posted?',
            options: options,
            answerIndex: options.indexOf(day),
          ),
        );
      }

      final tagged = (s['taggedEmails'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (tagged.isNotEmpty && tags.length >= 2 && questions.length < 5) {
        final firstTag = tagged.first;
        final options = _buildOptions(correct: firstTag, pool: tags);
        questions.add(
          _Question(
            prompt: 'Who was tagged in "$title"?',
            options: options,
            answerIndex: options.indexOf(firstTag),
          ),
        );
      }
    }

    if (questions.length < 3) {
      throw StateError(
        'Need more varied diary memories to build quiz questions.',
      );
    }
    return questions.take(5).toList();
  }

  List<String> _buildOptions({
    required String correct,
    required List<String> pool,
  }) {
    final cleaned = pool.where((e) => e.trim().isNotEmpty).toSet().toList()
      ..sort((a, b) => a.hashCode % _rng - b.hashCode % _rng);
    final options = <String>{correct};
    for (final item in cleaned) {
      if (options.length >= 4) break;
      if (item != correct) options.add(item);
    }
    return options.toList()..sort((a, b) => a.hashCode % _rng - b.hashCode % _rng);
  }

  String _weekdayName(int weekday) {
    const days = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final idx = weekday - 1;
    if (idx < 0 || idx >= days.length) return 'Mon';
    return days[idx];
  }

  Future<void> _submit() async {
    var hits = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_picked[i] == _questions[i].answerIndex) hits++;
    }
    setState(() {
      _submitted = true;
      _score = hits;
    });
    if (hits > 0) {
      try {
        await ref
            .read(gamificationRepositoryProvider)
            .recordGameRoundWon(points: hits * 5);
      } catch (_) {}
    }
    await AppAnalytics.logEvent(
      'quiz_submitted',
      params: {
        'score': hits,
        'total': _questions.length,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Memories quiz')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AppGradient(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_alt_rounded, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How well do you remember?',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '5 questions from real family diary entries · '
                            '+5 pts per correct answer',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!AppFlags.functionsEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Free mode: quiz is generated on-device from recent diary entries.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          if (_questions.isEmpty && !_loading) ...[
            Center(
              child: FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Generate a new quiz'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ],
          ] else if (_loading) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator()),
          ] else ...[
            ...List.generate(_questions.length, (i) {
              final q = _questions[i];
              final picked = _picked[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${i + 1}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.prompt,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(q.options.length, (j) {
                        final isPicked = picked == j;
                        final correct = _submitted && j == q.answerIndex;
                        final wrong = _submitted && isPicked && !correct;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _submitted
                                ? null
                                : () => setState(() => _picked[i] = j),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: correct
                                      ? Colors.green
                                      : wrong
                                          ? Colors.redAccent
                                          : isPicked
                                              ? scheme.primary
                                              : scheme.outlineVariant,
                                  width: correct || wrong ? 1.5 : 1,
                                ),
                                color: correct
                                    ? Colors.green.withValues(alpha: 0.08)
                                    : wrong
                                        ? Colors.redAccent
                                            .withValues(alpha: 0.08)
                                        : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    correct
                                        ? Icons.check_circle
                                        : wrong
                                            ? Icons.cancel
                                            : isPicked
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                    color: correct
                                        ? Colors.green
                                        : wrong
                                            ? Colors.redAccent
                                            : isPicked
                                                ? scheme.primary
                                                : scheme.outline,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(q.options[j])),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            if (_submitted)
              Card(
                color: scheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'You scored $_score / ${_questions.length}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+${_score * 5} family points',
                        style: TextStyle(color: scheme.onSecondaryContainer),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try another'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _picked.length == _questions.length ? _submit : null,
                  child: Text(
                    _picked.length == _questions.length
                        ? 'Submit answers'
                        : 'Answer all ${_questions.length} questions',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (_quizId != null)
              Text(
                'Quiz id: $_quizId',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Question {
  _Question({
    required this.prompt,
    required this.options,
    required this.answerIndex,
  });

  factory _Question.fromAnyMap(dynamic m) {
    final map = <String, dynamic>{};
    if (m is Map) {
      m.forEach((k, v) => map[k.toString()] = v);
    }
    return _Question(
      prompt: map['prompt']?.toString() ?? '',
      options: (map['options'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      answerIndex: (map['answerIndex'] as num?)?.toInt() ?? 0,
    );
  }

  final String prompt;
  final List<String> options;
  final int answerIndex;
}
