import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/payment_method.dart';
import 'package:shared_ledger/core/model/year_month.dart';
import 'package:shared_ledger/feature/entries/entries_screen.dart';
import 'package:shared_ledger/feature/entries/entry_form_screen.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';

import '../../support/app.dart';
import '../../support/fakes.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
const october = YearMonth(2026, 10);

final settings = FakeSettingsRepository(
  categories: const [
    Category(id: 'c-principal', name: '대출원금', countsAsSaving: true),
    Category(id: 'c-living', name: '소비'),
  ],
  paymentMethods: const [
    PaymentMethod(id: 'p-account', name: '공동 통장', kind: PaymentKind.account),
    PaymentMethod(id: 'p-auto', name: '자동이체', kind: PaymentKind.autoTransfer),
    PaymentMethod(id: 'p-shared', name: '공용 카드', kind: PaymentKind.card),
  ],
);

// 디자인(design/app/04)의 일부와 같은 가상의 10월 기본 월 지출.
final plannedMonth = MonthLedger(
  plannedExpenses: [
    PlannedExpense(
      id: 'principal',
      categoryId: 'c-principal',
      memberId: 'owner',
      title: '주택담보대출 원금',
      paymentMethodId: 'p-auto',
      amount: 800000,
      paidOn: DateTime(2026, 10, 25),
    ),
    const PlannedExpense(
      id: 'rent',
      categoryId: 'c-living',
      memberId: 'partner',
      title: '관리비',
      paymentMethodId: 'p-account',
    ),
    PlannedExpense(
      id: 'phone',
      categoryId: 'c-living',
      memberId: 'partner',
      title: '통신비',
      paymentMethodId: 'p-shared',
      amount: 98000,
      paidOn: DateTime(2026, 10, 21),
    ),
  ],
);

Future<void> pumpEntries(
  WidgetTester tester, {
  FakeEntriesRepository? entries,
  Ledger ledger = mine,
  Size size = phoneSize,
}) async {
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([ledger]),
    settings: settings,
    entries: entries ?? FakeEntriesRepository(),
    size: size,
  );
  await openTab(tester, HomeTab.entries);
}

// 항목 탭 아래에 입력 화면이 겹쳐 있을 때 입력 화면 안의 것만 찾는다(종류 세그먼트는 둘 다에 있다).
Finder inForm(Finder finder) =>
    find.descendant(of: find.byType(EntryFormScreen), matching: finder);

Finder inList(Finder finder) =>
    find.descendant(of: find.byType(EntriesScreen), matching: finder);

// 아직 만들어지지 않았으면 나올 때까지 끌어 내리고, 다 보이게 옮긴다.
// 끌고 난 뒤의 관성 스크롤 중에는 목록이 누름을 받지 않아서 멈출 때까지 그린다.
Future<void> showInForm(WidgetTester tester, Key key) async {
  final finder = inForm(find.byKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: inForm(find.byType(Scrollable)).first,
    );
  }
  await tester.ensureVisible(finder);
  await settle(tester);
}

Future<void> tapInForm(WidgetTester tester, Key key) async {
  await showInForm(tester, key);
  await tester.tap(inForm(find.byKey(key)));
  await settle(tester);
}

Future<void> enterInForm(WidgetTester tester, Key key, String text) async {
  await showInForm(tester, key);
  await tester.enterText(inForm(find.byKey(key)), text);
}

Future<void> openAddForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('add-entry')));
  await settleRoute(tester);
}

String? textIn(WidgetTester tester, Key key) =>
    tester.widget<Text>(inList(find.byKey(key))).data;

void main() {
  group('항목 목록', () {
    testWidgets('기본 지출은 분류마다 묶고 건수·지급 전 건수·합계와 금액 미정을 보여준다', (tester) async {
      await pumpEntries(
        tester,
        entries: FakeEntriesRepository({october: plannedMonth}),
      );

      expect(textIn(tester, const Key('entries-count')), '3건');
      expect(textIn(tester, const Key('entries-total')), '898,000원');
      expect(find.text('지급 전 1건'), findsOneWidget);
      expect(find.byKey(const ValueKey('group-c-principal')), findsOneWidget);
      expect(find.byKey(const ValueKey('group-c-living')), findsOneWidget);
      expect(find.text('금액 미정'), findsOneWidget);
      expect(find.text('자동이체 · 10/25 지급'), findsOneWidget);
      // 카드로 낸 기본 지출은 '결제'라고 적는다.
      expect(find.text('공용 카드 · 10/21 결제'), findsOneWidget);
    });

    testWidgets('종류를 바꾸면 그 종류의 목록을 보여주고, 없으면 안내한다', (tester) async {
      await pumpEntries(
        tester,
        entries: FakeEntriesRepository({october: plannedMonth}),
      );

      await tester.tap(inList(find.byKey(const Key('entry-kind-income'))));
      await settle(tester);

      expect(find.byKey(const Key('entries-empty')), findsOneWidget);
      expect(findSentence('이 달에 적은 수입이 없어요.'), findsOneWidget);
      expect(findSentence('+ 버튼으로 적을 수 있어요.'), findsOneWidget);
    });

    testWidgets('항목을 불러오지 못하면 안내한다', (tester) async {
      await pumpEntries(
        tester,
        entries: FakeEntriesRepository()..failNextWatch = true,
      );

      expect(find.byKey(const Key('entries-failed')), findsOneWidget);
    });

    testWidgets('보기 전용은 + 버튼이 없고 항목을 눌러도 고치는 화면이 열리지 않는다', (tester) async {
      await pumpEntries(
        tester,
        entries: FakeEntriesRepository({october: plannedMonth}),
        ledger: const Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'partner-uid',
          roles: {'me': MemberRole.viewer},
        ),
      );

      expect(find.byKey(const Key('add-entry')), findsNothing);
      await tester.tap(find.text('관리비'));
      await settleRoute(tester);
      expect(find.byType(EntryFormScreen), findsNothing);
    });

    testWidgets('+ 버튼은 요약·항목 탭에만 있다', (tester) async {
      await pumpEntries(tester);

      expect(find.byKey(const Key('add-entry')), findsOneWidget);
      await openTab(tester, HomeTab.summary);
      expect(find.byKey(const Key('add-entry')), findsOneWidget);
      for (final tab in [HomeTab.templates, HomeTab.settings]) {
        await openTab(tester, tab);
        expect(find.byKey(const Key('add-entry')), findsNothing);
      }
    });
  });

  group('항목 입력', () {
    testWidgets('+ 버튼으로 추가지출을 적으면 항목 탭과 요약 탭에 보인다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpEntries(tester, entries: entries);
      await tester.tap(inList(find.byKey(const Key('entry-kind-extra'))));
      await settle(tester);

      await openAddForm(tester);
      expect(find.text('항목 추가'), findsOneWidget);
      expect(find.text('쓴 날'), findsOneWidget);
      await enterInForm(tester, const Key('entry-amount'), '186000');
      expect(find.text('186,000'), findsOneWidget);
      await enterInForm(tester, const Key('entry-title'), '마트 장보기');
      await tapInForm(tester, const Key('entry-member-partner'));
      await tapInForm(tester, const Key('entry-method-p-account'));
      await tapInForm(tester, const Key('entry-save'));
      await settleRoute(tester);

      expect(find.byType(EntryFormScreen), findsNothing);
      expect(entries.added.single.month, october);
      expect(textIn(tester, const Key('entries-count')), '1건');
      expect(find.text('마트 장보기'), findsOneWidget);
      expect(find.text('공동 통장 · 10/15'), findsOneWidget);

      await openTab(tester, HomeTab.summary);
      expect(textOf(tester, const Key('spending')), '186,000원');
      expect(textOf(tester, const Key('cash-out')), '186,000원');
    });

    testWidgets('서버가 새 항목을 받지 않으면 목록에서 빠지고 알린다', (tester) async {
      final entries = FakeEntriesRepository()..rejectNextAdd = true;
      await pumpEntries(tester, entries: entries);
      await tester.tap(inList(find.byKey(const Key('entry-kind-income'))));
      await settle(tester);

      await openAddForm(tester);
      await enterInForm(tester, const Key('entry-amount'), '3000000');
      await enterInForm(tester, const Key('entry-title'), '월급');
      await tapInForm(tester, const Key('entry-save'));
      await settleRoute(tester);

      expect(find.byType(EntryFormScreen), findsNothing);
      expect(find.byKey(const Key('entries-empty')), findsOneWidget);
      expect(find.byKey(const Key('entry-rejected')), findsOneWidget);
      expect(
        findSentence('저장한 항목을 서버가 받지 않아 목록에서 빠졌어요. 쓰기 권한이 있는지 확인해 주세요.'),
        findsOneWidget,
      );
    });

    testWidgets('요약 탭의 + 버튼은 추가지출로 열고 보고 있는 달에 넣는다', (tester) async {
      final entries = FakeEntriesRepository();
      // 11월은 항목이 있는 달이라 머리말로 갈 수 있다.
      await pumpEntries(
        tester,
        entries: entries,
        ledger: Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'me',
          months: {const YearMonth(2026, 11)},
        ),
      );
      await openTab(tester, HomeTab.summary);
      await swipeMonth(tester);

      await openAddForm(tester);
      expect(find.text('쓴 날'), findsOneWidget);
      // 이번 달이 아니면 날짜는 비워 둔다.
      expect(find.text('날짜를 고를 수 있어요 (선택)'), findsOneWidget);
      await enterInForm(tester, const Key('entry-amount'), '5000');
      await enterInForm(tester, const Key('entry-title'), '간식');
      await tapInForm(tester, const Key('entry-method-p-shared'));
      expect(findSentence('카드로 낸 돈은 다음 달 카드대금으로 빠져나가요.'), findsOneWidget);
      await tapInForm(tester, const Key('entry-save'));
      await settleRoute(tester);

      expect(entries.added.single.month, const YearMonth(2026, 11));
      expect(entries.added.single.draft.kind, EntryKind.extra);
      expect(entries.added.single.draft.date, isNull);
    });

    testWidgets('빈 칸으로 저장하면 칸마다 안내하고 화면에 남는다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpEntries(tester, entries: entries);

      await openAddForm(tester);
      await tapInForm(tester, const Key('entry-save'));

      expect(entries.added, isEmpty);
      expect(find.byType(EntryFormScreen), findsOneWidget);
      expect(findSentence('내용을 입력해 주세요.'), findsOneWidget);
      expect(findSentence('분류를 골라 주세요.'), findsOneWidget);
      expect(findSentence('결제수단을 골라 주세요.'), findsOneWidget);
      // 기본 지출은 금액을 비워 두면 금액 미정이다.
      expect(findSentence('금액을 입력해 주세요.'), findsNothing);

      await enterInForm(tester, const Key('entry-title'), '관리비');
      await settle(tester);
      expect(findSentence('내용을 입력해 주세요.'), findsNothing);
    });

    testWidgets('기본 지출은 지급 완료를 켜면 지급한 날을 오늘로 채운다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpEntries(tester, entries: entries);

      await openAddForm(tester);
      expect(find.text('지급한 날'), findsNothing);
      await enterInForm(tester, const Key('entry-title'), '관리비');
      await tapInForm(tester, const Key('entry-category-c-living'));
      await tapInForm(tester, const Key('entry-method-p-account'));
      await tapInForm(tester, const Key('entry-paid'));
      expect(find.text('2026년 10월 15일'), findsOneWidget);
      await tapInForm(tester, const Key('entry-save'));
      await settleRoute(tester);

      final draft = entries.added.single.draft;
      expect(draft.amount, isNull);
      expect(draft.date, DateTime(2026, 10, 15));
      expect(find.text('공동 통장 · 10/15 지급'), findsOneWidget);
    });

    testWidgets('날짜는 한국어 달력에서 그달 안의 날로 고른다', (tester) async {
      await pumpEntries(tester);
      await tester.tap(inList(find.byKey(const Key('entry-kind-income'))));
      await settle(tester);
      await openAddForm(tester);

      await tapInForm(tester, const Key('entry-date'));
      expect(find.text('받은 날'), findsWidgets);
      await tester.tap(find.text('3'));
      await tester.tap(find.text('확인'));
      await settle(tester);

      expect(find.text('2026년 10월 3일'), findsOneWidget);
      await tapInForm(tester, const Key('entry-date-clear'));
      expect(find.text('날짜를 고를 수 있어요 (선택)'), findsOneWidget);
    });

    testWidgets('잘못 저장된 그달 밖의 날짜도 달력은 그달 안에서 연다', (tester) async {
      await pumpEntries(
        tester,
        entries: FakeEntriesRepository({
          october: MonthLedger(
            extraExpenses: [
              ExtraExpense(
                id: 'x1',
                memberId: 'owner',
                title: '간식',
                paymentMethodId: 'p-account',
                amount: 5000,
                spentOn: DateTime(2026, 11, 2),
              ),
            ],
          ),
        }),
      );
      await tester.tap(inList(find.byKey(const Key('entry-kind-extra'))));
      await settle(tester);
      await tester.tap(find.text('간식'));
      await settleRoute(tester);

      await tapInForm(tester, const Key('entry-date'));

      expect(tester.takeException(), isNull);
      expect(find.text('확인'), findsOneWidget);
    });

    testWidgets('화면 읽기 도구는 금액·내용 칸을 이름표와 함께 읽는다', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpEntries(tester);
      await openAddForm(tester);

      for (final (key, label) in [
        (const Key('entry-amount'), '금액'),
        (const Key('entry-title'), '내용'),
      ]) {
        await showInForm(tester, key);
        final node = tester.getSemantics(inForm(find.byKey(key)));
        expect(node.label, contains(label));
        expect(node.flagsCollection.isTextField, isTrue);
      }
      await showInForm(tester, const Key('entry-member-owner'));
      expect(
        tester.getSemantics(
          inForm(find.byKey(const Key('entry-member-owner'))),
        ),
        isSemantics(label: '하늘', isSelected: true, isButton: true),
      );
      semantics.dispose();
    });

    testWidgets('X를 누르면 저장하지 않고 닫힌다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpEntries(tester, entries: entries);
      await openAddForm(tester);
      await enterInForm(tester, const Key('entry-amount'), '1000');

      await tester.tap(find.byKey(const Key('entry-close')));
      await settleRoute(tester);

      expect(find.byType(EntryFormScreen), findsNothing);
      expect(entries.added, isEmpty);
    });
  });

  group('항목 고치기', () {
    testWidgets('항목을 눌러 금액을 채우고 저장하면 목록과 요약이 바뀐다', (tester) async {
      final entries = FakeEntriesRepository({october: plannedMonth});
      await pumpEntries(tester, entries: entries);

      await tester.tap(find.text('관리비'));
      await settleRoute(tester);
      expect(find.text('항목 고치기'), findsOneWidget);
      await enterInForm(tester, const Key('entry-amount'), '210000');
      await tapInForm(tester, const Key('entry-save'));
      await settleRoute(tester);

      expect(entries.updated.single.id, 'rent');
      expect(find.text('금액 미정'), findsNothing);
      expect(textIn(tester, const Key('entries-total')), '1,108,000원');

      await openTab(tester, HomeTab.summary);
      expect(textOf(tester, const Key('planned-total')), '1,108,000원');
    });

    testWidgets('연결이 없으면 고치지 못한다고 알리고 화면에 남는다', (tester) async {
      final entries = FakeEntriesRepository({october: plannedMonth})
        ..offline = true;
      await pumpEntries(tester, entries: entries);

      await tester.tap(find.text('관리비'));
      await settleRoute(tester);
      await tapInForm(tester, const Key('entry-save'));

      expect(
        findSentence('인터넷에 연결된 뒤에 다시 시도해 주세요. 고치기와 휴지통은 연결돼 있을 때만 돼요.'),
        findsOneWidget,
      );
      expect(find.byType(EntryFormScreen), findsOneWidget);
      expect(entries.updated, isEmpty);
    });

    testWidgets('휴지통에 넣으면 목록에서 빠지고, 되돌리기로 다시 꺼낸다', (tester) async {
      final entries = FakeEntriesRepository({october: plannedMonth});
      await pumpEntries(tester, entries: entries);

      await tester.tap(find.text('통신비'));
      await settleRoute(tester);
      await tapInForm(tester, const Key('entry-trash'));
      await settleRoute(tester);

      expect(find.byType(EntryFormScreen), findsNothing);
      expect(find.text('통신비'), findsNothing);
      expect(findSentence('휴지통에 넣었어요.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('restore-entry')));
      await settle(tester);

      expect(entries.restored.single.id, 'phone');
      expect(find.text('통신비'), findsOneWidget);
    });
  });

  group('넓은 화면', () {
    testWidgets('옆 탭 막대 위의 + 버튼으로 열고, 입력 화면은 가운데 좁게 둔다', (tester) async {
      await pumpEntries(tester, size: tabletSize);

      expect(find.byType(NavigationRail), findsOneWidget);
      await openAddForm(tester);

      expect(find.byType(EntryFormScreen), findsOneWidget);
      await showInForm(tester, const Key('entry-save'));
      final save = tester.getRect(inForm(find.byKey(const Key('entry-save'))));
      expect(save.width, lessThanOrEqualTo(560 - 40));
      expect(save.center.dx, closeTo(tabletSize.width / 2, 1));
    });

    testWidgets('+ 버튼이 없는 탭에서도 옆 탭 막대의 탭 위치는 그대로다', (tester) async {
      await pumpEntries(tester, size: tabletSize);
      final before = tester.getRect(find.byKey(HomeTab.settings.key));

      await openTab(tester, HomeTab.settings);

      expect(find.byKey(const Key('add-entry')), findsNothing);
      expect(tester.getRect(find.byKey(HomeTab.settings.key)), before);
    });
  });
}
