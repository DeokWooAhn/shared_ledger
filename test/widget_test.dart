import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/ledger_repository.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/payment_method.dart';
import 'package:shared_ledger/core/model/year_month.dart';
import 'package:shared_ledger/core/widget/tab_page.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/ledger/ledger_start_screen.dart';
import 'package:shared_ledger/feature/settings/invite_sheet.dart';
import 'package:shared_ledger/feature/summary/summary_screen.dart';

import 'support/app.dart';
import 'support/fakes.dart';

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
      expect(inMonthHeader(find.text('하')), findsOneWidget);
      expect(inMonthHeader(find.text('바')), findsOneWidget);
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
          lessThan(tester.getRect(inMonthHeader(find.text('하'))).left),
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
      expect(findSentence('구성원 2명'), findsOneWidget);
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

  group('월 요약', () {
    const ledger = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
    const october = YearMonth(2026, 10);

    // 디자인(design/app/03-summary.png)과 같은 숫자가 나오는 가상의 10월.
    final settings = FakeSettingsRepository(
      categories: const [
        Category(id: 'c-principal', name: '대출원금', countsAsSaving: true),
        Category(id: 'c-interest', name: '대출이자'),
        Category(id: 'c-invest', name: '저축/투자', countsAsSaving: true),
        Category(id: 'c-living', name: '소비'),
      ],
      paymentMethods: const [
        PaymentMethod(
          id: 'p-account',
          name: '공동 통장',
          kind: PaymentKind.account,
        ),
        PaymentMethod(
          id: 'p-auto',
          name: '자동이체',
          kind: PaymentKind.autoTransfer,
        ),
        PaymentMethod(id: 'p-shared', name: '공용 카드', kind: PaymentKind.card),
        PaymentMethod(id: 'p-sky', name: '하늘 카드', kind: PaymentKind.card),
      ],
    );

    PlannedExpense planned(
      String id,
      String categoryId,
      String memberId,
      String paymentMethodId,
      int? amount, {
      bool paid = false,
    }) => PlannedExpense(
      id: id,
      categoryId: categoryId,
      memberId: memberId,
      title: id,
      paymentMethodId: paymentMethodId,
      amount: amount,
      paidOn: paid ? DateTime(2026, 10, 5) : null,
    );

    ExtraExpense extra(String id, String memberId, String method, int amount) =>
        ExtraExpense(
          id: id,
          memberId: memberId,
          title: id,
          paymentMethodId: method,
          amount: amount,
        );

    final designMonth = MonthLedger(
      incomes: const [
        Income(id: 'i1', memberId: 'owner', title: '월급', amount: 3500000),
        Income(id: 'i2', memberId: 'partner', title: '월급', amount: 2300000),
      ],
      plannedExpenses: [
        planned('원금', 'c-principal', 'owner', 'p-auto', 800000, paid: true),
        planned('이자1', 'c-interest', 'partner', 'p-auto', 120000, paid: true),
        planned('이자2', 'c-interest', 'partner', 'p-account', 300000),
        planned('투자', 'c-invest', 'owner', 'p-account', 800000, paid: true),
        planned('통신', 'c-living', 'owner', 'p-shared', 101000),
        planned('보험', 'c-living', 'partner', 'p-shared', 178000),
      ],
      extraExpenses: [
        extra('간식', 'owner', 'p-shared', 5000),
        extra('책', 'partner', 'p-sky', 99000),
        extra('병원', 'owner', 'p-account', 254000),
      ],
      cardBills: const [
        CardBill(
          id: 'b1',
          memberId: 'owner',
          cardId: 'p-shared',
          amount: 600000,
        ),
        CardBill(id: 'b2', memberId: 'owner', cardId: 'p-sky', amount: 253000),
      ],
    );

    Future<void> pumpSummary(
      WidgetTester tester, {
      FakeEntriesRepository? entries,
      FakeSettingsRepository? settings,
      Size size = phoneSize,
    }) => pumpApp(
      tester,
      auth: FakeAuthRepository(signedIn: me),
      ledgers: FakeLedgerRepository([ledger]),
      settings: settings,
      entries: entries,
      size: size,
    );

    testWidgets('그달의 남는 현금·지출·저축·카드·기본 월 지출 소계를 보여준다', (tester) async {
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository({october: designMonth}),
        settings: settings,
      );

      expect(textOf(tester, const Key('remaining-cash')), '2,973,000원');
      expect(textOf(tester, const Key('cash-in')), '5,800,000원');
      expect(textOf(tester, const Key('cash-out')), '2,827,000원');
      expect(textOf(tester, const Key('spending')), '2,657,000원');
      expect(textOf(tester, const Key('saving')), '1,600,000원');
      expect(textOf(tester, const Key('planned-total')), '2,299,000원');

      final cards = find.byKey(const Key('card-section'));
      Finder inCards(String text) =>
          find.descendant(of: cards, matching: find.text(text));
      expect(inCards('11월'), findsOneWidget);
      expect(inCards('383,000원'), findsOneWidget);
      expect(inCards('공용 카드'), findsOneWidget);
      expect(inCards('284,000원'), findsOneWidget);
      expect(inCards('하늘 카드'), findsOneWidget);
      expect(inCards('99,000원'), findsOneWidget);
      expect(inCards('10월'), findsOneWidget);
      expect(inCards('853,000원'), findsOneWidget);
      expect(findSentence('이번 달 출금 · 카드대금 2건'), findsOneWidget);
      // 결제수단에 있어도 이번 달에 쓰지 않은 카드는 줄을 만들지 않는다.
      expect(find.byKey(const ValueKey('card-p-account')), findsNothing);

      final planned = find.byKey(const Key('planned-section'));
      Finder inPlanned(String text) =>
          find.descendant(of: planned, matching: find.text(text));
      expect(inPlanned('800,000원'), findsNWidgets(2));
      expect(inPlanned('420,000원'), findsOneWidget);
      expect(inPlanned('279,000원'), findsOneWidget);
      expect(inPlanned('저축'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byKey(const Key('member-owner')),
          matching: find.text('1,701,000원'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('member-partner')),
          matching: find.text('598,000원'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('empty-month')), findsNothing);
      expect(find.byKey(const Key('unpriced-planned')), findsNothing);
    });

    testWidgets('구성원별 막대는 두 사람의 기본 월 지출 비율로 나눠 그린다', (tester) async {
      // 막대 조각에 높이를 주지 않아 막대가 보이지 않은 적이 있다.
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository({october: designMonth}),
        settings: settings,
      );

      final parts = find.descendant(
        of: find.byKey(const Key('member-split')),
        matching: find.byType(DecoratedBox),
      );
      expect(parts, findsNWidgets(2));
      final owner = tester.getSize(parts.first);
      final partner = tester.getSize(parts.last);
      expect(owner.height, 10);
      expect(partner.height, 10);
      expect(owner.width / partner.width, closeTo(1701000 / 598000, 0.05));
    });

    testWidgets('항목이 없는 달은 0원으로 보여주고 안내하며, 카드가 없으면 카드 영역을 숨긴다', (tester) async {
      await pumpSummary(tester);

      expect(textOf(tester, const Key('remaining-cash')), '0원');
      expect(findSentence('아직 이 달에 적은 항목이 없어요.'), findsOneWidget);
      expect(find.byKey(const Key('card-section')), findsNothing);
      expect(textOf(tester, const Key('planned-total')), '0원');
    });

    testWidgets('금액 미정 기본 지출이 있으면 몇 건이 빠졌는지 알린다', (tester) async {
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository({
          october: MonthLedger(
            plannedExpenses: [
              planned('관리비', 'c-living', 'owner', 'p-account', null),
              planned('통신', 'c-living', 'owner', 'p-account', 50000),
            ],
          ),
        }),
        settings: settings,
      );

      expect(findSentence('금액 미정 1건은 합계에서 빠져 있어요'), findsOneWidget);
      expect(textOf(tester, const Key('planned-total')), '50,000원');
      expect(find.byKey(const Key('empty-month')), findsNothing);
    });

    testWidgets('달을 옮기면 그 달의 요약으로 바뀐다', (tester) async {
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository({
          october: designMonth,
          const YearMonth(2026, 11): const MonthLedger(
            incomes: [
              Income(id: 'i1', memberId: 'owner', title: '월급', amount: 1000),
            ],
          ),
        }),
        settings: settings,
      );

      await tester.tap(find.byKey(const Key('next-month')));
      await settle(tester);

      expect(find.text('2026년 11월'), findsOneWidget);
      expect(textOf(tester, const Key('remaining-cash')), '1,000원');
      expect(findSentence('이번 달 출금 · 카드대금 0건'), findsOneWidget);
    });

    testWidgets('항목을 불러오지 못하면 안내한다', (tester) async {
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository()..failNextWatch = true,
      );

      expect(find.byKey(const Key('summary-failed')), findsOneWidget);
      expect(find.byKey(const Key('remaining-cash')), findsNothing);
    });

    testWidgets('넓은 화면에서는 기본 월 지출을 오른쪽 칸에 둔다', (tester) async {
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository({october: designMonth}),
        settings: settings,
        size: tabletSize,
      );

      final cash = tester.getRect(find.byKey(const Key('remaining-cash')));
      final planned = tester.getRect(find.byKey(const Key('planned-section')));
      expect(planned.left, greaterThan(cash.right));
      expect(planned.top, lessThan(cash.bottom));
    });

    testWidgets('아이패드 세로처럼 덜 넓으면 한 칸으로 둔다', (tester) async {
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository({october: designMonth}),
        settings: settings,
        size: const Size(768, 1024),
      );

      final cash = tester.getRect(find.byKey(const Key('card-section')));
      final planned = tester.getRect(find.byKey(const Key('planned-section')));
      expect(planned.top, greaterThan(cash.bottom));
      expect(planned.width, lessThanOrEqualTo(tabPageMaxWidth));
    });

    testWidgets('본문 폭이 840에 못 미치면 탭 영역이 840을 넘어도 한 칸으로 둔다', (tester) async {
      // 양옆 여백(20씩)을 빼기 전 폭으로 두 칸을 정해, 본문이 800~839일 때도 두 칸이 된 적이 있다.
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository({october: designMonth}),
        settings: settings,
        size: const Size(950, 768),
      );
      final page = tester.getSize(find.byType(SummaryScreen)).width;
      expect(page, inInclusiveRange(840, 879), reason: '옆 탭 막대를 뺀 탭 영역 폭');

      final cards = tester.getRect(find.byKey(const Key('card-section')));
      final planned = tester.getRect(find.byKey(const Key('planned-section')));
      expect(planned.top, greaterThan(cards.bottom));
    });

    testWidgets('글자를 크게 해도 넘치지 않는다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSummary(
        tester,
        entries: FakeEntriesRepository({october: designMonth}),
        settings: settings,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('remaining-cash')), findsOneWidget);
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
