import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';

ExpenseTemplate template({String id = 't1', int dueDay = 25, int? amount}) =>
    ExpenseTemplate(
      id: id,
      title: '관리비',
      amount: amount,
      categoryId: 'c-living',
      paymentMethodId: 'p-account',
      memberId: 'partner',
      dueDay: dueDay,
    );

void main() {
  group('그달 예정일', () {
    test('예정일이 그달에 있으면 그날이다', () {
      expect(
        template(dueDay: 25).dueOn(const YearMonth(2026, 10)),
        DateTime(2026, 10, 25),
      );
      expect(
        template(dueDay: 1).dueOn(const YearMonth(2026, 2)),
        DateTime(2026, 2, 1),
      );
    });

    test('말일(31)은 달마다 그달 마지막 날이다', () {
      final lastDay = template(dueDay: lastDueDay);

      expect(lastDay.dueOnLastDay, isTrue);
      expect(lastDay.dueOn(const YearMonth(2026, 10)), DateTime(2026, 10, 31));
      expect(lastDay.dueOn(const YearMonth(2026, 11)), DateTime(2026, 11, 30));
      expect(lastDay.dueOn(const YearMonth(2026, 2)), DateTime(2026, 2, 28));
      expect(lastDay.dueOn(const YearMonth(2028, 2)), DateTime(2028, 2, 29));
    });

    test('그달에 없는 날(2월 30일)은 그달 말일로 당긴다', () {
      expect(
        template(dueDay: 30).dueOn(const YearMonth(2026, 2)),
        DateTime(2026, 2, 28),
      );
      expect(
        template(dueDay: 30).dueOn(const YearMonth(2026, 4)),
        DateTime(2026, 4, 30),
      );
    });
  });

  test('그달에 만들 고정 지출은 반복 설정 값에 예정일을 붙이고 지급 전이다', () {
    final draft = template(amount: 200000).draftFor(const YearMonth(2026, 11));

    expect(
      draft,
      EntryDraft(
        kind: EntryKind.planned,
        memberId: 'partner',
        amount: 200000,
        title: '관리비',
        categoryId: 'c-living',
        paymentMethodId: 'p-account',
        dueOn: DateTime(2026, 11, 25),
      ),
    );
    expect(draft.date, isNull);
  });

  test('자동으로 채우는 달은 이번 달과 다음 달뿐이다', () {
    const thisMonth = YearMonth(2026, 12);

    expect(fillsFromTemplates(thisMonth, thisMonth: thisMonth), isTrue);
    expect(
      fillsFromTemplates(const YearMonth(2027, 1), thisMonth: thisMonth),
      isTrue,
    );
    expect(
      fillsFromTemplates(const YearMonth(2026, 11), thisMonth: thisMonth),
      isFalse,
    );
    expect(
      fillsFromTemplates(const YearMonth(2027, 2), thisMonth: thisMonth),
      isFalse,
    );
  });

  test('그달에 아직 없는 고정 지출만 고르고, 휴지통에 넣은 것은 다시 만들지 않는다', () {
    final rent = template(id: 'rent');
    final phone = template(id: 'phone');
    final insurance = template(id: 'insurance');
    final ledger = MonthLedger(
      plannedExpenses: const [
        PlannedExpense(
          id: 'rent',
          categoryId: 'c-living',
          memberId: 'partner',
          title: '관리비',
          paymentMethodId: 'p-account',
        ),
      ],
      // 휴지통에 넣은 통신비 문서가 남아 있다.
      plannedIds: const {'phone'},
    );

    expect(templatesMissingIn(ledger, [rent, phone, insurance]), [insurance]);
    expect(templatesMissingIn(const MonthLedger(), const []), isEmpty);
  });

  test('되돌리기·고치기 화면의 값은 고정 지출 값과 같다', () {
    expect(
      TemplateDraft.of(template(amount: 1000)),
      const TemplateDraft(
        memberId: 'partner',
        title: '관리비',
        amount: 1000,
        categoryId: 'c-living',
        paymentMethodId: 'p-account',
        dueDay: 25,
      ),
    );
  });

  group('고정 지출 입력 검사', () {
    EntryDraft draft({String title = '관리비', int? amount}) => EntryDraft(
      kind: EntryKind.planned,
      memberId: 'owner',
      title: title,
      amount: amount,
      categoryId: 'c',
      paymentMethodId: 'p',
    );

    test('항목 검사에 매달 예정일을 더한다. 금액은 비울 수 있다', () {
      expect(fixedExpenseProblemsOf(draft(), dueDay: 1), isEmpty);
      expect(
        fixedExpenseProblemsOf(draft(amount: 0), dueDay: lastDueDay),
        isEmpty,
      );
      expect(fixedExpenseProblemsOf(draft(title: '가' * 41), dueDay: 1), {
        EntryProblem.titleTooLong,
      });
      expect(fixedExpenseProblemsOf(draft(amount: -1), dueDay: 1), {
        EntryProblem.amountNegative,
      });
    });

    test('예정일은 1일부터 말일까지만 받는다', () {
      for (final dueDay in [null, 0, lastDueDay + 1]) {
        expect(fixedExpenseProblemsOf(draft(), dueDay: dueDay), {
          EntryProblem.dueDayMissing,
        }, reason: '$dueDay');
      }
    });
  });

  group('고정 지출 항목과 반복 설정', () {
    const entry = EntryDraft(
      kind: EntryKind.planned,
      memberId: 'partner',
      title: ' 관리비 ',
      amount: 212000,
      categoryId: 'c-living',
      paymentMethodId: 'p-account',
      memo: '10월 난방',
    );

    test('반복 설정 값은 항목의 칸을 옮기고 금액은 따로 받는다', () {
      expect(
        templateDraftOf(entry, dueDay: lastDueDay, amount: null),
        const TemplateDraft(
          memberId: 'partner',
          title: '관리비',
          categoryId: 'c-living',
          paymentMethodId: 'p-account',
          dueDay: lastDueDay,
        ),
      );
    });

    test('그달 항목에는 매달 예정일의 그달 날짜를 붙이고, 없는 날은 그달 말일로 맞춘다', () {
      expect(
        fixedEntryIn(entry, const YearMonth(2026, 10), 25).dueOn,
        DateTime(2026, 10, 25),
      );
      expect(
        fixedEntryIn(entry, const YearMonth(2027, 2), 30).dueOn,
        DateTime(2027, 2, 28),
      );
      expect(fixedEntryIn(entry, const YearMonth(2026, 10), 25).memo, '10월 난방');
    });

    test('뒤 달은 고른 달보다 뒤의 달만 오래된 것부터 고른다', () {
      const october = YearMonth(2026, 10);
      expect(
        monthsAfter({
          october.next.next,
          october.previous,
          october,
          october.next,
        }, october),
        [october.next, october.next.next],
      );
      expect(monthsAfter(null, october), isEmpty);
    });
  });
}
