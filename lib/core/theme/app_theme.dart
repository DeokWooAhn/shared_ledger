import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `design/app.pen`의 색 토큰. 이름은 디자인 변수 이름을 따른다.
///
/// 화면에서는 이 값을 직접 쓰지 않고 `Theme.of(context).colorScheme`이나 [AppColors]로 꺼낸다.
abstract final class AppPalette {
  static const bgApp = Color(0xFFF4F5F3);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF237A6D);
  static const primaryStrong = Color(0xFF1F6F63);
  static const brand = Color(0xFF4AA596);
  static const primarySoft = Color(0xFFE7F3F0);
  static const line = Color(0xFFE3E7E4);
  static const lineSoft = Color(0xFFEEF1EF);
  static const textPrimary = Color(0xFF191F1C);
  static const textSecondary = Color(0xFF5E6762);
  static const textMuted = Color(0xFF6F7773);
  static const sky = Color(0xFF3E63C9);
  static const skySoft = Color(0xFFEAF0FD);
  static const sea = Color(0xFFB04A32);
  static const seaSoft = Color(0xFFFDEDE8);
  static const warn = Color(0xFF9A5B00);
  static const warnSoft = Color(0xFFFFF3DC);
  static const danger = Color(0xFFC93C3C);
}

/// [ColorScheme]에 자리가 없는 디자인 토큰.
///
/// 두 사람을 구분하는 색(관리자 [sky], 상대 [sea])과 '지급 전' 같은 주의 표시([warn])에 쓴다.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.textMuted,
    required this.brand,
    required this.sky,
    required this.skySoft,
    required this.sea,
    required this.seaSoft,
    required this.warn,
    required this.warnSoft,
  });

  final Color textMuted;
  final Color brand;
  final Color sky;
  final Color skySoft;
  final Color sea;
  final Color seaSoft;
  final Color warn;
  final Color warnSoft;

  static const light = AppColors(
    textMuted: AppPalette.textMuted,
    brand: AppPalette.brand,
    sky: AppPalette.sky,
    skySoft: AppPalette.skySoft,
    sea: AppPalette.sea,
    seaSoft: AppPalette.seaSoft,
    warn: AppPalette.warn,
    warnSoft: AppPalette.warnSoft,
  );

  @override
  AppColors copyWith({
    Color? textMuted,
    Color? brand,
    Color? sky,
    Color? skySoft,
    Color? sea,
    Color? seaSoft,
    Color? warn,
    Color? warnSoft,
  }) => AppColors(
    textMuted: textMuted ?? this.textMuted,
    brand: brand ?? this.brand,
    sky: sky ?? this.sky,
    skySoft: skySoft ?? this.skySoft,
    sea: sea ?? this.sea,
    seaSoft: seaSoft ?? this.seaSoft,
    warn: warn ?? this.warn,
    warnSoft: warnSoft ?? this.warnSoft,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      textMuted: mix(textMuted, other.textMuted),
      brand: mix(brand, other.brand),
      sky: mix(sky, other.sky),
      skySoft: mix(skySoft, other.skySoft),
      sea: mix(sea, other.sea),
      seaSoft: mix(seaSoft, other.seaSoft),
      warn: mix(warn, other.warn),
      warnSoft: mix(warnSoft, other.warnSoft),
    );
  }
}

extension AppColorsContext on BuildContext {
  /// [buildAppTheme]이 항상 등록한다. 테마 없이 그린 위젯 테스트에서는 밝은 색을 쓴다.
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// 상태 표시줄과 내비게이션 바를 투명하게 해 화면 바탕과 잇고, 아이콘은 어둡게 한다.
/// app.dart에서 앱 전체를 감싸 쓰고, AppBar 테마에서도 같은 값을 쓴다.
const appSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// 디자인 토큰으로 만든 앱 테마. 다크 모드는 디자인이 생기면 추가한다.
///
/// 글꼴은 시스템 글꼴을 쓴다(디자인의 Noto Sans KR은 앱에 넣지 않음).
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    primaryContainer: AppPalette.primarySoft,
    onPrimaryContainer: AppPalette.primaryStrong,
    secondary: AppPalette.brand,
    onSecondary: Colors.white,
    // 선택된 세그먼트·칩·탭 표시는 디자인의 primary-soft 바탕을 쓴다.
    secondaryContainer: AppPalette.primarySoft,
    onSecondaryContainer: AppPalette.primaryStrong,
    error: AppPalette.danger,
    onError: Colors.white,
    // 화면 바탕은 bg-app, 카드·시트·입력란은 card(흰색).
    surface: AppPalette.bgApp,
    onSurface: AppPalette.textPrimary,
    onSurfaceVariant: AppPalette.textSecondary,
    surfaceContainerLowest: AppPalette.card,
    surfaceContainerLow: AppPalette.card,
    surfaceContainer: AppPalette.card,
    surfaceContainerHigh: AppPalette.card,
    surfaceContainerHighest: AppPalette.lineSoft,
    outline: AppPalette.line,
    outlineVariant: AppPalette.lineSoft,
  );

  final base = ThemeData(colorScheme: scheme);
  final text = base.textTheme
      .apply(
        bodyColor: AppPalette.textPrimary,
        displayColor: AppPalette.textPrimary,
      )
      .copyWith(
        headlineMedium: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppPalette.textPrimary,
        ),
        headlineSmall: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppPalette.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppPalette.textPrimary,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: AppPalette.textPrimary),
        bodyMedium: const TextStyle(
          fontSize: 15,
          color: AppPalette.textPrimary,
        ),
        bodySmall: const TextStyle(
          fontSize: 13,
          color: AppPalette.textSecondary,
        ),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppPalette.textSecondary,
        ),
        labelSmall: const TextStyle(fontSize: 12, color: AppPalette.textMuted),
      );

  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );
  const buttonSize = Size(64, 54);
  const fieldRadius = BorderRadius.all(Radius.circular(12));

  return base.copyWith(
    scaffoldBackgroundColor: AppPalette.bgApp,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.bgApp,
      foregroundColor: AppPalette.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: appSystemOverlayStyle,
    ),
    cardTheme: const CardThemeData(
      color: AppPalette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        backgroundColor: AppPalette.card,
        foregroundColor: AppPalette.textPrimary,
        side: const BorderSide(color: AppPalette.line),
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: text.bodyLarge?.copyWith(color: AppPalette.textMuted),
      // 기본값은 한 줄이라 '초대 코드를 찾을 수 없어요…' 같은 안내가 잘린다.
      errorMaxLines: 3,
      border: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppPalette.line),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppPalette.line),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppPalette.primary, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppPalette.danger),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppPalette.danger, width: 1.5),
      ),
    ),
    extensions: const [AppColors.light],
  );
}
