import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/router.dart';

void main() {
  const me = AuthUser(uid: 'me');
  const ledger = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');

  group('appGate', () {
    test('로그인 상태를 모르면 불러오는 중이다', () {
      expect(
        appGate(user: const AsyncLoading(), ledgers: const AsyncData([])),
        AppGate.loading,
      );
    });

    test('로그아웃 상태면 로그인 단계다', () {
      expect(
        appGate(user: const AsyncData(null), ledgers: const AsyncData([])),
        AppGate.signedOut,
      );
    });

    test('로그인했지만 가계부 목록을 아직 모르면 불러오는 중이다', () {
      expect(
        appGate(user: const AsyncData(me), ledgers: const AsyncLoading()),
        AppGate.loading,
      );
    });

    test('가계부 목록을 불러오지 못하면 실패 단계다', () {
      expect(
        appGate(
          user: const AsyncData(me),
          ledgers: AsyncError<List<Ledger>>('denied', StackTrace.empty),
        ),
        AppGate.failed,
      );
    });

    test('가계부가 없으면 가계부 시작, 있으면 준비 완료다', () {
      expect(
        appGate(user: const AsyncData(me), ledgers: const AsyncData([])),
        AppGate.noLedger,
      );
      expect(
        appGate(user: const AsyncData(me), ledgers: const AsyncData([ledger])),
        AppGate.ready,
      );
    });
  });

  group('redirectFor', () {
    test('단계에 맞는 화면으로 옮기고, 이미 그 화면이면 그대로 둔다', () {
      expect(redirectFor(AppGate.signedOut, Routes.home), Routes.signIn);
      expect(redirectFor(AppGate.signedOut, Routes.signIn), isNull);
      expect(redirectFor(AppGate.noLedger, Routes.signIn), Routes.start);
      expect(redirectFor(AppGate.failed, Routes.home), Routes.loading);
    });

    test('준비가 끝나면 시작 화면들에서 홈으로 옮기고, 다른 화면은 그대로 둔다', () {
      expect(redirectFor(AppGate.ready, Routes.signIn), Routes.home);
      expect(redirectFor(AppGate.ready, Routes.start), Routes.home);
      expect(redirectFor(AppGate.ready, Routes.home), isNull);
    });
  });
}
