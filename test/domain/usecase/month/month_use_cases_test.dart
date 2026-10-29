import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/domain/repository/entries_repository.dart';
import 'package:shared_ledger/domain/usecase/month/month_use_cases.dart';
import 'package:shared_ledger/domain/usecase/month/plan_month_fill_use_case.dart';
import 'package:shared_ledger/domain/usecase/month/plan_months_backfill_use_case.dart';

import '../../../../testing/fakes.dart';
import '../../../../testing/provider_container.dart';

// testNow는 2026년 10월이다.
const september = YearMonth(2026, 9);
const october = YearMonth(2026, 10);
const november = YearMonth(2026, 11);
const december = YearMonth(2026, 12);

const rent = ExpenseTemplate(
  id: 'template-rent',
  title: '관리비',
  amount: 150000,
  categoryId: 'c-living',
  paymentMethodId: 'p-account',
  memberId: 'owner',
  dueDay: 25,
);
const phone = ExpenseTemplate(
  id: 'template-phone',
  title: '통신비',
  categoryId: 'c-living',
  paymentMethodId: 'p-account',
  memberId: 'partner',
  dueDay: 10,
);

/// [template]로 만든 그달 고정 지출(문서 id가 반복 설정 id).
PlannedExpense plannedOf(ExpenseTemplate template) => PlannedExpense(
  id: template.id,
  categoryId: template.categoryId,
  memberId: template.memberId,
  title: template.title,
  paymentMethodId: template.paymentMethodId,
);

// 10월이 달 목록에 있는 가계부.
final mine = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'me',
  months: {october},
);

MonthUseCases useCasesOf({
  FakeEntriesRepository? entries,
  FakeLedgerRepository? ledgers,
}) => MonthUseCases(
  entries ?? FakeEntriesRepository(),
  ledgers ?? FakeLedgerRepository(),
  now: () => testNow,
);

void main() {
  group('그달 채울 것 정하기', () {
    // 항목·고정 지출을 몇 번 꺼냈는지 센다(꺼낸 것만 공급자가 구독한다).
    var reads = 0;
    PlannedFill? plan({
      Ledger? ledger,
      bool canWrite = true,
      YearMonth month = october,
      List<YearMonth>? ledgerMonths = const [october, november],
      MonthLedger? entries = const MonthLedger(),
      List<ExpenseTemplate>? templates = const [rent, phone],
    }) => useCasesOf().planMonthFill(
      ledger: ledger ?? mine,
      canWrite: canWrite,
      month: month,
      ledgerMonths: ledgerMonths,
      entries: () {
        reads++;
        return entries;
      },
      templates: () {
        reads++;
        return templates;
      },
    );

    setUp(() => reads = 0);

    test('그달에 아직 고정 지출이 없는 반복 설정만 채울 것으로 낸다', () {
      final fill = plan(
        entries: MonthLedger(plannedExpenses: [plannedOf(rent)]),
      );

      expect(
        fill,
        const PlannedFill(ledgerId: 'l1', month: october, templates: [phone]),
      );
    });

    test('달 목록에 없는 달을 채우면 그달을 달 목록에 같이 더한다', () {
      final fill = plan(
        ledger: const Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'me',
          months: {},
        ),
      );

      expect(fill?.recordMonth, isTrue);
    });

    test('다 있으면 null이다', () {
      final fill = plan(
        entries: MonthLedger(
          plannedExpenses: [plannedOf(rent), plannedOf(phone)],
        ),
      );

      expect(fill, isNull);
    });

    test('보기 전용, 지난 달·다다음 달, 오가지 않는 달이면 항목과 고정 지출을 꺼내지 않고 null이다', () {
      expect(plan(canWrite: false), isNull);
      expect(plan(month: september), isNull);
      expect(plan(month: december), isNull);
      expect(plan(month: november, ledgerMonths: const [october]), isNull);
      expect(reads, 0);
    });

    test('항목이나 고정 지출을 아직 받지 못했으면 null이고, 그래도 둘 다 꺼낸다', () {
      expect(plan(entries: null), isNull);
      expect(reads, 2);
      reads = 0;
      expect(plan(templates: null), isNull);
      expect(reads, 2);
    });

    test('달 목록을 아직 모으지 않은 가계부(null)는 달을 가리지 않고 채울 것을 낸다', () {
      final fill = plan(
        ledger: const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
        ledgerMonths: null,
        month: november,
      );

      expect(
        fill,
        const PlannedFill(
          ledgerId: 'l1',
          month: november,
          templates: [rent, phone],
        ),
      );
    });
  });

  test('채울 것으로 그달 고정 지출을 만들고 달 목록에도 더한다', () async {
    final entries = FakeEntriesRepository();

    final created = await useCasesOf(entries: entries).fillMonthFromTemplates(
      const PlannedFill(
        ledgerId: 'l1',
        month: november,
        templates: [rent, phone],
        recordMonth: true,
      ),
      uid: 'me',
    );

    expect(created, 2);
    expect(entries.monthOf(november).plannedIds, {
      'template-rent',
      'template-phone',
    });
    expect(entries.recordedMonths, [november]);
  });

  group('달력에서 그달 만들기', () {
    test('이번 달 이후면 고정 지출을 읽어 채우고 그달을 달 목록에 더한다', () async {
      final entries = FakeEntriesRepository();
      var loads = 0;

      await useCasesOf(entries: entries).addMonth(
        ledgerId: 'l1',
        month: november,
        uid: 'me',
        templates: () async {
          loads++;
          return const [rent];
        },
      );

      expect(loads, 1);
      expect(entries.filled.single.templateIds, ['template-rent']);
      expect(entries.recordedMonths, [november]);
    });

    test('지난 달이면 고정 지출을 읽지 않고 달만 만든다', () async {
      final entries = FakeEntriesRepository();
      var loads = 0;

      await useCasesOf(entries: entries).addMonth(
        ledgerId: 'l1',
        month: september,
        uid: 'me',
        templates: () async {
          loads++;
          return const [rent];
        },
      );

      expect(loads, 0);
      expect(entries.filled.single.templateIds, isEmpty);
      expect(entries.recordedMonths, [september]);
    });

    test('연결이 없으면 저장소의 실패를 그대로 던진다', () async {
      final useCases = useCasesOf(
        entries: FakeEntriesRepository()..offline = true,
      );

      await expectLater(
        useCases.addMonth(
          ledgerId: 'l1',
          month: november,
          uid: 'me',
          templates: () async => const [rent],
        ),
        throwsA(isA<EntryWriteException>()),
      );
    });
  });

  group('항목 있는 달 목록 처음 모으기', () {
    test('살펴볼 달은 만든 달 1년 전부터 이번 달 1년 뒤까지다', () {
      final months = monthsToBackfill(
        createdIn: const YearMonth(2026, 10),
        thisMonth: const YearMonth(2026, 11),
      );

      expect(months.first, const YearMonth(2025, 10));
      expect(months.last, const YearMonth(2027, 11));
      expect(months, hasLength(26));
    });

    // 달 목록이 생기기 전에 만든 가계부(months가 null). 2026년 10월에 만들었다.
    final legacy = Ledger(
      id: 'l1',
      name: '우리 가계부',
      ownerUid: 'me',
      createdAt: DateTime(2026, 10, 1),
    );

    test('달 목록이 없는 가계부이고 쓸 수 있을 때만 범위를 낸다', () {
      final useCases = useCasesOf();

      expect(
        useCases.planMonthsBackfill(ledger: legacy, canWrite: true),
        MonthsBackfill(
          ledgerId: 'l1',
          months: monthsToBackfill(createdIn: october, thisMonth: october),
        ),
      );
      expect(
        useCases.planMonthsBackfill(ledger: legacy, canWrite: false),
        isNull,
      );
      expect(useCases.planMonthsBackfill(ledger: mine, canWrite: true), isNull);
      expect(useCases.planMonthsBackfill(ledger: null, canWrite: true), isNull);
    });

    test('범위에서 항목(휴지통 포함)이 있는 달만 찾아 가계부에 적는다', () async {
      final entries = FakeEntriesRepository({
        september: const MonthLedger(
          extraExpenses: [
            ExtraExpense(
              id: 'x1',
              memberId: 'owner',
              title: '간식',
              paymentMethodId: 'p-account',
              amount: 5000,
            ),
          ],
        ),
      });
      final ledgers = FakeLedgerRepository([legacy]);

      await useCasesOf(entries: entries, ledgers: ledgers).backfillMonths(
        MonthsBackfill(ledgerId: 'l1', months: const [september, october]),
      );

      expect(entries.scannedMonths, [september, october]);
      expect(ledgers.recordedMonths.single.ledgerId, 'l1');
      expect(ledgers.recordedMonths.single.months, {september});
    });

    test('연결이 없으면 적지 않고 저장소의 실패를 그대로 던진다', () async {
      final ledgers = FakeLedgerRepository([legacy]);
      final useCases = useCasesOf(
        entries: FakeEntriesRepository()..offline = true,
        ledgers: ledgers,
      );

      await expectLater(
        useCases.backfillMonths(
          const MonthsBackfill(ledgerId: 'l1', months: [october]),
        ),
        throwsA(isA<EntryWriteException>()),
      );
      expect(ledgers.recordedMonths, isEmpty);
    });
  });
}
