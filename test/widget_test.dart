import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/app.dart';
import 'package:shared_ledger/core/data/ledger_repository.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/widget/keep_all.dart';
import 'package:shared_ledger/feature/ledger/invite_sheet.dart';
import 'package:shared_ledger/feature/ledger/ledger_start_screen.dart';

import 'support/fakes.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required FakeLedgerRepository ledgers,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        ledgerRepositoryProvider.overrideWithValue(ledgers),
      ],
      child: const SharedLedgerApp(),
    ),
  );
  await settle(tester);
}

// 불러오는 중 화면의 진행 표시 때문에 pumpAndSettle 대신 몇 번만 그린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// 가계부 시작 화면은 스크롤되고 화면 밖 항목은 아직 만들어지지 않았을 수 있어서,
// 위젯이 나올 때까지 스크롤한 뒤 다룬다.
Future<void> scrollTo(WidgetTester tester, Key key) =>
    tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find.byType(Scrollable).first,
    );

Future<void> tapVisible(WidgetTester tester, Key key) async {
  await scrollTo(tester, key);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

Future<void> enterVisible(WidgetTester tester, Key key, String text) async {
  await scrollTo(tester, key);
  await tester.enterText(find.byKey(key), text);
}

// 화면의 문장은 줄바꿈을 막는 글자를 넣어 그리므로(keepAll) 같은 방식으로 찾는다.
Finder findSentence(String text) => find.text(keepAll(text));

const me = AuthUser(uid: 'me');
const partnerLedger = Ledger(
  id: 'l-partner',
  name: '바다네 가계부',
  ownerUid: 'partner',
);

void main() {
  group('로그인', () {
    testWidgets('로그아웃 상태면 로그인 화면을 보여준다', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(),
        ledgers: FakeLedgerRepository(),
      );

      expect(findSentence('심플 공유 가계부'), findsOneWidget);
      expect(findSentence('둘이 같이 쓰는 가계부'), findsOneWidget);
      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    });

    testWidgets('iOS에서는 Apple 로그인 버튼을 보여주고 누르면 Apple로 로그인한다', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth, ledgers: FakeLedgerRepository());

      await tester.tap(find.byKey(const Key('sign-in-apple')));
      await settle(tester);

      expect(auth.appleCalls, 1);
      expect(findSentence('함께 쓸 가계부를 정해요'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android에서는 Apple 로그인 버튼을 보여주지 않는다', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(),
        ledgers: FakeLedgerRepository(),
      );

      expect(find.byKey(const Key('sign-in-apple')), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Google로 로그인하고 가계부가 없으면 가계부 시작 화면으로 간다', (tester) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth, ledgers: FakeLedgerRepository());

      await tester.tap(find.byKey(const Key('sign-in-google')));
      await settle(tester);

      expect(auth.googleCalls, 1);
      expect(findSentence('함께 쓸 가계부를 정해요'), findsOneWidget);
    });

    testWidgets('로그인을 취소하면 로그인 화면에 그대로 있다', (tester) async {
      final auth = FakeAuthRepository()..cancelNextSignIn = true;
      await pumpApp(tester, auth: auth, ledgers: FakeLedgerRepository());

      await tester.tap(find.byKey(const Key('sign-in-google')));
      await settle(tester);

      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('가계부 시작', () {
    testWidgets('새로 만들면 나를 관리자로 저장하고 홈으로 간다', (tester) async {
      final ledgers = FakeLedgerRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );

      await enterVisible(tester, const Key('ledger-name'), ' 하늘바다 가계부 ');
      await tapVisible(tester, const Key('create-ledger'));

      expect(ledgers.created, [(name: '하늘바다 가계부', ownerUid: 'me')]);
      expect(find.text('하늘바다 가계부'), findsOneWidget);
      expect(find.text('관리자'), findsOneWidget);
    });

    testWidgets('가계부 이름이 비어 있으면 만들지 않고 안내한다', (tester) async {
      final ledgers = FakeLedgerRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );

      await enterVisible(tester, const Key('ledger-name'), '   ');
      await tapVisible(tester, const Key('create-ledger'));

      expect(ledgers.created, isEmpty);
      expect(findSentence('가계부 이름을 입력해 주세요.'), findsOneWidget);
    });

    testWidgets('초대 코드로 참여하면 초대받은 역할로 홈에 들어간다', (tester) async {
      final ledgers = FakeLedgerRepository()
        ..joinable['ABCDEFGH23'] = (
          ledger: partnerLedger,
          role: MemberRole.viewer,
        );
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );

      await enterVisible(tester, const Key('invite-code'), 'abcd-efgh 23');
      await tapVisible(tester, const Key('join-ledger'));

      expect(ledgers.joins, [(code: 'ABCDEFGH23', uid: 'me')]);
      expect(find.text('바다네 가계부'), findsOneWidget);
      expect(find.text('보기 전용'), findsOneWidget);
    });

    testWidgets('기간이 지난 초대 코드면 입력란 아래에 안내하고 화면에 남는다', (tester) async {
      final ledgers = FakeLedgerRepository()
        ..nextJoinFailure = JoinFailure.expired;
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );

      await enterVisible(tester, const Key('invite-code'), 'ABCDEFGH23');
      await tapVisible(tester, const Key('join-ledger'));

      expect(findSentence('기간이 지난 초대 코드예요. 새 코드를 받아 주세요.'), findsOneWidget);
      expect(find.byType(LedgerStartScreen), findsOneWidget);
    });

    testWidgets('초대 코드 모양이 아니면 서버에 묻지 않고 안내한다', (tester) async {
      final ledgers = FakeLedgerRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );

      await enterVisible(tester, const Key('invite-code'), 'abc');
      await tapVisible(tester, const Key('join-ledger'));

      expect(ledgers.joins, isEmpty);
      expect(findSentence('초대 코드를 다시 확인해 주세요.'), findsOneWidget);
    });

    testWidgets('참여에 실패한 뒤 같은 코드로 다시 누르면 바로 다시 시도한다', (tester) async {
      // 이전 오류가 남아 있어도 첫 누름이 무시되면 안 된다.
      final ledgers = FakeLedgerRepository()
        ..joinable['ABCDEFGH23'] = (
          ledger: partnerLedger,
          role: MemberRole.editor,
        )
        ..nextJoinFailure = JoinFailure.unavailable;
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );

      await enterVisible(tester, const Key('invite-code'), 'ABCDEFGH23');
      await tapVisible(tester, const Key('join-ledger'));
      expect(
        findSentence('이 가계부에는 더 들어갈 수 없어요. 초대한 사람에게 확인해 주세요.'),
        findsOneWidget,
      );

      await tapVisible(tester, const Key('join-ledger'));

      expect(ledgers.joins, hasLength(2));
      expect(find.text('바다네 가계부'), findsOneWidget);
    });

    testWidgets('두 명이 다 찬 가계부의 코드면 들어갈 수 없다고 안내한다', (tester) async {
      final ledgers = FakeLedgerRepository()
        ..joinable['ABCDEFGH23'] = (
          ledger: const Ledger(
            id: 'l-full',
            name: '가득 찬 가계부',
            ownerUid: 'partner',
            roles: {'someone': MemberRole.editor},
          ),
          role: MemberRole.editor,
        );
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );

      await enterVisible(tester, const Key('invite-code'), 'ABCDEFGH23');
      await tapVisible(tester, const Key('join-ledger'));

      expect(
        findSentence('이 가계부에는 더 들어갈 수 없어요. 초대한 사람에게 확인해 주세요.'),
        findsOneWidget,
      );
      expect(find.byType(LedgerStartScreen), findsOneWidget);
    });

    testWidgets('로그아웃에 실패하면 안내하고 화면에 남는다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me)..failNextSignOut = true;
      await pumpApp(tester, auth: auth, ledgers: FakeLedgerRepository());

      await tapVisible(tester, const Key('sign-out'));

      expect(findSentence('로그아웃하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.byType(LedgerStartScreen), findsOneWidget);
    });

    testWidgets('화면 읽기 도구는 입력란을 이름표와 함께 읽는다', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository(),
      );

      for (final (key, label) in [
        (const Key('ledger-name'), '가계부 이름'),
        (const Key('invite-code'), '초대 코드'),
      ]) {
        await scrollTo(tester, key);
        final node = tester.getSemantics(find.byKey(key));
        expect(node.label, contains(label));
        expect(node.flagsCollection.isTextField, isTrue);
      }
      semantics.dispose();
    });

    testWidgets('가계부 시작 화면에서 로그아웃하면 로그인 화면으로 간다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me);
      await pumpApp(tester, auth: auth, ledgers: FakeLedgerRepository());

      await tapVisible(tester, const Key('sign-out'));

      expect(auth.signOutCalls, 1);
      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    });
  });

  group('가계부 홈', () {
    testWidgets('이미 가계부가 있으면 바로 홈을 보여주고, 로그아웃하면 로그인 화면으로 간다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me);
      await pumpApp(
        tester,
        auth: auth,
        ledgers: FakeLedgerRepository([
          const Ledger(
            id: 'l1',
            name: '우리 가계부',
            ownerUid: 'partner',
            roles: {'me': MemberRole.viewer},
          ),
        ]),
      );

      expect(find.text('우리 가계부'), findsOneWidget);
      expect(find.text('보기 전용'), findsOneWidget);
      expect(find.text('2명'), findsOneWidget);
      expect(find.byKey(const Key('create-invite')), findsNothing);

      await tester.tap(find.byKey(const Key('sign-out')));
      await settle(tester);

      expect(auth.signOutCalls, 1);
      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    });

    testWidgets('혼자인 관리자는 역할을 골라 초대 코드를 만들 수 있다', (tester) async {
      final ledgers = FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );

      await tester.tap(find.byKey(const Key('create-invite')));
      await settle(tester);
      await tester.tap(find.text('보기 전용'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-invite')));
      await settle(tester);

      expect(ledgers.invites, [
        (ledgerId: 'l1', role: MemberRole.viewer, createdBy: 'me'),
      ]);
      expect(find.text('TESTCODE1A'), findsOneWidget);
      expect(findSentence('10월 28일 오후 3:05까지 쓸 수 있어요'), findsOneWidget);
    });

    testWidgets('두 명이 다 찬 가계부에서는 초대 코드를 만들 수 없다', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([
          const Ledger(
            id: 'l1',
            name: '우리 가계부',
            ownerUid: 'me',
            roles: {'partner': MemberRole.editor},
          ),
        ]),
      );

      expect(find.byKey(const Key('create-invite')), findsNothing);
      expect(findSentence('두 사람이 함께 쓰고 있어요.'), findsOneWidget);
    });
  });

  group('입력 검사와 문구', () {
    test('가계부 이름: 앞뒤 공백을 빼고 1~40자', () {
      expect(validateLedgerName('우리 가계부'), isNull);
      expect(validateLedgerName('  '), isNotNull);
      expect(validateLedgerName('가' * 40), isNull);
      expect(validateLedgerName('가' * 41), isNotNull);
    });

    test('초대 코드 입력: 비었거나 모양이 다르면 안내', () {
      expect(validateInviteCodeInput('ABCDEFGH23'), isNull);
      expect(validateInviteCodeInput(' abcd efgh 23 '), isNull);
      expect(validateInviteCodeInput(''), '초대 코드를 입력해 주세요.');
      expect(validateInviteCodeInput('abc'), '초대 코드를 다시 확인해 주세요.');
    });

    test('초대 코드 유효기간은 오전·오후 12시간제로 보여준다', () {
      expect(
        inviteExpiryText(DateTime(2026, 10, 28, 0, 5)),
        '10월 28일 오전 12:05까지 쓸 수 있어요',
      );
      expect(
        inviteExpiryText(DateTime(2026, 10, 28, 12)),
        '10월 28일 오후 12:00까지 쓸 수 있어요',
      );
    });
  });
}
