import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/activity.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/feature/settings/activity_controller.dart';

import '../../support/fakes.dart';
import '../../support/provider_container.dart';

/// [count]건의 기록. 앞의 것일수록 오래됐다(1분 간격).
List<Activity> history(int count, {String prefix = 'a'}) => [
  for (var i = 0; i < count; i++)
    Activity(
      id: '$prefix${i.toString().padLeft(3, '0')}',
      actorUid: 'me',
      action: ActivityAction.entryCreate,
      summary: '기록 $i',
      at: DateTime(2026, 10, 1).add(Duration(minutes: i)),
    ),
];

void main() {
  Future<(ProviderContainer, FakeActivityRepository)> pumpActivity(
    List<Activity> items,
  ) async {
    final activity = FakeActivityRepository(items);
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: const AuthUser(uid: 'me')),
      ledgers: FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]),
      activity: activity,
    );
    await loadSignedInUser(container);
    container.listen(myLedgersProvider, (_, _) {});
    await container.read(myLedgersProvider.future);
    recordStates(container, activityControllerProvider);
    // 최근 기록 구독이 첫 값을 낼 때까지 기다린다.
    await container.read(recentActivityProvider.future);
    return (container, activity);
  }

  ActivityState stateOf(ProviderContainer container) =>
      container.read(activityControllerProvider);

  group('변경 기록 합치기', () {
    test('같은 id는 새 값으로 바꾸고 새것부터 정렬한다', () {
      final [older, newer] = history(2);
      const pending = Activity(id: 'p1', actorUid: 'me', summary: '올리는 중');
      final merged = mergeActivities(
        [older, pending],
        [
          newer,
          Activity(
            id: 'p1',
            actorUid: 'me',
            summary: '올림',
            at: DateTime(2026, 10, 2),
          ),
        ],
      );

      expect(merged.map((a) => a.id), ['p1', newer.id, older.id]);
      expect(merged.first.summary, '올림');
    });

    test('서버에 닿기 전 기록(시간 없음)이 맨 앞에 온다', () {
      const pending = Activity(id: 'p1', actorUid: 'me', summary: '올리는 중');
      final merged = mergeActivities(history(2), [pending]);

      expect(merged.first, pending);
    });
  });

  test('최근 기록을 새것부터 받고, 꽉 차지 않았으면 더 볼 것이 없다', () async {
    final (container, _) = await pumpActivity(history(3));

    final state = stateOf(container);
    expect(state.load, ActivityLoad.ready);
    expect(state.items.map((a) => a.summary), ['기록 2', '기록 1', '기록 0']);
    expect(state.hasMore, isFalse);
  });

  test('최근 기록이 한 번에 읽는 개수만큼 차면 더 보기로 그보다 먼저 남긴 기록을 붙인다', () async {
    final (container, activity) = await pumpActivity(
      history(activityPageSize + 3),
    );
    expect(stateOf(container).items, hasLength(activityPageSize));
    expect(stateOf(container).hasMore, isTrue);

    await container.read(activityControllerProvider.notifier).loadMore();

    final state = stateOf(container);
    expect(activity.loads.single.before, DateTime(2026, 10, 1, 0, 3));
    expect(state.items, hasLength(activityPageSize + 3));
    expect(state.items.last.summary, '기록 0');
    expect(state.hasMore, isFalse);
    expect(state.loadingMore, isFalse);
  });

  test('더 본 뒤 새 기록이 와도 최근 목록에서 밀려난 기록이 사라지지 않는다', () async {
    final (container, activity) = await pumpActivity(
      history(activityPageSize + 3),
    );
    await container.read(activityControllerProvider.notifier).loadMore();

    activity.log(
      const ActivityDraft(ActivityAction.entryCreate, '새 기록'),
      uid: 'partner-uid',
    );
    await pumpEventQueue();

    final state = stateOf(container);
    expect(state.items.first.summary, '새 기록');
    expect(state.items, hasLength(activityPageSize + 4));
  });

  test('더 보기를 읽지 못하면 알리고, 알린 뒤 끈다', () async {
    final (container, activity) = await pumpActivity(history(activityPageSize));
    activity.failNextLoad = true;
    final controller = container.read(activityControllerProvider.notifier);

    await controller.loadMore();
    expect(stateOf(container).failure, ActivityFailure.loadMore);
    expect(stateOf(container).loadingMore, isFalse);
    expect(stateOf(container).hasMore, isTrue);

    controller.failureShown();
    expect(stateOf(container).failure, isNull);
  });

  test('처음 목록을 받지 못하면 실패로 그린다', () async {
    final activity = FakeActivityRepository()..failNextWatch = true;
    final container = createContainer(
      auth: FakeAuthRepository(signedIn: const AuthUser(uid: 'me')),
      ledgers: FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]),
      activity: activity,
    );
    await loadSignedInUser(container);
    container.listen(myLedgersProvider, (_, _) {});
    await container.read(myLedgersProvider.future);
    recordStates(container, activityControllerProvider);
    await pumpEventQueue();

    expect(stateOf(container).load, ActivityLoad.failed);
  });

  test('진행 중이거나 더 볼 것이 없으면 더 읽지 않는다', () async {
    final (container, activity) = await pumpActivity(history(activityPageSize));
    final controller = container.read(activityControllerProvider.notifier);

    await Future.wait([controller.loadMore(), controller.loadMore()]);
    expect(activity.loads, hasLength(1));

    await controller.loadMore();
    expect(stateOf(container).hasMore, isFalse);
    expect(activity.loads, hasLength(1));
  });
}
