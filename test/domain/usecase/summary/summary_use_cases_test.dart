import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/domain/usecase/summary/summary_use_cases.dart';

const living = Category(id: 'c-living', name: '소비');
const account = PaymentMethod(
  id: 'p-account',
  name: '공동 통장',
  kind: PaymentKind.account,
);
const card = PaymentMethod(id: 'p-card', name: '공용 카드', kind: PaymentKind.card);

void main() {
  test('그달 항목과 분류·결제수단으로 월 요약을 계산한다', () {
    final summary = const SummaryUseCases().calculateMonthSummary(
      const MonthLedger(
        plannedExpenses: [
          PlannedExpense(
            id: 't1',
            categoryId: 'c-living',
            memberId: 'owner',
            title: '관리비',
            paymentMethodId: 'p-account',
            amount: 150000,
          ),
        ],
        extraExpenses: [
          ExtraExpense(
            id: 'x1',
            memberId: 'owner',
            title: '장보기',
            paymentMethodId: 'p-card',
            amount: 30000,
          ),
        ],
      ),
      categories: const [living],
      paymentMethods: const [account, card],
    );

    expect(summary.categories, [(category: living, amount: 150000)]);
    expect(summary.cards, [(card: card, amount: 30000)]);
    expect(summary.isEmpty, isFalse);
  });

  test('보고 있는 달까지의 가계부 달로 통계(그동안 모은 돈)를 계산한다', () {
    const september = YearMonth(2026, 9);
    const october = YearMonth(2026, 10);
    const income = MonthLedger(
      incomes: [
        Income(id: 'i1', memberId: 'owner', title: '월급', amount: 100000),
      ],
    );
    final stats = const SummaryUseCases().calculateStatistics(
      income,
      month: october,
      history: {september: income, october: income},
      categories: const [living],
      paymentMethods: const [account, card],
    );

    expect(stats.saved, 200000);
    expect(stats.previous?.month, september);
  });
}
