import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/budget/budget_calculator.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/payment_method.dart';

const _saving = Category(id: 'saving', name: '저축', countsAsSaving: true);
const _living = Category(id: 'living', name: '소비');
const _account = PaymentMethod(
  id: 'account',
  name: '계좌',
  kind: PaymentKind.account,
);
const _cardA = PaymentMethod(id: 'card-a', name: '카드A', kind: PaymentKind.card);
const _cardB = PaymentMethod(id: 'card-b', name: '카드B', kind: PaymentKind.card);

final _calculator = BudgetCalculator(
  categories: const [_saving, _living],
  paymentMethods: const [_account, _cardA, _cardB],
);

final _paidDay = DateTime(2026, 10, 1);

PlannedExpense _planned({
  String categoryId = 'living',
  String memberId = 'm1',
  String paymentMethodId = 'account',
  int? amount = 10000,
  DateTime? paidOn,
}) => PlannedExpense(
  id: 'p',
  categoryId: categoryId,
  memberId: memberId,
  title: '항목',
  paymentMethodId: paymentMethodId,
  amount: amount,
  paidOn: paidOn,
);

ExtraExpense _extra({String paymentMethodId = 'account', int amount = 10000}) =>
    ExtraExpense(
      id: 'x',
      memberId: 'm1',
      title: '항목',
      paymentMethodId: paymentMethodId,
      amount: amount,
    );

void main() {
  test('수입 합계가 현금 유입이 된다', () {
    final summary = _calculator.summarize(
      const MonthLedger(
        incomes: [
          Income(id: 'i1', memberId: 'm1', title: '월급', amount: 3000000),
          Income(id: 'i2', memberId: 'm2', title: '월급', amount: 2000000),
        ],
      ),
    );

    expect(summary.cashIn, 5000000);
  });

  test('지급일이 없는 계좌 지출은 이번 달 지출에만 들어가고 현금 유출에는 들어가지 않는다', () {
    final summary = _calculator.summarize(
      MonthLedger(plannedExpenses: [_planned()]),
    );

    expect(summary.spending, 10000);
    expect(summary.cashOut, 0);
  });

  test('지급일이 있는 계좌 지출은 현금 유출에 들어간다', () {
    final summary = _calculator.summarize(
      MonthLedger(plannedExpenses: [_planned(paidOn: _paidDay)]),
    );

    expect(summary.cashOut, 10000);
  });

  test('카드로 낸 기본 지출은 지급일이 있어도 현금 유출이 아니라 카드 사용에 들어간다', () {
    final summary = _calculator.summarize(
      MonthLedger(
        plannedExpenses: [
          _planned(paymentMethodId: 'card-a', paidOn: _paidDay),
        ],
      ),
    );

    expect(summary.spending, 10000);
    expect(summary.cashOut, 0);
    expect(summary.cardUsage, 10000);
  });

  test('추가지출은 날짜가 없어도 카드가 아니면 현금 유출에 들어간다', () {
    final summary = _calculator.summarize(
      MonthLedger(
        extraExpenses: [
          _extra(),
          _extra(paymentMethodId: 'card-a', amount: 3000),
        ],
      ),
    );

    expect(summary.spending, 13000);
    expect(summary.cashOut, 10000);
    expect(summary.cardUsage, 3000);
  });

  test('카드대금은 현금 유출과 저번 달 사용분에 들어가고 이번 달 지출에는 들어가지 않는다', () {
    final summary = _calculator.summarize(
      const MonthLedger(
        cardBills: [
          CardBill(id: 'b', memberId: 'm1', cardId: 'card-a', amount: 500000),
        ],
      ),
    );

    expect(summary.cashOut, 500000);
    expect(summary.cardBillTotal, 500000);
    expect(summary.spending, 0);
  });

  test('저축으로 집계하는 분류의 기본 지출만 저축에 들어간다', () {
    final summary = _calculator.summarize(
      MonthLedger(
        plannedExpenses: [
          _planned(categoryId: 'saving', amount: 200000),
          _planned(amount: 50000),
        ],
      ),
    );

    expect(summary.saving, 200000);
    expect(summary.plannedByCategory, {'saving': 200000, 'living': 50000});
  });

  test('금액이 정해지지 않은 기본 지출은 0원으로 친다', () {
    final summary = _calculator.summarize(
      MonthLedger(
        plannedExpenses: [_planned(amount: null), _planned(amount: 7000)],
      ),
    );

    expect(summary.plannedTotal, 7000);
  });

  test('카드 사용분을 카드별로 나눠 보여준다', () {
    final summary = _calculator.summarize(
      MonthLedger(
        plannedExpenses: [_planned(paymentMethodId: 'card-a', amount: 10000)],
        extraExpenses: [
          _extra(paymentMethodId: 'card-a', amount: 2000),
          _extra(paymentMethodId: 'card-b', amount: 3000),
        ],
      ),
    );

    expect(summary.cardUsageByCard, {'card-a': 12000, 'card-b': 3000});
  });

  test('찾을 수 없는 결제수단은 카드가 아닌 것으로, 찾을 수 없는 분류는 저축이 아닌 것으로 본다', () {
    final summary = _calculator.summarize(
      MonthLedger(
        plannedExpenses: [
          _planned(
            categoryId: 'deleted',
            paymentMethodId: 'deleted',
            paidOn: _paidDay,
          ),
        ],
      ),
    );

    expect(summary.cardUsage, 0);
    expect(summary.cashOut, 10000);
    expect(summary.saving, 0);
  });

  test('현금 유출이 유입보다 많으면 남는 현금은 음수가 된다', () {
    final summary = _calculator.summarize(
      MonthLedger(
        incomes: const [
          Income(id: 'i', memberId: 'm1', title: '월급', amount: 5000),
        ],
        plannedExpenses: [_planned(paidOn: _paidDay)],
      ),
    );

    expect(summary.remainingCash, -5000);
  });
}
