import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/activity.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/trashed_entry.dart';
import 'package:shared_ledger/core/model/year_month.dart';
import 'package:shared_ledger/feature/settings/trash_controller.dart';

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

// 고정 지출에서 만든 이번 달 기본 월 지출. 지우면 다시 만들어져서 휴지통에 남긴다.
final rent = PlannedExpense(
  id: 'tpl-rent',
  categoryId: 'c1',
  memberId: 'owner',
  title: '월세',
  paymentMethodId: 'p1',
  amount: 500000,
  dueOn: DateTime(2026, 10, 25),
);

void main() {
  /// [entries]를 휴지통에 넣어 둔 가짜 저장소와 컨테이너.
  Future<(ProviderContainer, FakeEntriesRepository, FakeActivityRepository)>
  trashed(List<LedgerEntry> entries) async {
    final repository = FakeEntriesRepository({
      october: MonthLedger(
        trashed: [
          for (final entry in entries)
            TrashedEntry(entry: entry, deletedAt: DateTime(2026, 10, 14)),
        ],
      ),
    });
    final activity = FakeActivityRepository();
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: const AuthUser(uid: 'me')),
      ledgers: FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]),
      entries: repository,
      activity: activity,
    );
    await loadSignedInUser(container);
    container.listen(myLedgersProvider, (_, _) {});
    await container.read(myLedgersProvider.future);
    return (container, repository, activity);
  }

  test('되살리면 그달 목록에 다시 들어오고, 변경 기록을 남기고, 되살렸다고 알린다', () async {
    final (container, entries, activity) = await trashed([snack]);
    final states = recordStates(container, trashControllerProvider);

    await container
        .read(trashControllerProvider.notifier)
        .restore(snack, october);

    expect(entries.restored, [
      (ledgerId: 'l1', month: october, kind: EntryKind.extra, id: 'x1'),
    ]);
    expect(entries.monthOf(october).extraExpenses, [snack]);
    expect(entries.monthOf(october).trashed, isEmpty);
    expect(activity.logged, [
      const ActivityDraft(ActivityAction.entryRestore, "10월 추가지출 '간식' 5,000원"),
    ]);
    expect(states, [
      const TrashState(pending: (action: TrashAction.restore, id: 'x1')),
      const TrashState(notice: TrashNotice.restored),
    ]);
  });

  test('완전히 지우면 휴지통에서 빠지고, 변경 기록을 남긴다', () async {
    final (container, entries, activity) = await trashed([snack]);
    recordStates(container, trashControllerProvider);
    final controller = container.read(trashControllerProvider.notifier);

    await controller.purge(snack, october);

    expect(entries.purged.single.id, 'x1');
    expect(entries.monthOf(october).trashed, isEmpty);
    expect(entries.monthOf(october).extraExpenses, isEmpty);
    expect(activity.logged.single.action, ActivityAction.entryPurge);
    expect(container.read(trashControllerProvider).notice, TrashNotice.purged);

    controller.noticeShown();
    expect(container.read(trashControllerProvider), const TrashState());
  });

  test('고정 지출에서 만든 이번 달 기본 월 지출은 완전히 지우지 않는다', () async {
    final (container, entries, activity) = await trashed([rent]);
    final states = recordStates(container, trashControllerProvider);

    await container.read(trashControllerProvider.notifier).purge(rent, october);

    expect(entries.purged, isEmpty);
    expect(entries.monthOf(october).trashed.single.entry, rent);
    expect(activity.logged, isEmpty);
    expect(states, isEmpty);
  });

  test('지난 달의 고정 지출 항목은 다시 만들지 않아서 완전히 지운다', () async {
    final (container, entries, _) = await trashed([]);
    final september = october.previous;
    entries.put(september, MonthLedger(trashed: [TrashedEntry(entry: rent)]));
    recordStates(container, trashControllerProvider);

    await container
        .read(trashControllerProvider.notifier)
        .purge(rent, september);

    expect(entries.purged.single.month, september);
    expect(entries.monthOf(september).plannedIds, isEmpty);
  });

  test('연결이 없으면 되살리지 못했다고 알리고 휴지통에 그대로 두고, 알린 뒤 끈다', () async {
    final (container, entries, activity) = await trashed([snack]);
    entries.offline = true;
    recordStates(container, trashControllerProvider);
    final controller = container.read(trashControllerProvider.notifier);

    await controller.restore(snack, october);

    expect(
      container.read(trashControllerProvider).failure,
      TrashFailure.offline,
    );
    expect(entries.monthOf(october).trashed.single.entry, snack);
    expect(activity.logged, isEmpty);

    controller.failureShown();
    expect(container.read(trashControllerProvider), const TrashState());
  });

  test('그사이 상대가 되살렸거나 지웠으면 없어졌다고 알린다', () async {
    final (container, entries, _) = await trashed([snack]);
    entries.put(october, const MonthLedger(extraExpenses: [snack]));
    recordStates(container, trashControllerProvider);

    await container
        .read(trashControllerProvider.notifier)
        .purge(snack, october);

    expect(container.read(trashControllerProvider).failure, TrashFailure.gone);
    expect(entries.monthOf(october).extraExpenses, [snack]);
  });

  test('예상 못 한 오류는 동작마다 다른 실패로 알린다', () async {
    final (container, entries, _) = await trashed([snack]);
    recordStates(container, trashControllerProvider);
    final controller = container.read(trashControllerProvider.notifier);

    entries.failNextWrite = true;
    await controller.restore(snack, october);
    expect(
      container.read(trashControllerProvider).failure,
      TrashFailure.restore,
    );

    controller.failureShown();
    entries.failNextWrite = true;
    await controller.purge(snack, october);
    expect(container.read(trashControllerProvider).failure, TrashFailure.purge);
  });

  test('진행 중에 다시 누르면 무시한다', () async {
    final (container, entries, _) = await trashed([snack]);
    recordStates(container, trashControllerProvider);
    final controller = container.read(trashControllerProvider.notifier);

    await Future.wait([
      controller.restore(snack, october),
      controller.purge(snack, october),
    ]);

    expect(entries.restored, hasLength(1));
    expect(entries.purged, isEmpty);
  });
}
