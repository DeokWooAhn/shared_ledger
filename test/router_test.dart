import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
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
      expect(redirectFor(AppGate.ready, Routes.startCreate), Routes.home);
      expect(redirectFor(AppGate.ready, Routes.startJoin), Routes.home);
      expect(redirectFor(AppGate.ready, Routes.home), isNull);
      expect(redirectFor(AppGate.ready, Routes.months), isNull);
      expect(redirectFor(AppGate.ready, Routes.settings), isNull);
      expect(redirectFor(AppGate.ready, Routes.categories), isNull);
    });

    test('가계부가 없으면 시작 화면과 그 아래의 만들기·입장 화면에 머문다', () {
      expect(redirectFor(AppGate.noLedger, Routes.start), isNull);
      expect(redirectFor(AppGate.noLedger, Routes.startCreate), isNull);
      expect(redirectFor(AppGate.noLedger, Routes.startJoin), isNull);
      expect(redirectFor(AppGate.noLedger, Routes.months), Routes.start);
      expect(redirectFor(AppGate.signedOut, Routes.startJoin), Routes.signIn);
    });

    test('탭 화면에 있다가 로그아웃하면 로그인 화면으로 옮긴다', () {
      expect(redirectFor(AppGate.signedOut, Routes.settings), Routes.signIn);
      expect(
        redirectFor(AppGate.signedOut, Routes.paymentMethods),
        Routes.signIn,
      );
      expect(redirectFor(AppGate.noLedger, Routes.entries), Routes.start);
    });
  });

  group('탭 경로', () {
    test('설정 탭의 목록 화면은 설정 탭 경로 아래에 있다', () {
      expect(Routes.categories, '${Routes.settings}/categories');
      expect(Routes.paymentMethods, '${Routes.settings}/payment-methods');
    });

    test('탭마다 경로가 하나씩 있고, 홈은 요약 탭이다', () {
      final paths = [for (final tab in HomeTab.values) Routes.of(tab)];
      expect(paths.toSet(), hasLength(HomeTab.values.length));
      expect(Routes.of(HomeTab.summary), Routes.home);
    });
  });
}
