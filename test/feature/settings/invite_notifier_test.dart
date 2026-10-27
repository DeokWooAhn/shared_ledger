import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/feature/settings/invite_notifier.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

void main() {
  test('처음에는 편집자로 초대하고, 고른 역할로 코드를 만든다', () async {
    final ledgers = FakeLedgerRepository();
    final container = createContainer(ledgers: ledgers);
    final states = recordStates(container, inviteNotifierProvider);
    final notifier = container.read(inviteNotifierProvider.notifier);
    expect(container.read(inviteNotifierProvider).role, MemberRole.editor);

    notifier.selectRole(MemberRole.viewer);
    await notifier.create(ledgerId: 'l1', createdBy: 'me');

    expect(ledgers.invites, [
      (ledgerId: 'l1', role: MemberRole.viewer, createdBy: 'me'),
    ]);
    expect(states.map((s) => s.pending), [false, true, false]);
    expect(container.read(inviteNotifierProvider).invite?.code, 'TESTCODE1A');
  });

  test('만들기에 실패하면 시트 안에 보여줄 실패를 켜고 역할은 그대로 둔다', () async {
    final container = createContainer(
      ledgers: FakeLedgerRepository()..failNextInvite = true,
    );
    recordStates(container, inviteNotifierProvider);
    final notifier = container.read(inviteNotifierProvider.notifier);

    notifier.selectRole(MemberRole.viewer);
    await notifier.create(ledgerId: 'l1', createdBy: 'me');

    expect(
      container.read(inviteNotifierProvider),
      const InviteState(role: MemberRole.viewer, failed: true),
    );
  });

  test('코드를 만든 뒤에는 역할을 바꾸거나 다시 만들지 않는다', () async {
    final ledgers = FakeLedgerRepository();
    final container = createContainer(ledgers: ledgers);
    recordStates(container, inviteNotifierProvider);
    final notifier = container.read(inviteNotifierProvider.notifier);

    await notifier.create(ledgerId: 'l1', createdBy: 'me');
    notifier.selectRole(MemberRole.viewer);
    await notifier.create(ledgerId: 'l1', createdBy: 'me');

    expect(ledgers.invites, hasLength(1));
    expect(container.read(inviteNotifierProvider).role, MemberRole.editor);
  });
}
