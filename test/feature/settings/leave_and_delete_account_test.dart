import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/ledger/ledger_start_screen.dart';
import 'package:shared_ledger/feature/settings/account_screen.dart';
import 'package:shared_ledger/feature/settings/settings_screen.dart';

import '../../../testing/app.dart';
import '../../../testing/fakes.dart';

const me = AuthUser(uid: 'me', signInMethod: SignInMethod.google);

// 이름표는 가짜 설정 저장소의 기본값(owner 자리 '하늘', partner 자리 '바다')이다.
const shared = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'me',
  roles: {'partner-uid': MemberRole.editor},
);
const solo = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
const asEditor = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'partner-uid',
  roles: {'me': MemberRole.editor},
);

Future<void> pumpSettings(
  WidgetTester tester,
  FakeLedgerRepository ledgers, {
  FakeAuthRepository? auth,
}) async {
  await pumpApp(
    tester,
    auth: auth ?? FakeAuthRepository(signedIn: me),
    ledgers: ledgers,
  );
  await openTab(tester, HomeTab.settings);
}

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Future<void> openAccount(WidgetTester tester) async {
  await tapVisible(tester, const Key('open-account'));
  await settleRoute(tester);
}

/// 계정 화면에서 탈퇴하기를 누르고 확인 창에서 탈퇴한다.
Future<void> confirmDeleteAccount(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('delete-account')));
  await settle(tester);
  await tester.tap(find.byKey(const Key('delete-account-confirm')));
  await settle(tester);
}

void main() {
  group('가계부 나가기', () {
    testWidgets('관리자가 나가면 상대에게 관리자를 넘긴다고 묻고, 나가면 시작 화면에서 초대 코드로 다시 들어갈 수 있다', (
      tester,
    ) async {
      final ledgers = FakeLedgerRepository([shared]);
      await pumpSettings(tester, ledgers);

      await tapVisible(tester, const Key('leave-ledger'));
      expect(inDialog(find.text('가계부에서 나갈까요?')), findsOneWidget);
      expect(
        inDialog(
          findSentence(
            "나가면 '바다'에게 관리자를 넘겨요.\n"
            '내가 적은 내역은 가계부에 남아요.\n'
            '다시 들어오려면 새 초대 코드를 받아 주세요.',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('leave-ledger-confirm')));
      await settleRoute(tester);

      expect(ledgers.leaves, [(ledgerId: 'l1', uid: 'me')]);
      expect(find.byType(LedgerStartScreen), findsOneWidget);
      expect(find.byKey(const Key('start-join')), findsOneWidget);
      expect(findSentence('가계부에서 나왔어요.'), findsOneWidget);
    });

    testWidgets('초대로 들어온 사람은 관리자에게 새 코드를 받으라고 안내받고 나간다', (tester) async {
      final ledgers = FakeLedgerRepository([asEditor]);
      await pumpSettings(tester, ledgers);

      await tapVisible(tester, const Key('leave-ledger'));
      expect(
        inDialog(
          findSentence(
            '나가면 이 가계부를 더 볼 수 없어요.\n'
            '내가 적은 내역은 가계부에 남아요.\n'
            '다시 들어오려면 관리자에게 새 초대 코드를 받아 주세요.',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('leave-ledger-confirm')));
      await settleRoute(tester);

      expect(find.byType(LedgerStartScreen), findsOneWidget);
    });

    testWidgets('혼자 쓰는 관리자는 가계부가 지워진다는 확인을 받고 나간다', (tester) async {
      final ledgers = FakeLedgerRepository([solo]);
      await pumpSettings(tester, ledgers);

      await tapVisible(tester, const Key('leave-ledger'));
      expect(inDialog(find.text('가계부를 지울까요?')), findsOneWidget);
      expect(inDialog(find.text('지우고 나가기')), findsOneWidget);
      await tester.tap(find.byKey(const Key('leave-ledger-confirm')));
      await settleRoute(tester);

      expect(find.byType(LedgerStartScreen), findsOneWidget);
      expect(findSentence('가계부를 지우고 나왔어요.'), findsOneWidget);
    });

    testWidgets('확인 창에서 취소하면 나가지 않는다', (tester) async {
      final ledgers = FakeLedgerRepository([shared]);
      await pumpSettings(tester, ledgers);

      await tapVisible(tester, const Key('leave-ledger'));
      await tester.tap(find.byKey(const Key('leave-ledger-cancel')));
      await settle(tester);

      expect(ledgers.leaves, isEmpty);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('연결이 없으면 나가지 못했다고 알리고 설정 탭에 남는다', (tester) async {
      final ledgers = FakeLedgerRepository([shared])..offline = true;
      await pumpSettings(tester, ledgers);

      await tapVisible(tester, const Key('leave-ledger'));
      await tester.tap(find.byKey(const Key('leave-ledger-confirm')));
      await settle(tester);

      expect(
        findSentence('인터넷에 연결된 뒤에 다시 시도해 주세요. 가계부 나가기는 연결돼 있을 때만 돼요.'),
        findsOneWidget,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('탈퇴', () {
    testWidgets('계정 화면에서 탈퇴하면 다시 로그인한 뒤 가계부에서 나가고 로그인 화면으로 간다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me);
      final ledgers = FakeLedgerRepository([shared]);
      await pumpSettings(tester, ledgers, auth: auth);
      await openAccount(tester);

      await tester.tap(find.byKey(const Key('delete-account')));
      await settle(tester);
      expect(inDialog(find.text('탈퇴할까요?')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await settleRoute(tester);

      expect((auth.reauthCalls, auth.deleteCalls), (1, 1));
      expect(ledgers.leaves, [(ledgerId: 'l1', uid: 'me')]);
      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
      expect(findSentence('탈퇴했어요. 그동안 고마웠어요.'), findsOneWidget);
    });

    testWidgets('탈퇴하는 동안에는 가계부에서 다 나가도 시작 화면으로 옮기지 않는다', (tester) async {
      final hold = Completer<void>();
      final auth = FakeAuthRepository(signedIn: me)..holdDelete = hold.future;
      await pumpSettings(tester, FakeLedgerRepository([solo]), auth: auth);
      await openAccount(tester);

      await confirmDeleteAccount(tester);
      await settleRoute(tester);

      // 가계부에서는 나갔고 계정을 지우는 중이다.
      expect(find.byType(LedgerStartScreen), findsNothing);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('delete-account')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      hold.complete();
      await settleRoute(tester);
      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    });

    testWidgets('가계부에서 나간 뒤 계정을 지우지 못하면 알리고 시작 화면으로 간다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me)..failNextDelete = true;
      await pumpSettings(tester, FakeLedgerRepository([solo]), auth: auth);
      await openAccount(tester);

      await confirmDeleteAccount(tester);
      await settleRoute(tester);

      expect(findSentence('탈퇴하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.byType(LedgerStartScreen), findsOneWidget);
    });

    testWidgets('다시 로그인을 취소하면 계정 화면에 그대로 있다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me)..cancelNextReauth = true;
      final ledgers = FakeLedgerRepository([shared]);
      await pumpSettings(tester, ledgers, auth: auth);
      await openAccount(tester);

      await confirmDeleteAccount(tester);
      await settleRoute(tester);

      expect(ledgers.leaves, isEmpty);
      expect(auth.deleteCalls, 0);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byKey(const Key('account-failure')), findsNothing);
    });

    testWidgets('다른 계정으로 다시 로그인하면 알리고 계정 화면에 남는다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me)
        ..wrongAccountOnReauth = true;
      await pumpSettings(tester, FakeLedgerRepository([shared]), auth: auth);
      await openAccount(tester);

      await confirmDeleteAccount(tester);

      expect(
        findSentence('지금 계정과 다른 계정으로 로그인했어요.\n탈퇴할 계정으로 다시 시도해 주세요.'),
        findsOneWidget,
      );
      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets('가계부가 없어도 시작 화면의 탈퇴하기로 계정 화면을 열어 탈퇴한다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me);
      await pumpApp(tester, auth: auth, ledgers: FakeLedgerRepository());

      await tapVisible(tester, const Key('start-account'));
      await settleRoute(tester);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(find.byTooltip('가계부 시작으로 돌아가기'), findsOneWidget);
      await confirmDeleteAccount(tester);
      await settleRoute(tester);

      expect(auth.deleteCalls, 1);
      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    });
  });
}
