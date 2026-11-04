import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/widget/month_picker_sheet.dart';
import 'package:shared_ledger/core/widget/summary_parts.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/feature/entries/entries_screen.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/stats/stats_period_sheet.dart';
import 'package:shared_ledger/feature/stats/stats_screen.dart';

import '../../../testing/app.dart';
import '../../../testing/fakes.dart';

const me = AuthUser(uid: 'me');
const april = YearMonth(2026, 4);
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

/// 4월(기본 기간 밖), 9월, 10월 가계부. 이번 달은 10월이라 기본 기간은 5월~10월이다.
Map<YearMonth, MonthLedger> threeMonths() => {
  april: monthOf(income: 7000000),
  september: monthOf(income: 1000000, saved: 300000, spent: 200000),
  october: monthOf(income: 2000000, saved: 400000, paid: false, spent: 100000),
};

/// 통계 탭을 연다.
Future<FakeEntriesRepository> pumpStats(
  WidgetTester tester, {
  Ledger? ledger,
  Map<YearMonth, MonthLedger>? months,
  Size size = phoneSize,
}) async {
  final ledgers = months ?? threeMonths();
  final entries = FakeEntriesRepository(ledgers);
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([ledger ?? ledgerWith(ledgers.keys.toSet())]),
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

Finder inSheet(Finder finder) =>
    find.descendant(of: find.byType(StatsPeriodSheet), matching: finder);

/// 결제수단 줄의 비율 막대가 지금 그려진 만큼.
double paymentBar(WidgetTester tester, String id) => tester
    .widget<FractionallySizedBox>(
      find.descendant(
        of: find.byKey(ValueKey('payment-$id')),
        matching: find.byType(FractionallySizedBox),
      ),
    )
    .widthFactor!;

/// 조회 기간 시트를 열고 [range] 칸을 누른다.
Future<void> chooseRange(WidgetTester tester, String range) async {
  await tester.tap(find.byKey(const Key('open-stats-period')));
  await settleRoute(tester);
  await tester.tap(inSheet(find.byKey(ValueKey('stats-range-$range'))));
  await settle(tester);
}

void main() {
  testWidgets('기본 기간은 이번 달로 끝나는 최근 6개월이고, 본문 맨 위에 적으며 그 기간의 모은 돈을 더한다', (
    tester,
  ) async {
    await pumpStats(tester);

    expect(textOf(tester, const Key('stats-period')), '2026년 5월 ~ 10월');
    expect(find.textContaining('개월'), findsNothing);
    // 9월: 저축 300,000 + 현금 500,000 / 10월: 지급 전 저축은 현금에만, 현금 1,900,000. 4월은 기간 밖이다.
    expect(textOf(tester, const Key('saved-total')), '2,700,000원');
    expect(textOf(tester, const Key('saved-saving')), '300,000원');
    expect(textOf(tester, const Key('saved-cash')), '2,400,000원');
  });

  testWidgets('맨 위 수입 카드는 수입에서 지출·저축·남은 돈이 차지하는 비율을 막대와 범례로 보여준다', (
    tester,
  ) async {
    await pumpStats(tester);

    expect(textOf(tester, const Key('stats-income')), '3,000,000원');
    // 지출(저축 제외) 300,000 · 저축(대출원금) 700,000 · 남은 돈 2,000,000
    for (final (key, share, amount) in [
      ('income-consumption', '10%', '300,000원'),
      ('income-saving', '23%', '700,000원'),
      ('income-left', '67%', '2,000,000원'),
    ]) {
      for (final text in [share, amount]) {
        expect(
          find.descendant(of: find.byKey(Key(key)), matching: find.text(text)),
          findsOneWidget,
          reason: '$key $text',
        );
      }
    }
    expect(find.byKey(const Key('income-over')), findsNothing);
    // 수입 카드가 모은 돈 카드보다 위에 있다.
    expect(
      tester.getTopLeft(find.byKey(const Key('income-card'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('saved-card'))).dy),
    );
  });

  testWidgets('지출이 수입보다 많으면 남은 돈 대신 넘친 만큼을 초과로 알린다', (tester) async {
    await pumpStats(
      tester,
      months: {october: monthOf(income: 100000, spent: 300000)},
    );

    expect(find.byKey(const Key('income-left')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('income-over')),
        matching: find.text('200,000원'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('income-over')),
        matching: find.text('200%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('머리말은 통계 제목과 기간 아이콘 단추이고, 설명 글과 진한 파란 큰 카드가 없다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpStats(tester);

    expect(
      tester.getSemantics(find.byKey(const Key('open-stats-period'))),
      isSemantics(tooltip: '기간 설정', isButton: true),
    );
    expect(find.byKey(const Key('open-months')), findsNothing);
    expect(find.byType(HeroCard), findsNothing);
    for (final text in ['그동안', '저축은 빠져나간', '아직 모은 돈', '보다 +', '금액 미정']) {
      expect(find.textContaining(text), findsNothing, reason: text);
    }
    semantics.dispose();
  });

  testWidgets('조회 기간에서 3개월을 고르고 확인하면 그 기간으로 다시 센다', (tester) async {
    await pumpStats(tester);

    await chooseRange(tester, 'month3');
    expect(textOf(tester, const Key('stats-sheet-period')), '2026년 8월 ~ 10월');
    await tester.tap(find.byKey(const Key('stats-period-done')));
    await settleRoute(tester);

    expect(find.byType(StatsPeriodSheet), findsNothing);
    expect(textOf(tester, const Key('stats-period')), '2026년 8월 ~ 10월');
  });

  testWidgets('직접 고르기는 시트를 겹쳐 띄우지 않고, 누른 칸을 같은 시트 안의 휠로 고친다', (tester) async {
    await pumpStats(tester);

    await chooseRange(tester, 'custom');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(inSheet(find.byKey(const Key('stats-from'))), findsOneWidget);
    // 시작 칸(5월)을 두 칸 앞으로 굴려 3월로 옮긴다.
    await tester.drag(
      inSheet(find.byKey(const Key('month-picker-months'))),
      const Offset(0, monthPickerItemExtent * 2),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('stats-period-done')));
    await settleRoute(tester);

    expect(textOf(tester, const Key('stats-period')), '2026년 3월 ~ 10월');
    // 4월이 기간에 들어와 그달 현금 7,000,000원이 더해진다.
    expect(textOf(tester, const Key('saved-total')), '9,700,000원');
  });

  testWidgets('확인을 누르지 않고 닫으면 기간이 그대로다', (tester) async {
    await pumpStats(tester);

    await chooseRange(tester, 'month1');
    await tester.tapAt(const Offset(20, 20));
    await settleRoute(tester);

    expect(textOf(tester, const Key('stats-period')), '2026년 5월 ~ 10월');
  });

  testWidgets('지출은 분류별 고정 지출과 추가 지출로 나눈 도넛과, 이름·비율·금액을 적은 범례로 보여준다', (
    tester,
  ) async {
    await pumpStats(tester);

    // 고정 지출 대출원금 700,000원 + 추가 지출 300,000원.
    expect(textOf(tester, const Key('stats-spending')), '1,000,000원');
    expect(find.byKey(const Key('spending-donut')), findsOneWidget);
    for (final (key, name, share, amount) in [
      ('category-c-principal', '대출원금', '70%', '700,000원'),
      ('category-extra', '추가 지출', '30%', '300,000원'),
    ]) {
      for (final text in [name, share, amount]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.text(text),
          ),
          findsOneWidget,
          reason: '$key $text',
        );
      }
    }
  });

  testWidgets('달마다 모은 돈 막대는 기간 안의 가계부 달이고, 화면 읽기 도구는 달과 금액을 읽는다', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpStats(tester);

    expect(find.byKey(const ValueKey('saved-bar-2026-04')), findsNothing);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('saved-bar-2026-10'))),
      isSemantics(label: '10월 모은 돈 1,900,000원'),
    );
    expect(find.byKey(const ValueKey('saved-bar-2026-09')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('막대 끝에는 달마다 모은 돈을 만 원 단위로 짧게 적고, 모자란 달은 아래에 적는다', (tester) async {
    await pumpStats(
      tester,
      months: {
        september: monthOf(income: 1000000, saved: 300000, spent: 200000),
        october: monthOf(spent: 300000),
      },
    );

    expect(textOf(tester, const ValueKey('saved-amount-2026-09')), '80만');
    expect(textOf(tester, const ValueKey('saved-amount-2026-10')), '-30만');
    // 모자란 달의 금액은 기준선 아래에 있어 남은 달의 금액보다 아래다.
    expect(
      tester.getCenter(find.byKey(const ValueKey('saved-amount-2026-10'))).dy,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('saved-amount-2026-09'))).dy,
      ),
    );
  });

  testWidgets('1개월이면 막대 없이 그달 모은 돈만 보여준다', (tester) async {
    await pumpStats(tester);

    await chooseRange(tester, 'month1');
    await tester.tap(find.byKey(const Key('stats-period-done')));
    await settleRoute(tester);

    expect(textOf(tester, const Key('stats-period')), '2026년 10월');
    expect(find.byKey(const Key('recent-saved')), findsNothing);
    expect(textOf(tester, const Key('saved-total')), '1,900,000원');
  });

  testWidgets('통계 탭에 들어올 때마다 그래프를 처음부터 그린다', (tester) async {
    await pumpStats(tester);
    await settle(tester);
    final full = paymentBar(tester, 'p-account');
    expect(full, greaterThan(0));

    await openTab(tester, HomeTab.home);
    await tester.tap(find.byKey(const Key('tab-stats')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(paymentBar(tester, 'p-account'), lessThan(full));

    await settle(tester);
    await settle(tester);
    expect(paymentBar(tester, 'p-account'), full);
  });

  testWidgets('움직임 줄이기를 켰으면 그래프를 바로 다 그린다', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpStats(tester);

    await openTab(tester, HomeTab.home);
    await tester.tap(find.byKey(const Key('tab-stats')));
    await tester.pump();
    // 공동 통장: 추가 지출 300,000 + 대출원금 700,000 = 지출 전체.
    expect(paymentBar(tester, 'p-account'), 1);
  });

  testWidgets('기간에 쓴 돈이 없으면 도넛·구성원·결제수단 칸을 숨긴다', (tester) async {
    await pumpStats(
      tester,
      months: {september: monthOf(income: 1000), october: monthOf()},
    );

    expect(textOf(tester, const Key('stats-spending')), '0원');
    expect(find.byKey(const Key('spending-donut')), findsNothing);
    expect(find.byKey(const Key('member-section')), findsNothing);
    expect(find.byKey(const Key('payment-section')), findsNothing);
  });

  testWidgets('달 목록을 모으지 못한 옛 가계부의 보기 전용도 기간의 달을 읽어 모은 돈을 본다', (tester) async {
    await pumpStats(
      tester,
      ledger: ledgerWith(null, myRole: MemberRole.viewer),
      months: {october: monthOf(income: 5000)},
    );

    expect(textOf(tester, const Key('saved-total')), '5,000원');
  });

  testWidgets('+ 버튼은 통계 탭에 없다', (tester) async {
    await pumpStats(tester);

    expect(find.byKey(const Key('add-entry')), findsNothing);
  });

  testWidgets('넓은 화면에서는 지출과 결제수단을 오른쪽 칸에 둔다', (tester) async {
    await pumpStats(tester, size: tabletSize);

    final saved = tester.getRect(find.byKey(const Key('saved-card')));
    final spending = tester.getRect(find.byKey(const Key('spending-section')));
    expect(spending.left, greaterThan(saved.right));
    expect(spending.top, lessThan(saved.bottom));
  });

  testWidgets('홈의 할 일 줄을 누르면 내역 탭의 지출 칸으로 간다', (tester) async {
    await pumpStats(
      tester,
      months: {october: monthOf(saved: 300000, paid: false)},
    );
    await openTab(tester, HomeTab.home);

    await tapVisible(tester, const Key('pending-row'));
    await settleRoute(tester);

    expect(find.byType(EntriesScreen), findsOneWidget);
    expect(find.text('대출원금'), findsWidgets);
  });

  testWidgets('글자를 크게 해도 통계와 조회 기간 시트가 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpStats(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(StatsScreen), findsOneWidget);
    await chooseRange(tester, 'custom');
    expect(tester.takeException(), isNull);
  });
}
