import 'package:flutter_test/flutter_test.dart';
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
PlannedExpense rentIn(YearMonth month, {DateTime? paidOn, int? amount}) =>
    PlannedExpense(
      id: rent.id,
      categoryId: rent.categoryId,
      memberId: rent.memberId,
      title: rent.title,
      paymentMethodId: rent.paymentMethodId,
      amount: amount ?? rent.amount,
      dueOn: rent.dueOn(month),
      paidOn: paidOn,
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

      final problems = await TemplateUseCases(templates).addFixedExpense(
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

      final problems = await TemplateUseCases(templates).addFixedExpense(
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
        TemplateUseCases(templates).addFixedExpense(
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

      await TemplateUseCases(templates).updateFixedExpense(
        ledger: ledger,
        month: october,
        template: rent,
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

      await TemplateUseCases(templates).updateFixedExpense(
        ledger: ledger,
        month: october,
        template: rent,
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

      await TemplateUseCases(templates).updateFixedExpense(
        ledger: ledger,
        month: october,
        template: rent,
        entry: edited(),
        dueDay: 25,
        amountForLater: true,
        uid: 'me',
      );

      expect(entries.monthOf(november).plannedExpenses.single, paid);
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

      final months = await TemplateUseCases(templates).stopFixedExpense(
        ledger: ledger,
        month: october,
        id: rent.id,
        uid: 'me',
      );

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

      final months = await TemplateUseCases(templates).stopFixedExpense(
        ledger: ledger,
        month: october,
        id: rent.id,
        uid: 'me',
      );

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
      final months = await useCases.stopFixedExpense(
        ledger: ledger,
        month: october,
        id: rent.id,
        uid: 'me',
      );

      await useCases.resumeFixedExpense(
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
        TemplateUseCases(templates).stopFixedExpense(
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
}
