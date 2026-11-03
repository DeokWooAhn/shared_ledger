import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/core/widget/summary_parts.dart';
import 'package:shared_ledger/feature/entries/entries_screen.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';

import '../../../testing/app.dart';
import '../../../testing/fakes.dart';

const me = AuthUser(uid: 'me');
const september = YearMonth(2026, 9);
const october = YearMonth(2026, 10);
const november = YearMonth(2026, 11);

const card = PaymentMethod(id: 'p-card', name: '공용 카드', kind: PaymentKind.card);

Ledger ledgerWith(Set<YearMonth>? months, {MemberRole? myRole}) => Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: myRole == null ? 'me' : 'partner',
  roles: {'me': ?myRole},
  months: months,
);

/// [income]이 들어오고, 대출원금(저축) [saved](지급 완료면 [paid])와 추가 지출 [spent]가 나간 달.
MonthLedger monthOf({
  int income = 0,
  int saved = 0,
  bool paid = true,
  int spent = 0,
  String paymentMethodId = 'p-account',
}) => MonthLedger(
  incomes: [
    if (income > 0)
      Income(id: 'i', memberId: 'owner', title: '월급', amount: income),
  ],
  plannedExpenses: [
    if (saved > 0)
      PlannedExpense(
        id: 's',
        categoryId: 'c-principal',
        memberId: 'partner',
        title: '대출원금',
        paymentMethodId: 'p-account',
        amount: saved,
        paidOn: paid ? DateTime(2026, 9, 10) : null,
      ),
  ],
  extraExpenses: [
    if (spent > 0)
      ExtraExpense(
        id: 'x',
        memberId: 'owner',
        title: '장보기',
        paymentMethodId: paymentMethodId,
        amount: spent,
      ),
  ],
);

/// 통계 탭을 연다. 이번 달은 10월이다.
Future<FakeEntriesRepository> pumpStats(
  WidgetTester tester, {
  required Ledger ledger,
  required Map<YearMonth, MonthLedger> months,
  Size size = phoneSize,
}) async {
  final entries = FakeEntriesRepository(months);
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([ledger]),
    settings: FakeSettingsRepository(
      paymentMethods: const [
        PaymentMethod(
          id: 'p-account',
          name: '공동 통장',
          kind: PaymentKind.account,
        ),
        card,
      ],
    ),
    entries: entries,
    size: size,
  );
  await openTab(tester, HomeTab.stats);
  return entries;
}

void main() {
  testWidgets('그동안 모은 돈은 그달까지 달마다 빠져나간 저축 + 남는 현금이고, 지급 전 저축을 두 번 세지 않는다', (
    tester,
  ) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({september, october, november}),
      months: {
        september: monthOf(income: 1000000, saved: 300000, spent: 200000),
        october: monthOf(income: 2000000, saved: 400000, paid: false),
        november: monthOf(income: 9000000),
      },
    );

    expect(textOf(tester, const Key('stats-period')), '10월까지');
    expect(findSentence('그동안 모은 돈 · 2개 달'), findsOneWidget);
    expect(textOf(tester, const Key('saved-total')), '2,800,000원');
    expect(textOf(tester, const Key('saved-saving')), '300,000원');
    expect(textOf(tester, const Key('saved-cash')), '2,500,000원');
    // 기간 칩으로 달을 옮기면 그달까지로 다시 센다.
    await tester.tap(find.byKey(const Key('open-months')));
    await settleRoute(tester);
    await tester.tap(find.byKey(const ValueKey('month-2026-11')));
    await settleRoute(tester);
    expect(textOf(tester, const Key('stats-period')), '11월까지');
    expect(textOf(tester, const Key('saved-total')), '11,800,000원');
  });

  testWidgets('달마다 모은 돈 막대는 그달까지 최근 6개 달이고, 화면 읽기 도구는 달과 금액을 읽는다', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpStats(
      tester,
      ledger: ledgerWith({
        for (var month = 3; month <= 10; month++) YearMonth(2026, month),
      }),
      months: {
        for (var month = 3; month <= 10; month++)
          YearMonth(2026, month): monthOf(income: month * 10000),
      },
    );

    expect(find.byKey(const ValueKey('saved-bar-2026-04')), findsNothing);
    for (var month = 5; month <= 10; month++) {
      expect(
        find.byKey(ValueKey('saved-bar-2026-${'$month'.padLeft(2, '0')}')),
        findsOneWidget,
      );
    }
    expect(
      tester.getSemantics(find.byKey(const ValueKey('saved-bar-2026-10'))),
      isSemantics(label: '10월 모은 돈 100,000원'),
    );
    semantics.dispose();
  });

  testWidgets('그달 지출을 앞 달과 견주고, 결제수단별로 나눠 보여준다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({september, october}),
      months: {
        september: monthOf(spent: 500000),
        october: MonthLedger(
          extraExpenses: [
            for (final (id, method, amount) in [
              ('a', 'p-account', 100000),
              ('b', 'p-card', 300000),
            ])
              ExtraExpense(
                id: id,
                memberId: 'owner',
                title: id,
                paymentMethodId: method,
                amount: amount,
              ),
          ],
        ),
      },
    );

    expect(textOf(tester, const Key('stats-spending')), '400,000원');
    expect(find.text('9월보다 −100,000원'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('payment-section')));
    for (final (key, amount) in [
      ('payment-p-account', '100,000원'),
      ('payment-p-card', '300,000원'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.text(amount),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('고정 지출 분류별·구성원별 소계는 홈이 아니라 통계 탭에 있다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({october}),
      months: {october: monthOf(saved: 300000)},
    );

    expect(textOf(tester, const Key('planned-total')), '300,000원');
    await openTab(tester, HomeTab.home);
    expect(find.byKey(const Key('planned-section')), findsNothing);
  });

  testWidgets('달 목록을 모으지 못한 옛 가계부의 보기 전용은 모은 돈 대신 안내를 본다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith(null, myRole: MemberRole.viewer),
      months: {october: monthOf(spent: 1000)},
    );

    expect(find.byKey(const Key('saved-unknown')), findsOneWidget);
    expect(find.byKey(const Key('saved-card')), findsNothing);
    expect(find.byKey(const Key('recent-saved')), findsNothing);
    expect(textOf(tester, const Key('stats-spending')), '1,000원');
  });

  testWidgets('홈과 달리 머리말은 통계 제목과 기간 칩이고, 진한 파란 큰 카드가 없다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({october}),
      months: {october: monthOf(income: 1000)},
    );

    expect(find.text('통계'), findsWidgets);
    expect(find.byKey(const Key('month-title')), findsNothing);
    expect(find.byType(HeroCard), findsNothing);
  });

  testWidgets('지출이 앞 달보다 늘면 늘어난 만큼을 칩으로 알린다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({september, october}),
      months: {
        september: monthOf(spent: 100000),
        october: monthOf(spent: 250000),
      },
    );

    expect(find.text('9월보다 +150,000원'), findsOneWidget);
  });

  testWidgets('모은 돈이 모두 0원이면 빈 막대 자리 대신 안내를 보여준다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({september, october}),
      months: {september: monthOf(), october: monthOf()},
    );

    expect(find.byKey(const Key('saved-bars-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-bar-2026-10')), findsNothing);
  });

  testWidgets('+ 버튼은 통계 탭에 없다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({october}),
      months: {october: monthOf()},
    );

    expect(find.byKey(const Key('add-entry')), findsNothing);
  });

  testWidgets('넓은 화면에서는 고정 지출과 결제수단을 오른쪽 칸에 둔다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({october}),
      months: {october: monthOf(income: 1000, saved: 300)},
      size: tabletSize,
    );

    final saved = tester.getRect(find.byKey(const Key('saved-card')));
    final planned = tester.getRect(find.byKey(const Key('planned-section')));
    expect(planned.left, greaterThan(saved.right));
    expect(planned.top, lessThan(saved.bottom));
  });

  testWidgets('홈의 할 일 줄을 누르면 내역 탭의 지출 칸으로 간다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith({october}),
      months: {october: monthOf(saved: 300000, paid: false)},
    );
    await openTab(tester, HomeTab.home);

    await tapVisible(tester, const Key('pending-row'));
    await settleRoute(tester);

    expect(find.byType(EntriesScreen), findsOneWidget);
    expect(find.text('대출원금'), findsWidgets);
  });

  testWidgets('글자를 크게 해도 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpStats(
      tester,
      ledger: ledgerWith({september, october}),
      months: {
        september: monthOf(income: 1000000, saved: 300000, spent: 200000),
        october: monthOf(income: 2000000, saved: 400000, paid: false),
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('saved-total')), findsOneWidget);
  });
}
