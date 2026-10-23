import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `design/app.pen`의 색 토큰. 이름은 디자인 변수 이름을 따르고, 라이트·다크 두 벌이 있다.
///
/// 코발트([primary])가 버튼·선택된 칩·남는 현금 카드를 맡고, 바탕과 글자는 푸른 회색이다.
/// 화면에서는 이 값을 직접 쓰지 않고 `Theme.of(context).colorScheme`이나 [AppColors]로 꺼낸다.
@immutable
class AppPalette {
  const AppPalette._({
    required this.bgApp,
    required this.card,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.accentText,
    required this.line,
    required this.lineSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.hero,
    required this.onHero,
    required this.accentOnDark,
    required this.heroSub,
    required this.barMuted,
    required this.sky,
    required this.sea,
    required this.avatar,
    required this.income,
    required this.danger,
    required this.onDanger,
    required this.track,
    required this.segmentOn,
  });

  final Color bgApp;
  final Color card;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;

  /// 파란 글자·아이콘. [primarySoft] 바탕 위와 카드 위 모두에서 대비가 맞는다.
  final Color accentText;
  final Color line;
  final Color lineSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color hero;

  /// 남는 현금 카드 위의 흰 글자. 디자인은 `#FFFFFF`를 직접 쓴다.
  final Color onHero;
  final Color accentOnDark;
  final Color heroSub;
  final Color barMuted;
  final Color sky;
  final Color sea;
  final Color avatar;
  final Color income;
  final Color danger;

  /// 디자인에는 오류 색으로 채운 버튼이 없다. [ColorScheme.onError]를 채우려고 둔다.
  final Color onDanger;

  /// 세그먼트(항목 종류 고르기)의 바탕.
  final Color track;

  /// 세그먼트에서 고른 칸의 바탕.
  final Color segmentOn;

  static const light = AppPalette._(
    bgApp: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFF2D5BFF),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEAF0FF),
    accentText: Color(0xFF1F45D6),
    line: Color(0xFFE4E8F0),
    lineSoft: Color(0xFFEEF1F6),
    textPrimary: Color(0xFF171A21),
    textSecondary: Color(0xFF586070),
    textMuted: Color(0xFF6B7285),
    accent: Color(0xFF2D5BFF),
    onAccent: Color(0xFFFFFFFF),
    hero: Color(0xFF2449D8),
    onHero: Color(0xFFFFFFFF),
    accentOnDark: Color(0xFFFFFFFF),
    heroSub: Color(0xFFD6E0FF),
    barMuted: Color(0xFFD5DAE4),
    sky: Color(0xFF2D5BFF),
    sea: Color(0xFF5F6677),
    avatar: Color(0xFFE4E8F0),
    income: Color(0xFF3366FF),
    danger: Color(0xFFD93A3F),
    onDanger: Color(0xFFFFFFFF),
    track: Color(0xFFE9EDF5),
    segmentOn: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette._(
    bgApp: Color(0xFF0F1117),
    card: Color(0xFF181B23),
    primary: Color(0xFF2D5BFF),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFF1B2547),
    accentText: Color(0xFF9DB4FF),
    line: Color(0xFF2A2F3B),
    lineSoft: Color(0xFF222632),
    textPrimary: Color(0xFFF2F3F7),
    textSecondary: Color(0xFFADB3C2),
    textMuted: Color(0xFF8C92A3),
    accent: Color(0xFF2D5BFF),
    onAccent: Color(0xFFFFFFFF),
    hero: Color(0xFF2449D8),
    onHero: Color(0xFFFFFFFF),
    accentOnDark: Color(0xFFFFFFFF),
    heroSub: Color(0xFFD6E0FF),
    barMuted: Color(0xFF3A4050),
    sky: Color(0xFF2D5BFF),
    sea: Color(0xFFA3A9B8),
    avatar: Color(0xFF2A2F3B),
    income: Color(0xFF7C9BFF),
    danger: Color(0xFFFF6B6B),
    onDanger: Color(0xFF121212),
    track: Color(0xFF222632),
    segmentOn: Color(0xFF2E3443),
  );

  static AppPalette of(Brightness brightness) => switch (brightness) {
    Brightness.light => light,
    Brightness.dark => dark,
  };
}

/// [ColorScheme]에 자리가 없는 디자인 토큰.
///
/// - [textMuted]: 흐린 글자. 카드·시트·입력란 바탕 위에서만 쓴다.
/// - [accentText]: 카드 위의 파란 글자·아이콘. 연한 코발트 바탕 위에서는 `colorScheme.onPrimaryContainer`(같은 색)를 쓴다.
/// - [income]: 달력의 들어온 돈. 토요일 날짜(진한 파랑)와 구분되게 조금 연하다.
/// - 두 사람의 프로필은 둘 다 [avatar] 바탕에 이름 첫 글자다(나중에 프로필 사진으로 바꾼다).
///   구성원별 막대에서는 관리자를 [sky], 상대를 [sea]로 칠한다.
/// - 남는 현금 카드는 [hero](진한 코발트) 바탕에 금액 [accentOnDark], 현금 유입·유출 금액 [onHero], 보조 글자 [heroSub].
/// - 막대그래프에서 강조하지 않는 막대는 [barMuted].
/// - 세그먼트(항목 종류 고르기)는 [track] 바탕에 고른 칸만 [segmentOn].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.textMuted,
    required this.accentText,
    required this.income,
    required this.hero,
    required this.onHero,
    required this.accentOnDark,
    required this.heroSub,
    required this.barMuted,
    required this.sky,
    required this.sea,
    required this.avatar,
    required this.track,
    required this.segmentOn,
  });

  AppColors.from(AppPalette p)
    : this(
        textMuted: p.textMuted,
        accentText: p.accentText,
        income: p.income,
        hero: p.hero,
        onHero: p.onHero,
        accentOnDark: p.accentOnDark,
        heroSub: p.heroSub,
        barMuted: p.barMuted,
        sky: p.sky,
        sea: p.sea,
        avatar: p.avatar,
        track: p.track,
        segmentOn: p.segmentOn,
      );

  final Color textMuted;
  final Color accentText;
  final Color income;
  final Color hero;
  final Color onHero;
  final Color accentOnDark;
  final Color heroSub;
  final Color barMuted;
  final Color sky;
  final Color sea;
  final Color avatar;
  final Color track;
  final Color segmentOn;

  static final light = AppColors.from(AppPalette.light);
  static final dark = AppColors.from(AppPalette.dark);

  static AppColors of(Brightness brightness) => switch (brightness) {
    Brightness.light => light,
    Brightness.dark => dark,
  };

  @override
  AppColors copyWith({
    Color? textMuted,
    Color? accentText,
    Color? income,
    Color? hero,
    Color? onHero,
    Color? accentOnDark,
    Color? heroSub,
    Color? barMuted,
    Color? sky,
    Color? sea,
    Color? avatar,
    Color? track,
    Color? segmentOn,
  }) => AppColors(
    textMuted: textMuted ?? this.textMuted,
    accentText: accentText ?? this.accentText,
    income: income ?? this.income,
    hero: hero ?? this.hero,
    onHero: onHero ?? this.onHero,
    accentOnDark: accentOnDark ?? this.accentOnDark,
    heroSub: heroSub ?? this.heroSub,
    barMuted: barMuted ?? this.barMuted,
    sky: sky ?? this.sky,
    sea: sea ?? this.sea,
    avatar: avatar ?? this.avatar,
    track: track ?? this.track,
    segmentOn: segmentOn ?? this.segmentOn,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      textMuted: mix(textMuted, other.textMuted),
      accentText: mix(accentText, other.accentText),
      income: mix(income, other.income),
      hero: mix(hero, other.hero),
      onHero: mix(onHero, other.onHero),
      accentOnDark: mix(accentOnDark, other.accentOnDark),
      heroSub: mix(heroSub, other.heroSub),
      barMuted: mix(barMuted, other.barMuted),
      sky: mix(sky, other.sky),
      sea: mix(sea, other.sea),
      avatar: mix(avatar, other.avatar),
      track: mix(track, other.track),
      segmentOn: mix(segmentOn, other.segmentOn),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppColors &&
      other.textMuted == textMuted &&
      other.accentText == accentText &&
      other.income == income &&
      other.hero == hero &&
      other.onHero == onHero &&
      other.accentOnDark == accentOnDark &&
      other.heroSub == heroSub &&
      other.barMuted == barMuted &&
      other.sky == sky &&
      other.sea == sea &&
      other.avatar == avatar &&
      other.track == track &&
      other.segmentOn == segmentOn;

  @override
  int get hashCode => Object.hash(
    textMuted,
    accentText,
    income,
    hero,
    onHero,
    accentOnDark,
    heroSub,
    barMuted,
    sky,
    sea,
    avatar,
    track,
    segmentOn,
  );
}

extension AppColorsContext on BuildContext {
  /// [buildAppTheme]이 항상 등록한다. 테마 없이 그린 위젯 테스트에서는 지금 밝기의 기본값을 쓴다.
  AppColors get appColors {
    final theme = Theme.of(this);
    return theme.extension<AppColors>() ?? AppColors.of(theme.brightness);
  }
}

/// 상태 표시줄과 내비게이션 바를 투명하게 해 화면 바탕과 잇고, 아이콘은 바탕과 반대 밝기로 한다.
/// app.dart에서 앱 전체를 감싸 쓰고, AppBar 테마에서도 같은 값을 쓴다.
SystemUiOverlayStyle appSystemOverlayStyle(Brightness brightness) {
  final icons = switch (brightness) {
    Brightness.light => Brightness.dark,
    Brightness.dark => Brightness.light,
  };
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS는 아이콘이 아니라 바탕의 밝기를 받는다.
    statusBarBrightness: brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

/// 디자인 토큰으로 만든 앱 테마. app.dart가 라이트·다크 두 벌을 넘겨 기기 설정을 따른다.
///
/// 글꼴은 시스템 글꼴을 쓴다(디자인의 Noto Sans KR은 앱에 넣지 않음).
ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final p = AppPalette.of(brightness);
  final scheme = ColorScheme(
    brightness: brightness,
    // 버튼과 선택된 칩은 코발트다.
    primary: p.primary,
    onPrimary: p.onPrimary,
    // 연한 코발트 바탕(아이콘 원, 배지, 안내 상자)과 그 위의 파란 글자.
    primaryContainer: p.primarySoft,
    onPrimaryContainer: p.accentText,
    secondary: p.primary,
    onSecondary: p.onPrimary,
    // 선택 표시는 디자인에서 컴포넌트마다 달라(탭은 포인트 색, 칩은 primary, 세그먼트는 밝은 바탕)
    // 그 화면을 만들 때 컴포넌트 테마로 정한다. 여기서는 연한 코발트를 둔다.
    secondaryContainer: p.primarySoft,
    onSecondaryContainer: p.accentText,
    // 포인트 색. 선택된 탭, + 버튼, 지급 전 배지, 입력 중인 칸, 앱 아이콘에만 쓴다.
    tertiary: p.accent,
    onTertiary: p.onAccent,
    error: p.danger,
    onError: p.onDanger,
    // 화면 바탕은 bg-app, 카드·시트·입력란은 card.
    surface: p.bgApp,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.card,
    surfaceContainerLow: p.card,
    surfaceContainer: p.card,
    surfaceContainerHigh: p.card,
    surfaceContainerHighest: p.lineSoft,
    outline: p.line,
    outlineVariant: p.lineSoft,
  );

  final base = ThemeData(colorScheme: scheme);
  final text = base.textTheme
      .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary)
      .copyWith(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: p.textPrimary),
        bodyMedium: TextStyle(fontSize: 15, color: p.textPrimary),
        bodySmall: TextStyle(fontSize: 13, color: p.textSecondary),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.textSecondary,
        ),
        labelSmall: TextStyle(fontSize: 12, color: p.textMuted),
      );

  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );
  const buttonSize = Size(64, 54);
  const fieldRadius = BorderRadius.all(Radius.circular(12));
  OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    scaffoldBackgroundColor: p.bgApp,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bgApp,
      foregroundColor: p.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: appSystemOverlayStyle(brightness),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
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
        backgroundColor: p.card,
        foregroundColor: p.textPrimary,
        side: BorderSide(color: p.line),
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: text.bodyLarge?.copyWith(color: p.textMuted),
      // 기본값은 한 줄이라 '초대 코드를 찾을 수 없어요…' 같은 안내가 잘린다.
      errorMaxLines: 3,
      border: fieldBorder(p.line),
      enabledBorder: fieldBorder(p.line),
      focusedBorder: fieldBorder(p.accent, 1.5),
      errorBorder: fieldBorder(p.danger),
      focusedErrorBorder: fieldBorder(p.danger, 1.5),
    ),
    extensions: [AppColors.of(brightness)],
  );
}
