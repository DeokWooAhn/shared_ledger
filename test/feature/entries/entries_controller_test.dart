import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/expense_template.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/year_month.dart';
import 'package:shared_ledger/feature/entries/entries_controller.dart';

import '../../support/fakes.dart';
import '../../support/provider_container.dart';

const october = YearMonth(2026, 10);
const snack = ExtraExpense(
  id: 'x1',
  memberId: 'owner',
  title: '간식',
  paymentMethodId: 'p1',
  amount: 5000,
);

void main() {
  /// 간식 한 건을 휴지통에 넣어 둔 가짜 저장소와 컨테이너.
  Future<(ProviderContainer, FakeEntriesRepository)> trashedSnack() async {
    final entries = FakeEntriesRepository({
      october: const MonthLedger(extraExpenses: [snack]),
    });
    await entries.trash(
      ledgerId: 'l1',
      month: october,
      kind: EntryKind.extra,
      id: 'x1',
      uid: 'me',
    );
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: const AuthUser(uid: 'me')),
      ledgers: FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]),
      entries: entries,
    );
    await loadSignedInUser(container);
    container.listen(myLedgersProvider, (_, _) {});
    await container.read(myLedgersProvider.future);
    return (container, entries);
  }

  test('휴지통에 넣은 항목을 되돌리면 다시 목록에 들어온다', () async {
    final (container, entries) = await trashedSnack();
    final states = recordStates(container, entriesControllerProvider);

    await container
        .read(entriesControllerProvider.notifier)
        .restore(snack, october);

    expect(entries.restored, [
      (ledgerId: 'l1', month: october, kind: EntryKind.extra, id: 'x1'),
    ]);
    expect(entries.monthOf(october).extraExpenses, [snack]);
    expect(states, [const EntriesState(restoring: true), const EntriesState()]);
  });

  test('연결이 없으면 꺼내지 못했다고 알리고, 알린 뒤 끈다', () async {
    final (container, entries) = await trashedSnack();
    entries.offline = true;
    recordStates(container, entriesControllerProvider);
    final controller = container.read(entriesControllerProvider.notifier);

    await controller.restore(snack, october);
    expect(
      container.read(entriesControllerProvider).failure,
      EntriesFailure.restoreOffline,
    );
    expect(entries.monthOf(october).extraExpenses, isEmpty);

    controller.failureShown();
    expect(container.read(entriesControllerProvider), const EntriesState());
  });

  test('그사이 꺼냈거나 지운 항목이면 알린다', () async {
    final (container, entries) = await trashedSnack();
    await entries.restore(
      ledgerId: 'l1',
      month: october,
      kind: EntryKind.extra,
      id: 'x1',
      uid: 'me',
    );
    recordStates(container, entriesControllerProvider);

    await container
        .read(entriesControllerProvider.notifier)
        .restore(snack, october);

    expect(
      container.read(entriesControllerProvider).failure,
      EntriesFailure.restoreGone,
    );
  });

  group('그달 가계부 만들기', () {
    const rent = ExpenseTemplate(
      id: 'rent',
      title: '관리비',
      categoryId: 'c-spending',
      paymentMethodId: 'p-account',
      memberId: 'partner',
      dueDay: 25,
    );
    const september = YearMonth(2026, 9);

    Future<(ProviderContainer, FakeEntriesRepository)> ready({
      List<ExpenseTemplate> templates = const [rent],
    }) async {
      final entries = FakeEntriesRepository();
      final container = createContainer(
        auth: FakeAuthRepository(signedIn: const AuthUser(uid: 'me')),
        ledgers: FakeLedgerRepository([
          Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me', months: {october}),
        ]),
        entries: entries,
        templates: FakeTemplatesRepository(templates),
      );
      await loadSignedInUser(container);
      container.listen(myLedgersProvider, (_, _) {});
      await container.read(myLedgersProvider.future);
      return (container, entries);
    }

    test('고정 지출로 그달 기본 월 지출을 채우고 그달을 달 목록에 더한다', () async {
      final (container, entries) = await ready();
      final states = recordStates(container, entriesControllerProvider);

      final added = await container
          .read(entriesControllerProvider.notifier)
          .addMonth(september);
      await pumpEventQueue();

      expect(added, isTrue);
      expect(states, [
        const EntriesState(addingMonth: true),
        const EntriesState(),
      ]);
      final planned = entries.monthOf(september).plannedExpenses.single;
      expect(planned.id, 'rent');
      expect(planned.dueOn, DateTime(2026, 9, 25));
      expect(planned.isPaid, isFalse);
      expect(container.read(currentLedgerProvider)?.months, {
        september,
        october,
      });
    });

    test('고정 지출이 없어도 그달을 달 목록에 더한다', () async {
      final (container, entries) = await ready(templates: const []);

      final added = await container
          .read(entriesControllerProvider.notifier)
          .addMonth(september);

      expect(added, isTrue);
      expect(entries.monthOf(september).plannedExpenses, isEmpty);
      expect(entries.recordedMonths, [september]);
    });

    test('연결이 없으면 만들지 않고 알릴 실패를 켠다', () async {
      final (container, entries) = await ready();
      entries.offline = true;
      recordStates(container, entriesControllerProvider);

      final added = await container
          .read(entriesControllerProvider.notifier)
          .addMonth(september);

      expect(added, isFalse);
      expect(entries.recordedMonths, isEmpty);
      expect(
        container.read(entriesControllerProvider).failure,
        EntriesFailure.addMonthOffline,
      );
    });
  });
}
