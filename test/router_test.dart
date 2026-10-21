import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/household.dart';
import 'package:shared_ledger/router.dart';

void main() {
  const me = AuthUser(uid: 'me');
  const household = Household(id: 'h1', name: '우리집', ownerUid: 'me');

  group('appGate', () {
    test('로그인 상태를 모르면 불러오는 중이다', () {
      expect(
        appGate(user: const AsyncLoading(), households: const AsyncData([])),
        AppGate.loading,
      );
    });

    test('로그아웃 상태면 로그인 단계다', () {
      expect(
        appGate(user: const AsyncData(null), households: const AsyncData([])),
        AppGate.signedOut,
      );
    });

    test('로그인했지만 가구 목록을 아직 모르면 불러오는 중이다', () {
      expect(
        appGate(user: const AsyncData(me), households: const AsyncLoading()),
        AppGate.loading,
      );
    });

    test('가구 목록을 불러오지 못하면 실패 단계다', () {
      expect(
        appGate(
          user: const AsyncData(me),
          households: AsyncError<List<Household>>('denied', StackTrace.empty),
        ),
        AppGate.failed,
      );
    });

    test('가구가 없으면 가구 만들기, 있으면 준비 완료다', () {
      expect(
        appGate(user: const AsyncData(me), households: const AsyncData([])),
        AppGate.noHousehold,
      );
      expect(
        appGate(
          user: const AsyncData(me),
          households: const AsyncData([household]),
        ),
        AppGate.ready,
      );
    });
  });

  group('redirectFor', () {
    test('단계에 맞는 화면으로 옮기고, 이미 그 화면이면 그대로 둔다', () {
      expect(redirectFor(AppGate.signedOut, Routes.home), Routes.signIn);
      expect(redirectFor(AppGate.signedOut, Routes.signIn), isNull);
      expect(
        redirectFor(AppGate.noHousehold, Routes.signIn),
        Routes.createHousehold,
      );
      expect(redirectFor(AppGate.failed, Routes.home), Routes.loading);
    });

    test('준비가 끝나면 시작 화면들에서 홈으로 옮기고, 다른 화면은 그대로 둔다', () {
      expect(redirectFor(AppGate.ready, Routes.signIn), Routes.home);
      expect(redirectFor(AppGate.ready, Routes.createHousehold), Routes.home);
      expect(redirectFor(AppGate.ready, Routes.home), isNull);
    });
  });
}
