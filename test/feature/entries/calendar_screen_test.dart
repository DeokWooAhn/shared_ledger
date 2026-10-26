import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/payment_method.dart';
import 'package:shared_ledger/core/model/year_month.dart';
import 'package:shared_ledger/core/widget/month_picker_sheet.dart';
import 'package:shared_ledger/feature/entries/calendar_screen.dart';
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
  ],
  paymentMethods: const [
    PaymentMethod(id: 'p-account', name: '공동 통장', kind: PaymentKind.account),
    PaymentMethod(id: 'p-auto', name: '자동이체', kind: PaymentKind.autoTransfer),
    PaymentMethod(id: 'p-shared', name: '공용 카드', kind: PaymentKind.card),
  ],
);

// 디자인(design/app/08)과 같은 구성의 가상 10월.
MonthLedger octoberLedger() => MonthLedger(
  incomes: [
    Income(
      id: 'salary',
      memberId: 'partner',
      title: '급여',
      amount: 2700000,
      receivedOn: DateTime(2026, 10, 10),
    ),
  ],
  extraExpenses: [
    ExtraExpense(
      id: 'mart',
      memberId: 'partner',
      title: '마트 장보기',
      paymentMethodId: 'p-shared',
      amount: 186000,
      spentOn: DateTime(2026, 10, 18),
    ),
    ExtraExpense(
      id: 'dinner',
      memberId: 'owner',
      title: '외식',
      paymentMethodId: 'p-shared',
      amount: 72000,
      spentOn: DateTime(2026, 10, 18),
    ),
    const ExtraExpense(
      id: 'gift',
      memberId: 'owner',
      title: '경조사',
      paymentMethodId: 'p-account',
      amount: 100000,
    ),
  ],
  plannedExpenses: [
    PlannedExpense(
      id: 'principal',
      categoryId: 'c-principal',
      memberId: 'owner',
      title: '주택담보대출 원금',
      paymentMethodId: 'p-auto',
      amount: 800000,
      dueOn: DateTime(2026, 10, 25),
    ),
  ],
);

/// 요약 탭에서 달 이름을 눌러 달력을 연다.
Future<FakeEntriesRepository> openCalendar(
  WidgetTester tester, {
  Ledger ledger = mine,
  Size size = phoneSize,
}) async {
  final entries = FakeEntriesRepository({october: octoberLedger()});
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([ledger]),
    settings: settings,
    entries: entries,
    size: size,
  );
  await tester.tap(find.byKey(const Key('open-calendar')));
  await settleRoute(tester);
  return entries;
}

Finder day(int day) => find.byKey(ValueKey('calendar-day-$day'));

Finder inDay(int number, Finder finder) =>
    find.descendant(of: day(number), matching: finder);

String? dayTitle(WidgetTester tester) =>
    textOf(tester, const Key('calendar-day-title'));

Future<void> tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  group('열고 닫기', () {
    testWidgets('요약 탭의 달 이름을 누르면 달력이 열리고 오늘을 고른다', (tester) async {
      await openCalendar(tester);

      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(dayTitle(tester), '10월 15일 목요일');
      expect(find.byKey(const Key('calendar-day-empty')), findsOneWidget);
    });

    testWidgets('항목 탭에서도 달 이름으로 달력을 열고, 뒤로 가면 닫힌다', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([mine]),
        settings: settings,
        entries: FakeEntriesRepository({october: octoberLedger()}),
      );
      await openTab(tester, HomeTab.entries);
      await tester.tap(find.byKey(const Key('open-calendar')));
      await settleRoute(tester);
      expect(find.byType(CalendarScreen), findsOneWidget);
      // 닫기 단추가 없다. Android 뒤로가기(iOS는 왼쪽 끝 밀기)로 닫는다.
      expect(find.byKey(const Key('calendar-close')), findsNothing);

      await tester.binding.handlePopRoute();
      await settleRoute(tester);

      expect(find.byType(CalendarScreen), findsNothing);
      expect(find.byKey(HomeTab.entries.key), findsOneWidget);
    });

    testWidgets('머리말의 달 이름은 화면 읽기 도구가 달력 열기 단추로 읽는다', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(signedIn: me),
        ledgers: FakeLedgerRepository([mine]),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('open-calendar'))),
        isSemantics(
          label: '2026년 10월',
          hint: '달력 열기',
          isButton: true,
          isHeader: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('날짜 칸', () {
    testWidgets('들어온 돈·나간 돈·예정을 짧게 보여주고, 날짜 없는 항목 수를 알린다', (tester) async {
      await openCalendar(tester);

      expect(inDay(10, find.text('+270만')), findsOneWidget);
      expect(inDay(18, find.text('-25.8만')), findsOneWidget);
      expect(inDay(25, find.text('예정')), findsOneWidget);
      expect(inDay(25, find.textContaining('80')), findsNothing);
      expect(findSentence('날짜 없는 항목 1건은 항목 탭에서 볼 수 있어요.'), findsOneWidget);
    });

    testWidgets('화면 읽기 도구는 칸을 한 문장으로 읽고 누를 수 있다', (tester) async {
      final semantics = tester.ensureSemantics();
      await openCalendar(tester);

      expect(
        tester.getSemantics(day(10)),
        isSemantics(
          label: '10월 10일 토요일, 들어온 돈 2,700,000원',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(day(15)),
        isSemantics(label: '10월 15일 목요일, 오늘', isSelected: true),
      );
      semantics.dispose();
    });
  });

  group('고른 날', () {
    testWidgets('날짜를 누르면 그날 항목을 종류와 함께 보여주고 합계를 낸다', (tester) async {
      await openCalendar(tester);

      await tester.tap(day(18));
      await settle(tester);

      expect(dayTitle(tester), '10월 18일 일요일');
      expect(textOf(tester, const Key('calendar-day-total')), '-258,000원');
      expect(find.text('항목 2건'), findsOneWidget);
      expect(find.text('추가지출 · 공용 카드 · 10/18'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('calendar-entry-mart')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-entry-dinner')),
        findsOneWidget,
      );
    });

    testWidgets('예정만 있는 날은 지급 전 표시와 지급 완료 안내를 보여준다', (tester) async {
      await openCalendar(tester);

      await tester.tap(day(25));
      await settle(tester);

      expect(find.text('예정 1건'), findsOneWidget);
      expect(textOf(tester, const Key('calendar-day-total')), '-800,000원 예정');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-entry-principal')),
          matching: find.text('지급 전'),
        ),
        findsOneWidget,
      );
      expect(findSentence('예정 항목을 누르면 지급 완료로 바꿀 수 있어요.'), findsOneWidget);
    });

    testWidgets('항목을 누르면 고치는 화면이 열린다', (tester) async {
      await openCalendar(tester);
      await tester.tap(day(18));
      await settle(tester);

      await tapShown(tester, find.byKey(const ValueKey('calendar-entry-mart')));
      await settleRoute(tester);

      expect(find.byType(EntryFormScreen), findsOneWidget);
      expect(find.text('2026년 10월 18일'), findsOneWidget);
    });

    testWidgets('항목이 없는 날은 안내를 누르면 그 날짜로 추가지출을 열고, 저장하면 그날에 보인다', (
      tester,
    ) async {
      final entries = await openCalendar(tester);
      await tester.tap(day(16));
      await settle(tester);

      await tapShown(tester, find.byKey(const Key('calendar-day-empty')));
      await settleRoute(tester);
      expect(find.text('쓴 날'), findsOneWidget);
      expect(find.text('2026년 10월 16일'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('entry-amount')), '5000');
      await tester.enterText(find.byKey(const Key('entry-title')), '간식');
      await tapShown(tester, find.byKey(const Key('entry-method-p-shared')));
      await tapShown(tester, find.byKey(const Key('entry-save')));
      await settleRoute(tester);

      final added = entries.added.single;
      expect(added.month, october);
      expect(added.draft.kind, EntryKind.extra);
      expect(added.draft.date, DateTime(2026, 10, 16));
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.text('항목 1건'), findsOneWidget);
      expect(find.byKey(const Key('calendar-day-empty')), findsNothing);
    });

    testWidgets('항목이 있는 날에는 따로 추가 단추가 없다', (tester) async {
      await openCalendar(tester);
      await tester.tap(day(18));
      await settle(tester);

      expect(find.byKey(const Key('calendar-day-empty')), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('보기 전용은 빈 날 안내와 항목을 눌러도 입력 화면이 열리지 않는다', (tester) async {
      await openCalendar(
        tester,
        ledger: const Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'partner',
          roles: {'me': MemberRole.viewer},
        ),
      );
      await tester.tap(day(16));
      await settle(tester);
      await tapShown(tester, find.byKey(const Key('calendar-day-empty')));
      await settleRoute(tester);
      expect(find.byType(EntryFormScreen), findsNothing);

      await tester.tap(day(18));
      await settle(tester);
      await tapShown(tester, find.byKey(const ValueKey('calendar-entry-mart')));
      await settleRoute(tester);
      expect(find.byType(EntryFormScreen), findsNothing);
    });
  });

  group('달 옮기기', () {
    testWidgets('다음 달로 가면 1일을 고르고, 오늘을 누르면 이번 달 오늘로 돌아온다', (tester) async {
      await openCalendar(tester);

      await tester.tap(find.byKey(const Key('calendar-next-month')));
      await settle(tester);
      expect(find.text('2026년 11월'), findsOneWidget);
      expect(dayTitle(tester), '11월 1일 일요일');

      await tester.tap(find.byKey(const Key('calendar-today')));
      await settle(tester);
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(dayTitle(tester), '10월 15일 목요일');
    });

    testWidgets('달 이름을 누르면 달 고르기 시트로 다른 달로 가고, 탭도 그 달을 본다', (tester) async {
      await openCalendar(tester);

      await tester.tap(find.byKey(const Key('calendar-month')));
      await settleRoute(tester);
      expect(find.byType(MonthPickerSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('month-picker-3')));
      await settleRoute(tester);

      expect(find.text('2026년 3월'), findsOneWidget);
      expect(dayTitle(tester), '3월 1일 일요일');
      await tester.binding.handlePopRoute();
      await settleRoute(tester);
      expect(textOf(tester, const Key('month-title')), '2026년 3월');
    });
  });

  testWidgets('넓은 화면에서는 달력과 고른 날 목록을 두 칸으로 놓는다', (tester) async {
    await openCalendar(tester, size: tabletSize);

    expect(
      tester.getRect(find.byKey(const Key('calendar-day-title'))).left,
      greaterThan(tester.getRect(day(31)).right),
    );
  });
}
