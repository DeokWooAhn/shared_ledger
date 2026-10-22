import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/app.dart';
import 'package:shared_ledger/core/data/ledger_repository.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/widget/keep_all.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/ledger/ledger_start_screen.dart';
import 'package:shared_ledger/feature/settings/invite_sheet.dart';

import 'support/fakes.dart';
import 'support/provider_container.dart';

/// 디자인과 같은 휴대폰 화면 크기. 테스트 기본값(800×600)은 넓은 화면 배치가 된다.
const phoneSize = Size(390, 844);
const tabletSize = Size(1024, 768);

Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required FakeLedgerRepository ledgers,
  FakeSettingsRepository? settings,
  Size size = phoneSize,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        ledgerRepositoryProvider.overrideWithValue(ledgers),
        settingsRepositoryProvider.overrideWithValue(
          settings ?? FakeSettingsRepository(),
        ),
        clockProvider.overrideWithValue(() => testNow),
      ],
      child: const SharedLedgerApp(),
    ),
  );
  await settle(tester);
}

Future<void> openTab(WidgetTester tester, HomeTab tab) async {
  await tester.tap(find.byKey(tab.key));
  await settle(tester);
}

// 불러오는 중 화면의 진행 표시 때문에 pumpAndSettle 대신 몇 번만 그린다.
// 화면 전환(300ms)이 끝날 만큼 그려야 이전 화면의 Scaffold가 남아 스낵바가 두 번 보이지 않는다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
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

      expect(find.byKey(const Key('app-logo')), findsOneWidget);
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

    testWidgets('기기가 다크 모드면 어두운 테마로 그린다', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(),
        ledgers: FakeLedgerRepository(),
      );

      final context = tester.element(find.byKey(const Key('sign-in-google')));
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('다크 모드에서 Apple 버튼은 흰 바탕에 검정 글자다', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(),
        ledgers: FakeLedgerRepository(),
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('sign-in-apple')),
      );
      expect(button.style?.backgroundColor?.resolve({}), Colors.white);
      expect(button.style?.foregroundColor?.resolve({}), Colors.black);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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

      expect(ledgers.created, [
        (name: '하늘바다 가계부', ownerUid: 'me', ownerName: '나'),
      ]);
      expect(find.text('2026년 10월'), findsOneWidget);

      await openTab(tester, HomeTab.settings);
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
      expect(find.text('2026년 10월'), findsOneWidget);

      await openTab(tester, HomeTab.settings);
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
      expect(find.byType(HomeShell), findsOneWidget);
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
    const shared = Ledger(
      id: 'l1',
      name: '우리 가계부',
      ownerUid: 'partner',
      roles: {'me': MemberRole.viewer},
    );

    testWidgets('가계부가 있으면 요약 탭에서 이번 달과 두 사람 이름표를 보여준다', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([shared]),
      );

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.text('하'), findsOneWidget);
      expect(find.text('바'), findsOneWidget);
    });

    testWidgets('달을 옮기면 항목 탭도 같은 달을 보고, 해를 넘어간다', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([shared]),
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('next-month')));
        await settle(tester);
      }
      expect(find.text('2027년 1월'), findsOneWidget);

      await openTab(tester, HomeTab.entries);
      expect(find.text('2027년 1월'), findsOneWidget);
      await tester.tap(find.byKey(const Key('previous-month')));
      await settle(tester);

      await openTab(tester, HomeTab.summary);
      expect(find.text('2026년 12월'), findsOneWidget);
    });

    testWidgets('글자를 크게 해도 달 이름이 잘리지 않는다', (tester) async {
      // 달 이름과 오른쪽 여백(Spacer)이 남는 폭을 반씩 나눠 '2026…'으로 잘린 적이 있다.
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(
          tester,
          auth: FakeAuthRepository(signedIn: me),
          ledgers: FakeLedgerRepository([shared]),
        );

        final title = tester.renderObject<RenderParagraph>(
          find.byKey(const Key('month-title')),
        );
        expect(title.didExceedMaxLines, isFalse, reason: '글자 배율 $scale');
        expect(
          tester.getRect(find.byKey(const Key('month-title'))).right,
          lessThan(tester.getRect(find.text('하')).left),
          reason: '글자 배율 $scale',
        );
      }
    });

    testWidgets('고른 탭은 화면 읽기 도구에 선택됨으로 알린다', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([shared]),
      );

      await openTab(tester, HomeTab.templates);

      expect(
        tester.getSemantics(find.byKey(HomeTab.templates.key)),
        isSemantics(label: '고정 지출', isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.byKey(HomeTab.summary.key)),
        isSemantics(label: '요약', isSelected: false, isButton: true),
      );
      semantics.dispose();
    });

    testWidgets('넓은 화면에서는 옆 탭 막대로 옮겨 다닌다', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([shared]),
        size: tabletSize,
      );

      expect(find.byType(NavigationRail), findsOneWidget);

      await openTab(tester, HomeTab.settings);
      expect(find.text('우리 가계부'), findsOneWidget);
    });

    testWidgets('설정 탭에서 두 사람의 이름표와 역할을 보고, 로그아웃하면 로그인 화면으로 간다', (tester) async {
      final auth = FakeAuthRepository(signedIn: me);
      await pumpApp(
        tester,
        auth: auth,
        ledgers: FakeLedgerRepository([shared]),
      );

      await openTab(tester, HomeTab.settings);

      expect(find.text('우리 가계부'), findsOneWidget);
      expect(find.text('구성원 2명'), findsOneWidget);
      expect(find.text('하늘'), findsOneWidget);
      expect(find.text('관리자'), findsOneWidget);
      expect(find.text('바다 (나)'), findsOneWidget);
      expect(find.text('보기 전용'), findsOneWidget);
      expect(find.byKey(const Key('create-invite')), findsNothing);

      await tapVisible(tester, const Key('sign-out'));

      expect(auth.signOutCalls, 1);
      expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    });

    testWidgets('혼자인 관리자는 설정 탭에서 역할을 골라 초대 코드를 만들 수 있다', (tester) async {
      final ledgers = FakeLedgerRepository([
        const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      ]);
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: ledgers,
      );
      await openTab(tester, HomeTab.settings);

      expect(find.text('하늘 (나)'), findsOneWidget);
      expect(find.text('초대 전'), findsOneWidget);

      await tapVisible(tester, const Key('create-invite'));
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
      await openTab(tester, HomeTab.settings);

      expect(find.text('편집자'), findsOneWidget);
      expect(find.byKey(const Key('create-invite')), findsNothing);
      expect(findSentence('두 사람이 함께 쓰고 있어요.'), findsOneWidget);
    });

    testWidgets('이름표가 생기기 전에 만든 가계부는 역할 이름으로 보여준다', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([
          const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
        ]),
        settings: FakeSettingsRepository(members: const []),
      );
      await openTab(tester, HomeTab.settings);

      expect(find.text('관리자 (나)'), findsOneWidget);
      expect(find.text('상대'), findsOneWidget);
    });
  });

  group('입력 검사와 문구', () {
    test('가계부 이름: 앞뒤 공백을 빼고 1~40자', () {
      expect(validateLedgerName('우리 가계부'), isNull);
      expect(validateLedgerName('  '), isNotNull);
      expect(validateLedgerName('가' * 40), isNull);
      expect(validateLedgerName('가' * 41), isNotNull);
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
