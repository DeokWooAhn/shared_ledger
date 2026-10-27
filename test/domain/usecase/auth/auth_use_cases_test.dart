import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/usecase/auth/auth_use_cases.dart';

import '../../../../testing/fakes.dart';

const me = AuthUser(uid: 'me');

void main() {
  test('로그인 상태를 지켜보다가 로그아웃하면 null을 받는다', () async {
    final auth = FakeAuthRepository(signedIn: me);
    final useCases = AuthUseCases(auth);
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
    final useCases = AuthUseCases(auth);

    expect(await useCases.signInWithGoogle(), isTrue);
    auth.cancelNextSignIn = true;
    expect(await useCases.signInWithApple(), isFalse);

    expect((auth.googleCalls, auth.appleCalls), (1, 1));
  });

  test('로그인 오류는 그대로 던진다(취소와 다르다)', () async {
    final useCases = AuthUseCases(FakeAuthRepository()..failNextSignIn = true);

    await expectLater(useCases.signInWithGoogle(), throwsStateError);
  });
}
