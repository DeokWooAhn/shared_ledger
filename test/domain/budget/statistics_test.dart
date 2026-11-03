import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/budget/statistics.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/domain/model/year_month.dart';

const saving = Category(id: 'c-saving', name: '저축', countsAsSaving: true);
const living = Category(id: 'c-living', name: '소비');
const account = PaymentMethod(
  id: 'p-account',
  name: '공동 통장',
  kind: PaymentKind.account,
);
const card = PaymentMethod(id: 'p-card', name: '공용 카드', kind: PaymentKind.card);

const september = YearMonth(2026, 9);
const october = YearMonth(2026, 10);
const november = YearMonth(2026, 11);

/// [income]이 들어오고, 저축 [saved](지급 완료면 [paid])와 계좌 추가 지출 [spent]가 나간 달.
MonthLedger monthOf({
  int income = 0,
  int saved = 0,
  bool paid = true,
  int spent = 0,
  String paymentMethodId = 'p-account',
}) => MonthLedger(
  incomes: [
    if (income > 0)
      Income(id: 'i', memberId: 'owner', title: '월급', amount: income),
  ],
  plannedExpenses: [
    if (saved > 0)
      PlannedExpense(
        id: 's',
        categoryId: saving.id,
        memberId: 'owner',
        title: '적금',
        paymentMethodId: 'p-account',
        amount: saved,
        paidOn: paid ? DateTime(2026, 9, 10) : null,
      ),
  ],
  extraExpenses: [
    if (spent > 0)
      ExtraExpense(
        id: 'x',
        memberId: 'owner',
        title: '장보기',
        paymentMethodId: paymentMethodId,
        amount: spent,
      ),
  ],
);

Statistics statisticsOf(
  Map<YearMonth, MonthLedger>? history, {
  YearMonth month = october,
  MonthLedger? ledger,
  List<PaymentMethod> paymentMethods = const [account, card],
}) => Statistics.of(
  ledger ?? history?[month] ?? const MonthLedger(),
  month: month,
  history: history,
  categories: const [saving, living],
  paymentMethods: paymentMethods,
);

void main() {
  test('그동안 모은 돈은 보고 있는 달까지 달마다 빠져나간 저축 + 남는 현금을 더하고, 뒤 달은 넣지 않는다', () {
    final stats = statisticsOf({
      // 저축 300,000원을 내고 200,000원을 써서 현금 500,000원이 남았다 → 800,000원
      september: monthOf(income: 1000000, saved: 300000, spent: 200000),
      // 지급 전 저축 400,000원은 아직 통장에 있어 남는 현금 2,000,000원에만 들어간다
      october: monthOf(income: 2000000, saved: 400000, paid: false),
      november: monthOf(income: 9000000),
    });

    expect(stats.savedMonths?.map((m) => m.month), [september, october]);
    // 밖에서 목록을 고칠 수 없다.
    expect(() => stats.savedMonths?.clear(), throwsUnsupportedError);
    expect(() => stats.payments.clear(), throwsUnsupportedError);
    expect(stats.savedSaving, 300000);
    expect(stats.savedCash, 2500000);
    expect(stats.saved, 2800000);
  });

  test('남는 현금이 모자란 달은 모은 돈을 줄인다', () {
    final stats = statisticsOf({
      september: monthOf(income: 1000000),
      october: monthOf(spent: 300000),
    });

    expect(stats.savedMonths?.last.total, -300000);
    expect(stats.saved, 700000);
  });

  test('달마다 모은 돈 막대는 그달까지 최근 6개 달이다', () {
    final stats = statisticsOf({
      for (var month = 3; month <= 10; month++)
        YearMonth(2026, month): monthOf(income: month * 1000),
    });

    expect(stats.savedMonths, hasLength(8));
    expect(stats.recentSaved.map((m) => m.month.month), [5, 6, 7, 8, 9, 10]);
  });

  test('앞 달은 가계부가 있는 바로 앞 달이고, 없으면 비교하지 않는다', () {
    final stats = statisticsOf({
      const YearMonth(2026, 7): monthOf(spent: 500000),
      october: monthOf(spent: 400000),
    });

    expect(stats.previous?.month, const YearMonth(2026, 7));
    expect(stats.previous?.spending, 500000);
    expect(statisticsOf({october: monthOf()}).previous, isNull);
  });

  test('달 목록을 모르는 옛 가계부는 모은 돈과 앞 달을 계산하지 않고 그달 요약만 낸다', () {
    final stats = statisticsOf(null, ledger: monthOf(spent: 1000));

    expect(stats.savedMonths, isNull);
    expect(stats.saved, isNull);
    expect(stats.recentSaved, isEmpty);
    expect(stats.previous, isNull);
    expect(stats.summary.totals.spending, 1000);
  });

  test('결제수단별 지출은 쓴 결제수단만 설정 순서대로 두고, 지워진 결제수단은 맨 뒤에 모은다', () {
    final stats = statisticsOf({
      october: MonthLedger(
        extraExpenses: [
          for (final (id, method, amount) in [
            ('a', 'p-card', 3000),
            ('b', 'p-old', 2000),
            ('c', 'p-gone', 1000),
          ])
            ExtraExpense(
              id: id,
              memberId: 'owner',
              title: id,
              paymentMethodId: method,
              amount: amount,
            ),
        ],
      ),
    });

    expect(
      [for (final (:method, :amount) in stats.payments) (method?.id, amount)],
      [('p-card', 3000), (null, 3000)],
    );
  });
}
