import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'services/budget_engine.dart';

/// Design tokens. True neutral darks (no navy/slate), one accent that lives
/// on the data (money left = green), amber/red only for warnings.
@immutable
class Tokens extends ThemeExtension<Tokens> {
  const Tokens({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.accentTint,
    required this.warn,
    required this.warnTint,
    required this.danger,
    required this.dangerTint,
    required this.onAccent,
  });

  /// Page ground.
  final Color bg;

  /// Cards and grouped lists.
  final Color surface;

  /// Sheets, controls, chips.
  final Color raised;

  /// 1px structural lines.
  final Color line;

  /// Control outlines.
  final Color lineStrong;

  /// Primary, secondary and meta text (all >= 4.5:1 on [surface]).
  final Color ink;
  final Color ink2;
  final Color ink3;

  final Color accent;
  final Color accentTint;
  final Color warn;
  final Color warnTint;
  final Color danger;
  final Color dangerTint;
  final Color onAccent;

  static const dark = Tokens(
    bg: Color(0xFF0A0A0B),
    surface: Color(0xFF141416),
    raised: Color(0xFF1D1D20),
    line: Color(0xFF26262A),
    lineStrong: Color(0xFF3C3C42),
    ink: Color(0xFFF4F4F5),
    ink2: Color(0xFFB4B4BA),
    ink3: Color(0xFF94949B),
    accent: Color(0xFF4ADE9A),
    accentTint: Color(0xFF13261C),
    warn: Color(0xFFF5B544),
    warnTint: Color(0xFF2A2112),
    danger: Color(0xFFFF6B5E),
    dangerTint: Color(0xFF2C1614),
    onAccent: Color(0xFF06140D),
  );

  static const light = Tokens(
    bg: Color(0xFFF6F6F4),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF0F0EE),
    line: Color(0xFFE6E6E3),
    lineStrong: Color(0xFFCFCFCB),
    ink: Color(0xFF111111),
    ink2: Color(0xFF555555),
    ink3: Color(0xFF6B6B6B),
    accent: Color(0xFF137A4B),
    accentTint: Color(0xFFDDF5E7),
    warn: Color(0xFF9A5B00),
    warnTint: Color(0xFFFFF3DC),
    danger: Color(0xFFC4242A),
    dangerTint: Color(0xFFFFE9E7),
    onAccent: Color(0xFFFFFFFF),
  );

  Color forStatus(BudgetStatus s) => switch (s) {
        BudgetStatus.safe => accent,
        BudgetStatus.warning => warn,
        BudgetStatus.over => danger,
      };

  Color tintFor(BudgetStatus s) => switch (s) {
        BudgetStatus.safe => accentTint,
        BudgetStatus.warning => warnTint,
        BudgetStatus.over => dangerTint,
      };

  @override
  Tokens copyWith() => this;

  @override
  Tokens lerp(Tokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Tokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      ink3: l(ink3, other.ink3),
      accent: l(accent, other.accent),
      accentTint: l(accentTint, other.accentTint),
      warn: l(warn, other.warn),
      warnTint: l(warnTint, other.warnTint),
      danger: l(danger, other.danger),
      dangerTint: l(dangerTint, other.dangerTint),
      onAccent: l(onAccent, other.onAccent),
    );
  }
}

extension TokensX on BuildContext {
  Tokens get tk => Theme.of(this).extension<Tokens>()!;
}

/// Type scale: 12 / 13 / 15 / 17 / 22 / 36.
class AppType {
  static const family = 'Cairo';
  static const meta = TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400);
  static const body = TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w400);
  static const bodyStrong = TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600);
  static const title = TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w700);
  static const figure = TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w600);
  static const page = TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w700);
  static const lead = TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.5);
}

ThemeMode themeModeFrom(String v) => switch (v) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

ThemeData buildTheme(Brightness brightness) {
  final tk = brightness == Brightness.dark ? Tokens.dark : Tokens.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: tk.ink,
    onPrimary: tk.bg,
    secondary: tk.accent,
    onSecondary: tk.onAccent,
    tertiary: tk.accent,
    onTertiary: tk.onAccent,
    error: tk.danger,
    onError: tk.bg,
    surface: tk.surface,
    onSurface: tk.ink,
    onSurfaceVariant: tk.ink2,
    outline: tk.lineStrong,
    outlineVariant: tk.line,
    surfaceContainerLowest: tk.surface,
    surfaceContainerLow: tk.surface,
    surfaceContainer: tk.raised,
    surfaceContainerHigh: tk.raised,
    surfaceContainerHighest: tk.raised,
    primaryContainer: tk.raised,
    onPrimaryContainer: tk.ink,
    secondaryContainer: tk.raised,
    onSecondaryContainer: tk.ink,
    inverseSurface: tk.ink,
    onInverseSurface: tk.bg,
  );
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
  final text = base.textTheme.apply(bodyColor: tk.ink, displayColor: tk.ink);
  return base.copyWith(
    textTheme: text,
    dividerTheme: DividerThemeData(color: tk.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: tk.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppType.title.copyWith(color: tk.ink, fontFamily: AppType.family),
      iconTheme: IconThemeData(color: tk.ink),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: tk.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tk.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tk.raised,
      labelStyle: AppType.body.copyWith(color: tk.ink2),
      floatingLabelStyle: AppType.label.copyWith(color: tk.ink2),
      hintStyle: AppType.body.copyWith(color: tk.ink3),
      helperStyle: AppType.meta.copyWith(color: tk.ink3),
      suffixStyle: AppType.body.copyWith(color: tk.ink2),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tk.ink2, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tk.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    // Primary action: inverted (ink on ground), never a brand fill.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tk.ink,
        foregroundColor: tk.bg,
        disabledBackgroundColor: tk.raised,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppType.bodyStrong.copyWith(fontFamily: AppType.family),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tk.ink,
        minimumSize: const Size(44, 44),
        textStyle: AppType.bodyStrong.copyWith(fontFamily: AppType.family),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tk.ink,
        side: BorderSide(color: tk.lineStrong),
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: AppType.bodyStrong.copyWith(fontFamily: AppType.family),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tk.surface,
      selectedColor: tk.ink,
      side: BorderSide(color: tk.line),
      labelStyle: AppType.label.copyWith(color: tk.ink, fontFamily: AppType.family),
      secondaryLabelStyle: AppType.label.copyWith(color: tk.bg, fontFamily: AppType.family),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: tk.surface,
        foregroundColor: tk.ink2,
        selectedBackgroundColor: tk.ink,
        selectedForegroundColor: tk.bg,
        side: BorderSide(color: tk.line),
        textStyle: AppType.label.copyWith(fontFamily: AppType.family, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? tk.accent : tk.raised),
      thumbColor: WidgetStatePropertyAll(brightness == Brightness.dark ? tk.ink : Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tk.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: tk.lineStrong,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tk.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: AppType.title.copyWith(color: tk.ink, fontFamily: AppType.family),
      contentTextStyle: AppType.body.copyWith(color: tk.ink2, fontFamily: AppType.family),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tk.ink,
      contentTextStyle: AppType.body.copyWith(color: tk.bg, fontFamily: AppType.family),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tk.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: AppType.body.copyWith(color: tk.ink, fontFamily: AppType.family),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: tk.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: tk.surface,
      headerForegroundColor: tk.ink,
      dayForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? tk.bg : tk.ink),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? tk.ink : null),
      todayForegroundColor: WidgetStatePropertyAll(tk.accent),
      todayBorder: BorderSide(color: tk.accent),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: tk.surface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tk.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => AppType.meta.copyWith(
            fontFamily: AppType.family,
            color: s.contains(WidgetState.selected) ? tk.ink : tk.ink3,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? tk.ink : tk.ink3,
            size: 24,
          )),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tk.ink,
      foregroundColor: tk.bg,
      elevation: 0,
      highlightElevation: 0,
      extendedTextStyle: AppType.bodyStrong.copyWith(fontFamily: AppType.family),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(brightness: brightness, primaryColor: tk.ink),
  );
}
