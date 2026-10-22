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
  for (final brightness in Brightness.values) {
    group('${brightness.name} 테마', () {
      final theme = buildAppTheme(brightness);
      final scheme = theme.colorScheme;
      final colors = AppColors.of(brightness);

      test('밝기에 맞는 색 구성과 디자인 토큰 확장(AppColors)을 쓴다', () {
        expect(scheme.brightness, brightness);
        expect(theme.extension<AppColors>(), colors);
      });

      test('상태 표시줄 아이콘은 바탕과 반대 밝기다', () {
        final style = theme.appBarTheme.systemOverlayStyle;
        expect(style?.statusBarBrightness, brightness);
        expect(
          style?.statusBarIconBrightness,
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
        );
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
          (
            '보조 글자 / 카드',
            scheme.onSurfaceVariant,
            scheme.surfaceContainerLowest,
          ),
          ('흐린 글자 / 카드', colors.textMuted, scheme.surfaceContainerLowest),
          ('오류 글자 / 카드', scheme.error, scheme.surfaceContainerLowest),
          ('오류 위 글자 / 오류', scheme.onError, scheme.error),
          ('남는 현금 금액 / 남는 현금 카드', colors.accentOnDark, colors.hero),
          ('남는 현금 보조 글자 / 남는 현금 카드', colors.heroSub, colors.hero),
          ('현금 유입·유출 금액 / 남는 현금 카드', colors.onHero, colors.hero),
          ('관리자 동그라미 글자 / 그 바탕', scheme.onPrimary, colors.skySoft),
          ('상대 동그라미 글자 / 그 바탕', colors.sea, colors.seaSoft),
          ('상대를 고른 칩 글자 / 그 바탕', scheme.onPrimary, colors.sea),
          ('세그먼트 글자 / 세그먼트 바탕', scheme.onSurfaceVariant, colors.track),
          ('세그먼트에서 고른 칸 글자 / 그 바탕', scheme.onSurface, colors.segmentOn),
        ];
        for (final (name, foreground, background) in pairs) {
          test(name, () {
            expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
          });
        }
      });

      test('포인트 색은 화면 바탕·카드와 3:1 이상 구분된다', () {
        expect(contrast(scheme.tertiary, scheme.surface), greaterThan(3));
        expect(
          contrast(scheme.tertiary, scheme.surfaceContainerLowest),
          greaterThan(3),
        );
      });
    });
  }
}
