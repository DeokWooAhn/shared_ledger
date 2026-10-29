import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/widget/month_picker_sheet.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/months/months_screen.dart';
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

Future<FakeLedgerRepository> pumpMonths(
  WidgetTester tester, {
  required Ledger ledger,
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
  await openTab(tester, HomeTab.months);
  return ledgers;
}

Finder inMonths(Finder finder) =>
    find.descendant(of: find.byType(MonthsScreen), matching: finder);

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

  testWidgets('달을 누르면 그달로 바꾸고 요약 탭으로 간다', (tester) async {
    await pumpMonths(tester, ledger: ledgerWith({september, october}));

    await tester.tap(find.byKey(const ValueKey('month-2026-09')));
    await settle(tester);

    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(monthTitle(tester), '9월');
  });

  testWidgets('가계부를 추가하면 반복 설정으로 채우고 그달 요약으로 간다', (tester) async {
    final entries = FakeEntriesRepository();
    await pumpMonths(
      tester,
      ledger: ledgerWith({september, october}),
      entries: entries,
      templates: FakeTemplatesRepository(const [rent]),
    );

    await tester.tap(find.byKey(const Key('add-month')));
    await settle(tester);
    // 이번 달이 있으면 마지막 달의 다음 달(11월)부터 보여준다.
    expect(find.text('2026년 11월'), findsOneWidget);
    await tester.tap(find.byKey(const Key('month-picker-done')));
    await settle(tester);

    expect(entries.recordedMonths, [const YearMonth(2026, 11)]);
    expect(
      find.byKey(const ValueKey('month-2026-11')),
      findsNothing,
      reason: '요약 탭으로 옮겼다',
    );
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
    await settle(tester);
    await tester.drag(
      find.byKey(const Key('month-picker-months')),
      const Offset(0, monthPickerItemExtent * 2),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('month-picker-done')));
    await settle(tester);

    expect(entries.filled, isEmpty);
    expect(monthTitle(tester), '9월');
  });

  testWidgets('연결이 없으면 추가하지 못했다고 알리고 가계부 탭에 남는다', (tester) async {
    final entries = FakeEntriesRepository()..offline = true;
    await pumpMonths(tester, ledger: ledgerWith({october}), entries: entries);

    await tester.tap(find.byKey(const Key('add-month')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('month-picker-done')));
    await settle(tester);

    expect(
      findSentence('연결되지 않아 가계부를 추가하지 못했어요. 연결된 뒤에 다시 해 주세요.'),
      findsOneWidget,
    );
    expect(find.byType(MonthsScreen), findsOneWidget);
  });

  testWidgets('보기 전용은 가계부를 추가할 수 없다', (tester) async {
    await pumpMonths(
      tester,
      ledger: ledgerWith({october}, roles: const {'me': MemberRole.viewer}),
    );

    expect(find.byKey(const Key('add-month')), findsNothing);
    expect(find.byKey(const ValueKey('month-2026-10')), findsOneWidget);
  });
}
