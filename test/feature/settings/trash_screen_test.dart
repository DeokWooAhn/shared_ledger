import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/domain/model/trashed_entry.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/feature/entries/entries_screen.dart';
import 'package:shared_ledger/feature/entries/entry_form_screen.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/settings/trash_screen.dart';

import '../../../testing/app.dart';
import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

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
const october = YearMonth(2026, 10);

const lunch = ExtraExpense(
  id: 'lunch',
  memberId: 'partner',
  title: '점심',
  paymentMethodId: 'p-shared',
  amount: 12000,
);
const cardBill = CardBill(
  id: 'bill',
  memberId: 'owner',
  cardId: 'p-shared',
  amount: 500000,
);
// 고정 지출에서 만든 이번 달 기본 월 지출. 지우면 다시 만들어져서 휴지통에 남긴다.
final management = PlannedExpense(
  id: 'tpl-management',
  categoryId: 'c-living',
  memberId: 'owner',
  title: '관리비',
  paymentMethodId: 'p-account',
  dueOn: DateTime(2026, 10, 25),
);

FakeSettingsRepository settings() => FakeSettingsRepository(
  categories: const [Category(id: 'c-living', name: '소비')],
  paymentMethods: const [
    PaymentMethod(id: 'p-account', name: '공동 통장', kind: PaymentKind.account),
    PaymentMethod(id: 'p-shared', name: '공용 카드', kind: PaymentKind.card),
  ],
);

/// [entries]를 [month]의 휴지통에 넣어 둔 가짜 저장소. 넣은 때는 10/14, 자동 삭제는 그 30일 뒤다.
FakeEntriesRepository trashOf(
  List<LedgerEntry> entries, {
  YearMonth month = october,
}) => FakeEntriesRepository({
  month: MonthLedger(
    trashed: [
      for (final entry in entries)
        TrashedEntry(
          entry: entry,
          deletedAt: DateTime(2026, 10, 14, 10),
          purgeAt: staysInTrash(entry, month: month, thisMonth: october)
              ? null
              : DateTime(2026, 11, 13, 10),
        ),
    ],
  ),
});

Future<void> pumpTrashApp(
  WidgetTester tester, {
  required FakeEntriesRepository entries,
  Ledger ledger = mine,
  FakeActivityRepository? activity,
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

Finder inTrash(Finder finder) =>
    find.descendant(of: find.byType(TrashScreen), matching: finder);

/// 화면 아래쪽에 걸친 위젯도 다 보이게 옮긴 뒤 누른다.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

/// 설정 탭에서 휴지통을 연다. 하위 화면 전환은 settle(400ms)보다 길다.
Future<void> openTrash(WidgetTester tester) async {
  await openTab(tester, HomeTab.settings);
  await tapShown(tester, find.byKey(const Key('open-trash')));
  await settleRoute(tester);
}

String? settingValue(WidgetTester tester, Key row) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(row), matching: find.byType(Text)),
    )
    .map((text) => text.data)
    .lastOrNull;

void main() {
  group('휴지통', () {
    testWidgets('항목 탭에서 휴지통에 넣은 항목을 휴지통에서 되살리면 항목 탭에 다시 보인다', (tester) async {
      final entries = FakeEntriesRepository({
        october: const MonthLedger(extraExpenses: [lunch]),
      });
      await pumpTrashApp(tester, entries: entries);
      await openTab(tester, HomeTab.entries);
      await tester.tap(
        find.descendant(
          of: find.byType(EntriesScreen),
          matching: find.byKey(const Key('entry-kind-extra')),
        ),
      );
      await settle(tester);

      // 항목 탭에서 휴지통에 넣는다.
      await tester.tap(find.text('점심'));
      await settleRoute(tester);
      final trash = find.descendant(
        of: find.byType(EntryFormScreen),
        matching: find.byKey(const Key('entry-trash')),
      );
      await tester.scrollUntilVisible(
        trash,
        200,
        scrollable: find
            .descendant(
              of: find.byType(EntryFormScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapShown(tester, trash);
      await settleRoute(tester);
      expect(find.text('점심'), findsNothing);
      // '휴지통에 넣었어요' 스낵바(5초)가 사라질 때까지 기다린다. 남아 있으면 다음 알림이 그 뒤에 줄을 선다.
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);

      // 설정의 휴지통 줄에 보고 있는 달의 건수가 보인다.
      await openTab(tester, HomeTab.settings);
      expect(settingValue(tester, const Key('open-trash')), '10월 1건');
      await tapShown(tester, find.byKey(const Key('open-trash')));
      await settleRoute(tester);

      expect(inTrash(find.text('점심')), findsOneWidget);
      expect(inTrash(find.text('추가지출 · 10/15에 넣음')), findsOneWidget);
      expect(inTrash(findSentence('30일 뒤 자동으로 지워져요')), findsOneWidget);

      await tapShown(tester, inTrash(find.byKey(const Key('restore-lunch'))));

      expect(entries.restored.single.id, 'lunch');
      expect(findSentence('되살렸어요. 항목 목록과 합계에 다시 들어가요.'), findsOneWidget);
      expect(inTrash(findSentence('10월 휴지통이 비어 있어요.')), findsOneWidget);

      await openTab(tester, HomeTab.entries);
      expect(find.text('점심'), findsOneWidget);
    });

    testWidgets('최근에 넣은 것부터 보여주고, 카드대금은 카드 이름을 제목으로 쓴다', (tester) async {
      final entries = FakeEntriesRepository({
        october: MonthLedger(
          trashed: [
            TrashedEntry(entry: cardBill, deletedAt: DateTime(2026, 10, 1)),
            TrashedEntry(entry: lunch, deletedAt: DateTime(2026, 10, 14)),
          ],
        ),
      });
      await pumpTrashApp(tester, entries: entries);
      await openTrash(tester);

      final lunchTop = tester.getTopLeft(inTrash(find.text('점심'))).dy;
      final cardTop = tester.getTopLeft(inTrash(find.text('공용 카드'))).dy;
      expect(lunchTop, lessThan(cardTop));
      expect(inTrash(find.text('500,000원')), findsOneWidget);
      // 자동 삭제를 넣기 전에 넣은 항목은 안내 없이 넣은 날만 보인다.
      expect(inTrash(find.byKey(const Key('trash-note'))), findsNothing);
    });

    testWidgets('완전 삭제는 확인 대화상자에서 지운다고 해야 지우고 변경 기록에 남긴다', (tester) async {
      final entries = trashOf([lunch]);
      final activity = FakeActivityRepository();
      await pumpTrashApp(tester, entries: entries, activity: activity);
      await openTrash(tester);

      await tapShown(tester, inTrash(find.byKey(const Key('purge-lunch'))));
      expect(find.text('완전히 지울까요?'), findsOneWidget);
      expect(find.text('점심 · 12,000원'), findsOneWidget);
      await tester.tap(find.byKey(const Key('purge-cancel')));
      await settle(tester);

      expect(entries.purged, isEmpty);
      expect(inTrash(find.text('점심')), findsOneWidget);

      await tapShown(tester, inTrash(find.byKey(const Key('purge-lunch'))));
      await tester.tap(find.byKey(const Key('purge-confirm')));
      await settle(tester);

      expect(entries.purged.single.id, 'lunch');
      expect(inTrash(find.text('점심')), findsNothing);
      expect(findSentence('완전히 지웠어요.'), findsOneWidget);
      expect(activity.logged.single.summary, "10월 추가지출 '점심' 12,000원");
    });

    testWidgets('고정 지출에서 만든 이번 달 기본 지출은 완전 삭제 없이 남겨 둔다고 알린다', (tester) async {
      await pumpTrashApp(tester, entries: trashOf([management]));
      await openTrash(tester);

      expect(inTrash(find.text('관리비')), findsOneWidget);
      expect(inTrash(find.text('금액 미정')), findsOneWidget);
      expect(
        inTrash(findSentence('고정 지출에서 만든 항목이라 지우면 다시 생겨요. 휴지통에 남겨 둬요.')),
        findsOneWidget,
      );
      expect(
        inTrash(find.byKey(const Key('restore-tpl-management'))),
        findsOneWidget,
      );
      expect(
        inTrash(find.byKey(const Key('purge-tpl-management'))),
        findsNothing,
      );
    });

    testWidgets('달 머리말로 다른 달의 휴지통을 본다. 지난 달의 고정 지출 항목은 지울 수 있다', (
      tester,
    ) async {
      await pumpTrashApp(
        tester,
        entries: trashOf([management], month: october.previous),
      );
      await openTrash(tester);
      expect(inTrash(findSentence('10월 휴지통이 비어 있어요.')), findsOneWidget);

      await swipeMonth(
        tester,
        next: false,
        title: inTrash(find.byKey(const Key('month-title'))),
      );

      expect(inTrash(find.text('관리비')), findsOneWidget);
      expect(
        inTrash(find.byKey(const Key('purge-tpl-management'))),
        findsOneWidget,
      );
    });

    testWidgets('연결이 없으면 되살리지 못했다고 알리고 휴지통에 그대로 둔다', (tester) async {
      final entries = trashOf([lunch])..offline = true;
      await pumpTrashApp(tester, entries: entries);
      await openTrash(tester);

      await tapShown(tester, inTrash(find.byKey(const Key('restore-lunch'))));

      expect(
        findSentence('인터넷에 연결된 뒤에 다시 시도해 주세요. 휴지통은 연결돼 있을 때만 바꿀 수 있어요.'),
        findsOneWidget,
      );
      expect(inTrash(find.text('점심')), findsOneWidget);
    });

    testWidgets('보기 전용은 휴지통을 보기만 한다', (tester) async {
      await pumpTrashApp(tester, entries: trashOf([lunch]), ledger: asViewer);
      await openTrash(tester);

      expect(
        inTrash(find.byKey(const Key('view-only-notice'))),
        findsOneWidget,
      );
      expect(inTrash(find.text('점심')), findsOneWidget);
      expect(inTrash(find.byKey(const Key('restore-lunch'))), findsNothing);
      expect(inTrash(find.byKey(const Key('purge-lunch'))), findsNothing);
    });

    testWidgets('뒤로 가면 설정 첫 화면으로 돌아온다', (tester) async {
      await pumpTrashApp(tester, entries: trashOf([lunch]));
      await openTrash(tester);

      await tester.tap(inTrash(find.byKey(const Key('sub-page-back'))));
      await settleRoute(tester);

      expect(find.byType(TrashScreen), findsNothing);
      expect(find.byKey(const Key('open-trash')), findsOneWidget);
    });
  });

  group('자동 삭제 안내', () {
    test('남은 날은 올림해서 세고, 하루가 안 남았으면 곧 지워진다고 한다', () {
      expect(
        trashPurgeLabel(DateTime(2026, 11, 13, 10), testNow),
        '30일 뒤 자동으로 지워져요',
      );
      expect(
        trashPurgeLabel(testNow.add(const Duration(hours: 1)), testNow),
        '1일 뒤 자동으로 지워져요',
      );
      expect(trashPurgeLabel(testNow, testNow), '곧 자동으로 지워져요');
    });
  });

  group('넓은 화면', () {
    testWidgets('옆 탭 막대로 설정에서 휴지통을 열고, 목록은 가운데 640폭으로 둔다', (tester) async {
      await pumpTrashApp(tester, entries: trashOf([lunch]), size: tabletSize);
      await openTrash(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.getSize(inTrash(find.byType(Card)).first).width, 640);
      expect(inTrash(find.byKey(const Key('restore-lunch'))), findsOneWidget);
    });
  });
}
