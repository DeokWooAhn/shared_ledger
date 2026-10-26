import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/expense_template.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/payment_method.dart';
import 'package:shared_ledger/core/model/year_month.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/templates/template_form_screen.dart';
import 'package:shared_ledger/feature/templates/templates_screen.dart';

import '../../support/app.dart';
import '../../support/fakes.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
const october = YearMonth(2026, 10);

final settings = FakeSettingsRepository(
  categories: const [
    Category(id: 'c-principal', name: '대출원금', countsAsSaving: true),
    Category(id: 'c-spending', name: '소비'),
  ],
  paymentMethods: const [
    PaymentMethod(id: 'p-account', name: '공동 통장', kind: PaymentKind.account),
    PaymentMethod(id: 'p-auto', name: '자동이체', kind: PaymentKind.autoTransfer),
    PaymentMethod(id: 'p-shared', name: '공용 카드', kind: PaymentKind.card),
  ],
);

// 디자인(design/app/06)의 일부와 같은 가상의 고정 지출.
const principal = ExpenseTemplate(
  id: 'principal',
  title: '주택담보대출 원금',
  amount: 800000,
  categoryId: 'c-principal',
  paymentMethodId: 'p-auto',
  memberId: 'owner',
  dueDay: 25,
);
const rent = ExpenseTemplate(
  id: 'rent',
  title: '관리비',
  categoryId: 'c-spending',
  paymentMethodId: 'p-account',
  memberId: 'partner',
  dueDay: lastDueDay,
);

/// 앱을 띄운다. 요약 탭에서 시작한다.
Future<void> pumpLedger(
  WidgetTester tester, {
  FakeTemplatesRepository? templates,
  FakeEntriesRepository? entries,
  Ledger ledger = mine,
  Size size = phoneSize,
}) => pumpApp(
  tester,
  auth: FakeAuthRepository(signedIn: me),
  ledgers: FakeLedgerRepository([ledger]),
  settings: settings,
  entries: entries ?? FakeEntriesRepository(),
  templates: templates ?? FakeTemplatesRepository(const [principal, rent]),
  size: size,
);

/// 앱을 띄우고 고정 지출 탭을 연다.
Future<void> pumpTemplates(
  WidgetTester tester, {
  FakeTemplatesRepository? templates,
  FakeEntriesRepository? entries,
  Ledger ledger = mine,
  Size size = phoneSize,
}) async {
  await pumpLedger(
    tester,
    templates: templates,
    entries: entries,
    ledger: ledger,
    size: size,
  );
  await openTab(tester, HomeTab.templates);
}

// 고정 지출 탭 아래에 입력 화면이 겹쳐 있을 때 입력 화면 안의 것만 찾는다.
Finder inForm(Finder finder) =>
    find.descendant(of: find.byType(TemplateFormScreen), matching: finder);

Finder inList(Finder finder) =>
    find.descendant(of: find.byType(TemplatesScreen), matching: finder);

// 입력 화면은 스크롤되므로 위젯이 화면 안에 들어오게 한 뒤 다룬다.
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

Future<void> tapInList(WidgetTester tester, Key key) async {
  await tester.ensureVisible(inList(find.byKey(key)));
  await settle(tester);
  await tester.tap(inList(find.byKey(key)));
  await settleRoute(tester);
}

/// 예정일 칸을 눌러 시트에서 [day]일(31은 말일)을 고른다.
Future<void> pickDueDay(WidgetTester tester, int day) async {
  await tapInForm(tester, const Key('template-due-day'));
  await tester.tap(find.byKey(Key('due-day-$day')));
  await settle(tester);
}

String? textIn(WidgetTester tester, Key key) =>
    tester.widget<Text>(inList(find.byKey(key))).data;

void main() {
  group('고정 지출 목록', () {
    testWidgets('매달 나가는 돈 합계와 개수, 분류마다 묶은 고정 지출을 예정일과 함께 보여준다', (tester) async {
      await pumpTemplates(tester);

      expect(textIn(tester, const Key('templates-total')), '800,000원');
      expect(textIn(tester, const Key('templates-count')), '2개 · 금액 미정 1개');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('template-group-c-principal')),
          matching: find.byKey(const ValueKey('template-principal')),
        ),
        findsOneWidget,
      );
      final rentRow = find.byKey(const ValueKey('template-rent'));
      for (final text in ['말일', '관리비', '공동 통장 · 바다', '금액 미정']) {
        expect(
          find.descendant(of: rentRow, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('template-principal')),
          matching: find.text('25일'),
        ),
        findsOneWidget,
      );
      // 고정 지출 탭에는 항목 + 버튼이 없다.
      expect(find.byKey(const Key('add-entry')), findsNothing);
    });

    testWidgets('고정 지출이 없으면 안내와 추가 버튼을 보여준다', (tester) async {
      await pumpTemplates(tester, templates: FakeTemplatesRepository());

      expect(find.byKey(const Key('templates-empty')), findsOneWidget);
      expect(find.byKey(const Key('templates-total')), findsNothing);
      expect(find.byKey(const Key('add-template')), findsOneWidget);
    });

    testWidgets('보기 전용은 추가 버튼이 없고 줄을 눌러도 고치기 화면이 열리지 않는다', (tester) async {
      await pumpTemplates(
        tester,
        ledger: const Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'partner-uid',
          roles: {'me': MemberRole.viewer},
        ),
      );

      expect(find.byKey(const Key('add-template')), findsNothing);
      await tapInList(tester, const ValueKey('template-rent'));
      expect(find.byType(TemplateFormScreen), findsNothing);
    });
  });

  group('추가·고치기·삭제', () {
    testWidgets('고정 지출을 추가하면 목록과 합계에 들어간다', (tester) async {
      final templates = FakeTemplatesRepository(const [principal]);
      await pumpTemplates(tester, templates: templates);

      await tapInList(tester, const Key('add-template'));
      expect(find.byType(TemplateFormScreen), findsOneWidget);
      await enterInForm(tester, const Key('template-amount'), '154000');
      await enterInForm(tester, const Key('template-title'), '보험');
      await tapInForm(tester, const Key('template-category-c-spending'));
      await tapInForm(tester, const Key('template-method-p-auto'));
      await pickDueDay(tester, 15);
      expect(inForm(find.text('매월 15일')), findsOneWidget);
      await tapInForm(tester, const Key('template-save'));
      await settleRoute(tester);

      expect(find.byType(TemplateFormScreen), findsNothing);
      expect(templates.added.single.draft.amount, 154000);
      expect(templates.added.single.draft.memberId, 'owner');
      expect(textIn(tester, const Key('templates-total')), '954,000원');
      expect(textIn(tester, const Key('templates-count')), '2개');
      expect(find.text('보험'), findsOneWidget);
      expect(find.text('자동이체 · 하늘'), findsWidgets);
    });

    testWidgets('꼭 필요한 칸을 비우고 저장하면 입력란 아래에 알리고 닫히지 않는다', (tester) async {
      final templates = FakeTemplatesRepository();
      await pumpTemplates(tester, templates: templates);

      await tapInList(tester, const Key('add-template'));
      await tapInForm(tester, const Key('template-save'));

      expect(find.byType(TemplateFormScreen), findsOneWidget);
      expect(templates.added, isEmpty);
      for (final message in [
        '내용을 입력해 주세요.',
        '분류를 골라 주세요.',
        '결제수단을 골라 주세요.',
        '예정일을 골라 주세요.',
      ]) {
        expect(inForm(findSentence(message)), findsOneWidget, reason: message);
      }
    });

    testWidgets('카드를 고르면 다음 달 카드대금으로 빠져나간다고 알린다', (tester) async {
      await pumpTemplates(tester);

      await tapInList(tester, const Key('add-template'));
      expect(inForm(find.byKey(const Key('template-card-note'))), findsNothing);
      await tapInForm(tester, const Key('template-method-p-shared'));

      expect(
        inForm(find.byKey(const Key('template-card-note'))),
        findsOneWidget,
      );
    });

    testWidgets('줄을 눌러 고치면 목록이 바뀌고, 이미 만든 이번 달 기본 지출은 그대로다', (tester) async {
      final templates = FakeTemplatesRepository(const [principal, rent]);
      final entries = FakeEntriesRepository();
      await pumpTemplates(tester, templates: templates, entries: entries);
      // 요약 탭을 열었을 때 이번 달 기본 지출이 만들어졌다.
      expect(entries.monthOf(october).plannedExpenses, hasLength(2));

      await tapInList(tester, const ValueKey('template-principal'));
      expect(inForm(find.text('고정 지출 고치기')), findsOneWidget);
      expect(inForm(find.text('매월 25일')), findsOneWidget);
      await enterInForm(tester, const Key('template-amount'), '900,000');
      await tapInForm(tester, const Key('template-save'));
      await settleRoute(tester);

      expect(templates.updated.single.id, 'principal');
      expect(textIn(tester, const Key('templates-total')), '900,000원');
      final planned = entries.monthOf(october).plannedExpenses;
      expect(planned.firstWhere((e) => e.id == 'principal').amount, 800000);
    });

    testWidgets('지우면 목록에서 빠지고, 되돌리기로 다시 살린다', (tester) async {
      final templates = FakeTemplatesRepository(const [principal, rent]);
      await pumpTemplates(tester, templates: templates);

      await tapInList(tester, const ValueKey('template-rent'));
      await tapInForm(tester, const Key('template-delete'));
      await settleRoute(tester);

      expect(find.byType(TemplateFormScreen), findsNothing);
      expect(find.byKey(const ValueKey('template-rent')), findsNothing);
      expect(textIn(tester, const Key('templates-count')), '1개');
      expect(
        find.byKey(const Key('template-deleted-snack-bar')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('restore-template')));
      await settle(tester);

      expect(templates.restored.single.id, 'rent');
      expect(find.byKey(const ValueKey('template-rent')), findsOneWidget);
      expect(textIn(tester, const Key('templates-count')), '2개 · 금액 미정 1개');
    });

    testWidgets('오프라인이면 저장하지 않고 연결 안내를 띄운다', (tester) async {
      final templates = FakeTemplatesRepository(const [rent])..offline = true;
      await pumpTemplates(tester, templates: templates);

      await tapInList(tester, const ValueKey('template-rent'));
      await tapInForm(tester, const Key('template-save'));

      expect(find.byType(TemplateFormScreen), findsOneWidget);
      expect(
        findSentence('인터넷에 연결된 뒤에 다시 시도해 주세요. 고정 지출은 연결돼 있을 때만 바꿀 수 있어요.'),
        findsOneWidget,
      );
    });
  });

  group('그달 기본 지출 만들기', () {
    testWidgets('이번 달을 열면 고정 지출로 그달 기본 지출이 생겨 요약·항목 탭에 보인다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpLedger(tester, entries: entries);

      expect(entries.filled.single.month, october);
      await scrollTo(tester, const Key('planned-total'));
      expect(textOf(tester, const Key('planned-total')), '800,000원');
      expect(findSentence('금액 미정 1건은 합계에서 빠져 있어요'), findsOneWidget);

      await openTab(tester, HomeTab.entries);
      expect(find.byKey(const ValueKey('entry-principal')), findsOneWidget);
      expect(find.byKey(const ValueKey('entry-rent')), findsOneWidget);
      // 지급 전이라 고정 지출에서 옮긴 예정일을 보여준다.
      expect(find.text('자동이체 · 10/25 예정'), findsOneWidget);
      expect(find.text('공동 통장 · 말일 예정'), findsOneWidget);
      expect(find.text('지급 전 2건'), findsOneWidget);
    });

    testWidgets('다음 달도 열면 만들고, 지난 달은 만들지 않는다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpLedger(tester, entries: entries);
      await openTab(tester, HomeTab.entries);

      await swipeMonth(tester);
      expect(
        entries.monthOf(const YearMonth(2026, 11)).plannedExpenses,
        hasLength(2),
      );
      expect(find.text('자동이체 · 11/25 예정'), findsOneWidget);
      expect(find.text('공동 통장 · 말일 예정'), findsOneWidget);

      await swipeMonth(tester, next: false);
      await swipeMonth(tester, next: false);
      expect(
        entries.monthOf(const YearMonth(2026, 9)).plannedExpenses,
        isEmpty,
      );
      expect(find.byKey(const Key('entries-empty')), findsOneWidget);
      expect(entries.filled.map((f) => f.month), [
        october,
        const YearMonth(2026, 11),
      ]);
    });

    testWidgets('휴지통에 넣은 이번 달 기본 지출은 다시 만들지 않는다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpLedger(tester, entries: entries);
      await entries.trash(
        ledgerId: 'l1',
        month: october,
        kind: EntryKind.planned,
        id: 'rent',
        uid: 'me',
      );
      await settle(tester);

      // 다른 달에 갔다가 돌아와도 관리비는 휴지통에 그대로 있다.
      await openTab(tester, HomeTab.entries);
      await swipeMonth(tester);
      await swipeMonth(tester, next: false);

      expect(entries.monthOf(october).plannedExpenses.map((e) => e.id), [
        'principal',
      ]);
      expect(find.byKey(const ValueKey('entry-rent')), findsNothing);
    });

    testWidgets('고정 지출을 더하면 이번 달 기본 지출에도 바로 들어간다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpTemplates(
        tester,
        templates: FakeTemplatesRepository(const [principal]),
        entries: entries,
      );

      await tapInList(tester, const Key('add-template'));
      await enterInForm(tester, const Key('template-title'), '관리비');
      await tapInForm(tester, const Key('template-member-partner'));
      await tapInForm(tester, const Key('template-category-c-spending'));
      await tapInForm(tester, const Key('template-method-p-account'));
      await pickDueDay(tester, lastDueDay);
      await tapInForm(tester, const Key('template-save'));
      await settleRoute(tester);
      await openTab(tester, HomeTab.entries);

      expect(entries.monthOf(october).plannedExpenses.map((e) => e.title), [
        '주택담보대출 원금',
        '관리비',
      ]);
      expect(find.text('공동 통장 · 말일 예정'), findsOneWidget);
    });

    testWidgets('보기 전용은 그달 기본 지출을 만들지 않는다', (tester) async {
      final entries = FakeEntriesRepository();
      await pumpLedger(
        tester,
        entries: entries,
        ledger: const Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'partner-uid',
          roles: {'me': MemberRole.viewer},
        ),
      );
      await openTab(tester, HomeTab.entries);

      expect(entries.filled, isEmpty);
      expect(find.byKey(const Key('entries-empty')), findsOneWidget);
    });
  });

  group('넓은 화면', () {
    testWidgets('옆 탭 막대로 고정 지출 탭을 열고, 입력 화면은 가운데 좁게 둔다', (tester) async {
      await pumpTemplates(tester, size: tabletSize);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(const ValueKey('template-rent')), findsOneWidget);
      final total = tester.getRect(
        inList(find.byKey(const Key('templates-total'))),
      );
      // 본문은 가운데 640폭이다.
      expect(total.left, greaterThan((tabletSize.width - 640) / 2));

      await tapInList(tester, const Key('add-template'));
      await showInForm(tester, const Key('template-save'));
      final save = tester.getRect(
        inForm(find.byKey(const Key('template-save'))),
      );
      expect(save.width, lessThanOrEqualTo(560 - 40));
      expect(save.center.dx, closeTo(tabletSize.width / 2, 1));
    });
  });
}
