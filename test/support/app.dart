import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/app.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/widget/keep_all.dart';
import 'package:shared_ledger/core/widget/month_header.dart';
import 'package:shared_ledger/feature/home/home_shell.dart';

import 'fakes.dart';
import 'provider_container.dart';

// 앱 전체를 띄우는 위젯 테스트의 도우미. 작성 기준은 testing 스킬.

/// 디자인과 같은 휴대폰 화면 크기. 테스트 기본값(800×600)은 넓은 화면 배치가 된다.
const phoneSize = Size(390, 844);
const tabletSize = Size(1024, 768);

Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required FakeLedgerRepository ledgers,
  FakeSettingsRepository? settings,
  FakeEntriesRepository? entries,
  Size size = phoneSize,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        ledgerRepositoryProvider.overrideWithValue(ledgers),
        settingsRepositoryProvider.overrideWithValue(
          settings ?? FakeSettingsRepository(),
        ),
        entriesRepositoryProvider.overrideWithValue(
          entries ?? FakeEntriesRepository(),
        ),
        clockProvider.overrideWithValue(() => testNow),
      ],
      child: const SharedLedgerApp(),
    ),
  );
  await settle(tester);
}

Future<void> openTab(WidgetTester tester, HomeTab tab) async {
  await tester.tap(find.byKey(tab.key));
  await settle(tester);
}

// 불러오는 중 화면의 진행 표시 때문에 pumpAndSettle 대신 몇 번만 그린다.
// 화면 전환(300ms)이 끝날 만큼 그려야 이전 화면의 Scaffold가 남아 스낵바가 두 번 보이지 않는다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// 가계부 시작 화면은 스크롤되고 화면 밖 항목은 아직 만들어지지 않았을 수 있어서,
// 위젯이 나올 때까지 스크롤한 뒤 다룬다.
Future<void> scrollTo(WidgetTester tester, Key key) =>
    tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find.byType(Scrollable).first,
    );

Future<void> tapVisible(WidgetTester tester, Key key) async {
  await scrollTo(tester, key);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

Future<void> enterVisible(WidgetTester tester, Key key, String text) async {
  await scrollTo(tester, key);
  await tester.enterText(find.byKey(key), text);
}

// 화면의 문장은 줄바꿈을 막는 글자를 넣어 그리므로(keepAll) 같은 방식으로 찾는다.
Finder findSentence(String text) => find.text(keepAll(text));

// 이름표 첫 글자는 머리말과 월 요약의 구성원별 소계에 둘 다 나온다. 머리말 것만 찾는다.
Finder inMonthHeader(Finder finder) =>
    find.descendant(of: find.byType(MonthHeader), matching: finder);

// 키를 단 금액 글자의 내용.
String? textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data;
