import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/expense_template.dart';
import 'package:shared_ledger/core/model/holidays.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/year_month.dart';

import '../../support/fakes.dart';
import '../../support/provider_container.dart';

void main() {
  const me = AuthUser(uid: 'me');

  test('보는 달은 이번 달에서 시작하고 앞뒤로 옮긴다', () {
    final container = createContainer(now: DateTime(2026, 12, 31, 23));
    final month = container.read(selectedMonthProvider.notifier);

    expect(container.read(selectedMonthProvider), const YearMonth(2026, 12));
    month.next();
    expect(container.read(selectedMonthProvider), const YearMonth(2027, 1));
    month
      ..previous()
      ..previous();
    expect(container.read(selectedMonthProvider), const YearMonth(2026, 11));
  });

  group('요약·항목 탭이 오가는 달', () {
    Future<ProviderContainer> withLedger(Ledger ledger) async {
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([ledger]),
      );
      await loadSignedInUser(container);
      container.listen(myLedgersProvider, (_, _) {});
      await container.read(myLedgersProvider.future);
      return container;
    }

    test('항목 있는 달에 이번 달을 더해 오래된 것부터 둔다(다음 달은 항목이 있을 때만)', () async {
      final container = await withLedger(
        Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'me',
          months: {const YearMonth(2026, 12), const YearMonth(2026, 8)},
        ),
      );

      expect(container.read(ledgerMonthsProvider), const [
        YearMonth(2026, 8),
        YearMonth(2026, 10),
        YearMonth(2026, 12),
      ]);
    });

    test('달 목록을 아직 모으지 않은 가계부거나 가계부가 없으면 달을 가리지 않는다(null)', () async {
      final container = await withLedger(
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      );
      expect(container.read(ledgerMonthsProvider), isNull);
      expect(createContainer().read(ledgerMonthsProvider), isNull);
    });
  });

  test('이름표는 지금 가계부의 것을 읽는다', () async {
    final settings = FakeSettingsRepository();
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: me),
      ledgers: FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]),
      settings: settings,
    );
    await loadSignedInUser(container);
    container.listen(membersProvider, (_, _) {});
    // 가계부 목록이 오기 전에는 지금 가계부가 없어 빈 목록이다. 목록을 받은 뒤의 값을 본다.
    await container.read(myLedgersProvider.future);

    expect(await container.read(membersProvider.future), settings.members);
    expect(settings.watched, ['l1']);
  });

  test('가계부가 없으면 설정을 구독하지 않고 빈 목록이다', () async {
    final settings = FakeSettingsRepository();
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: me),
      settings: settings,
    );
    await loadSignedInUser(container);
    for (final provider in [
      membersProvider,
      categoriesProvider,
      paymentMethodsProvider,
    ]) {
      container.listen(provider, (_, _) {});
    }

    expect(await container.read(membersProvider.future), isEmpty);
    expect(await container.read(categoriesProvider.future), isEmpty);
    expect(await container.read(paymentMethodsProvider.future), isEmpty);
    expect(settings.watched, isEmpty);
  });

  test('고정 지출은 지금 가계부의 것을 읽고, 가계부가 없으면 구독하지 않는다', () async {
    const rent = ExpenseTemplate(
      id: 'rent',
      title: '관리비',
      categoryId: 'c1',
      paymentMethodId: 'p1',
      memberId: 'owner',
      dueDay: lastDueDay,
    );
    final templates = FakeTemplatesRepository(const [rent]);
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: me),
      ledgers: FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]),
      templates: templates,
    );
    await loadSignedInUser(container);
    container.listen(templatesProvider, (_, _) {});

    expect(await container.read(templatesProvider.future), isEmpty);
    expect(templates.watched, isEmpty);

    await container.read(myLedgersProvider.future);
    await pumpEventQueue();

    expect(container.read(templatesProvider).value, [rent]);
    expect(templates.watched, ['l1']);
  });

  group('내 역할과 항목 탭의 종류', () {
    const shared = Ledger(
      id: 'l1',
      name: '우리 가계부',
      ownerUid: 'partner',
      roles: {'me': MemberRole.viewer},
    );

    Future<ProviderContainer> signedInWith(List<Ledger> ledgers) async {
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository(ledgers),
      );
      await loadSignedInUser(container);
      container.listen(myRoleProvider, (_, _) {});
      await container.read(myLedgersProvider.future);
      return container;
    }

    test('내 역할은 지금 가계부에서의 역할이다', () async {
      final owner = await signedInWith([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]);
      final viewer = await signedInWith([shared]);

      expect(owner.read(myRoleProvider), MemberRole.owner);
      expect(viewer.read(myRoleProvider), MemberRole.viewer);
    });

    test('가계부가 없거나 로그아웃 상태면 역할이 없다', () async {
      final noLedger = await signedInWith(const []);
      final signedOut = createContainer();
      signedOut.listen(myRoleProvider, (_, _) {});

      expect(noLedger.read(myRoleProvider), isNull);
      expect(signedOut.read(myRoleProvider), isNull);
    });

    test('항목 탭은 기본 월 지출에서 시작하고 고른 종류를 기억한다', () {
      final container = createContainer();

      expect(container.read(selectedEntryKindProvider), EntryKind.planned);
      container
          .read(selectedEntryKindProvider.notifier)
          .select(EntryKind.extra);
      expect(container.read(selectedEntryKindProvider), EntryKind.extra);
    });
  });

  group('보는 달의 항목과 요약', () {
    const ledger = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
    const october = YearMonth(2026, 10);
    const november = YearMonth(2026, 11);
    const octoberLedger = MonthLedger(
      incomes: [
        Income(id: 'i1', memberId: 'owner', title: '월급', amount: 3000000),
      ],
      plannedExpenses: [
        PlannedExpense(
          id: 't1',
          categoryId: 'c-principal',
          memberId: 'partner',
          title: '대출원금',
          paymentMethodId: 'p-account',
          amount: 800000,
        ),
      ],
    );

    Future<ProviderContainer> signedIn(FakeEntriesRepository entries) async {
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([ledger]),
        entries: entries,
      );
      await loadSignedInUser(container);
      container.listen(monthSummaryProvider, (_, _) {});
      await container.read(myLedgersProvider.future);
      return container;
    }

    test('지금 가계부의 보는 달만 구독하고, 달을 옮기면 그 달을 구독한다', () async {
      final entries = FakeEntriesRepository({october: octoberLedger});
      final container = await signedIn(entries);

      expect(await selectedMonthLedger(container), octoberLedger);
      container.read(selectedMonthProvider.notifier).next();
      final next = await selectedMonthLedger(container);

      expect(next.incomes, isEmpty);
      expect(entries.watched, [
        (ledgerId: 'l1', month: october),
        (ledgerId: 'l1', month: november),
      ]);
    });

    test('항목·분류·결제수단으로 요약을 계산한다', () async {
      final container = await signedIn(
        FakeEntriesRepository({october: octoberLedger}),
      );
      await selectedMonthLedger(container);
      await container.read(categoriesProvider.future);
      await container.read(paymentMethodsProvider.future);

      final summary = container.read(monthSummaryProvider).value;

      expect(summary?.totals.cashIn, 3000000);
      // 지급 전 계좌 지출은 현금 유출에 넣지 않고, 저축 분류라 저축에 넣는다.
      expect(summary?.totals.cashOut, 0);
      expect(summary?.totals.saving, 800000);
      expect(summary?.categories.first.amount, 800000);
    });

    test('달을 옮긴 직후에는 이전 달 요약 대신 불러오는 중이다', () async {
      final container = await signedIn(
        FakeEntriesRepository({october: octoberLedger}),
      );
      await selectedMonthLedger(container);
      await container.read(categoriesProvider.future);
      await container.read(paymentMethodsProvider.future);
      expect(container.read(monthSummaryProvider).hasValue, isTrue);

      container.read(selectedMonthProvider.notifier).next();

      expect(container.read(monthSummaryProvider), isA<AsyncLoading<Object>>());
      await selectedMonthLedger(container);
      expect(container.read(monthSummaryProvider).value?.isEmpty, isTrue);
    });

    test('항목을 바꾸면 요약도 바뀐다', () async {
      final entries = FakeEntriesRepository({october: octoberLedger});
      final container = await signedIn(entries);
      await selectedMonthLedger(container);
      await container.read(categoriesProvider.future);
      await container.read(paymentMethodsProvider.future);

      entries.put(october, const MonthLedger());
      await pumpEventQueue();

      expect(container.read(monthSummaryProvider).value?.isEmpty, isTrue);
    });

    test('항목을 읽지 못하면 요약도 실패다', () async {
      final container = await signedIn(
        FakeEntriesRepository()..failNextWatch = true,
      );
      await expectLater(selectedMonthLedger(container), throwsStateError);

      expect(container.read(monthSummaryProvider).hasError, isTrue);
    });

    test('가계부가 없으면 항목을 구독하지 않고 빈 달이다', () async {
      final entries = FakeEntriesRepository({october: octoberLedger});
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        entries: entries,
      );
      await loadSignedInUser(container);
      container.listen(monthLedgerProvider, (_, _) {});
      await container.read(myLedgersProvider.future);

      final month = await selectedMonthLedger(container);

      expect(month.incomes, isEmpty);
      expect(entries.watched, isEmpty);
    });
  });

  group('공휴일', () {
    Future<Holidays> holidaysOf(ProviderContainer container, int year) async {
      final subscription = container.listen(
        holidaysOfYearProvider(year).future,
        (_, _) {},
      );
      try {
        return await subscription.read();
      } finally {
        subscription.close();
      }
    }

    test('로그인했으면 그해 공휴일 문서를 구독한다', () async {
      final holidays = FakeHolidaysRepository({
        2026: const Holidays({'2026-10-03': '개천절'}),
      });
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: me),
        holidays: holidays,
      );
      await loadSignedInUser(container);

      final year = await holidaysOf(container, 2026);

      expect(year.nameOf(DateTime(2026, 10, 3)), '개천절');
      expect(holidays.watched, [2026]);
    });

    test('로그인하지 않았으면 구독하지 않고 빈 해다', () async {
      final holidays = FakeHolidaysRepository({
        2026: const Holidays({'2026-10-03': '개천절'}),
      });
      final container = createContainer(holidays: holidays);
      await loadSignedInUser(container);

      expect(await holidaysOf(container, 2026), const Holidays());
      expect(holidays.watched, isEmpty);
    });
  });
}
