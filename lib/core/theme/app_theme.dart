import 'package:flutter/material.dart';

/// FAM — electric violet, coral warmth, mint accents; soft surfaces.
///
/// Design pass (2026 revamp): Material 3 "Expressive" defaults — bolder
/// type weights, larger touch targets, varied corner shapes instead of one
/// radius everywhere, and a per-member accent color so each family member
/// reads as a consistent "person" across avatars, task cards, and diary
/// entries. All free — no new dependencies, just Material 3 primitives
/// already ships with Flutter.
abstract final class AppTheme {
  static const seed = Color(0xFF6D4CFF);
  static const secondary = Color(0xFFFF8A65);
  static const tertiary = Color(0xFF2DD4BF);

  /// Curated, high-contrast, print-friendly palette for per-member accents.
  /// Deliberately not a raw hash-to-RGB — those tend to land on muddy
  /// colors. Picking from a short, designed list keeps every member's
  /// color feeling intentional next to the app's own primary/secondary.
  static const List<Color> memberPalette = [
    Color(0xFFEF5DA8), // rose
    Color(0xFF2DD4BF), // mint
    Color(0xFFFF8A65), // coral
    Color(0xFF6D4CFF), // violet
    Color(0xFFFFC93C), // marigold
    Color(0xFF4CC9F0), // sky
    Color(0xFF9D4EDD), // orchid
    Color(0xFF5FD068), // leaf
  ];

  /// Deterministic accent color for a member — same input (uid or email)
  /// always maps to the same color, so it's stable across the app without
  /// needing to store a color choice anywhere.
  static Color colorForMember(String seedString) {
    if (seedString.isEmpty) return memberPalette.first;
    final hash = seedString.codeUnits.fold<int>(0, (acc, c) => acc * 31 + c);
    return memberPalette[hash.abs() % memberPalette.length];
  }

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      secondary: secondary,
      tertiary: tertiary,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
    );
    return base.copyWith(
      scaffoldBackgroundColor: Color.lerp(
        scheme.surface,
        scheme.primaryContainer,
        brightness == Brightness.light ? 0.04 : 0.08,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: scheme.onSecondaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Color.lerp(scheme.surface, scheme.primaryContainer, 0.12),
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        elevation: 3,
        shadowColor: scheme.shadow.withValues(alpha: 0.12),
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // Expressive touch: pill-shaped FAB, slightly larger than default —
      // this is the button people mash the most (new memory, add task).
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: const StadiumBorder(),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          height: 1.35,
        ),
      ),
    );
  }
}

/// Reusable soft background gradient — used by hero surfaces across the app.
class AppGradient extends StatelessWidget {
  const AppGradient({
    super.key,
    required this.child,
    this.opacity = 0.55,
    this.borderRadius,
  });

  final Widget child;
  final double opacity;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: opacity),
            scheme.secondaryContainer.withValues(alpha: opacity * 0.85),
            scheme.tertiaryContainer.withValues(alpha: opacity * 0.7),
          ],
        ),
      ),
      child: child,
    );
  }
}
