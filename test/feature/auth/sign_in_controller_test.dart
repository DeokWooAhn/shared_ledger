import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/feature/auth/sign_in_controller.dart';

import '../../support/fakes.dart';
import '../../support/provider_container.dart';

void main() {
  test('Google로 로그인하면 진행 중을 거쳐 끝나고, 실패 표시는 없다', () async {
    final auth = FakeAuthRepository();
    final container = createContainer(auth: auth);
    final states = recordStates(container, signInControllerProvider);

    await container
        .read(signInControllerProvider.notifier)
        .signIn(SignInMethod.google);

    expect(auth.googleCalls, 1);
    expect(states, [
      const SignInState(pending: SignInMethod.google),
      const SignInState(),
    ]);
  });

  test('Apple을 고르면 Apple로 로그인한다', () async {
    final auth = FakeAuthRepository();
    final container = createContainer(auth: auth);
    recordStates(container, signInControllerProvider);

    await container
        .read(signInControllerProvider.notifier)
        .signIn(SignInMethod.apple);

    expect(auth.appleCalls, 1);
    expect(auth.googleCalls, 0);
  });

  test('로그인 창을 닫으면(취소) 실패로 알리지 않는다', () async {
    final container = createContainer(
      auth: FakeAuthRepository()..cancelNextSignIn = true,
    );
    recordStates(container, signInControllerProvider);

    await container
        .read(signInControllerProvider.notifier)
        .signIn(SignInMethod.google);

    expect(container.read(signInControllerProvider), const SignInState());
  });

  test('로그인에 실패하면 실패를 켜고, 화면이 알린 뒤 끈다', () async {
    final container = createContainer(
      auth: FakeAuthRepository()..failNextSignIn = true,
    );
    recordStates(container, signInControllerProvider);
    final controller = container.read(signInControllerProvider.notifier);

    await controller.signIn(SignInMethod.google);
    expect(
      container.read(signInControllerProvider),
      const SignInState(failed: true),
    );

    controller.failureShown();
    expect(container.read(signInControllerProvider), const SignInState());
  });

  test('진행 중에 다시 누르면 무시한다', () async {
    final auth = FakeAuthRepository();
    final container = createContainer(auth: auth);
    recordStates(container, signInControllerProvider);
    final controller = container.read(signInControllerProvider.notifier);

    await Future.wait([
      controller.signIn(SignInMethod.google),
      controller.signIn(SignInMethod.google),
    ]);

    expect(auth.googleCalls, 1);
  });
}
