import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/activity.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/payment_method.dart';
import 'package:shared_ledger/core/widget/keep_all.dart';
import 'package:shared_ledger/feature/entries/entries_screen.dart';
import 'package:shared_ledger/feature/entries/entry_form_screen.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/settings/activity_screen.dart';

import '../../support/app.dart';
import '../../support/fakes.dart';
import '../../support/provider_container.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'me',
  roles: {'partner-uid': MemberRole.editor},
);
const asViewer = Ledger(
  id: 'l1',
  name: '우리 가계부',
  ownerUid: 'partner-uid',
  roles: {'me': MemberRole.viewer},
);

FakeSettingsRepository settings() => FakeSettingsRepository(
  categories: const [Category(id: 'c-living', name: '소비')],
  paymentMethods: const [
    PaymentMethod(id: 'p-account', name: '공동 통장', kind: PaymentKind.account),
  ],
);

Future<void> pumpActivityApp(
  WidgetTester tester, {
  required FakeActivityRepository activity,
  Ledger ledger = mine,
  FakeEntriesRepository? entries,
  Size size = phoneSize,
}) => pumpApp(
  tester,
  auth: FakeAuthRepository(signedIn: me),
  ledgers: FakeLedgerRepository([ledger]),
  settings: settings(),
  entries: entries,
  activity: activity,
  size: size,
);

Finder inActivity(Finder finder) =>
    find.descendant(of: find.byType(ActivityScreen), matching: finder);

Finder inForm(Finder finder) =>
    find.descendant(of: find.byType(EntryFormScreen), matching: finder);

/// 화면 아래쪽에 걸친 위젯도 다 보이게 옮긴 뒤 누른다.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

/// 설정 탭에서 변경 기록을 연다. 하위 화면 전환은 settle(400ms)보다 길다.
Future<void> openActivity(WidgetTester tester) async {
  await openTab(tester, HomeTab.settings);
  await tapShown(tester, find.byKey(const Key('open-activity')));
  await settleRoute(tester);
}

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

/// [id] 기록 줄 안의 [finder].
Finder inRow(String id, Finder finder) =>
    find.descendant(of: find.byKey(ValueKey('activity-$id')), matching: finder);

/// [count]건의 기록. 앞의 것일수록 오래됐다(10/1부터 1분 간격).
List<Activity> history(int count) => [
  for (var i = 0; i < count; i++)
    Activity(
      id: 'old-${i.toString().padLeft(3, '0')}',
      actorUid: 'me',
      action: ActivityAction.entryCreate,
      summary: '기록 $i',
      at: DateTime(2026, 10, 1).add(Duration(minutes: i)),
    ),
];

void main() {
  group('변경 기록', () {
    testWidgets('항목을 더하고 고치면 누가·언제·무엇을 했는지 변경 기록에 쌓인다', (tester) async {
      final activity = FakeActivityRepository();
      await pumpActivityApp(tester, activity: activity);

      // 항목 탭에서 추가지출을 더한다.
      await openTab(tester, HomeTab.entries);
      await tester.tap(
        find.descendant(
          of: find.byType(EntriesScreen),
          matching: find.byKey(const Key('entry-kind-extra')),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-entry')));
      await settleRoute(tester);
      await showInForm(tester, const Key('entry-amount'));
      await tester.enterText(
        inForm(find.byKey(const Key('entry-amount'))),
        '12000',
      );
      await showInForm(tester, const Key('entry-title'));
      await tester.enterText(
        inForm(find.byKey(const Key('entry-title'))),
        '점심',
      );
      await showInForm(tester, const Key('entry-method-p-account'));
      await tester.tap(inForm(find.byKey(const Key('entry-method-p-account'))));
      await settle(tester);
      await showInForm(tester, const Key('entry-save'));
      await tester.tap(inForm(find.byKey(const Key('entry-save'))));
      await settleRoute(tester);

      // 금액을 고친다.
      await tester.tap(find.text('점심'));
      await settleRoute(tester);
      await showInForm(tester, const Key('entry-amount'));
      await tester.enterText(
        inForm(find.byKey(const Key('entry-amount'))),
        '15000',
      );
      await showInForm(tester, const Key('entry-save'));
      await tester.tap(inForm(find.byKey(const Key('entry-save'))));
      await settleRoute(tester);

      await openActivity(tester);

      expect(inActivity(find.text('오늘')), findsOneWidget);
      // 새것부터: 고친 기록이 위, 더한 기록이 아래다.
      final [updated, created] = activity.activities.reversed.toList();
      expect(inRow(updated.id, find.text('하늘')), findsOneWidget);
      expect(inRow(updated.id, find.text('수정')), findsOneWidget);
      expect(inRow(updated.id, find.text('오전 9:01')), findsOneWidget);
      expect(
        inRow(updated.id, findSentence("10월 추가지출 '점심' · 금액 12,000원 → 15,000원")),
        findsOneWidget,
      );
      expect(inRow(created.id, find.text('추가')), findsOneWidget);
      expect(
        inRow(created.id, findSentence("10월 추가지출 '점심' 12,000원")),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(ValueKey('activity-${updated.id}'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(ValueKey('activity-${created.id}'))).dy,
        ),
      );
    });

    testWidgets('상대가 남긴 기록도 바로 보이고, 날짜별로 묶고, 나간 사람은 나간 구성원으로 보인다', (
      tester,
    ) async {
      final activity = FakeActivityRepository([
        Activity(
          id: 'gone',
          actorUid: 'gone-uid',
          action: ActivityAction.categoryCreate,
          summary: "분류 '여행'",
          at: DateTime(2026, 10, 12, 21, 30),
        ),
      ]);
      await pumpActivityApp(tester, activity: activity);
      await openActivity(tester);

      expect(inActivity(find.text('10월 12일 (월)')), findsOneWidget);
      expect(inRow('gone', find.text('나간 구성원')), findsOneWidget);
      expect(inRow('gone', find.text('오후 9:30')), findsOneWidget);

      activity.put([
        ...activity.activities,
        Activity(
          id: 'partner',
          actorUid: 'partner-uid',
          action: ActivityAction.entryTrash,
          summary: "10월 추가지출 '점심' 12,000원",
          at: DateTime(2026, 10, 14, 20),
        ),
      ]);
      await settle(tester);

      expect(inActivity(find.text('어제')), findsOneWidget);
      expect(inRow('partner', find.text('바다')), findsOneWidget);
      expect(inRow('partner', find.text('휴지통')), findsOneWidget);
    });

    testWidgets('서버에 닿기 전 기록은 오늘 맨 위에 올리는 중으로 보인다', (tester) async {
      final activity = FakeActivityRepository([
        Activity(
          id: 'done',
          actorUid: 'me',
          action: ActivityAction.entryCreate,
          summary: "10월 추가지출 '점심' 12,000원",
          at: DateTime(2026, 10, 15, 8),
        ),
        const Activity(
          id: 'pending',
          actorUid: 'me',
          action: ActivityAction.entryCreate,
          summary: "10월 추가지출 '커피' 4,500원",
        ),
      ]);
      await pumpActivityApp(tester, activity: activity);
      await openActivity(tester);

      expect(inActivity(find.text('오늘')), findsOneWidget);
      expect(inRow('pending', find.text('올리는 중')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('activity-pending'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('activity-done'))).dy,
        ),
      );
    });

    testWidgets('50건이 넘으면 더 보기로 더 오래된 기록을 불러온다', (tester) async {
      final activity = FakeActivityRepository(history(activityPageSize + 2));
      await pumpActivityApp(tester, activity: activity);
      await openActivity(tester);

      expect(find.byKey(const ValueKey('activity-old-000')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('activity-more')),
        400,
        scrollable: inActivity(find.byType(Scrollable)).first,
      );
      await tapShown(tester, find.byKey(const Key('activity-more')));

      expect(activity.loads, hasLength(1));
      expect(find.byKey(const Key('activity-more')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('activity-old-000')),
        400,
        scrollable: inActivity(find.byType(Scrollable)).first,
      );
      expect(find.byKey(const ValueKey('activity-old-000')), findsOneWidget);
    });

    testWidgets('더 불러오지 못하면 알린다', (tester) async {
      final activity = FakeActivityRepository(history(activityPageSize))
        ..failNextLoad = true;
      await pumpActivityApp(tester, activity: activity);
      await openActivity(tester);

      await tester.scrollUntilVisible(
        find.byKey(const Key('activity-more')),
        400,
        scrollable: inActivity(find.byType(Scrollable)).first,
      );
      await tapShown(tester, find.byKey(const Key('activity-more')));

      expect(findSentence('더 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.byKey(const Key('activity-more')), findsOneWidget);
    });

    testWidgets('기록이 없으면 안내한다', (tester) async {
      await pumpActivityApp(tester, activity: FakeActivityRepository());
      await openActivity(tester);
      expect(
        inActivity(findSentence('아직 변경 기록이 없어요. 항목이나 설정을 바꾸면 여기에 남아요.')),
        findsOneWidget,
      );
    });

    testWidgets('기록을 불러오지 못하면 다시 열어 달라고 한다', (tester) async {
      await pumpActivityApp(
        tester,
        activity: FakeActivityRepository()..failNextWatch = true,
      );
      await openActivity(tester);
      expect(
        inActivity(findSentence('변경 기록을 불러오지 못했어요. 잠시 후 다시 열어 주세요.')),
        findsOneWidget,
      );
    });

    testWidgets('보기 전용도 변경 기록을 본다', (tester) async {
      final activity = FakeActivityRepository([
        Activity(
          id: 'owner',
          actorUid: 'partner-uid',
          action: ActivityAction.ledgerRename,
          summary: "가계부 이름 '우리 가계부' → '하늘바다 가계부'",
          at: DateTime(2026, 10, 15, 8),
        ),
      ]);
      await pumpActivityApp(tester, activity: activity, ledger: asViewer);
      await openActivity(tester);

      // 보기 전용 가계부에서는 상대(관리자)가 owner 이름표다.
      expect(inRow('owner', find.text('하늘')), findsOneWidget);
      expect(inRow('owner', find.text('이름 변경')), findsOneWidget);
    });

    testWidgets('화면 읽기 도구는 기록 한 줄을 누가·무엇을·언제와 함께 읽는다', (tester) async {
      final semantics = tester.ensureSemantics();
      final activity = FakeActivityRepository([
        Activity(
          id: 'a1',
          actorUid: 'partner-uid',
          action: ActivityAction.entryTrash,
          summary: "10월 추가지출 '점심' 12,000원",
          at: DateTime(2026, 10, 15, 8, 40),
        ),
      ]);
      await pumpActivityApp(tester, activity: activity);
      await openActivity(tester);

      final label = tester
          .getSemantics(find.byKey(const ValueKey('activity-a1')))
          .label;
      // 이름은 동그라미와 글자 두 번이 아니라 한 번만 읽는다.
      expect(label.split('\n'), [
        '바다',
        '휴지통',
        '오전 8:40',
        keepAll("10월 추가지출 '점심' 12,000원"),
      ]);
      semantics.dispose();
    });
  });

  group('기록 표시', () {
    test('날짜는 오늘·어제, 그 밖에는 월·일·요일, 해가 다르면 연도까지 적는다', () {
      expect(
        activityDayLabel(DateTime(2026, 10, 15, 23), today: testNow),
        '오늘',
      );
      expect(activityDayLabel(DateTime(2026, 10, 14), today: testNow), '어제');
      expect(
        activityDayLabel(DateTime(2026, 10, 12), today: testNow),
        '10월 12일 (월)',
      );
      expect(
        activityDayLabel(DateTime(2025, 12, 31), today: testNow),
        '2025년 12월 31일 (수)',
      );
      // 달이 바뀌는 날의 어제.
      expect(
        activityDayLabel(DateTime(2026, 9, 30), today: DateTime(2026, 10, 1)),
        '어제',
      );
    });

    test('시각은 오전·오후 12시간제로 적는다', () {
      expect(activityTimeLabel(DateTime(2026, 10, 15, 0, 5)), '오전 12:05');
      expect(activityTimeLabel(DateTime(2026, 10, 15, 9, 30)), '오전 9:30');
      expect(activityTimeLabel(DateTime(2026, 10, 15, 12)), '오후 12:00');
      expect(activityTimeLabel(DateTime(2026, 10, 15, 21, 30)), '오후 9:30');
    });

    test('모르는 동작은 변경으로 표시한다', () {
      expect(activityActionLabel(null), '변경');
      expect(activityActionLabel(ActivityAction.entryPurge), '완전 삭제');
    });
  });

  group('넓은 화면', () {
    testWidgets('옆 탭 막대로 설정에서 변경 기록을 열고, 목록은 가운데 640폭으로 둔다', (tester) async {
      final activity = FakeActivityRepository(history(3));
      await pumpActivityApp(tester, activity: activity, size: tabletSize);
      await openActivity(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.getSize(inActivity(find.byType(Card)).first).width, 640);
    });
  });
}
