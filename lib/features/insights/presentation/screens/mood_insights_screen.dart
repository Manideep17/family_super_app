import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../diary/domain/entities/story.dart';
import '../../../diary/presentation/diary_moods.dart';
import '../../../diary/presentation/providers/diary_providers.dart';

/// Mood analytics: a soft donut + a 14-day stacked column chart driven by
/// the actual diary entries. No external service — all client-side.
class MoodInsightsScreen extends ConsumerWidget {
  const MoodInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStories = ref.watch(storiesStreamProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mood insights')),
      body: asyncStories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (stories) {
          if (stories.isEmpty) {
            return _Empty(scheme: scheme);
          }
          final byMood = <String, int>{};
          for (final s in stories) {
            byMood[s.mood] = (byMood[s.mood] ?? 0) + 1;
          }
          final total = stories.length;
          final entries = byMood.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _HeaderCard(total: total, dominant: entries.first.key),
              const SizedBox(height: 18),
              Text('Mood mix', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 56,
                    sections: entries.map((e) {
                      final color = _moodColor(context, e.key);
                      final pct = (e.value / total * 100).toStringAsFixed(0);
                      return PieChartSectionData(
                        value: e.value.toDouble(),
                        color: color,
                        title: '${_emojiFor(e.key)} $pct%',
                        radius: 56,
                        titleStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entries.map((e) {
                  return Chip(
                    avatar: CircleAvatar(
                      radius: 8,
                      backgroundColor: _moodColor(context, e.key),
                    ),
                    label: Text('${_label(e.key)} · ${e.value}'),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              Text('Last 14 days', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: _DailyBars(stories: stories),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _moodColor(BuildContext ctx, String mood) {
    final scheme = Theme.of(ctx).colorScheme;
    switch (mood) {
      case 'happy':
        return scheme.primary;
      case 'fun':
        return scheme.secondary;
      case 'love':
        return Colors.pinkAccent;
      case 'proud':
        return scheme.tertiary;
      case 'calm':
        return Colors.lightBlue;
      case 'sad':
        return Colors.indigo;
      case 'angry':
        return Colors.redAccent;
      default:
        return scheme.outline;
    }
  }

  String _label(String mood) {
    for (final o in DiaryMoods.options) {
      if (o.$1 == mood) return o.$2;
    }
    return mood;
  }

  String _emojiFor(String mood) {
    for (final o in DiaryMoods.options) {
      if (o.$1 == mood) return o.$3;
    }
    return '✨';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.total, required this.dominant});

  final int total;
  final String dominant;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AppGradient(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family mood',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total memor${total == 1 ? 'y' : 'ies'} written · '
                      'mostly $dominant',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.stories});

  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 13));

    final perDay = List<int>.filled(14, 0);
    for (final s in stories) {
      final d = s.createdAt;
      final diff = DateTime(d.year, d.month, d.day).difference(start).inDays;
      if (diff >= 0 && diff < 14) perDay[diff] += 1;
    }
    final maxValue = (perDay.reduce((a, b) => a > b ? a : b)).clamp(1, 9999);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue.toDouble() + 0.5,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= 14) return const SizedBox.shrink();
                if (i % 2 != 0) return const SizedBox.shrink();
                final d = start.add(Duration(days: i));
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat.Md().format(d),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < 14; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: perDay[i].toDouble(),
                  width: 12,
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'No memories yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Once your family starts writing diary entries, mood charts '
              'will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
