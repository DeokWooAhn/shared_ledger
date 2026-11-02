import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/widget/month_picker_sheet.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/entries/entries_screen.dart';
import 'package:shared_ledger/feature/months/months_sheet.dart';
import 'package:shared_ledger/feature/summary/summary_screen.dart';

import '../../../testing/app.dart';
import '../../../testing/fakes.dart';

const me = AuthUser(uid: 'me');
const september = YearMonth(2026, 9);
const october = YearMonth(2026, 10);

Ledger ledgerWith(Set<YearMonth> months, {Map<String, MemberRole>? roles}) =>
    Ledger(
      id: 'l1',
      name: '우리 가계부',
      ownerUid: roles == null ? 'me' : 'partner',
      roles: roles ?? const {},
      months: months,
    );

const rent = ExpenseTemplate(
  id: 'rent',
  title: '관리비',
  amount: 200000,
  categoryId: 'c-living',
  paymentMethodId: 'p-account',
  memberId: 'owner',
  dueDay: 25,
);

/// [tab] 탭에서 머리말의 달 이름을 눌러 달 고르기를 연다.
Future<FakeLedgerRepository> pumpMonths(
  WidgetTester tester, {
  required Ledger ledger,
  HomeTab tab = HomeTab.home,
  FakeEntriesRepository? entries,
  FakeTemplatesRepository? templates,
}) async {
  final ledgers = FakeLedgerRepository([ledger]);
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: me),
    ledgers: ledgers,
    entries: entries,
    templates: templates,
  );
  await openTab(tester, tab);
  await tester.tap(find.byKey(const Key('open-months')));
  await settleRoute(tester);
  return ledgers;
}

Finder inMonths(Finder finder) =>
    find.descendant(of: find.byType(MonthsSheet), matching: finder);

void main() {
  testWidgets('추가한 달만 해별로 최근 달부터 보여 주고, 이번 달 표시를 단다', (tester) async {
    await pumpMonths(
      tester,
      ledger: ledgerWith({
        const YearMonth(2025, 12),
        september,
        october,
        const YearMonth(2026, 11),
      }),
    );

    expect(inMonths(find.text('2026년')), findsOneWidget);
    expect(inMonths(find.text('2025년')), findsOneWidget);
    final rows = [
      for (final month in ['2026-11', '2026-10', '2026-09', '2025-12'])
        tester.getTopLeft(find.byKey(ValueKey('month-$month'))).dy,
    ];
    expect(rows, orderedEquals([...rows]..sort()));
    expect(inMonths(find.text('이번 달')), findsOneWidget);
  });

  testWidgets('이번 달을 추가하지 않았으면 보이지 않는다', (tester) async {
    await pumpMonths(tester, ledger: ledgerWith({september}));

    expect(find.byKey(const ValueKey('month-2026-09')), findsOneWidget);
    expect(find.byKey(const ValueKey('month-2026-10')), findsNothing);
    expect(inMonths(find.text('이번 달')), findsNothing);
  });

  testWidgets('달을 누르면 그달로 바꾸고 닫으며, 보던 탭에 그대로 있다', (tester) async {
    await pumpMonths(
      tester,
      ledger: ledgerWith({september, october}),
      tab: HomeTab.entries,
    );
    expect(inMonths(find.byIcon(Icons.check)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('month-2026-09')));
    await settleRoute(tester);

    expect(find.byType(MonthsSheet), findsNothing);
    expect(find.byType(EntriesScreen), findsOneWidget);
    expect(monthTitle(tester), '9월');
  });

  testWidgets('달을 추가하면 반복 설정으로 채우고, 시트를 닫고 그달을 본다', (tester) async {
    final entries = FakeEntriesRepository();
    await pumpMonths(
      tester,
      ledger: ledgerWith({september, october}),
      entries: entries,
      templates: FakeTemplatesRepository(const [rent]),
    );

    await tester.tap(find.byKey(const Key('add-month')));
    await settleRoute(tester);
    // 이번 달이 있으면 마지막 달의 다음 달(11월)부터 보여준다.
    expect(find.text('2026년 11월'), findsOneWidget);
    await tester.tap(find.byKey(const Key('month-picker-done')));
    await settleRoute(tester);

    expect(entries.recordedMonths, [const YearMonth(2026, 11)]);
    expect(find.byType(MonthsSheet), findsNothing);
    expect(
      entries.monthOf(const YearMonth(2026, 11)).plannedExpenses.single.id,
      rent.id,
    );
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(monthTitle(tester), '11월');
  });

  testWidgets('이미 있는 달을 고르면 새로 만들지 않고 그달로 간다', (tester) async {
    final entries = FakeEntriesRepository();
    await pumpMonths(
      tester,
      ledger: ledgerWith({september, october}),
      entries: entries,
    );

    await tester.tap(find.byKey(const Key('add-month')));
    await settleRoute(tester);
    await tester.drag(
      find.byKey(const Key('month-picker-months')),
      const Offset(0, monthPickerItemExtent * 2),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('month-picker-done')));
    await settleRoute(tester);

    expect(entries.filled, isEmpty);
    expect(find.byType(MonthsSheet), findsNothing);
    expect(monthTitle(tester), '9월');
  });

  testWidgets('연결이 없으면 추가하지 못했다고 시트 안에 알리고 시트에 남는다', (tester) async {
    final entries = FakeEntriesRepository()..offline = true;
    await pumpMonths(tester, ledger: ledgerWith({october}), entries: entries);

    await tester.tap(find.byKey(const Key('add-month')));
    await settleRoute(tester);
    await tester.tap(find.byKey(const Key('month-picker-done')));
    await settleRoute(tester);

    expect(
      inMonths(findSentence('연결되지 않아 달을 추가하지 못했어요. 연결된 뒤에 다시 해 주세요.')),
      findsOneWidget,
    );
    expect(find.byType(MonthsSheet), findsOneWidget);
  });

  testWidgets('휴지통에서도 달 이름을 눌러 달 고르기로 다른 달의 휴지통을 본다', (tester) async {
    await pumpApp(
      tester,
      auth: FakeAuthRepository(signedIn: me),
      ledgers: FakeLedgerRepository([
        ledgerWith({september, october}),
      ]),
    );
    await openTab(tester, HomeTab.settings);
    await tapVisible(tester, const Key('open-trash'));
    await settleRoute(tester);

    await tester.tap(find.byKey(const Key('open-months')));
    await settleRoute(tester);
    await tester.tap(find.byKey(const ValueKey('month-2026-09')));
    await settleRoute(tester);

    expect(findSentence('9월 휴지통이 비어 있어요.'), findsOneWidget);
  });

  testWidgets('달 목록을 모으지 못한 옛 가계부의 보기 전용은 연·월 휠로 아무 달이나 고른다', (tester) async {
    // 보기 전용은 달 목록을 모을 수 없어서 months가 null로 남는다.
    await pumpMonths(
      tester,
      ledger: const Ledger(
        id: 'l1',
        name: '우리 가계부',
        ownerUid: 'partner',
        roles: {'me': MemberRole.viewer},
      ),
    );

    expect(inMonths(find.byType(CircularProgressIndicator)), findsNothing);
    expect(find.byKey(const Key('add-month')), findsNothing);
    await tester.tap(find.byKey(const Key('pick-any-month')));
    await settleRoute(tester);
    await tester.drag(
      find.byKey(const Key('month-picker-months')),
      const Offset(0, monthPickerItemExtent * 2),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('month-picker-done')));
    await settleRoute(tester);

    expect(find.byType(MonthsSheet), findsNothing);
    expect(monthTitle(tester), '8월');
  });

  testWidgets('보기 전용은 달을 추가할 수 없다', (tester) async {
    await pumpMonths(
      tester,
      ledger: ledgerWith({october}, roles: const {'me': MemberRole.viewer}),
    );

    expect(find.byKey(const Key('add-month')), findsNothing);
    expect(find.byKey(const ValueKey('month-2026-10')), findsOneWidget);
  });
}
