import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/budget/statistics.dart';
import 'package:shared_ledger/domain/budget/stats_period.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/member.dart';
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

const august = YearMonth(2026, 8);
const september = YearMonth(2026, 9);
const october = YearMonth(2026, 10);
const november = YearMonth(2026, 11);

/// 8월~10월 석 달.
final threeMonths = StatsPeriod.recent(StatsRange.month3, october);

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
  Map<YearMonth, MonthLedger> ledgers, {
  StatsPeriod? period,
  List<Category> categories = const [saving, living],
  List<PaymentMethod> paymentMethods = const [account, card],
}) => Statistics.of(
  ledgers,
  period: period ?? threeMonths,
  categories: categories,
  paymentMethods: paymentMethods,
);

void main() {
  test('모은 돈은 기간 안의 달마다 빠져나간 저축 + 남는 현금을 더하고, 기간 밖의 달은 넣지 않는다', () {
    final stats = statisticsOf({
      // 기간 밖
      const YearMonth(2026, 7): monthOf(income: 9000000),
      // 저축 300,000원을 내고 200,000원을 써서 현금 500,000원이 남았다 → 800,000원
      september: monthOf(income: 1000000, saved: 300000, spent: 200000),
      // 지급 전 저축 400,000원은 아직 통장에 있어 남는 현금 2,000,000원에만 들어간다
      october: monthOf(income: 2000000, saved: 400000, paid: false),
      november: monthOf(income: 9000000),
    });

    expect(stats.savedMonths.map((m) => m.month), [september, october]);
    expect(stats.savedSaving, 300000);
    expect(stats.savedCash, 2500000);
    expect(stats.saved, 2800000);
    // 밖에서 목록을 고칠 수 없다.
    expect(() => stats.savedMonths.clear(), throwsUnsupportedError);
    expect(() => stats.payments.clear(), throwsUnsupportedError);
  });

  test('남는 현금이 모자란 달은 모은 돈을 줄인다', () {
    final stats = statisticsOf({
      september: monthOf(income: 1000000),
      october: monthOf(spent: 300000),
    });

    expect(stats.savedMonths.last.total, -300000);
    expect(stats.saved, 700000);
  });

  test('지출은 기간의 합이고, 고정 지출 분류별 합계와 추가 지출로 나뉜다', () {
    final stats = statisticsOf({
      august: monthOf(saved: 100000, spent: 50000),
      september: MonthLedger(
        plannedExpenses: [
          PlannedExpense(
            id: 'rent',
            categoryId: living.id,
            memberId: 'partner',
            title: '관리비',
            paymentMethodId: 'p-account',
            amount: 200000,
          ),
          PlannedExpense(
            id: 'old',
            categoryId: 'c-gone',
            memberId: 'owner',
            title: '지운 분류',
            paymentMethodId: 'p-account',
            amount: 7000,
          ),
        ],
      ),
      october: monthOf(saved: 100000),
    });

    expect(stats.spending, 457000);
    // 쓴 분류만 설정 순서대로, 지워진 분류는 맨 뒤 하나로.
    expect(
      [
        for (final (:category, :amount) in stats.categories)
          (category?.id, amount),
      ],
      [('c-saving', 200000), ('c-living', 200000), (null, 7000)],
    );
    expect(stats.planned, 407000);
    expect(stats.extra, 50000);
    expect(stats.plannedOf(MemberSlot.owner), 207000);
    expect(stats.plannedOf(MemberSlot.partner), 200000);
  });

  test('수입은 기간의 현금 유입 합이고, 지출은 저축과 저축을 뺀 지출로, 수입에서 지출을 뺀 것이 남은 돈이다', () {
    final stats = statisticsOf({
      september: monthOf(income: 1000000, saved: 300000, spent: 200000),
      // 지급 전 저축도 저축(지출 기준)에 들어간다.
      october: monthOf(income: 2000000, saved: 400000, paid: false),
    });

    expect(stats.income, 3000000);
    expect(stats.spending, 900000);
    expect(stats.saving, 700000);
    expect(stats.consumption, 200000);
    expect(stats.left, 2100000);
    // 지출이 수입보다 많으면 남은 돈은 음수다.
    expect(
      statisticsOf({october: monthOf(income: 100000, spent: 300000)}).left,
      -200000,
    );
  });

  test('결제수단별 지출은 기간을 더해 쓴 결제수단만 설정 순서대로 두고, 지워진 결제수단은 맨 뒤에 모은다', () {
    final stats = statisticsOf({
      september: monthOf(spent: 1000, paymentMethodId: 'p-card'),
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
      [('p-card', 4000), (null, 3000)],
    );
  });

  test('기간에 가계부 달이 없으면 모두 0이다', () {
    final stats = statisticsOf({november: monthOf(income: 1000)});

    expect(stats.savedMonths, isEmpty);
    expect(stats.saved, 0);
    expect(stats.spending, 0);
    expect(stats.categories, isEmpty);
    expect(stats.payments, isEmpty);
  });
}
