import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/member.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/feature/entries/entries_screen.dart';
import 'package:shared_ledger/feature/entries/entry_form_screen.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/settings/categories_screen.dart';
import 'package:shared_ledger/feature/settings/payment_methods_screen.dart';
import 'package:shared_ledger/feature/settings/rename_sheet.dart';
import 'package:shared_ledger/feature/settings/setting_sheet.dart';
import 'package:shared_ledger/feature/settings/settings_screen.dart';
import 'package:shared_ledger/feature/templates/templates_screen.dart';

import '../../../testing/app.dart';
import '../../../testing/fakes.dart';

const me = AuthUser(uid: 'me', signInMethod: SignInMethod.google);
const october = YearMonth(2026, 10);

final mine = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'me',
  roles: const {'partner-uid': MemberRole.editor},
  createdAt: DateTime(2026, 10, 1, 9),
);
const asEditor = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'partner-uid',
  roles: {'me': MemberRole.editor},
);
const asViewer = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'partner-uid',
  roles: {'me': MemberRole.viewer},
);

const principal = Category(
  id: 'c-principal',
  name: '대출원금',
  countsAsSaving: true,
);
const living = Category(id: 'c-living', name: '소비');
const oldCategory = Category(id: 'c-old', name: '예전 분류', hidden: true);
const account = PaymentMethod(
  id: 'p-account',
  name: '공동 통장',
  kind: PaymentKind.account,
);
const sharedCard = PaymentMethod(
  id: 'p-shared',
  name: '공용 카드',
  kind: PaymentKind.card,
);

FakeSettingsRepository settingsOf({
  List<Category> categories = const [principal, living, oldCategory],
  List<PaymentMethod> paymentMethods = const [account, sharedCard],
}) => FakeSettingsRepository(
  categories: categories,
  paymentMethods: paymentMethods,
);

// 공용 카드로 낸 10월 기본 지출과 추가지출.
final cardMonth = MonthLedger(
  plannedExpenses: [
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
  extraExpenses: const [
    ExtraExpense(
      id: 'market',
      memberId: 'owner',
      title: '마트 장보기',
      paymentMethodId: 'p-shared',
      amount: 40000,
    ),
  ],
);

const phoneBill = ExpenseTemplate(
  id: 'phone',
  title: '통신비',
  amount: 98000,
  categoryId: 'c-living',
  paymentMethodId: 'p-shared',
  memberId: 'partner',
  dueDay: 21,
);

/// 앱을 띄우고 설정 탭을 연다.
Future<void> pumpSettings(
  WidgetTester tester, {
  Ledger? ledger,
  FakeLedgerRepository? ledgers,
  FakeSettingsRepository? settings,
  FakeEntriesRepository? entries,
  FakeTemplatesRepository? templates,
  Size size = phoneSize,
}) async {
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: me),
    ledgers: ledgers ?? FakeLedgerRepository([ledger ?? mine]),
    settings: settings ?? settingsOf(),
    entries: entries ?? FakeEntriesRepository(),
    templates: templates ?? FakeTemplatesRepository(),
    size: size,
  );
  await openTab(tester, HomeTab.settings);
}

// 탭 아래에 다른 화면이 겹쳐 있을 수 있어서 맨 위 화면 안의 것만 찾는다.
Finder inSheet(Finder finder) =>
    find.descendant(of: find.byType(BottomSheet), matching: finder);

Finder inSettings(Finder finder) =>
    find.descendant(of: find.byType(SettingsScreen), matching: finder);

Finder inCategories(Finder finder) =>
    find.descendant(of: find.byType(CategoriesScreen), matching: finder);

Finder inMethods(Finder finder) =>
    find.descendant(of: find.byType(PaymentMethodsScreen), matching: finder);

Finder inEntryForm(Finder finder) =>
    find.descendant(of: find.byType(EntryFormScreen), matching: finder);

Finder inEntries(Finder finder) =>
    find.descendant(of: find.byType(EntriesScreen), matching: finder);

/// 화면 아래쪽에 걸친 위젯도 다 보이게 옮긴 뒤 누른다.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

// 목록 화면을 여닫는 전환은 settle(400ms)보다 길다(Android 전환).
Future<void> openCategories(WidgetTester tester) async {
  await tapShown(tester, find.byKey(const Key('open-categories')));
  await settleRoute(tester);
}

Future<void> openMethods(WidgetTester tester) async {
  await tapShown(tester, find.byKey(const Key('open-payment-methods')));
  await settleRoute(tester);
}

/// 시트의 이름 칸에 [name]을 넣고 [saveKey]로 저장한다.
Future<void> saveInSheet(
  WidgetTester tester, {
  required Key fieldKey,
  required String name,
  required Key saveKey,
}) async {
  await tester.enterText(inSheet(find.byKey(fieldKey)), name);
  await tapShown(tester, inSheet(find.byKey(saveKey)));
}

// 입력 화면은 스크롤되므로 위젯이 화면 안에 들어오게 한 뒤 다룬다.
Future<void> showInEntryForm(WidgetTester tester, Key key) async {
  final finder = inEntryForm(find.byKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: inEntryForm(find.byType(Scrollable)).first,
    );
  }
  await tester.ensureVisible(finder);
  await settle(tester);
}

Future<void> tapInEntryForm(WidgetTester tester, Key key) async {
  await showInEntryForm(tester, key);
  await tester.tap(inEntryForm(find.byKey(key)));
  await settle(tester);
}

/// 항목 탭에서 [kind] 종류를 고르고 + 버튼으로 입력 화면을 연다.
Future<void> openEntryForm(WidgetTester tester, EntryKind kind) async {
  await openTab(tester, HomeTab.entries);
  await tester.tap(inEntries(find.byKey(Key('entry-kind-${kind.name}'))));
  await settle(tester);
  await tester.tap(find.byKey(const Key('add-entry')));
  await settleRoute(tester);
}

void main() {
  group('설정 탭', () {
    testWidgets('가계부 이름과 만든 달, 보이는 분류·결제수단 개수, 로그인 방법을 보여준다', (tester) async {
      await pumpSettings(tester);

      expect(find.text('우리 가계부'), findsOneWidget);
      expect(findSentence('구성원 2명 · 2026년 10월부터'), findsOneWidget);
      // 숨긴 분류(예전 분류)는 세지 않는다.
      expect(
        find.descendant(
          of: find.byKey(const Key('open-categories')),
          matching: find.text('2개'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('open-payment-methods')),
          matching: find.text('2개'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('sign-in-method')));
      expect(
        find.descendant(
          of: find.byKey(const Key('sign-in-method')),
          matching: find.text('Google'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('화면 읽기 도구는 설정 줄을 이름·값과 함께 버튼으로 읽는다', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSettings(tester);

      final row = tester.getSemantics(find.byKey(const Key('open-categories')));
      expect(row.label, contains('분류'));
      expect(row.label, contains('2개'));
      expect(row.flagsCollection.isButton, isTrue);
      final method = tester.getSemantics(
        find.byKey(const Key('sign-in-method')),
      );
      expect(method.flagsCollection.isButton, isFalse);
      semantics.dispose();
    });

    testWidgets('관리자는 연필 단추로 가계부 이름을 바꾼다', (tester) async {
      final ledgers = FakeLedgerRepository([mine]);
      await pumpSettings(tester, ledgers: ledgers);

      await tapShown(tester, find.byKey(const Key('rename-ledger')));
      expect(find.byType(RenameSheet), findsOneWidget);
      await saveInSheet(
        tester,
        fieldKey: const Key('rename-field'),
        name: '하늘바다 가계부',
        saveKey: const Key('rename-save'),
      );

      expect(find.byType(RenameSheet), findsNothing);
      expect(ledgers.renames, [(ledgerId: 'l1', name: '하늘바다 가계부')]);
      expect(inSettings(find.text('하늘바다 가계부')), findsOneWidget);
    });

    testWidgets('이름을 비우거나 연결이 없으면 시트 안에 알리고 닫지 않는다', (tester) async {
      final ledgers = FakeLedgerRepository([mine])..offline = true;
      await pumpSettings(tester, ledgers: ledgers);
      await tapShown(tester, find.byKey(const Key('rename-ledger')));

      await saveInSheet(
        tester,
        fieldKey: const Key('rename-field'),
        name: '  ',
        saveKey: const Key('rename-save'),
      );
      expect(findSentence('이름을 입력해 주세요.'), findsOneWidget);

      await saveInSheet(
        tester,
        fieldKey: const Key('rename-field'),
        name: '새 이름',
        saveKey: const Key('rename-save'),
      );
      expect(
        findSentence('인터넷에 연결된 뒤에 다시 시도해 주세요. 설정은 연결돼 있을 때만 바꿀 수 있어요.'),
        findsOneWidget,
      );
      expect(find.byType(RenameSheet), findsOneWidget);
      expect(ledgers.renames, isEmpty);
    });

    testWidgets('편집자는 가계부 이름은 못 바꾸고, 이름표를 바꾸면 항목 입력과 고정 지출에 바뀐 이름이 보인다', (
      tester,
    ) async {
      final settings = settingsOf();
      await pumpSettings(
        tester,
        ledger: asEditor,
        settings: settings,
        templates: FakeTemplatesRepository(const [phoneBill]),
      );

      expect(find.byKey(const Key('rename-ledger')), findsNothing);
      await tapShown(tester, find.byKey(const Key('member-partner')));
      await saveInSheet(
        tester,
        fieldKey: const Key('rename-field'),
        name: '파도',
        saveKey: const Key('rename-save'),
      );

      expect(settings.renamedMembers.single.slot, MemberSlot.partner);
      expect(inSettings(find.text('파도 (나)')), findsOneWidget);

      await openTab(tester, HomeTab.templates);
      expect(
        find.descendant(
          of: find.byType(TemplatesScreen),
          matching: find.text('공용 카드 · 파도'),
        ),
        findsOneWidget,
      );

      await openEntryForm(tester, EntryKind.extra);
      expect(
        inEntryForm(find.byKey(const Key('entry-member-partner'))),
        findsOneWidget,
      );
      expect(inEntryForm(find.text('파도')), findsOneWidget);
    });

    testWidgets('보기 전용은 연필이 없고 이름표를 눌러도 시트가 열리지 않는다', (tester) async {
      await pumpSettings(tester, ledger: asViewer);

      expect(find.byKey(const Key('rename-ledger')), findsNothing);
      await tapShown(tester, find.byKey(const Key('member-owner')));
      expect(find.byType(RenameSheet), findsNothing);
    });

    testWidgets('설정 시트(초대·이름)는 떠 있는 탭 막대에 가리지 않게 앱 맨 위에 뜬다', (tester) async {
      await pumpSettings(
        tester,
        ledger: const Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me'),
      );
      Finder sheetInShell() => find.descendant(
        of: find.byType(HomeShell),
        matching: find.byType(BottomSheet),
      );

      for (final key in [
        const Key('create-invite'),
        const Key('member-owner'),
      ]) {
        await tapShown(tester, find.byKey(key));
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(sheetInShell(), findsNothing);
        await tester.tapAt(const Offset(195, 40));
        await settle(tester);
        expect(find.byType(BottomSheet), findsNothing);
      }
    });

    testWidgets('목록 화면에서 뒤로 가거나 설정 탭을 다시 누르면 설정 첫 화면으로 돌아온다', (tester) async {
      await pumpSettings(tester);

      await openCategories(tester);
      expect(find.byType(CategoriesScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('sub-page-back')));
      await settleRoute(tester);
      expect(find.byType(CategoriesScreen), findsNothing);

      await openMethods(tester);
      expect(find.byType(PaymentMethodsScreen), findsOneWidget);
      await openTab(tester, HomeTab.settings);
      await settleRoute(tester);
      expect(find.byType(PaymentMethodsScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('분류', () {
    testWidgets('보이는 분류를 순서대로 두고, 숨긴 분류는 아래에 따로 모은다', (tester) async {
      await pumpSettings(tester);
      await openCategories(tester);

      expect(
        inCategories(find.byKey(const ValueKey('category-c-principal'))),
        findsOneWidget,
      );
      expect(inCategories(find.text('저축')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('hidden-categories')),
          matching: find.text('예전 분류'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('분류를 더하면 목록 맨 뒤에 보이고 항목 입력의 분류에서 고를 수 있다', (tester) async {
      final settings = settingsOf();
      await pumpSettings(tester, settings: settings);
      await openCategories(tester);

      await tapShown(tester, find.byKey(const Key('add-category')));
      await tester.tap(inSheet(find.byKey(const Key('category-saving'))));
      await settle(tester);
      await saveInSheet(
        tester,
        fieldKey: const Key('category-name'),
        name: '비상금',
        saveKey: const Key('category-save'),
      );

      expect(settings.addedCategories.single.draft, (
        name: '비상금',
        countsAsSaving: true,
      ));
      expect(settings.addedCategories.single.order, 3);
      expect(inCategories(find.text('비상금')), findsOneWidget);

      await openEntryForm(tester, EntryKind.planned);
      expect(
        inEntryForm(find.byKey(const Key('entry-category-category-new-1'))),
        findsOneWidget,
      );
    });

    testWidgets('같은 이름은 숨긴 분류와도 겹칠 수 없다', (tester) async {
      final settings = settingsOf();
      await pumpSettings(tester, settings: settings);
      await openCategories(tester);

      await tapShown(tester, find.byKey(const Key('add-category')));
      await saveInSheet(
        tester,
        fieldKey: const Key('category-name'),
        name: '예전 분류',
        saveKey: const Key('category-save'),
      );

      expect(findSentence('같은 이름이 이미 있어요.'), findsOneWidget);
      expect(settings.addedCategories, isEmpty);
    });

    testWidgets('분류를 숨기면 새 항목에서는 고를 수 없지만 지난 항목과 요약에는 그대로 보인다', (tester) async {
      final settings = settingsOf();
      await pumpSettings(
        tester,
        settings: settings,
        entries: FakeEntriesRepository({october: cardMonth}),
      );
      await openCategories(tester);

      await tapShown(
        tester,
        inCategories(find.byKey(const ValueKey('category-c-living'))),
      );
      await tapShown(tester, inSheet(find.byKey(const Key('setting-hide'))));

      expect(find.byKey(const Key('setting-outcome')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('hidden-categories')),
          matching: find.text('소비'),
        ),
        findsOneWidget,
      );

      // 새 기본 지출에서는 고를 수 없다.
      await openEntryForm(tester, EntryKind.planned);
      expect(
        inEntryForm(find.byKey(const Key('entry-category-c-living'))),
        findsNothing,
      );
      await tester.tap(inEntryForm(find.byKey(const Key('entry-close'))));
      await settleRoute(tester);

      // 그 분류를 쓰던 항목을 고칠 때는 그대로 보인다.
      await tester.tap(inEntries(find.text('통신비')));
      await settleRoute(tester);
      expect(
        inEntryForm(find.byKey(const Key('entry-category-c-living'))),
        findsOneWidget,
      );
      await tester.tap(inEntryForm(find.byKey(const Key('entry-close'))));
      await settleRoute(tester);

      // 그달에 쓴 항목이 있어서 요약의 분류 소계에도 남는다.
      await openTab(tester, HomeTab.summary);
      await tester.ensureVisible(find.byKey(const Key('planned-section')));
      expect(
        find.descendant(
          of: find.byKey(const Key('planned-section')),
          matching: find.text('소비'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('숨긴 분류는 시트에서 다시 보이게 한다', (tester) async {
      final settings = settingsOf();
      await pumpSettings(tester, settings: settings);
      await openCategories(tester);

      await tapShown(
        tester,
        inCategories(find.byKey(const ValueKey('category-c-old'))),
      );
      await tapShown(tester, inSheet(find.byKey(const Key('setting-show'))));

      expect(findSentence('다시 보이게 했어요.'), findsOneWidget);
      expect(find.byKey(const Key('hidden-categories')), findsNothing);
      expect(settings.categories.last.hidden, isFalse);
    });

    testWidgets('고정 지출이 쓰는 분류를 고치려 하면 숨겨도 고정 지출은 그대로라고 알린다', (tester) async {
      await pumpSettings(
        tester,
        templates: FakeTemplatesRepository(const [phoneBill]),
      );
      await openCategories(tester);

      await tapShown(
        tester,
        inCategories(find.byKey(const ValueKey('category-c-living'))),
      );

      expect(
        findSentence('고정 지출 1개가 이 분류를 써요. 숨겨도 그 고정 지출은 이 분류로 계속 만들어져요.'),
        findsOneWidget,
      );
    });

    testWidgets('보기 전용은 분류를 보기만 한다', (tester) async {
      await pumpSettings(tester, ledger: asViewer);
      await openCategories(tester);

      expect(find.byKey(const Key('view-only-notice')), findsOneWidget);
      expect(find.byKey(const Key('add-category')), findsNothing);
      await tester.tap(
        inCategories(find.byKey(const ValueKey('category-c-living'))),
      );
      await settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  group('결제수단·카드', () {
    testWidgets('카드를 추가하면 그 카드로 카드대금과 카드 지출을 적고, 요약에 카드별로 보인다', (tester) async {
      final settings = settingsOf(paymentMethods: const [account]);
      final entries = FakeEntriesRepository();
      await pumpSettings(tester, settings: settings, entries: entries);
      await openMethods(tester);

      await tapShown(tester, find.byKey(const Key('add-payment-method')));
      await tester.tap(inSheet(find.byKey(const Key('method-kind-card'))));
      await settle(tester);
      expect(
        inSheet(find.byKey(const Key('method-card-note'))),
        findsOneWidget,
      );
      await saveInSheet(
        tester,
        fieldKey: const Key('method-name'),
        name: '하늘 카드',
        saveKey: const Key('method-save'),
      );

      expect(settings.addedPaymentMethods.single.draft, (
        name: '하늘 카드',
        kind: PaymentKind.card,
      ));
      expect(inMethods(find.text('하늘 카드')), findsOneWidget);

      // 카드대금: 저번 달에 그 카드로 쓴 돈이 이번 달에 빠져나간다.
      await openEntryForm(tester, EntryKind.cardBill);
      await tester.enterText(
        inEntryForm(find.byKey(const Key('entry-amount'))),
        '320000',
      );
      await tapInEntryForm(tester, const Key('entry-card-method-new-1'));
      await tapInEntryForm(tester, const Key('entry-save'));
      await settleRoute(tester);
      expect(entries.added.single.draft.cardId, 'method-new-1');
      expect(inEntries(find.text('하늘 카드')), findsOneWidget);

      // 카드 지출: 이번 달에 쓴 돈은 다음 달 청구 예정이다.
      await openEntryForm(tester, EntryKind.extra);
      await tester.enterText(
        inEntryForm(find.byKey(const Key('entry-amount'))),
        '45000',
      );
      await tester.enterText(
        inEntryForm(find.byKey(const Key('entry-title'))),
        '외식',
      );
      await tapInEntryForm(tester, const Key('entry-method-method-new-1'));
      expect(
        inEntryForm(find.byKey(const Key('entry-card-note'))),
        findsOneWidget,
      );
      await tapInEntryForm(tester, const Key('entry-save'));
      await settleRoute(tester);
      expect(entries.added.last.draft.paymentMethodId, 'method-new-1');

      await openTab(tester, HomeTab.summary);
      await tester.ensureVisible(find.byKey(const Key('card-section')));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('card-method-new-1')),
          matching: find.text('45,000원'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('card-bills')),
          matching: find.text('320,000원'),
        ),
        findsOneWidget,
      );
      // 카드 지출은 이번 달 현금 유출이 아니고, 카드대금만 빠져나간다.
      expect(textOf(tester, const Key('cash-out')), '320,000원');
    });

    testWidgets('카드 이름을 바꾸면 항목·요약·고정 지출 탭에 바뀐 이름으로 보인다', (tester) async {
      final settings = settingsOf();
      await pumpSettings(
        tester,
        settings: settings,
        entries: FakeEntriesRepository({october: cardMonth}),
        templates: FakeTemplatesRepository(const [phoneBill]),
      );
      await openMethods(tester);

      await tapShown(
        tester,
        inMethods(find.byKey(const ValueKey('method-p-shared'))),
      );
      // 고칠 때는 종류를 바꿀 수 없다.
      expect(inSheet(find.byKey(const Key('method-kind-card'))), findsNothing);
      expect(findSentence('종류는 바꿀 수 없어요.'), findsOneWidget);
      await saveInSheet(
        tester,
        fieldKey: const Key('method-name'),
        name: '바다 카드',
        saveKey: const Key('method-save'),
      );
      expect(settings.renamedPaymentMethods.single, (
        ledgerId: 'l1',
        id: 'p-shared',
        name: '바다 카드',
        uid: 'me',
      ));

      await openTab(tester, HomeTab.entries);
      await tester.tap(inEntries(find.byKey(const Key('entry-kind-extra'))));
      await settle(tester);
      expect(inEntries(find.text('바다 카드')), findsOneWidget);

      await openTab(tester, HomeTab.summary);
      await tester.ensureVisible(find.byKey(const Key('card-section')));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('card-p-shared')),
          matching: find.text('바다 카드'),
        ),
        findsOneWidget,
      );

      await openTab(tester, HomeTab.templates);
      expect(
        find.descendant(
          of: find.byType(TemplatesScreen),
          matching: find.text('바다 카드 · 바다'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('카드를 숨기면 새 항목에서 고를 수 없지만 그 카드로 쓴 돈은 카드 사용분 그대로다', (
      tester,
    ) async {
      final settings = settingsOf();
      await pumpSettings(
        tester,
        settings: settings,
        entries: FakeEntriesRepository({october: cardMonth}),
      );
      await openMethods(tester);

      await tapShown(
        tester,
        inMethods(find.byKey(const ValueKey('method-p-shared'))),
      );
      await tapShown(tester, inSheet(find.byKey(const Key('setting-hide'))));
      expect(
        find.descendant(
          of: find.byKey(const Key('hidden-payment-methods')),
          matching: find.text('공용 카드'),
        ),
        findsOneWidget,
      );

      await openEntryForm(tester, EntryKind.cardBill);
      expect(
        inEntryForm(find.byKey(const Key('entry-card-p-shared'))),
        findsNothing,
      );
      expect(
        findSentence('카드가 아직 없어요. 설정에서 카드를 추가한 뒤 적어 주세요.'),
        findsOneWidget,
      );
      await tester.tap(inEntryForm(find.byKey(const Key('entry-close'))));
      await settleRoute(tester);

      await openTab(tester, HomeTab.summary);
      expect(textOf(tester, const Key('cash-out')), '0원');
      await tester.ensureVisible(find.byKey(const Key('card-usage')));
      expect(
        find.descendant(
          of: find.byKey(const Key('card-usage')),
          matching: find.text('138,000원'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('보기 전용은 결제수단을 보기만 한다', (tester) async {
      await pumpSettings(tester, ledger: asViewer);
      await openMethods(tester);

      expect(find.byKey(const Key('view-only-notice')), findsOneWidget);
      expect(find.byKey(const Key('add-payment-method')), findsNothing);
    });
  });

  group('넓은 화면', () {
    testWidgets('옆 탭 막대로 설정을 열고, 목록은 가운데 640폭, 시트는 560폭으로 둔다', (tester) async {
      await pumpSettings(tester, size: tabletSize);

      expect(find.byType(NavigationRail), findsOneWidget);
      await openMethods(tester);

      expect(tester.getSize(inMethods(find.byType(Card)).first).width, 640);

      await tapShown(
        tester,
        inMethods(find.byKey(const ValueKey('method-p-shared'))),
      );
      // 시트 틀은 화면 폭이고, 내용은 가운데 560폭이다.
      expect(tester.getSize(find.byType(SettingSheet)).width, 560);
    });
  });
}
