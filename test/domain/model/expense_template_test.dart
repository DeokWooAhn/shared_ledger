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

  test('고정 수입 반복 설정은 고정 수입 id만 보고, 같은 id의 고정 지출이 있어도 만든다', () {
    const salary = ExpenseTemplate(
      id: 'salary',
      kind: EntryKind.fixedIncome,
      title: '월급',
      amount: 3000000,
      memberId: 'owner',
      dueDay: 25,
    );
    const bonus = ExpenseTemplate(
      id: 'bonus',
      kind: EntryKind.fixedIncome,
      title: '수당',
      amount: 100000,
      memberId: 'owner',
      dueDay: 10,
    );
    // 휴지통에 넣은 수당 문서가 남아 있고, 월급과 같은 id의 고정 지출 문서가 있다.
    const ledger = MonthLedger(
      plannedIds: {'salary'},
      fixedIncomeIds: {'bonus'},
    );

    expect(templatesMissingIn(ledger, [salary, bonus]), [salary]);
    expect(
      salary.draftFor(const YearMonth(2026, 10)).kind,
      EntryKind.fixedIncome,
    );
  });

  test('반복 설정으로 만든 항목은 고정 지출은 지급, 고정 수입은 받음으로 끝난다', () {
    final paid = DateTime(2026, 10, 25);
    expect(
      fixedEntrySettled(
        PlannedExpense(
          id: 'p',
          categoryId: 'c',
          memberId: 'owner',
          title: '월세',
          paymentMethodId: 'p',
          paidOn: paid,
        ),
      ),
      isTrue,
    );
    expect(
      fixedEntrySettled(
        const FixedIncome(id: 'f', memberId: 'owner', title: '월급', amount: 1),
      ),
      isFalse,
    );
    expect(
      fixedEntrySettled(
        FixedIncome(
          id: 'f',
          memberId: 'owner',
          title: '월급',
          amount: 1,
          receivedOn: paid,
        ),
      ),
      isTrue,
    );
    // 다른 종류는 반복 설정으로 만들지 않는다.
    expect(
      fixedEntrySettled(
        Income(
          id: 'i',
          memberId: 'owner',
          title: '용돈',
          amount: 1,
          receivedOn: paid,
        ),
      ),
      isFalse,
    );
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
      expect(fixedEntryProblemsOf(draft(), dueDay: 1), isEmpty);
      expect(
        fixedEntryProblemsOf(draft(amount: 0), dueDay: lastDueDay),
        isEmpty,
      );
      expect(fixedEntryProblemsOf(draft(title: '가' * 41), dueDay: 1), {
        EntryProblem.titleTooLong,
      });
      expect(fixedEntryProblemsOf(draft(amount: -1), dueDay: 1), {
        EntryProblem.amountNegative,
      });
    });

    test('예정일은 1일부터 말일까지만 받는다', () {
      for (final dueDay in [null, 0, lastDueDay + 1]) {
        expect(fixedEntryProblemsOf(draft(), dueDay: dueDay), {
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

  group('고친 뒤의 반복 설정', () {
    // 11월 관리비를 열었을 때의 값. 12월에서 반복 설정 제목을 '관리비(난방)'으로 바꾼 뒤라 11월 제목은 옛 값이다.
    final base = EntryDraft(
      kind: EntryKind.planned,
      memberId: 'owner',
      amount: 200000,
      title: '관리비',
      categoryId: 'c-living',
      paymentMethodId: 'p-account',
      dueOn: DateTime(2026, 11, 10),
    );
    const current = TemplateDraft(
      memberId: 'owner',
      title: '관리비(난방)',
      amount: 200000,
      categoryId: 'c-living',
      paymentMethodId: 'p-account',
      dueDay: 10,
    );

    EntryDraft change({
      String? title,
      String? categoryId,
      DateTime? dueOn,
      int? amount,
      String? memo,
    }) => EntryDraft(
      kind: base.kind,
      memberId: base.memberId,
      amount: amount ?? base.amount,
      title: title ?? base.title,
      categoryId: categoryId ?? base.categoryId,
      paymentMethodId: base.paymentMethodId,
      dueOn: dueOn ?? base.dueOn,
      memo: memo ?? base.memo,
    );

    test('지난달 메모만 고치면 그달의 옛 제목으로 반복 설정을 되돌리지 않는다', () {
      final mine = change(memo: '난방 포함');

      expect(
        templateAfterEdit(
          current,
          base: base,
          mine: mine,
          merged: mine,
          dueDay: null,
          amountForLater: false,
        ),
        current,
      );
    });

    test('내가 바꾼 칸만 반복 설정에 얹는다', () {
      final mine = change(categoryId: 'c-home', amount: 230000);

      final next = templateAfterEdit(
        current,
        base: base,
        mine: mine,
        merged: mine,
        dueDay: null,
        amountForLater: false,
      );

      expect(next.categoryId, 'c-home');
      expect(next.title, '관리비(난방)');
      // 금액은 '다음 달부터도'가 아니면 그달만 바뀐다.
      expect(next.amount, 200000);
      expect(
        templateAfterEdit(
          current,
          base: base,
          mine: mine,
          merged: mine,
          dueDay: null,
          amountForLater: true,
        ).amount,
        230000,
      );
    });

    test('예정일 겹침에서 상대 값을 고르면 반복 설정도 상대 값을 지킨다', () {
      // 10일이던 것을 상대가 20일로(반복 설정도 20일), 내가 15일로 바꿨다.
      const theirs = TemplateDraft(
        memberId: 'owner',
        title: '관리비(난방)',
        amount: 200000,
        categoryId: 'c-living',
        paymentMethodId: 'p-account',
        dueDay: 20,
      );
      final mine = change(dueOn: DateTime(2026, 11, 15));

      TemplateDraft after(DateTime mergedDueOn) => templateAfterEdit(
        theirs,
        base: base,
        mine: mine,
        merged: change(dueOn: mergedDueOn),
        dueDay: 15,
        amountForLater: false,
      );

      expect(after(DateTime(2026, 11, 20)).dueDay, 20);
      expect(after(DateTime(2026, 11, 15)).dueDay, 15);
    });

    test('겹침에서 상대 값을 고른 칸은 내가 바꿨어도 반복 설정에 얹지 않는다', () {
      final next = templateAfterEdit(
        current,
        base: base,
        mine: change(title: '관리비(전기)'),
        merged: change(title: '관리비(수도)'),
        dueDay: null,
        amountForLater: false,
      );

      expect(next.title, '관리비(난방)');
    });
  });
}
