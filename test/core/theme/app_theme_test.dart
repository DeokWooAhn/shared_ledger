import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/theme/app_theme.dart';

/// WCAG 명도 대비. 본문 크기 글자는 4.5:1 이상이어야 읽기 어렵지 않다.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (light, dark) = la > lb ? (la, lb) : (lb, la);
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  final scheme = buildAppTheme().colorScheme;
  const colors = AppColors.light;

  test('앱 테마에 디자인 토큰 확장(AppColors)을 등록한다', () {
    expect(buildAppTheme().extension<AppColors>(), colors);
  });

  group('글자와 바탕의 대비가 4.5:1 이상이다', () {
    final pairs = <(String, Color, Color)>[
      ('버튼 글자 / 버튼', scheme.onPrimary, scheme.primary),
      ('포인트 색 위 글자 / 포인트 색', scheme.onTertiary, scheme.tertiary),
      (
        '아이콘 원·초대 코드 / 그 바탕',
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
      ('본문 / 화면 바탕', scheme.onSurface, scheme.surface),
      ('본문 / 카드', scheme.onSurface, scheme.surfaceContainerLowest),
      ('보조 글자 / 화면 바탕', scheme.onSurfaceVariant, scheme.surface),
      ('보조 글자 / 카드', scheme.onSurfaceVariant, scheme.surfaceContainerLowest),
      ('흐린 글자 / 카드', colors.textMuted, scheme.surfaceContainerLowest),
      ('오류 글자 / 카드', scheme.error, scheme.surfaceContainerLowest),
      ('검정 카드 위 금액 / 검정 카드', colors.accentOnDark, scheme.primary),
      ('검정 카드 위 보조 글자 / 검정 카드', colors.heroSub, scheme.primary),
      ('관리자 동그라미 글자 / 그 바탕', scheme.onPrimary, colors.skySoft),
      ('상대 동그라미 글자 / 그 바탕', colors.sea, colors.seaSoft),
    ];
    for (final (name, foreground, background) in pairs) {
      test(name, () {
        expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
