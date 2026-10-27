import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/core/widget/keep_all.dart';
import 'package:shared_ledger/feature/entries/entry_form_screen.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';
import 'package:shared_ledger/feature/settings/categories_screen.dart';
import 'package:shared_ledger/feature/settings/settings_screen.dart';
import 'package:shared_ledger/feature/summary/summary_screen.dart';
import 'package:shared_ledger/feature/templates/templates_screen.dart';

import '../../../testing/app.dart';
import '../../../testing/fakes.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');

/// 앱을 닫으라는 요청(SystemNavigator.pop)이 몇 번 갔는지 센다.
List<String> recordExits(WidgetTester tester) {
  final exits = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') exits.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return exits;
}

/// Android 뒤로가기를 한 번 한다(버튼이나 스와이프 동작).
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
}

Future<void> pumpHome(WidgetTester tester, {Size size = phoneSize}) => pumpApp(
  tester,
  auth: FakeAuthRepository(signedIn: me),
  ledgers: FakeLedgerRepository([mine]),
  size: size,
);

final exitHint = find.text(keepAll('한 번 더 뒤로 가면 앱이 종료돼요.'));

void main() {
  testWidgets('요약이 아닌 탭의 첫 화면에서 뒤로 가면 앱을 닫지 않고 요약 탭으로 간다', (tester) async {
    final exits = recordExits(tester);
    await pumpHome(tester);
    await openTab(tester, HomeTab.templates);
    expect(find.byType(TemplatesScreen), findsOneWidget);

    await pressBack(tester);

    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.byType(TemplatesScreen), findsNothing);
    expect(exitHint, findsNothing);
    expect(exits, isEmpty);
  });

  testWidgets('요약 탭에서 한 번 뒤로 가면 안내만 하고, 2초 안에 한 번 더 뒤로 가면 앱을 닫는다', (
    tester,
  ) async {
    final exits = recordExits(tester);
    await pumpHome(tester);

    await pressBack(tester);
    expect(exitHint, findsOneWidget);
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(exits, isEmpty);

    await pressBack(tester);
    expect(exits, hasLength(1));
  });

  testWidgets('안내 뒤 2초가 지나서 뒤로 가면 다시 안내만 하고 앱을 닫지 않는다', (tester) async {
    final exits = recordExits(tester);
    await pumpHome(tester);

    await pressBack(tester);
    await tester.pump(homeExitWindow);
    await settle(tester);
    await pressBack(tester);

    expect(exitHint, findsOneWidget);
    expect(exits, isEmpty);
  });

  testWidgets('안내를 본 뒤 다른 탭에 다녀오면 요약에서 다시 한 번 안내부터 한다', (tester) async {
    final exits = recordExits(tester);
    await pumpHome(tester);

    await pressBack(tester);
    await openTab(tester, HomeTab.entries);
    await openTab(tester, HomeTab.summary);
    await pressBack(tester);

    expect(exitHint, findsOneWidget);
    expect(exits, isEmpty);
  });

  testWidgets('안내를 띄운 뒤 다른 탭으로 옮기면 안내도 닫힌다', (tester) async {
    await pumpHome(tester);

    await pressBack(tester);
    expect(exitHint, findsOneWidget);
    await openTab(tester, HomeTab.entries);

    expect(exitHint, findsNothing);
  });

  testWidgets('탭 위로 연 항목 입력 화면에서는 입력 화면만 닫히고 앱은 그대로다', (tester) async {
    final exits = recordExits(tester);
    await pumpHome(tester);
    await tester.tap(find.byKey(const Key('add-entry')));
    await settleRoute(tester);
    expect(find.byType(EntryFormScreen), findsOneWidget);

    await pressBack(tester);
    await settleRoute(tester);

    expect(find.byType(EntryFormScreen), findsNothing);
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(exitHint, findsNothing);
    expect(exits, isEmpty);
  });

  testWidgets('탭 안의 하위 화면에서는 그 화면만 닫히고 탭은 그대로다', (tester) async {
    final exits = recordExits(tester);
    await pumpHome(tester);
    await openTab(tester, HomeTab.settings);
    final open = find.byKey(const Key('open-categories'));
    await tester.ensureVisible(open);
    await settle(tester);
    await tester.tap(open);
    await settleRoute(tester);
    expect(find.byType(CategoriesScreen), findsOneWidget);

    await pressBack(tester);
    await settleRoute(tester);

    expect(find.byType(CategoriesScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(exits, isEmpty);
  });

  testWidgets('넓은 화면(옆 탭 막대)에서도 같은 순서로 동작한다', (tester) async {
    final exits = recordExits(tester);
    await pumpHome(tester, size: tabletSize);
    await openTab(tester, HomeTab.settings);

    await pressBack(tester);
    expect(find.byType(SummaryScreen), findsOneWidget);

    await pressBack(tester);
    await pressBack(tester);
    expect(exits, hasLength(1));
  });
}
