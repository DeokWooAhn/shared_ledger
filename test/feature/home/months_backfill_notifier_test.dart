import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/feature/home/months_backfill_notifier.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');

// 달 목록이 생기기 전에 만든 가계부(months가 null). 2026년 10월에 만들었다.
final legacy = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'me',
  createdAt: DateTime(2026, 10, 1),
);

MonthLedger withExtra(String id) => MonthLedger(
  extraExpenses: [
    ExtraExpense(
      id: id,
      memberId: 'owner',
      title: '간식',
      paymentMethodId: 'p-card',
      amount: 5000,
    ),
  ],
);

/// 로그인하고 가계부 목록까지 받은 컨테이너.
Future<ProviderContainer> ready({
  required FakeLedgerRepository ledgers,
  FakeEntriesRepository? entries,
}) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: ledgers,
    entries: entries,
  );
  await loadSignedInUser(container);
  container.listen(myLedgersProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  return container;
}

void main() {
  group('모을 것(monthsBackfillProvider)', () {
    test('달 목록이 없는 가계부이고 쓸 수 있으면 그 범위를 낸다', () async {
      final container = await ready(ledgers: FakeLedgerRepository([legacy]));

      final backfill = container.read(monthsBackfillProvider);

      expect(backfill?.ledgerId, 'l1');
      expect(backfill?.months.first, const YearMonth(2025, 10));
      expect(backfill?.months.last, const YearMonth(2027, 10));
    });

    test('이미 달 목록이 있거나 보기 전용이면 모으지 않는다', () async {
      final recorded = await ready(
        ledgers: FakeLedgerRepository([
          Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me', months: const {}),
        ]),
      );
      expect(recorded.read(monthsBackfillProvider), isNull);

      final viewing = await ready(
        ledgers: FakeLedgerRepository([
          const Ledger(
            id: 'l1',
            name: '우리 가계부',
            ownerUid: 'partner',
            roles: {'me': MemberRole.viewer},
          ),
        ]),
      );
      expect(viewing.read(monthsBackfillProvider), isNull);
    });
  });

  group('모으기(MonthsBackfillNotifier)', () {
    test('범위 안에서 항목(휴지통 포함)이 있는 달만 찾아 가계부에 한 번 적는다', () async {
      final ledgers = FakeLedgerRepository([legacy]);
      final entries = FakeEntriesRepository({
        const YearMonth(2026, 9): withExtra('snack'),
        const YearMonth(2026, 10): withExtra('lunch'),
        // 범위(2025-10 ~ 2027-10) 밖이라 찾지 않는다.
        const YearMonth(2024, 1): withExtra('old'),
      });
      final container = await ready(ledgers: ledgers, entries: entries);

      // 홈 틀처럼 Notifier를 살려 두면 스스로 듣고 모은다.
      container.listen(monthsBackfillNotifierProvider, (_, _) {});
      await pumpEventQueue();

      expect(ledgers.recordedMonths.single.months, {
        const YearMonth(2026, 9),
        const YearMonth(2026, 10),
      });
      expect(entries.scannedMonths, hasLength(25));
      expect(container.read(currentLedgerProvider)?.months, {
        const YearMonth(2026, 9),
        const YearMonth(2026, 10),
      });
      // 목록이 생겨서 다시 모으지 않는다.
      expect(container.read(monthsBackfillProvider), isNull);
    });

    test('항목이 하나도 없으면 빈 목록을 적어 다시 모으지 않게 한다', () async {
      final ledgers = FakeLedgerRepository([legacy]);
      final container = await ready(ledgers: ledgers);

      container.listen(monthsBackfillNotifierProvider, (_, _) {});
      await pumpEventQueue();

      expect(ledgers.recordedMonths.single.months, isEmpty);
      expect(container.read(currentLedgerProvider)?.months, isEmpty);
    });

    test('오프라인이면 알리지 않고 그만두며, 같은 세션에서는 다시 하지 않는다', () async {
      final ledgers = FakeLedgerRepository([legacy]);
      final entries = FakeEntriesRepository()..offline = true;
      final container = await ready(ledgers: ledgers, entries: entries);
      final states = recordStates(container, monthsBackfillNotifierProvider);
      await pumpEventQueue();

      expect(states, [true, false]);
      expect(ledgers.recordedMonths, isEmpty);

      entries.offline = false;
      await container
          .read(monthsBackfillNotifierProvider.notifier)
          .run(container.read(monthsBackfillProvider)!);
      expect(ledgers.recordedMonths, isEmpty);
    });
  });
}
