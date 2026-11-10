import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/entry_edit.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/domain/repository/templates_repository.dart';
import 'package:shared_ledger/domain/usecase/template/template_use_cases.dart';

import '../../../../testing/fakes.dart';

const september = YearMonth(2026, 9);
const october = YearMonth(2026, 10);
const november = YearMonth(2026, 11);

/// 9·10·11월 가계부가 있는 가계부. 10월을 고치면 11월이 뒤 달이다.
final ledger = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'me',
  months: {september, october, november},
);

const rent = ExpenseTemplate(
  id: 'template-rent',
  title: '관리비',
  amount: 200000,
  categoryId: 'c-living',
  paymentMethodId: 'p-account',
  memberId: 'owner',
  dueDay: 25,
);

/// 항목 입력 화면이 넘기는 고정 지출 값.
const phone = EntryDraft(
  kind: EntryKind.planned,
  memberId: 'partner',
  title: '통신비',
  amount: 50000,
  categoryId: 'c-living',
  paymentMethodId: 'p-account',
);

/// [rent]로 [month]에 만든 그달 항목. [paidOn]이 있으면 지급한 것이다.
/// [title]·[dueDay]를 주면 그 뒤에 반복 설정이 바뀐 것처럼 그 값으로 만든다.
PlannedExpense rentIn(
  YearMonth month, {
  DateTime? paidOn,
  int? amount,
  String? title,
  int? dueDay,
}) => PlannedExpense(
  id: rent.id,
  categoryId: rent.categoryId!,
  memberId: rent.memberId,
  title: title ?? rent.title,
  paymentMethodId: rent.paymentMethodId!,
  amount: amount ?? rent.amount,
  dueOn: dueDateIn(month, dueDay ?? rent.dueDay),
  paidOn: paidOn,
);

const salary = ExpenseTemplate(
  id: 'template-salary',
  kind: EntryKind.fixedIncome,
  title: '월급',
  amount: 3000000,
  memberId: 'owner',
  dueDay: 25,
);

/// [salary]로 [month]에 만든 그달 고정 수입. [receivedOn]이 있으면 받은 것이다.
FixedIncome salaryIn(YearMonth month, {DateTime? receivedOn, int? amount}) =>
    FixedIncome(
      id: salary.id,
      memberId: salary.memberId,
      title: salary.title,
      amount: amount ?? salary.amount!,
      dueOn: salary.dueOn(month),
      receivedOn: receivedOn,
    );

/// 반복 설정과 그달 항목을 잇는 가짜 저장소들.
({FakeTemplatesRepository templates, FakeEntriesRepository entries}) fakes({
  List<ExpenseTemplate> templates = const [rent],
  Map<YearMonth, MonthLedger> months = const {},
}) {
  final entries = FakeEntriesRepository(months);
  return (
    templates: FakeTemplatesRepository(templates)..entries = entries,
    entries: entries,
  );
}

void main() {
  test('그 가계부의 반복 설정을 지켜본다', () async {
    final templates = FakeTemplatesRepository([rent]);

    expect(await TemplateUseCases(templates).watchTemplates('l1').first, [
      rent,
    ]);
    expect(templates.watched, ['l1']);
  });

  group('고정 지출 더하기', () {
    test('반복 설정과 그달 항목(예정일 포함)을 같은 id로 만들고, 뒤 달에도 지급 전으로 만든다', () async {
      final (:templates, :entries) = fakes(templates: const []);

      final problems = await TemplateUseCases(templates).addFixedEntry(
        ledger: ledger,
        month: october,
        entry: phone,
        dueDay: 21,
        uid: 'me',
      );

      expect(problems, isEmpty);
      final template = templates.templates.single;
      expect(TemplateDraft.of(template).dueDay, 21);
      expect(template.amount, 50000);
      expect(
        entries.monthOf(october).plannedExpenses.single.dueOn,
        DateTime(2026, 10, 21),
      );
      expect(entries.monthOf(october).plannedExpenses.single.id, template.id);
      // 9월(앞의 달)은 건드리지 않고 11월(뒤 달)에만 만든다.
      expect(templates.added.single.laterMonths, [november]);
      expect(
        entries.monthOf(november).plannedExpenses.single.dueOn,
        DateTime(2026, 11, 21),
      );
      expect(entries.monthOf(september).plannedExpenses, isEmpty);
    });

    test('매달 예정일을 고르지 않았으면 쓰지 않고 문제를 돌려준다', () async {
      final (:templates, entries: _) = fakes(templates: const []);

      final problems = await TemplateUseCases(templates).addFixedEntry(
        ledger: ledger,
        month: october,
        entry: phone,
        dueDay: null,
        uid: 'me',
      );

      expect(problems, {EntryProblem.dueDayMissing});
      expect(templates.added, isEmpty);
    });

    test('연결이 없으면 offline으로 실패한다', () async {
      final (:templates, entries: _) = fakes(templates: const []);
      templates.offline = true;

      await expectLater(
        TemplateUseCases(templates).addFixedEntry(
          ledger: ledger,
          month: october,
          entry: phone,
          dueDay: 21,
          uid: 'me',
        ),
        throwsA(
          isA<TemplateWriteException>().having(
            (e) => e.reason,
            'reason',
            TemplateWriteFailure.offline,
          ),
        ),
      );
    });
  });

  group('고정 지출 고치기', () {
    EntryDraft edited({int amount = 230000}) => EntryDraft(
      kind: EntryKind.planned,
      memberId: 'partner',
      title: '관리비(난방)',
      amount: amount,
      categoryId: 'c-living',
      paymentMethodId: 'p-account',
    );

    test('금액은 그달만 바꾸고, 다른 칸과 예정일은 반복 설정과 뒤 달의 지급 전 항목에도 맞춘다', () async {
      final (:templates, :entries) = fakes(
        months: {
          october: MonthLedger(plannedExpenses: [rentIn(october)]),
          november: MonthLedger(plannedExpenses: [rentIn(november)]),
        },
      );

      await TemplateUseCases(templates).updateFixedEntry(
        ledger: ledger,
        month: october,
        template: rent,
        original: rentIn(october),
        entry: edited(),
        dueDay: lastDueDay,
        amountForLater: false,
        uid: 'me',
      );

      final template = templates.templates.single;
      expect(template.amount, 200000);
      expect(template.title, '관리비(난방)');
      expect(template.dueDay, lastDueDay);
      final thisMonth = entries.monthOf(october).plannedExpenses.single;
      expect(thisMonth.amount, 230000);
      expect(thisMonth.dueOn, DateTime(2026, 10, 31));
      final later = entries.monthOf(november).plannedExpenses.single;
      expect(later.amount, 200000);
      expect(later.title, '관리비(난방)');
      expect(later.memberId, 'partner');
      expect(later.dueOn, DateTime(2026, 11, 30));
    });

    test('다음 달부터도 이 금액이면 반복 설정과 뒤 달의 지급 전 항목 금액도 바꾼다', () async {
      final (:templates, :entries) = fakes(
        months: {
          october: MonthLedger(plannedExpenses: [rentIn(october)]),
          november: MonthLedger(plannedExpenses: [rentIn(november)]),
        },
      );

      await TemplateUseCases(templates).updateFixedEntry(
        ledger: ledger,
        month: october,
        template: rent,
        original: rentIn(october),
        entry: edited(),
        dueDay: 25,
        amountForLater: true,
        uid: 'me',
      );

      expect(templates.templates.single.amount, 230000);
      expect(entries.monthOf(november).plannedExpenses.single.amount, 230000);
    });

    test('뒤 달에 이미 지급한 항목은 실제로 나간 돈이라 그대로 둔다', () async {
      final paid = rentIn(november, paidOn: DateTime(2026, 11, 25));
      final (:templates, :entries) = fakes(
        months: {
          october: MonthLedger(plannedExpenses: [rentIn(october)]),
          november: MonthLedger(plannedExpenses: [paid]),
        },
      );

      await TemplateUseCases(templates).updateFixedEntry(
        ledger: ledger,
        month: october,
        template: rent,
        original: rentIn(october),
        entry: edited(),
        dueDay: 25,
        amountForLater: true,
        uid: 'me',
      );

      expect(entries.monthOf(november).plannedExpenses.single, paid);
    });
  });

  group('고정 지출 고치기와 반복 설정의 다른 변경', () {
    /// 화면을 연 [original]에서 [memo]·[categoryId]만 바꾼 값. 화면은 그달 예정일을 그대로 넘긴다.
    EntryDraft from(LedgerEntry original, {String? memo, String? categoryId}) {
      final draft = EntryDraft.of(original);
      return EntryDraft(
        kind: draft.kind,
        memberId: draft.memberId,
        amount: draft.amount,
        title: draft.title,
        categoryId: categoryId ?? draft.categoryId,
        paymentMethodId: draft.paymentMethodId,
        date: draft.date,
        dueOn: draft.dueOn,
        memo: memo ?? draft.memo,
      );
    }

    // 11월에서 제목을 '관리비(난방)', 예정일을 10일로 바꾼 반복 설정. 10월 항목은 옛 값 그대로다.
    const retitled = ExpenseTemplate(
      id: 'template-rent',
      title: '관리비(난방)',
      amount: 200000,
      categoryId: 'c-living',
      paymentMethodId: 'p-account',
      memberId: 'owner',
      dueDay: 10,
    );

    test('지난달 메모만 고치면 반복 설정과 뒤 달은 그대로고, 그달 예정일도 옮기지 않는다', () async {
      final (:templates, :entries) = fakes(
        templates: const [retitled],
        months: {
          october: MonthLedger(plannedExpenses: [rentIn(october)]),
          november: MonthLedger(
            plannedExpenses: [rentIn(november, title: '관리비(난방)', dueDay: 10)],
          ),
        },
      );

      await TemplateUseCases(templates).updateFixedEntry(
        ledger: ledger,
        month: october,
        template: retitled,
        original: rentIn(october),
        entry: from(rentIn(october), memo: '난방 포함'),
        dueDay: null,
        amountForLater: false,
        uid: 'me',
      );

      expect(templates.templates.single, retitled);
      final thisMonth = entries.monthOf(october).plannedExpenses.single;
      expect(thisMonth.memo, '난방 포함');
      expect(thisMonth.title, '관리비');
      expect(thisMonth.dueOn, DateTime(2026, 10, 25));
      final later = entries.monthOf(november).plannedExpenses.single;
      expect(later.title, '관리비(난방)');
      expect(later.dueOn, DateTime(2026, 11, 10));
    });

    test('바꾼 칸만 반복 설정과 뒤 달에 맞추고, 뒤 달의 다른 칸은 덮지 않는다', () async {
      final (:templates, :entries) = fakes(
        templates: const [retitled],
        months: {
          october: MonthLedger(plannedExpenses: [rentIn(october)]),
          november: MonthLedger(
            plannedExpenses: [rentIn(november, title: '관리비(11월)', dueDay: 12)],
          ),
        },
      );

      await TemplateUseCases(templates).updateFixedEntry(
        ledger: ledger,
        month: october,
        template: retitled,
        original: rentIn(october),
        entry: from(rentIn(october), categoryId: 'c-home'),
        dueDay: null,
        amountForLater: false,
        uid: 'me',
      );

      final template = templates.templates.single;
      expect(template.categoryId, 'c-home');
      expect(template.title, '관리비(난방)');
      expect(template.dueDay, 10);
      final later = entries.monthOf(november).plannedExpenses.single;
      expect(later.categoryId, 'c-home');
      expect(later.title, '관리비(11월)');
      expect(later.dueOn, DateTime(2026, 11, 12));
    });

    group('예정일을 상대와 다르게 바꾸면', () {
      // 25일이던 것을 화면을 연 사이 상대가 20일로 바꿨다(반복 설정과 뒤 달도 20일). 나는 15일로 바꾼다.
      const moved = ExpenseTemplate(
        id: 'template-rent',
        title: '관리비',
        amount: 200000,
        categoryId: 'c-living',
        paymentMethodId: 'p-account',
        memberId: 'owner',
        dueDay: 20,
      );

      Future<
        ({FakeTemplatesRepository templates, FakeEntriesRepository entries})
      >
      saveWith(EditConflictChoice? choice) async {
        final repositories = fakes(
          templates: const [moved],
          months: {
            october: MonthLedger(
              plannedExpenses: [rentIn(october, dueDay: 20)],
            ),
            november: MonthLedger(
              plannedExpenses: [rentIn(november, dueDay: 20)],
            ),
          },
        );
        await TemplateUseCases(repositories.templates).updateFixedEntry(
          ledger: ledger,
          month: october,
          template: rent,
          original: rentIn(october),
          entry: from(rentIn(october)),
          dueDay: 15,
          amountForLater: false,
          uid: 'me',
          choice: choice,
        );
        return repositories;
      }

      test('고르기 전에는 쓰지 않고 겹친 칸을 알린다', () async {
        await expectLater(
          saveWith(null),
          throwsA(
            isA<EntryEditConflict>().having((e) => e.fields, 'fields', {
              EntryField.dueOn,
            }),
          ),
        );
      });

      test('상대 값을 고르면 그달·반복 설정·뒤 달 모두 상대 예정일이다', () async {
        final (:templates, :entries) = await saveWith(
          EditConflictChoice.theirs,
        );

        expect(
          entries.monthOf(october).plannedExpenses.single.dueOn,
          DateTime(2026, 10, 20),
        );
        expect(templates.templates.single.dueDay, 20);
        expect(
          entries.monthOf(november).plannedExpenses.single.dueOn,
          DateTime(2026, 11, 20),
        );
      });

      test('내 값을 고르면 그달·반복 설정·뒤 달 모두 내 예정일이다', () async {
        final (:templates, :entries) = await saveWith(EditConflictChoice.mine);

        expect(
          entries.monthOf(october).plannedExpenses.single.dueOn,
          DateTime(2026, 10, 15),
        );
        expect(templates.templates.single.dueDay, 15);
        expect(
          entries.monthOf(november).plannedExpenses.single.dueOn,
          DateTime(2026, 11, 15),
        );
      });
    });
  });

  group('고정 지출 그만하기와 되돌리기', () {
    test('반복 설정을 지우고 그달과 뒤 달의 지급 전 항목을 휴지통에 넣는다. 앞의 달은 남는다', () async {
      final (:templates, :entries) = fakes(
        months: {
          september: MonthLedger(
            plannedExpenses: [rentIn(september, paidOn: DateTime(2026, 9, 25))],
          ),
          october: MonthLedger(plannedExpenses: [rentIn(october)]),
          november: MonthLedger(plannedExpenses: [rentIn(november)]),
        },
      );

      final months = await TemplateUseCases(
        templates,
      ).stopFixedEntry(ledger: ledger, month: october, id: rent.id, uid: 'me');

      expect(months, [october, november]);
      expect(templates.templates, isEmpty);
      expect(entries.monthOf(october).plannedExpenses, isEmpty);
      expect(entries.monthOf(november).plannedExpenses, isEmpty);
      expect(entries.monthOf(september).plannedExpenses, hasLength(1));
      // 다시 만들어지지 않으니 보통처럼 자동으로 지워진다.
      expect(entries.monthOf(october).trashed.single.purgeAt, isNotNull);
    });

    test('그달 항목을 이미 지급했으면 그달 것은 남기고 다음 달부터 그만한다', () async {
      final paid = rentIn(october, paidOn: DateTime(2026, 10, 25));
      final (:templates, :entries) = fakes(
        months: {
          october: MonthLedger(plannedExpenses: [paid]),
          november: MonthLedger(plannedExpenses: [rentIn(november)]),
        },
      );

      final months = await TemplateUseCases(
        templates,
      ).stopFixedEntry(ledger: ledger, month: october, id: rent.id, uid: 'me');

      expect(months, [november]);
      expect(entries.monthOf(october).plannedExpenses, [paid]);
    });

    test('되돌리기는 반복 설정을 같은 id로 되살리고 그때 휴지통에 넣은 항목을 꺼낸다', () async {
      final (:templates, :entries) = fakes(
        months: {
          october: MonthLedger(plannedExpenses: [rentIn(october)]),
          november: MonthLedger(plannedExpenses: [rentIn(november)]),
        },
      );
      final useCases = TemplateUseCases(templates);
      final months = await useCases.stopFixedEntry(
        ledger: ledger,
        month: october,
        id: rent.id,
        uid: 'me',
      );

      await useCases.resumeFixedEntry(
        ledgerId: 'l1',
        template: rent,
        months: months,
        uid: 'me',
      );

      expect(templates.templates, [rent]);
      for (final month in [october, november]) {
        final restored = entries.monthOf(month).plannedExpenses.single;
        expect(restored.id, rent.id, reason: '$month');
        expect(restored.dueOn, rent.dueOn(month), reason: '$month');
        expect(entries.monthOf(month).trashed, isEmpty, reason: '$month');
      }
    });

    test('그사이 상대가 그만했으면 notFound로 실패한다', () async {
      final (:templates, entries: _) = fakes(
        templates: const [],
        months: {
          october: MonthLedger(plannedExpenses: [rentIn(october)]),
        },
      );

      await expectLater(
        TemplateUseCases(templates).stopFixedEntry(
          ledger: ledger,
          month: october,
          id: rent.id,
          uid: 'me',
        ),
        throwsA(
          isA<TemplateWriteException>().having(
            (e) => e.reason,
            'reason',
            TemplateWriteFailure.notFound,
          ),
        ),
      );
    });
  });

  group('고정 수입', () {
    const pay = EntryDraft(
      kind: EntryKind.fixedIncome,
      memberId: 'owner',
      title: '월급',
      amount: 3000000,
    );

    test('금액이 없으면 쓰지 않고 문제를 돌려준다', () async {
      final (:templates, entries: _) = fakes(templates: const []);

      final problems = await TemplateUseCases(templates).addFixedEntry(
        ledger: ledger,
        month: october,
        entry: const EntryDraft(
          kind: EntryKind.fixedIncome,
          memberId: 'owner',
          title: '월급',
        ),
        dueDay: 25,
        uid: 'me',
      );

      expect(problems, {EntryProblem.amountMissing});
      expect(templates.added, isEmpty);
    });

    test('더하면 고정 수입 반복 설정과 그달·뒤 달의 받기 전 고정 수입을 만든다', () async {
      final (:templates, :entries) = fakes(templates: const []);

      final problems = await TemplateUseCases(templates).addFixedEntry(
        ledger: ledger,
        month: october,
        entry: pay,
        dueDay: 25,
        uid: 'me',
      );

      expect(problems, isEmpty);
      final template = templates.templates.single;
      expect(template.kind, EntryKind.fixedIncome);
      expect(template.categoryId, isNull);
      for (final month in [october, november]) {
        final income = entries.monthOf(month).fixedIncomes.single;
        expect(income.id, template.id, reason: '$month');
        expect(income.isReceived, isFalse, reason: '$month');
        expect(income.dueOn, DateTime(month.year, month.month, 25));
        expect(entries.monthOf(month).plannedExpenses, isEmpty);
      }
    });

    test('다음 달부터도 이 금액이면 뒤 달의 받기 전 고정 수입만 맞추고, 받은 것은 그대로 둔다', () async {
      final received = salaryIn(november, receivedOn: DateTime(2026, 11, 25));
      final (:templates, :entries) = fakes(
        templates: const [salary],
        months: {
          october: MonthLedger(fixedIncomes: [salaryIn(october)]),
          november: MonthLedger(fixedIncomes: [received]),
        },
      );
      final longer = Ledger(
        id: 'l1',
        name: '우리 가계부',
        ownerUid: 'me',
        months: {october, november, const YearMonth(2026, 12)},
      );
      await entries.fillPlanned(
        ledgerId: 'l1',
        month: const YearMonth(2026, 12),
        templates: const [salary],
        uid: 'me',
      );

      await TemplateUseCases(templates).updateFixedEntry(
        ledger: longer,
        month: october,
        template: salary,
        original: salaryIn(october),
        entry: EntryDraft.of(salaryIn(october, amount: 3200000)),
        dueDay: 25,
        amountForLater: true,
        uid: 'me',
      );

      expect(templates.templates.single.amount, 3200000);
      expect(entries.monthOf(october).fixedIncomes.single.amount, 3200000);
      expect(entries.monthOf(november).fixedIncomes.single, received);
      expect(
        entries.monthOf(const YearMonth(2026, 12)).fixedIncomes.single.amount,
        3200000,
      );
    });

    test('그만하면 받은 그달 것은 남기고 뒤 달의 받기 전 것만 휴지통에 넣으며, 되돌리기로 돌아온다', () async {
      final received = salaryIn(october, receivedOn: DateTime(2026, 10, 25));
      final (:templates, :entries) = fakes(
        templates: const [salary],
        months: {
          october: MonthLedger(fixedIncomes: [received]),
          november: MonthLedger(fixedIncomes: [salaryIn(november)]),
        },
      );
      final useCases = TemplateUseCases(templates);

      final months = await useCases.stopFixedEntry(
        ledger: ledger,
        month: october,
        id: salary.id,
        uid: 'me',
      );

      expect(months, [november]);
      expect(entries.monthOf(october).fixedIncomes, [received]);
      expect(entries.monthOf(november).fixedIncomes, isEmpty);
      expect(
        entries.monthOf(november).trashed.single.entry.kind,
        EntryKind.fixedIncome,
      );

      await useCases.resumeFixedEntry(
        ledgerId: 'l1',
        template: salary,
        months: months,
        uid: 'me',
      );

      expect(templates.templates, [salary]);
      expect(entries.monthOf(november).fixedIncomes.single.id, salary.id);
    });
  });
}
