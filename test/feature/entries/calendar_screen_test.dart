import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/holidays.dart';
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

// 2026년 10월 공휴일. 3일은 토요일이지만 개천절, 5일은 대체공휴일, 9일은 한글날이다.
const holidays2026 = Holidays({
  '2026-10-03': '개천절',
  '2026-10-05': '대체공휴일',
  '2026-10-09': '한글날',
});

/// 요약 탭에서 달 이름을 눌러 달력을 연다.
Future<FakeEntriesRepository> openCalendar(
  WidgetTester tester, {
  Ledger ledger = mine,
  Size size = phoneSize,
  FakeHolidaysRepository? holidays,
}) async {
  final entries = FakeEntriesRepository({october: octoberLedger()});
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([ledger]),
    settings: settings,
    entries: entries,
    holidays: holidays ?? FakeHolidaysRepository({2026: holidays2026}),
    size: size,
  );
  await tester.tap(find.byKey(const Key('open-calendar')));
  await settleRoute(tester);
  return entries;
}

Finder day(int day) => find.byKey(ValueKey('calendar-day-$day'));

Finder inDay(int number, Finder finder) =>
    find.descendant(of: day(number), matching: finder);

String? calendarTitle(WidgetTester tester) =>
    textOf(tester, const Key('calendar-month-title'));

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
      expect(calendarTitle(tester), '10월');
      expect(dayTitle(tester), '10월 15일 목요일');
      expect(find.byKey(const Key('calendar-day-empty')), findsOneWidget);
    });

    testWidgets('항목 탭에서도 달 이름으로 달력을 열고, 뒤로 단추로 닫는다', (tester) async {
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

      await tester.tap(find.byKey(const Key('calendar-back')));
      await settleRoute(tester);

      expect(find.byType(CalendarScreen), findsNothing);
      expect(find.byKey(HomeTab.entries.key), findsOneWidget);
    });

    testWidgets('달 이름의 누르는 곳은 머리말과 달력 위 모두 높이 48 이상이다', (tester) async {
      await openCalendar(tester);
      expect(
        tester.getSize(find.byKey(const Key('calendar-month'))).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.byKey(const Key('calendar-back')));
      await settleRoute(tester);
      expect(
        tester.getSize(find.byKey(const Key('open-calendar'))).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('글자를 두 배로 키워도 오늘 단추의 글자가 한 줄이다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openCalendar(tester);

      final today = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const Key('calendar-today')),
          matching: find.text('오늘'),
        ),
      );
      // 두 글자의 줄 위치가 같아야 한다('오/늘'로 갈리지 않음).
      final lines = today
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 2),
          )
          .map((box) => box.top)
          .toSet();
      expect(lines, hasLength(1));
      expect(today.didExceedMaxLines, isFalse);
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
          label: '10월',
          hint: '달력 열기',
          isButton: true,
          isHeader: true,
          hasTapAction: true,
          // 항목 있는 달이 아직 없어서 이번 달이 첫 달이다. 다음 달로만 옮길 수 있다.
          hasIncreaseAction: true,
          hasDecreaseAction: false,
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

    testWidgets('공휴일은 일요일처럼 빨간 숫자이고, 칸과 고른 날 제목에서 이름을 알린다', (tester) async {
      final semantics = tester.ensureSemantics();
      await openCalendar(tester);
      final error = Theme.of(tester.element(day(3))).colorScheme.error;
      Color? numberColor(int number) =>
          tester.widget<Text>(inDay(number, find.text('$number'))).style?.color;

      expect(numberColor(3), error);
      expect(numberColor(5), error);
      expect(numberColor(9), error);
      expect(numberColor(10), isNot(error));
      expect(numberColor(11), error);
      expect(
        tester.getSemantics(day(9)),
        isSemantics(label: '10월 9일 금요일, 한글날', isButton: true),
      );

      await tester.tap(day(9));
      await settle(tester);
      expect(textOf(tester, const Key('calendar-day-holiday')), '한글날');
      await tester.tap(day(8));
      await settle(tester);
      expect(find.byKey(const Key('calendar-day-holiday')), findsNothing);
      semantics.dispose();
    });

    testWidgets('그해 공휴일을 아직 받지 못했으면 일요일만 빨갛고, 그해 문서 하나만 구독한다', (tester) async {
      final holidays = FakeHolidaysRepository();
      await openCalendar(tester, holidays: holidays);
      final error = Theme.of(tester.element(day(3))).colorScheme.error;
      Color? numberColor(int number) =>
          tester.widget<Text>(inDay(number, find.text('$number'))).style?.color;

      expect(numberColor(3), isNot(error));
      expect(numberColor(4), error);
      expect(holidays.watched.toSet(), {2026});
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

    testWidgets('휴지통에 넣고 돌아온 뒤 달력을 닫아도 되돌리기로 다시 꺼낸다', (tester) async {
      // 요약 탭에서 연 달력이라, 달력을 닫으면 항목 컨트롤러를 듣는 화면이 없다.
      final entries = await openCalendar(tester);
      await tester.tap(day(18));
      await settle(tester);
      await tapShown(tester, find.byKey(const ValueKey('calendar-entry-mart')));
      await settleRoute(tester);
      await tapShown(tester, find.byKey(const Key('entry-trash')));
      await settleRoute(tester);
      expect(entries.trashed.single.id, 'mart');

      await tester.tap(find.byKey(const Key('calendar-back')));
      await settleRoute(tester);
      expect(find.byType(CalendarScreen), findsNothing);
      await tester.tap(find.byKey(const Key('restore-entry')));
      await settle(tester);

      expect(entries.restored.single.id, 'mart');
    });

    testWidgets('가계부가 없는 달의 빈 날을 누르면 새로 만들지 묻고, 취소하면 입력 화면을 열지 않는다', (
      tester,
    ) async {
      await openCalendar(
        tester,
        ledger: Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'me',
          months: {october},
        ),
      );
      await tester.fling(
        find.byKey(const Key('calendar-swipe')),
        const Offset(300, 0),
        800,
      );
      await settleRoute(tester);
      expect(calendarTitle(tester), '9월');

      await tapShown(tester, find.byKey(const Key('calendar-day-empty')));
      expect(find.byKey(const Key('add-month-dialog')), findsOneWidget);
      expect(findSentence('2026년 9월에는 가계부가 없어요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-month-cancel')));
      await settleRoute(tester);

      expect(find.byKey(const Key('add-month-dialog')), findsNothing);
      expect(find.byType(EntryFormScreen), findsNothing);
    });

    testWidgets('추가를 고르면 그날로 입력 화면을 열고, 저장하면 그달이 탭에서도 오가는 달이 된다', (
      tester,
    ) async {
      final entries = await openCalendar(
        tester,
        ledger: Ledger(
          id: 'l1',
          name: '우리 가계부',
          ownerUid: 'me',
          months: {october},
        ),
      );
      await tester.fling(
        find.byKey(const Key('calendar-swipe')),
        const Offset(300, 0),
        800,
      );
      await settleRoute(tester);

      await tapShown(tester, find.byKey(const Key('calendar-day-empty')));
      await tester.tap(find.byKey(const Key('add-month-confirm')));
      await settleRoute(tester);
      expect(find.text('2026년 9월 1일'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('entry-amount')), '5000');
      await tester.enterText(find.byKey(const Key('entry-title')), '간식');
      await tapShown(tester, find.byKey(const Key('entry-method-p-shared')));
      await tapShown(tester, find.byKey(const Key('entry-save')));
      await settleRoute(tester);

      expect(entries.added.single.month, const YearMonth(2026, 9));
      expect(entries.recordedMonths, [const YearMonth(2026, 9)]);
      // 이제 9월은 항목 있는 달이라, 닫아도 탭이 9월에 머문다.
      await tester.tap(find.byKey(const Key('calendar-back')));
      await settleRoute(tester);
      expect(monthTitle(tester), '9월');
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
    testWidgets('달력을 왼쪽으로 밀면 다음 달 1일을 고르고, 오늘을 누르면 이번 달 오늘로 돌아온다', (
      tester,
    ) async {
      await openCalendar(tester);

      await tester.fling(
        find.byKey(const Key('calendar-swipe')),
        const Offset(-300, 0),
        800,
      );
      // 판이 멈추는 모습(튕김)은 settle보다 길다.
      await settleRoute(tester);
      expect(calendarTitle(tester), '11월');
      expect(dayTitle(tester), '11월 1일 일요일');

      await tester.tap(find.byKey(const Key('calendar-today')));
      await settle(tester);
      expect(calendarTitle(tester), '10월');
      expect(dayTitle(tester), '10월 15일 목요일');
    });

    testWidgets('판은 손가락을 따라 다음 달과 함께 밀리고, 반이 안 되게 밀다 놓으면 그 달로 돌아온다', (
      tester,
    ) async {
      await openCalendar(tester);
      final grid = find.byKey(const Key('calendar-swipe'));
      final width = tester.getSize(grid).width;
      expect(day(30), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(grid));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(Offset(-width * 0.1, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 미는 동안에는 10월 30일과 오른쪽에서 들어오는 11월 30일이 같이 보이고, 달은 아직 그대로다.
      expect(day(30), findsNWidgets(2));
      expect(calendarTitle(tester), '10월');

      // 멈췄다가 놓으면(튕기지 않으면) 반을 넘지 않았으니 10월로 돌아온다.
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await settleRoute(tester);
      expect(calendarTitle(tester), '10월');
      expect(dayTitle(tester), '10월 15일 목요일');
      expect(day(30), findsOneWidget);
    });

    testWidgets('앞뒤 달 항목도 미리 받아 두어, 넘기자마자 그달 목록을 보여준다', (tester) async {
      final entries = await openCalendar(tester);

      expect(
        entries.watched.map((watch) => watch.month),
        containsAll([
          const YearMonth(2026, 9),
          october,
          const YearMonth(2026, 11),
        ]),
      );

      await tester.fling(
        find.byKey(const Key('calendar-swipe')),
        const Offset(300, 0),
        800,
      );
      await settleRoute(tester);
      expect(calendarTitle(tester), '9월');
      expect(find.byKey(const Key('calendar-loading')), findsNothing);
      expect(find.byKey(const Key('calendar-day-empty')), findsOneWidget);
    });

    testWidgets('달 이름을 오른쪽으로 밀면 이전 달로 가고, 해가 바뀌면 연도를 붙인다', (tester) async {
      await openCalendar(tester);

      for (var i = 0; i < 10; i++) {
        await tester.fling(
          find.byKey(const Key('calendar-month-title')),
          const Offset(200, 0),
          800,
        );
        await settle(tester);
      }

      expect(calendarTitle(tester), '2025년 12월');
    });

    testWidgets('달 이름을 누르면 연·월 휠 시트로 다른 달로 가고, 항목 없는 달이면 닫을 때 탭은 연 달로 돌아온다', (
      tester,
    ) async {
      await openCalendar(tester);

      await tester.tap(find.byKey(const Key('calendar-month')));
      await settleRoute(tester);
      expect(find.byType(MonthPickerSheet), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('month-picker-months')),
        const Offset(0, monthPickerItemExtent * 7),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month-picker-done')));
      await settleRoute(tester);

      expect(calendarTitle(tester), '3월');
      expect(dayTitle(tester), '3월 1일 일요일');
      await tester.tap(find.byKey(const Key('calendar-back')));
      await settleRoute(tester);
      expect(monthTitle(tester), '10월');
    });

    testWidgets('요약·항목 탭이 오가는 달로 옮기고 닫으면 탭도 그 달을 본다', (tester) async {
      await openCalendar(tester);

      await tester.fling(
        find.byKey(const Key('calendar-swipe')),
        const Offset(-300, 0),
        800,
      );
      await settleRoute(tester);
      expect(calendarTitle(tester), '11월');
      await tester.tap(find.byKey(const Key('calendar-back')));
      await settleRoute(tester);

      expect(monthTitle(tester), '11월');
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
