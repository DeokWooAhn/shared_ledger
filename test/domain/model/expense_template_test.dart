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

  test('그달에 만들 기본 월 지출은 고정 지출 값에 예정일을 붙이고 지급 전이다', () {
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
}
