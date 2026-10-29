import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/budget/budget_calculator.dart';

import 'sheet_fixtures.dart';

// 정답은 기존 시트 수식(docs/plan.md '계산 규칙')으로 손으로 계산한 값이다.
void main() {
  final calculator = BudgetCalculator(
    categories: sheetCategories,
    paymentMethods: sheetPaymentMethods,
  );

  group('기존 시트 구성의 예시 데이터에서 시트 수식과 같은 값이 나온다', () {
    test('10월 상단 요약 (지급 전 계좌 지출은 현금 유출에서 빠진다)', () {
      final summary = calculator.summarize(october2026);

      expect(summary.cashIn, 6350000);
      expect(summary.spending, 4026500);
      expect(summary.cashOut, 4806800);
      expect(summary.saving, 1150000);
      expect(summary.remainingCash, 1543200);
    });

    test('10월 카드 소계', () {
      final summary = calculator.summarize(october2026);

      expect(summary.cardBillTotal, 1350000);
      expect(summary.cardUsage, 538500);
    });

    test('10월 고정 지출 소계', () {
      final summary = calculator.summarize(october2026);

      expect(summary.plannedTotal, 3436100);
      expect(summary.plannedByCategory, {
        loanPrincipal: 950000,
        loanInterest: 540000,
        savingInvest: 200000,
        living: 1746100,
      });
      expect(summary.plannedByMember, {
        memberA: 1594200,
        memberB: 995200,
        shared: 846700,
      });
    });

    test('11월 상단 요약과 카드 소계', () {
      final summary = calculator.summarize(november2026);

      expect(summary.cashIn, 3200000);
      expect(summary.spending, 3496100);
      expect(summary.cashOut, 2998000);
      expect(summary.saving, 1160000);
      expect(summary.remainingCash, 202000);
      expect(summary.cardBillTotal, 0);
      expect(summary.cardUsage, 498100);
    });

    test('11월 고정 지출 소계', () {
      final summary = calculator.summarize(november2026);

      expect(summary.plannedTotal, 3496100);
      expect(summary.plannedByCategory, {
        loanPrincipal: 960000,
        loanInterest: 530000,
        savingInvest: 200000,
        living: 1806100,
      });
      expect(summary.plannedByMember, {
        memberA: 1594200,
        memberB: 995200,
        shared: 906700,
      });
    });
  });
}
