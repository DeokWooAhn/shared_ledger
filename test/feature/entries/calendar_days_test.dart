import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/feature/entries/calendar_days.dart';

const october = YearMonth(2026, 10);

Income income(String id, int amount, {DateTime? on}) => Income(
  id: id,
  memberId: 'owner',
  title: id,
  amount: amount,
  receivedOn: on,
);

ExtraExpense extra(String id, int amount, {DateTime? on}) => ExtraExpense(
  id: id,
  memberId: 'partner',
  title: id,
  paymentMethodId: 'p-shared',
  amount: amount,
  spentOn: on,
);

PlannedExpense planned(
  String id, {
  int? amount,
  DateTime? paidOn,
  DateTime? dueOn,
}) => PlannedExpense(
  id: id,
  categoryId: 'c-living',
  memberId: 'owner',
  title: id,
  paymentMethodId: 'p-auto',
  amount: amount,
  paidOn: paidOn,
  dueOn: dueOn,
);

void main() {
  group('날짜별로 모으기', () {
    test('날짜가 있는 항목은 그 날에 모으고 들어온 돈·나간 돈·합계를 낸다', () {
      final calendar = CalendarMonth.of(
        MonthLedger(
          incomes: [income('급여', 2700000, on: DateTime(2026, 10, 10))],
          plannedExpenses: [
            planned('적금', amount: 500000, paidOn: DateTime(2026, 10, 10)),
          ],
          extraExpenses: [extra('간식', 9800, on: DateTime(2026, 10, 11))],
          cardBills: [
            CardBill(
              id: 'bill',
              memberId: 'owner',
              cardId: 'p-shared',
              amount: 612000,
              paidOn: DateTime(2026, 10, 10),
            ),
          ],
        ),
        october,
      );

      final tenth = calendar.dayOf(10);
      expect(tenth.income, 2700000);
      expect(tenth.spending, 1112000);
      expect(tenth.net, 1588000);
      expect(calendar.dayOf(11).spending, 9800);
      expect(calendar.dayOf(12).isEmpty, isTrue);
      expect(calendar.undatedCount, 0);
    });

    test('한 날의 항목은 수입·고정 지출·추가 지출·카드 대금 순, 같은 종류는 제목 순이다', () {
      final day = DateTime(2026, 10, 18);
      final calendar = CalendarMonth.of(
        MonthLedger(
          extraExpenses: [
            extra('외식', 72000, on: day),
            extra('마트', 186000, on: day),
          ],
          incomes: [income('용돈', 100000, on: day)],
        ),
        october,
      );

      expect(calendar.dayOf(18).entries.map((e) => e.id), ['용돈', '마트', '외식']);
    });

    test('지급 전 고정 지출은 예정일에, 지급한 것은 지급한 날에 놓는다', () {
      final calendar = CalendarMonth.of(
        MonthLedger(
          plannedExpenses: [
            planned('원금', amount: 800000, dueOn: DateTime(2026, 10, 25)),
            planned('관리비', dueOn: DateTime(2026, 10, 25)),
            planned(
              '보험',
              amount: 154000,
              paidOn: DateTime(2026, 10, 15),
              dueOn: DateTime(2026, 10, 25),
            ),
          ],
        ),
        october,
      );

      final due = calendar.dayOf(25);
      expect(due.entries, isEmpty);
      expect(due.scheduled.map((e) => e.id), ['관리비', '원금']);
      // 나갈 돈이라 빼고, 금액 미정은 0원으로 친다.
      expect(due.scheduledTotal, -800000);
      expect(calendar.dayOf(15).entries.single.id, '보험');
    });

    test('받기 전 고정 수입은 예정일에, 받은 것은 받은 날에 들어온 돈으로 놓는다', () {
      final calendar = CalendarMonth.of(
        MonthLedger(
          fixedIncomes: [
            FixedIncome(
              id: '월급',
              memberId: 'owner',
              title: '월급',
              amount: 3000000,
              dueOn: DateTime(2026, 10, 25),
            ),
            FixedIncome(
              id: '수당',
              memberId: 'partner',
              title: '수당',
              amount: 200000,
              receivedOn: DateTime(2026, 10, 10),
              dueOn: DateTime(2026, 10, 25),
            ),
          ],
          plannedExpenses: [
            planned('원금', amount: 800000, dueOn: DateTime(2026, 10, 25)),
          ],
        ),
        october,
      );

      final due = calendar.dayOf(25);
      // 고정 수입이 먼저다. 예정 합계는 들어올 돈에서 나갈 돈을 뺀다.
      expect(due.scheduled.map((e) => e.id), ['월급', '원금']);
      expect(due.scheduledTotal, 2200000);
      final received = calendar.dayOf(10);
      expect(received.entries.single.id, '수당');
      expect(received.income, 200000);
      expect(received.spending, 0);
    });

    test('날짜가 없거나 그달 밖의 날짜인 항목은 달력에 놓지 않고 센다', () {
      final calendar = CalendarMonth.of(
        MonthLedger(
          incomes: [income('날짜 없는 수입', 10000)],
          extraExpenses: [
            extra('날짜 없는 지출', 5000),
            extra('다른 달', 3000, on: DateTime(2026, 9, 30)),
          ],
          plannedExpenses: [planned('예정일 없음', amount: 1000)],
        ),
        october,
      );

      expect(calendar.undatedCount, 4);
      for (var day = 1; day <= calendar.length; day++) {
        expect(calendar.dayOf(day).isEmpty, isTrue, reason: '$day일');
      }
    });

    test('빈 날도 그날 날짜로 돌려주고, 달 길이는 그달 마지막 날이다', () {
      final calendar = CalendarMonth.of(
        const MonthLedger(),
        const YearMonth(2026, 2),
      );

      expect(calendar.length, 28);
      expect(calendar.dayOf(28).date, DateTime(2026, 2, 28));
      expect(calendar.dayOf(28).isEmpty, isTrue);
    });

    test('하루의 목록은 고칠 수 없고, 넘긴 목록을 나중에 고쳐도 바뀌지 않는다', () {
      final calendar = CalendarMonth.of(
        MonthLedger(
          incomes: [income('salary', 2700000, on: DateTime(2026, 10, 10))],
          plannedExpenses: [planned('rent', dueOn: DateTime(2026, 10, 31))],
        ),
        october,
      );
      expect(
        () => calendar.dayOf(10).entries.add(extra('snack', 5000)),
        throwsUnsupportedError,
      );
      expect(
        () => calendar.dayOf(31).scheduled.clear(),
        throwsUnsupportedError,
      );

      final source = <LedgerEntry>[income('bonus', 100000)];
      final day = CalendarDay(date: DateTime(2026, 10, 1), entries: source);
      source.clear();
      expect(day.entries, hasLength(1));
    });
  });

  group('짧은 금액', () {
    test('1만 원 이상은 만 원 단위로 소수 한 자리까지, 아래는 쉼표로 쓴다', () {
      expect(calendarAmount(2700000), '+270만');
      expect(calendarAmount(-258000), '-25.8만');
      expect(calendarAmount(-27000), '-2.7만');
      expect(calendarAmount(-853000), '-85.3만');
      expect(calendarAmount(-9800), '-9,800');
      expect(calendarAmount(12345000), '+1,234.5만');
      expect(calendarAmount(0), '0');
    });

    test('천 원 단위에서 반올림한다', () {
      expect(calendarAmount(99950), '+10만');
      expect(calendarAmount(-15450), '-1.5만');
      expect(calendarAmount(10000), '+1만');
    });
  });
}
