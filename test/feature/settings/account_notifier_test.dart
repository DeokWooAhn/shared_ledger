import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/feature/settings/account_notifier.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const solo = Ledger(id: 'solo', name: '혼자 가계부', ownerUid: 'me');
const invited = Ledger(
  id: 'invited',
  name: '들어간 가계부',
  ownerUid: 'partner',
  roles: {'me': MemberRole.editor},
);

/// 로그인하고 가계부 목록까지 받은 컨테이너.
Future<ProviderContainer> ready(
  FakeAuthRepository auth,
  FakeLedgerRepository ledgers,
) async {
  final container = createContainer(auth: auth, ledgers: ledgers);
  await loadSignedInUser(container);
  container
    ..listen(myLedgersProvider, (_, _) {})
    ..listen(deletingAccountProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  return container;
}

void main() {
  test('다시 로그인한 뒤 내 가계부에서 모두 나가고 계정을 지운다', () async {
    final auth = FakeAuthRepository(signedIn: me);
    final ledgers = FakeLedgerRepository([solo, invited]);
    final container = await ready(auth, ledgers);
    final states = recordStates(container, accountNotifierProvider);

    final deleted = await container
        .read(accountNotifierProvider.notifier)
        .deleteAccount();

    expect(deleted, isTrue);
    expect(ledgers.leaves.map((l) => l.ledgerId), ['solo', 'invited']);
    expect(auth.deleteCalls, 1);
    expect(states.first, const AccountState(deleting: true));
    await pumpEventQueue();
    expect(container.read(authUserProvider).value, isNull);
    expect(container.read(deletingAccountProvider), isFalse);
  });

  test('탈퇴하는 동안 탈퇴 중 표시를 켜 두고 끝나면 끈다', () async {
    final auth = FakeAuthRepository(signedIn: me);
    final hold = Completer<void>();
    auth
      ..holdDelete = hold.future
      ..failNextDelete = true;
    final container = await ready(auth, FakeLedgerRepository([solo]));
    recordStates(container, accountNotifierProvider);

    final deleting = container
        .read(accountNotifierProvider.notifier)
        .deleteAccount();
    await pumpEventQueue();
    // 가계부에서는 나갔지만 계정을 지우기 전이다.
    expect(container.read(myLedgersProvider).value, isEmpty);
    expect(container.read(deletingAccountProvider), isTrue);

    hold.complete();
    expect(await deleting, isFalse);
    expect(
      container.read(accountNotifierProvider).failure,
      AccountFailure.failed,
    );
    expect(container.read(deletingAccountProvider), isFalse);
  });

  test('다시 로그인을 취소하면 아무것도 바꾸지 않고 실패로 알리지도 않는다', () async {
    final auth = FakeAuthRepository(signedIn: me)..cancelNextReauth = true;
    final ledgers = FakeLedgerRepository([solo]);
    final container = await ready(auth, ledgers);
    recordStates(container, accountNotifierProvider);

    expect(
      await container.read(accountNotifierProvider.notifier).deleteAccount(),
      isFalse,
    );

    expect(ledgers.leaves, isEmpty);
    expect(auth.deleteCalls, 0);
    expect(container.read(accountNotifierProvider), const AccountState());
    expect(container.read(deletingAccountProvider), isFalse);
  });

  test('다른 계정으로 다시 로그인하면 그렇게 알린다', () async {
    final auth = FakeAuthRepository(signedIn: me)..wrongAccountOnReauth = true;
    final container = await ready(auth, FakeLedgerRepository([solo]));
    final notifier = container.read(accountNotifierProvider.notifier);
    recordStates(container, accountNotifierProvider);

    expect(await notifier.deleteAccount(), isFalse);

    expect(
      container.read(accountNotifierProvider).failure,
      AccountFailure.wrongAccount,
    );
    notifier.failureShown();
    expect(container.read(accountNotifierProvider), const AccountState());
  });

  test('연결이 없어 가계부에서 나가지 못하면 계정을 지우지 않고 알린다', () async {
    final auth = FakeAuthRepository(signedIn: me);
    final container = await ready(
      auth,
      FakeLedgerRepository([invited])..offline = true,
    );
    recordStates(container, accountNotifierProvider);

    expect(
      await container.read(accountNotifierProvider.notifier).deleteAccount(),
      isFalse,
    );

    expect(
      container.read(accountNotifierProvider).failure,
      AccountFailure.offline,
    );
    expect(auth.deleteCalls, 0);
  });
}
