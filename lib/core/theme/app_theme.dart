import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `design/app.pen`의 색 토큰. 이름은 디자인 변수 이름을 따른다.
///
/// 무채색 바탕에 포인트 색([accent]) 하나를 쓴다. 디자인의 `primary-strong`·`brand`는
/// [primary]와 같은 값이라 따로 두지 않는다.
/// 화면에서는 이 값을 직접 쓰지 않고 `Theme.of(context).colorScheme`이나 [AppColors]로 꺼낸다.
abstract final class AppPalette {
  static const bgApp = Color(0xFFF5F5F4);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1A1A1A);
  static const primarySoft = Color(0xFFF0F0EE);
  static const line = Color(0xFFE6E6E4);
  static const lineSoft = Color(0xFFF0F0EE);
  static const textPrimary = Color(0xFF191F1C);
  static const textSecondary = Color(0xFF5F5F5F);
  static const textMuted = Color(0xFF737373);
  static const accent = Color(0xFF2D5BFF);
  static const onAccent = Color(0xFFFFFFFF);
  static const accentOnDark = Color(0xFF7C9BFF);
  static const heroSub = Color(0xFFBDBDBD);
  static const barMuted = Color(0xFFD4D4D2);
  static const sky = Color(0xFF1A1A1A);
  static const skySoft = Color(0xFF1A1A1A);
  static const sea = Color(0xFF6B6B69);
  static const seaSoft = Color(0xFFFFFFFF);
  static const memberLine = Color(0xFFD6D6D4);
  static const danger = Color(0xFFC93C3C);
}

/// [ColorScheme]에 자리가 없는 디자인 토큰.
///
/// - [textMuted]: 흐린 글자. 카드·시트·입력란처럼 흰 바탕 위에서만 쓴다.
/// - 두 사람 구분은 색이 아니라 채움과 테두리로 한다. 관리자([sky])는 [skySoft]를 채운 동그라미에
///   흰 글자, 상대([sea])는 [seaSoft] 바탕에 [memberLine] 테두리와 [sea] 글자.
/// - 남는 현금 같은 검정 카드 위에서는 금액에 [accentOnDark], 보조 글자에 [heroSub]를 쓴다.
/// - 막대그래프에서 강조하지 않는 막대는 [barMuted].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.textMuted,
    required this.accentOnDark,
    required this.heroSub,
    required this.barMuted,
    required this.sky,
    required this.skySoft,
    required this.sea,
    required this.seaSoft,
    required this.memberLine,
  });

  final Color textMuted;
  final Color accentOnDark;
  final Color heroSub;
  final Color barMuted;
  final Color sky;
  final Color skySoft;
  final Color sea;
  final Color seaSoft;
  final Color memberLine;

  static const light = AppColors(
    textMuted: AppPalette.textMuted,
    accentOnDark: AppPalette.accentOnDark,
    heroSub: AppPalette.heroSub,
    barMuted: AppPalette.barMuted,
    sky: AppPalette.sky,
    skySoft: AppPalette.skySoft,
    sea: AppPalette.sea,
    seaSoft: AppPalette.seaSoft,
    memberLine: AppPalette.memberLine,
  );

  @override
  AppColors copyWith({
    Color? textMuted,
    Color? accentOnDark,
    Color? heroSub,
    Color? barMuted,
    Color? sky,
    Color? skySoft,
    Color? sea,
    Color? seaSoft,
    Color? memberLine,
  }) => AppColors(
    textMuted: textMuted ?? this.textMuted,
    accentOnDark: accentOnDark ?? this.accentOnDark,
    heroSub: heroSub ?? this.heroSub,
    barMuted: barMuted ?? this.barMuted,
    sky: sky ?? this.sky,
    skySoft: skySoft ?? this.skySoft,
    sea: sea ?? this.sea,
    seaSoft: seaSoft ?? this.seaSoft,
    memberLine: memberLine ?? this.memberLine,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      textMuted: mix(textMuted, other.textMuted),
      accentOnDark: mix(accentOnDark, other.accentOnDark),
      heroSub: mix(heroSub, other.heroSub),
      barMuted: mix(barMuted, other.barMuted),
      sky: mix(sky, other.sky),
      skySoft: mix(skySoft, other.skySoft),
      sea: mix(sea, other.sea),
      seaSoft: mix(seaSoft, other.seaSoft),
      memberLine: mix(memberLine, other.memberLine),
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
    // 버튼과 선택된 칩은 검정이다.
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    primaryContainer: AppPalette.primarySoft,
    onPrimaryContainer: AppPalette.primary,
    secondary: AppPalette.primary,
    onSecondary: Colors.white,
    // 선택 표시는 디자인에서 컴포넌트마다 달라(탭은 포인트 색, 칩은 검정, 세그먼트는 흰 바탕)
    // 그 화면을 만들 때 컴포넌트 테마로 정한다. 여기서는 중립색만 둔다.
    secondaryContainer: AppPalette.primarySoft,
    onSecondaryContainer: AppPalette.primary,
    // 포인트 색. 선택된 탭, + 버튼, 지급 전 배지, 입력 중인 칸, 앱 아이콘에만 쓴다.
    tertiary: AppPalette.accent,
    onTertiary: AppPalette.onAccent,
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
        borderSide: BorderSide(color: AppPalette.accent, width: 1.5),
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
