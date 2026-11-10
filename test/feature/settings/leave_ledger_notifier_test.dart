import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/activity.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/member.dart';
import 'package:shared_ledger/feature/settings/leave_ledger_notifier.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const shared = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'me',
  roles: {'partner': MemberRole.editor},
);

/// 로그인하고 가계부 목록까지 받은 컨테이너.
Future<ProviderContainer> ready(
  FakeLedgerRepository ledgers, {
  FakeActivityRepository? activity,
}) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: ledgers,
    activity: activity,
  );
  await loadSignedInUser(container);
  container.listen(myLedgersProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  return container;
}

void main() {
  test('관리자가 나가면 상대에게 관리자를 넘기고, 내 가계부 목록에서 빠지며, 변경 기록을 남긴다', () async {
    final ledgers = FakeLedgerRepository([shared]);
    final activity = FakeActivityRepository();
    final container = await ready(ledgers, activity: activity);
    final states = recordStates(container, leaveLedgerNotifierProvider);

    final outcome = await container
        .read(leaveLedgerNotifierProvider.notifier)
        .leave();

    expect(outcome, LeaveOutcome.handsOver);
    expect(ledgers.leaves, [(ledgerId: 'l1', uid: 'me')]);
    expect(states, [
      const LeaveLedgerState(leaving: true),
      const LeaveLedgerState(),
    ]);
    await pumpEventQueue();
    expect(container.read(currentLedgerProvider), isNull);
    final [handedOver] = await ledgers.watchMyLedgers('partner').first;
    expect(handedOver.roleOf('partner'), MemberRole.owner);
    expect(handedOver.ownerSlot, MemberSlot.partner);
    final [log] = activity.activities;
    expect((log.actorUid, log.action), ('me', ActivityAction.ledgerLeave));
  });

  test('보기 전용은 나가도 변경 기록을 남기지 않는다(규칙상 남길 수 없다)', () async {
    final ledgers = FakeLedgerRepository([
      const Ledger(
        id: 'l1',
        name: '우리 가계부',
        ownerUid: 'partner',
        roles: {'me': MemberRole.viewer},
      ),
    ]);
    final activity = FakeActivityRepository();
    final container = await ready(ledgers, activity: activity);

    final outcome = await container
        .read(leaveLedgerNotifierProvider.notifier)
        .leave();

    expect(outcome, LeaveOutcome.memberLeaves);
    expect(activity.activities, isEmpty);
  });

  test('연결이 없으면 나가지 않고 실패를 알린다', () async {
    final ledgers = FakeLedgerRepository([shared])..offline = true;
    final container = await ready(ledgers);
    final notifier = container.read(leaveLedgerNotifierProvider.notifier);
    recordStates(container, leaveLedgerNotifierProvider);

    expect(await notifier.leave(), isNull);

    expect(
      container.read(leaveLedgerNotifierProvider).failure,
      LeaveLedgerFailure.offline,
    );
    expect(ledgers.leaves, isEmpty);
    notifier.failureShown();
    expect(
      container.read(leaveLedgerNotifierProvider),
      const LeaveLedgerState(),
    );
  });

  test('예상하지 못한 오류면 실패를 알린다', () async {
    final ledgers = FakeLedgerRepository([shared])..failNextLeave = true;
    final container = await ready(ledgers);
    recordStates(container, leaveLedgerNotifierProvider);

    expect(
      await container.read(leaveLedgerNotifierProvider.notifier).leave(),
      isNull,
    );

    expect(
      container.read(leaveLedgerNotifierProvider).failure,
      LeaveLedgerFailure.failed,
    );
  });

  test('그사이 이미 나갔으면 실패로 알리지 않는다', () async {
    final ledgers = FakeLedgerRepository([shared]);
    final container = await ready(ledgers);
    recordStates(container, leaveLedgerNotifierProvider);
    // 다른 기기에서 먼저 나갔지만 이 기기의 목록은 아직 바뀌기 전이다.
    await ledgers.leave(ledgerId: 'l1', uid: 'me');

    expect(
      await container.read(leaveLedgerNotifierProvider.notifier).leave(),
      isNull,
    );

    expect(
      container.read(leaveLedgerNotifierProvider),
      const LeaveLedgerState(),
    );
  });
}
