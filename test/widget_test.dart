import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/app.dart';
import 'package:shared_ledger/core/data/providers.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/household.dart';
import 'package:shared_ledger/feature/household/create_household_screen.dart';

import 'support/fakes.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required FakeHouseholdRepository households,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        householdRepositoryProvider.overrideWithValue(households),
      ],
      child: const SharedLedgerApp(),
    ),
  );
  await settle(tester);
}

// 불러오는 중 화면의 진행 표시 때문에 pumpAndSettle 대신 몇 번만 그린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('로그아웃 상태면 로그인 화면을 보여준다', (tester) async {
    await pumpApp(
      tester,
      auth: FakeAuthRepository(),
      households: FakeHouseholdRepository(),
    );

    expect(find.text('심플 공유 가계부'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
  });

  testWidgets('iOS에서는 Apple 로그인 버튼을 보여주고 누르면 Apple로 로그인한다', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth, households: FakeHouseholdRepository());

    await tester.tap(find.byKey(const Key('sign-in-apple')));
    await settle(tester);

    expect(auth.appleCalls, 1);
    expect(find.text('가구 만들기'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android에서는 Apple 로그인 버튼을 보여주지 않는다', (tester) async {
    await pumpApp(
      tester,
      auth: FakeAuthRepository(),
      households: FakeHouseholdRepository(),
    );

    expect(find.byKey(const Key('sign-in-apple')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Google로 로그인하고 가구가 없으면 가구 만들기 화면으로 간다', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth, households: FakeHouseholdRepository());

    await tester.tap(find.byKey(const Key('sign-in-google')));
    await settle(tester);

    expect(auth.googleCalls, 1);
    expect(find.text('가구 만들기'), findsOneWidget);
  });

  testWidgets('로그인을 취소하면 로그인 화면에 그대로 있다', (tester) async {
    final auth = FakeAuthRepository()..cancelNextSignIn = true;
    await pumpApp(tester, auth: auth, households: FakeHouseholdRepository());

    await tester.tap(find.byKey(const Key('sign-in-google')));
    await settle(tester);

    expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('가구를 만들면 나를 관리자로 저장하고 가구 홈으로 간다', (tester) async {
    final households = FakeHouseholdRepository();
    await pumpApp(
      tester,
      auth: FakeAuthRepository(signedIn: const AuthUser(uid: 'me')),
      households: households,
    );

    await tester.enterText(find.byKey(const Key('household-name')), ' 행복한 집 ');
    await tester.tap(find.byKey(const Key('create-household')));
    await settle(tester);

    expect(households.created, [(name: '행복한 집', ownerUid: 'me')]);
    expect(find.text('행복한 집'), findsOneWidget);
    expect(find.text('관리자'), findsOneWidget);
  });

  testWidgets('가구 이름이 비어 있으면 만들지 않고 안내한다', (tester) async {
    final households = FakeHouseholdRepository();
    await pumpApp(
      tester,
      auth: FakeAuthRepository(signedIn: const AuthUser(uid: 'me')),
      households: households,
    );

    await tester.enterText(find.byKey(const Key('household-name')), '   ');
    await tester.tap(find.byKey(const Key('create-household')));
    await settle(tester);

    expect(households.created, isEmpty);
    expect(find.text('가구 이름을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('이미 가구가 있으면 바로 가구 홈을 보여주고, 로그아웃하면 로그인 화면으로 간다', (tester) async {
    final auth = FakeAuthRepository(signedIn: const AuthUser(uid: 'me'));
    await pumpApp(
      tester,
      auth: auth,
      households: FakeHouseholdRepository([
        const Household(
          id: 'h1',
          name: '우리집',
          ownerUid: 'owner',
          roles: {'me': HouseholdRole.viewer},
        ),
      ]),
    );

    expect(find.text('우리집'), findsOneWidget);
    expect(find.text('보기 전용'), findsOneWidget);
    expect(find.text('2명'), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await settle(tester);

    expect(auth.signOutCalls, 1);
    expect(find.byKey(const Key('sign-in-google')), findsOneWidget);
  });

  test('가구 이름 검사: 앞뒤 공백을 빼고 1~40자', () {
    expect(validateHouseholdName('우리집'), isNull);
    expect(validateHouseholdName('  '), isNotNull);
    expect(validateHouseholdName('가' * 40), isNull);
    expect(validateHouseholdName('가' * 41), isNotNull);
  });
}
