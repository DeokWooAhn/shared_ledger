import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/repository/auth_repository.dart';
import 'package:shared_ledger/domain/repository/settings_repository.dart';
import 'package:shared_ledger/domain/usecase/auth/auth_use_cases.dart';

import '../../../../testing/fakes.dart';

const me = AuthUser(uid: 'me');

void main() {
  test('로그인 상태를 지켜보다가 로그아웃하면 null을 받는다', () async {
    final auth = FakeAuthRepository(signedIn: me);
    final useCases = AuthUseCases(auth, FakeLedgerRepository());
    final users = <AuthUser?>[];
    final subscription = useCases.watchAuthUser().listen(users.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await useCases.signOut();
    await pumpEventQueue();

    expect(users, [me, null]);
    expect(auth.signOutCalls, 1);
  });

  test('Google·Apple로 로그인하면 true이고, 로그인 창을 닫으면 false다', () async {
    final auth = FakeAuthRepository();
    final useCases = AuthUseCases(auth, FakeLedgerRepository());

    expect(await useCases.signInWithGoogle(), isTrue);
    auth.cancelNextSignIn = true;
    expect(await useCases.signInWithApple(), isFalse);

    expect((auth.googleCalls, auth.appleCalls), (1, 1));
  });

  test('로그인 오류는 그대로 던진다(취소와 다르다)', () async {
    final useCases = AuthUseCases(
      FakeAuthRepository()..failNextSignIn = true,
      FakeLedgerRepository(),
    );

    await expectLater(useCases.signInWithGoogle(), throwsA(isA<FakeFailure>()));
  });

  group('탈퇴', () {
    const solo = Ledger(id: 'solo', name: '혼자 가계부', ownerUid: 'me');
    const shared = Ledger(
      id: 'shared',
      name: '같이 가계부',
      ownerUid: 'me',
      roles: {'partner': MemberRole.editor},
    );
    const invited = Ledger(
      id: 'invited',
      name: '들어간 가계부',
      ownerUid: 'partner',
      roles: {'me': MemberRole.viewer},
    );

    test('다시 로그인한 뒤 내 가계부에서 모두 나가고 계정을 지운다', () async {
      final auth = FakeAuthRepository(signedIn: me);
      final ledgers = FakeLedgerRepository([solo, shared, invited]);
      final useCases = AuthUseCases(auth, ledgers);

      final deleted = await useCases.deleteAccount(
        uid: 'me',
        ledgerIds: ['solo', 'shared', 'invited'],
      );

      expect(deleted, isTrue);
      expect((auth.reauthCalls, auth.deleteCalls), (1, 1));
      expect(ledgers.leaves.map((l) => l.ledgerId), [
        'solo',
        'shared',
        'invited',
      ]);
      // 혼자 쓰던 가계부는 없어지고, 같이 쓰던 가계부는 상대가 관리자로 이어 쓴다.
      final left = await ledgers.watchMyLedgers('partner').first;
      expect(left.map((l) => (l.id, l.ownerUid)), [
        ('shared', 'partner'),
        ('invited', 'partner'),
      ]);
      expect(await ledgers.watchMyLedgers('me').first, isEmpty);
      expect(await useCases.watchAuthUser().first, isNull);
    });

    test('다시 로그인을 취소하면 가계부에서 나가지도, 계정을 지우지도 않는다', () async {
      final auth = FakeAuthRepository(signedIn: me)..cancelNextReauth = true;
      final ledgers = FakeLedgerRepository([shared]);

      final deleted = await AuthUseCases(
        auth,
        ledgers,
      ).deleteAccount(uid: 'me', ledgerIds: ['shared']);

      expect(deleted, isFalse);
      expect(ledgers.leaves, isEmpty);
      expect(auth.deleteCalls, 0);
    });

    test('다른 계정으로 다시 로그인하면 아무것도 바꾸지 않고 실패한다', () async {
      final auth = FakeAuthRepository(signedIn: me)
        ..wrongAccountOnReauth = true;
      final ledgers = FakeLedgerRepository([shared]);

      await expectLater(
        AuthUseCases(
          auth,
          ledgers,
        ).deleteAccount(uid: 'me', ledgerIds: ['shared']),
        throwsA(
          isA<AccountDeletionException>().having(
            (e) => e.reason,
            'reason',
            AccountDeletionFailure.wrongAccount,
          ),
        ),
      );
      expect(ledgers.leaves, isEmpty);
      expect(auth.deleteCalls, 0);
    });

    test('그사이 이미 나간 가계부는 건너뛰고 탈퇴한다', () async {
      final auth = FakeAuthRepository(signedIn: me);
      final ledgers = FakeLedgerRepository([solo]);

      final deleted = await AuthUseCases(
        auth,
        ledgers,
      ).deleteAccount(uid: 'me', ledgerIds: ['gone', 'solo']);

      expect(deleted, isTrue);
      expect(ledgers.leaves.map((l) => l.ledgerId), ['solo']);
      expect(auth.deleteCalls, 1);
    });

    test('연결이 없어 나가지 못하면 계정을 지우지 않는다', () async {
      final auth = FakeAuthRepository(signedIn: me);
      final ledgers = FakeLedgerRepository([shared])..offline = true;

      await expectLater(
        AuthUseCases(
          auth,
          ledgers,
        ).deleteAccount(uid: 'me', ledgerIds: ['shared']),
        throwsA(
          isA<SettingsWriteException>().having(
            (e) => e.reason,
            'reason',
            SettingsWriteFailure.offline,
          ),
        ),
      );
      expect(auth.deleteCalls, 0);
      expect(await auth.authStateChanges().first, me);
    });
  });
}
