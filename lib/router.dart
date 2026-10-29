import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/providers.dart';
import 'domain/model/auth_user.dart';
import 'domain/model/ledger.dart';
import 'domain/model/ledger_entries.dart';
import 'domain/model/year_month.dart';
import 'core/widget/loading_screen.dart';
import 'feature/months/months_screen.dart';
import 'feature/ledger/join_ledger_screen.dart';
import 'feature/ledger/create_ledger_screen.dart';
import 'feature/auth/sign_in_screen.dart';
import 'feature/entries/calendar_screen.dart';
import 'feature/entries/entries_screen.dart';
import 'feature/entries/entry_form_notifier.dart';
import 'feature/entries/entry_form_screen.dart';
import 'feature/home/home_shell.dart';
import 'feature/ledger/ledger_start_screen.dart';
import 'feature/settings/activity_screen.dart';
import 'feature/settings/categories_screen.dart';
import 'feature/settings/payment_methods_screen.dart';
import 'feature/settings/settings_screen.dart';
import 'feature/settings/trash_screen.dart';
import 'feature/summary/summary_screen.dart';

abstract final class Routes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const start = '/start';

  /// 가계부 시작의 만들기·입장 화면. 시작 화면 위로 쌓여 뒤로 가면 시작 화면으로 돌아온다.
  static const startCreate = '$start/create';
  static const startJoin = '$start/join';

  // 홈의 탭. 가계부가 있으면 요약 탭에서 시작한다.
  static const summary = '/';
  static const entries = '/entries';
  static const months = '/months';
  static const settings = '/settings';
  static const home = summary;

  /// 항목 입력·수정. 탭 막대를 가리는 전체 화면이고, 무엇을 열지는 [EntryFormArgs]를 `extra`로 넘긴다.
  static const entry = '/entry';

  /// 달력. 요약·항목 탭 머리말의 달 이름으로 열고, 입력 화면처럼 탭 막대를 가리는 전체 화면이다.
  /// 닫기 단추 없이 뒤로가기(iOS는 왼쪽 끝 밀기)로 닫는다.
  static const calendar = '/calendar';

  /// 설정 탭 안의 분류·결제수단 목록, 휴지통, 변경 기록. 탭 막대는 그대로 보인다.
  static const categories = '$settings/categories';
  static const paymentMethods = '$settings/payment-methods';
  static const trash = '$settings/trash';
  static const activity = '$settings/activity';

  /// [tab] 탭의 경로.
  static String of(HomeTab tab) => switch (tab) {
    HomeTab.summary => summary,
    HomeTab.entries => entries,
    HomeTab.months => months,
    HomeTab.settings => settings,
  };
}

Widget _tabScreen(HomeTab tab) => switch (tab) {
  HomeTab.summary => const SummaryScreen(openCalendar: _openCalendar),
  HomeTab.entries => const EntriesScreen(
    openForm: _openEntryForm,
    openCalendar: _openCalendar,
  ),
  HomeTab.months => const MonthsScreen(openSummary: _openSummary),
  HomeTab.settings => const SettingsScreen(
    openCategories: _openCategories,
    openPaymentMethods: _openPaymentMethods,
    openTrash: _openTrash,
    openActivity: _openActivity,
  ),
};

// 설정 탭의 하위 경로. 탭 막대를 다시 누르면 설정 첫 화면으로 돌아간다.
List<RouteBase> _tabRoutes(HomeTab tab) => switch (tab) {
  HomeTab.settings => [
    GoRoute(
      path: _subPath(Routes.categories),
      builder: (_, _) => const CategoriesScreen(),
    ),
    GoRoute(
      path: _subPath(Routes.paymentMethods),
      builder: (_, _) => const PaymentMethodsScreen(),
    ),
    GoRoute(
      path: _subPath(Routes.trash),
      builder: (_, _) => const TrashScreen(),
    ),
    GoRoute(
      path: _subPath(Routes.activity),
      builder: (_, _) => const ActivityScreen(),
    ),
  ],
  HomeTab.summary || HomeTab.entries || HomeTab.months => const [],
};

// 하위 GoRoute의 path는 앞의 탭 경로를 뺀 나머지다. 예: '/settings/categories' → 'categories'
String _subPath(String location) =>
    location.substring(location.lastIndexOf('/') + 1);

void _openCategories(BuildContext context) =>
    unawaited(context.push<void>(Routes.categories));

void _openPaymentMethods(BuildContext context) =>
    unawaited(context.push<void>(Routes.paymentMethods));

void _openTrash(BuildContext context) =>
    unawaited(context.push<void>(Routes.trash));

void _openActivity(BuildContext context) =>
    unawaited(context.push<void>(Routes.activity));

void _openSummary(BuildContext context) => context.go(Routes.summary);

void _openCreateLedger(BuildContext context) =>
    unawaited(context.push<void>(Routes.startCreate));

void _openJoinLedger(BuildContext context) =>
    unawaited(context.push<void>(Routes.startJoin));

void _openCalendar(BuildContext context) =>
    unawaited(context.push<void>(Routes.calendar));

// 항목 입력 화면을 열고, 닫힐 때의 결과(저장·휴지통·고정 지출 그만하기)를 돌려준다.
Future<EntryFormOutcome?> _openEntryForm(
  BuildContext context,
  EntryFormArgs args,
) => context.push<EntryFormOutcome>(Routes.entry, extra: args);

// + 버튼. 새 항목은 결과를 기다릴 일이 없다.
void _addEntry(BuildContext context, EntryKind kind, YearMonth month) =>
    unawaited(
      _openEntryForm(context, EntryFormArgs.add(kind: kind, month: month)),
    );

/// 로그인·가계부 상태에 따라 보여 줄 화면 단계.
enum AppGate { loading, failed, signedOut, noLedger, ready }

AppGate appGate({
  required AsyncValue<AuthUser?> user,
  required AsyncValue<List<Ledger>> ledgers,
}) {
  if (!user.hasValue && !user.hasError) return AppGate.loading;
  if (user.value == null) return AppGate.signedOut;
  if (ledgers.hasError) return AppGate.failed;
  final list = ledgers.value;
  if (list == null) return AppGate.loading;
  return list.isEmpty ? AppGate.noLedger : AppGate.ready;
}

/// [gate]에 맞지 않는 화면이면 옮길 경로를, 맞으면 null을 돌려준다.
String? redirectFor(AppGate gate, String location) {
  final target = switch (gate) {
    AppGate.loading || AppGate.failed => Routes.loading,
    AppGate.signedOut => Routes.signIn,
    AppGate.noLedger => Routes.start,
    AppGate.ready => null,
  };
  // 가계부 시작은 만들기·입장 화면(`/start/…`)까지 한 묶음이다.
  bool inStart(String location) =>
      location == Routes.start || location.startsWith('${Routes.start}/');
  if (target != null) {
    final there = target == Routes.start
        ? inStart(location)
        : location == target;
    return there ? null : target;
  }
  const entryRoutes = {Routes.loading, Routes.signIn};
  return entryRoutes.contains(location) || inStart(location)
      ? Routes.home
      : null;
}

final appGateProvider = Provider<AppGate>(
  (ref) => appGate(
    user: ref.watch(authUserProvider),
    ledgers: ref.watch(myLedgersProvider),
  ),
);

final routerProvider = Provider<GoRouter>((ref) {
  final gate = ValueNotifier(AppGate.loading);
  ref.listen(
    appGateProvider,
    (_, next) => gate.value = next,
    fireImmediately: true,
  );
  ref.onDispose(gate.dispose);

  final router = GoRouter(
    initialLocation: Routes.loading,
    refreshListenable: gate,
    redirect: (_, state) => redirectFor(gate.value, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.loading, builder: (_, _) => const LoadingScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.start,
        builder: (_, _) => const LedgerStartScreen(
          openCreate: _openCreateLedger,
          openJoin: _openJoinLedger,
        ),
        routes: [
          GoRoute(
            path: _subPath(Routes.startCreate),
            builder: (_, _) => const CreateLedgerScreen(),
          ),
          GoRoute(
            path: _subPath(Routes.startJoin),
            builder: (_, _) => const JoinLedgerScreen(),
          ),
        ],
      ),
      // 탭마다 화면 상태를 지키는 홈. branch 순서가 HomeTab 순서와 같아야 한다.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            HomeShell(navigationShell: navigationShell, onAddEntry: _addEntry),
        branches: [
          for (final tab in HomeTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: Routes.of(tab),
                  builder: (_, _) => _tabScreen(tab),
                  routes: _tabRoutes(tab),
                ),
              ],
            ),
        ],
      ),
      // 탭 밖(루트)에 둬서 탭 막대를 가린다. 열 항목 없이 들어오면 항목 탭으로 보낸다.
      // 입력 화면은 왼쪽 위 뒤로 단추로 닫으니 보통 화면처럼 옆에서 들어오고, iOS는 왼쪽 끝을 밀어 닫는다.
      GoRoute(
        path: Routes.entry,
        redirect: (_, state) =>
            state.extra is EntryFormArgs ? null : Routes.entries,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          child: switch (state.extra) {
            final EntryFormArgs args => EntryFormScreen(args: args),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
      // 닫기 단추가 없어서 보통 화면으로 연다. iOS는 왼쪽 끝을 밀어서, Android는 뒤로가기로 닫는다
      // (fullscreenDialog면 iOS에서 밀어 닫을 수 없다).
      GoRoute(
        path: Routes.calendar,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          child: const CalendarScreen(openForm: _openEntryForm),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
