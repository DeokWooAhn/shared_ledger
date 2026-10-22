import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
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

      expect(await container.read(monthLedgerProvider.future), octoberLedger);
      container.read(selectedMonthProvider.notifier).next();
      final next = await container.read(monthLedgerProvider.future);

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
      await container.read(monthLedgerProvider.future);
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
      await container.read(monthLedgerProvider.future);
      await container.read(categoriesProvider.future);
      await container.read(paymentMethodsProvider.future);
      expect(container.read(monthSummaryProvider).hasValue, isTrue);

      container.read(selectedMonthProvider.notifier).next();

      expect(container.read(monthSummaryProvider), isA<AsyncLoading<Object>>());
      await container.read(monthLedgerProvider.future);
      expect(container.read(monthSummaryProvider).value?.isEmpty, isTrue);
    });

    test('항목을 바꾸면 요약도 바뀐다', () async {
      final entries = FakeEntriesRepository({october: octoberLedger});
      final container = await signedIn(entries);
      await container.read(monthLedgerProvider.future);
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
      await expectLater(
        container.read(monthLedgerProvider.future),
        throwsStateError,
      );

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

      final month = await container.read(monthLedgerProvider.future);

      expect(month.incomes, isEmpty);
      expect(entries.watched, isEmpty);
    });
  });
}
