import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'services/budget_engine.dart';

/// Design tokens. Banking look: deep navy for the hero surfaces, orange for
/// the one call to action, white cards with soft shadows on a cool grey
/// ground. Dark mode keeps the same navy family.
@immutable
class Tokens extends ThemeExtension<Tokens> {
  const Tokens({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.raised,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.primary,
    required this.primaryEnd,
    required this.onPrimary,
    required this.onPrimary2,
    required this.accent,
    required this.accentTint,
    required this.onAccent,
    required this.good,
    required this.goodTint,
    required this.warn,
    required this.warnTint,
    required this.danger,
    required this.dangerTint,
    required this.shadow,
  });

  final bool dark;

  /// Page ground, cards, inputs/chips.
  final Color bg;
  final Color surface;
  final Color raised;
  final Color line;
  final Color lineStrong;

  /// Text: primary, secondary, meta (all >= 4.5:1 on [surface]).
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// Navy hero surfaces (gradient from [primary] to [primaryEnd]).
  final Color primary;
  final Color primaryEnd;
  final Color onPrimary;
  final Color onPrimary2;

  /// Orange: the main action and highlights.
  final Color accent;
  final Color accentTint;
  final Color onAccent;

  final Color good;
  final Color goodTint;
  final Color warn;
  final Color warnTint;
  final Color danger;
  final Color dangerTint;
  final Color shadow;

  /// Status colours that read on the navy hero.
  static const heroGood = Color(0xFF6EE7A8);
  static const heroWarn = Color(0xFFFFC27A);
  static const heroDanger = Color(0xFFFF9C9C);

  static const light = Tokens(
    dark: false,
    bg: Color(0xFFF2F3F8),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFEEF0F6),
    line: Color(0xFFE6E8F0),
    lineStrong: Color(0xFFCDD0DE),
    ink: Color(0xFF17163F),
    ink2: Color(0xFF4E5171),
    ink3: Color(0xFF686C8C),
    primary: Color(0xFF1E1B5E),
    primaryEnd: Color(0xFF3B35B2),
    onPrimary: Color(0xFFFFFFFF),
    onPrimary2: Color(0xFFC8C7EE),
    accent: Color(0xFFF2763A),
    accentTint: Color(0xFFFFEDE3),
    onAccent: Color(0xFFFFFFFF),
    good: Color(0xFF15803D),
    goodTint: Color(0xFFDCFCE7),
    warn: Color(0xFFB45309),
    warnTint: Color(0xFFFEF3C7),
    danger: Color(0xFFDC2626),
    dangerTint: Color(0xFFFEE2E2),
    shadow: Color(0x161E1B5E),
  );

  static const darkTokens = Tokens(
    dark: true,
    bg: Color(0xFF0D0C22),
    surface: Color(0xFF17163A),
    raised: Color(0xFF222052),
    line: Color(0xFF2B2963),
    lineStrong: Color(0xFF3F3C85),
    ink: Color(0xFFF3F3FA),
    ink2: Color(0xFFBDBCE0),
    ink3: Color(0xFF9E9DCA),
    primary: Color(0xFF26227A),
    primaryEnd: Color(0xFF4A43CF),
    onPrimary: Color(0xFFFFFFFF),
    onPrimary2: Color(0xFFC8C7EE),
    accent: Color(0xFFFF8A4C),
    accentTint: Color(0xFF3A2418),
    onAccent: Color(0xFF1B0C04),
    good: Color(0xFF4ADE80),
    goodTint: Color(0xFF12301F),
    warn: Color(0xFFFBBF24),
    warnTint: Color(0xFF33280F),
    danger: Color(0xFFF87171),
    dangerTint: Color(0xFF3A1717),
    shadow: Color(0x00000000),
  );

  Gradient get hero => LinearGradient(
        colors: [primary, primaryEnd],
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      );

  List<BoxShadow> get cardShadow =>
      dark ? const [] : [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))];

  Color forStatus(BudgetStatus s) => switch (s) {
        BudgetStatus.safe => good,
        BudgetStatus.warning => warn,
        BudgetStatus.over => danger,
      };

  Color tintFor(BudgetStatus s) => switch (s) {
        BudgetStatus.safe => goodTint,
        BudgetStatus.warning => warnTint,
        BudgetStatus.over => dangerTint,
      };

  static Color onHero(BudgetStatus s) => switch (s) {
        BudgetStatus.safe => heroGood,
        BudgetStatus.warning => heroWarn,
        BudgetStatus.over => heroDanger,
      };

  @override
  Tokens copyWith() => this;

  @override
  Tokens lerp(Tokens? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension TokensX on BuildContext {
  Tokens get tk => Theme.of(this).extension<Tokens>()!;
}

/// Type scale.
class AppType {
  static const family = 'Cairo';
  static const meta = TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500);
  static const label = TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500);
  static const body = TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500);
  static const bodyStrong = TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w700);
  static const title = TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w800);
  static const figure = TextStyle(fontSize: 20, height: 1.25, fontWeight: FontWeight.w800);
  static const page = TextStyle(fontSize: 26, height: 1.25, fontWeight: FontWeight.w800);
  static const lead = TextStyle(fontSize: 44, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -0.5);
}

/// Radii.
class R {
  static const card = 22.0;
  static const hero = 28.0;
  static const control = 16.0;
  static const tile = 14.0;
}

ThemeMode themeModeFrom(String v) => switch (v) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };

ThemeData buildTheme(Brightness brightness) {
  final tk = brightness == Brightness.dark ? Tokens.darkTokens : Tokens.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: tk.primary,
    onPrimary: tk.onPrimary,
    secondary: tk.accent,
    onSecondary: tk.onAccent,
    tertiary: tk.accent,
    onTertiary: tk.onAccent,
    error: tk.danger,
    onError: Colors.white,
    surface: tk.surface,
    onSurface: tk.ink,
    onSurfaceVariant: tk.ink2,
    outline: tk.lineStrong,
    outlineVariant: tk.line,
    surfaceContainerLowest: tk.surface,
    surfaceContainerLow: tk.surface,
    surfaceContainer: tk.raised,
    surfaceContainerHigh: tk.surface,
    surfaceContainerHighest: tk.raised,
    primaryContainer: tk.raised,
    onPrimaryContainer: tk.ink,
    secondaryContainer: tk.accentTint,
    onSecondaryContainer: tk.ink,
    inverseSurface: tk.ink,
    onInverseSurface: tk.bg,
  );
  final btnBg = tk.dark ? tk.primaryEnd : tk.primary;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: AppType.family,
    scaffoldBackgroundColor: tk.bg,
    canvasColor: tk.bg,
    splashFactory: NoSplash.splashFactory,
    extensions: [tk],
  );
  final f = AppType.family;
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: tk.ink, displayColor: tk.ink),
    dividerTheme: DividerThemeData(color: tk.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: tk.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppType.title.copyWith(color: tk.ink, fontFamily: f),
      iconTheme: IconThemeData(color: tk.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tk.raised,
      labelStyle: AppType.body.copyWith(color: tk.ink3),
      floatingLabelStyle: AppType.label.copyWith(color: tk.ink2, fontWeight: FontWeight.w700),
      hintStyle: AppType.body.copyWith(color: tk.ink3),
      helperStyle: AppType.meta.copyWith(color: tk.ink3),
      suffixStyle: AppType.body.copyWith(color: tk.ink3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.control), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.control), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.control),
        borderSide: BorderSide(color: tk.dark ? tk.primaryEnd : tk.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.control),
        borderSide: BorderSide(color: tk.danger, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: btnBg,
        foregroundColor: Colors.white,
        disabledBackgroundColor: tk.raised,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.control)),
        textStyle: AppType.bodyStrong.copyWith(fontFamily: f, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tk.accent,
        minimumSize: const Size(44, 44),
        textStyle: AppType.bodyStrong.copyWith(fontFamily: f),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tk.ink,
        side: BorderSide(color: tk.lineStrong),
        minimumSize: const Size(44, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.control)),
        textStyle: AppType.bodyStrong.copyWith(fontFamily: f),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tk.surface,
      selectedColor: btnBg,
      side: BorderSide(color: tk.line),
      labelStyle: AppType.label.copyWith(color: tk.ink, fontFamily: f),
      secondaryLabelStyle: AppType.label.copyWith(color: Colors.white, fontFamily: f),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.tile)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: tk.raised,
        foregroundColor: tk.ink2,
        selectedBackgroundColor: btnBg,
        selectedForegroundColor: Colors.white,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.control)),
        textStyle: AppType.label.copyWith(fontFamily: f, fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? tk.accent : tk.raised),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tk.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: tk.lineStrong,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.hero))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tk.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.card)),
      titleTextStyle: AppType.title.copyWith(color: tk.ink, fontFamily: f),
      contentTextStyle: AppType.body.copyWith(color: tk.ink2, fontFamily: f),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tk.dark ? tk.raised : tk.primary,
      contentTextStyle: AppType.body.copyWith(color: Colors.white, fontFamily: f),
      actionTextColor: tk.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.control)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: tk.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: tk.primary,
      headerForegroundColor: Colors.white,
      dayForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : tk.ink),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? tk.accent : null),
      todayForegroundColor: WidgetStatePropertyAll(tk.accent),
      todayBorder: BorderSide(color: tk.accent),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: tk.surface),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: tk.accent, linearTrackColor: tk.raised),
    cupertinoOverrideTheme: CupertinoThemeData(brightness: brightness, primaryColor: tk.accent),
  );
}
