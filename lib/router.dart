import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/data/providers.dart';
import 'core/model/auth_user.dart';
import 'core/model/ledger.dart';
import 'core/model/ledger_entries.dart';
import 'core/model/year_month.dart';
import 'core/widget/loading_screen.dart';
import 'feature/auth/sign_in_screen.dart';
import 'feature/entries/entries_screen.dart';
import 'feature/entries/entry_form_controller.dart';
import 'feature/entries/entry_form_screen.dart';
import 'feature/home/home_shell.dart';
import 'feature/ledger/ledger_start_screen.dart';
import 'feature/settings/activity_screen.dart';
import 'feature/settings/categories_screen.dart';
import 'feature/settings/payment_methods_screen.dart';
import 'feature/settings/settings_screen.dart';
import 'feature/settings/trash_screen.dart';
import 'feature/summary/summary_screen.dart';
import 'feature/templates/template_form_controller.dart';
import 'feature/templates/template_form_screen.dart';
import 'feature/templates/templates_screen.dart';

abstract final class Routes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const start = '/start';

  // 홈의 탭. 가계부가 있으면 요약 탭에서 시작한다.
  static const summary = '/';
  static const entries = '/entries';
  static const templates = '/templates';
  static const settings = '/settings';
  static const home = summary;

  /// 항목 입력·수정. 탭 막대를 가리는 전체 화면이고, 무엇을 열지는 [EntryFormArgs]를 `extra`로 넘긴다.
  static const entry = '/entry';

  /// 고정 지출 입력·수정. 항목 입력처럼 탭 막대를 가리는 전체 화면이고, [TemplateFormArgs]를 `extra`로 넘긴다.
  static const template = '/template';

  /// 설정 탭 안의 분류·결제수단 목록, 휴지통, 변경 기록. 탭 막대는 그대로 보인다.
  static const categories = '$settings/categories';
  static const paymentMethods = '$settings/payment-methods';
  static const trash = '$settings/trash';
  static const activity = '$settings/activity';

  /// [tab] 탭의 경로.
  static String of(HomeTab tab) => switch (tab) {
    HomeTab.summary => summary,
    HomeTab.entries => entries,
    HomeTab.templates => templates,
    HomeTab.settings => settings,
  };
}

Widget _tabScreen(HomeTab tab) => switch (tab) {
  HomeTab.summary => const SummaryScreen(),
  HomeTab.entries => const EntriesScreen(openForm: _openEntryForm),
  HomeTab.templates => const TemplatesScreen(openForm: _openTemplateForm),
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
  HomeTab.summary || HomeTab.entries || HomeTab.templates => const [],
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

// 항목 입력 화면을 열고, 닫힐 때의 결과(저장·휴지통)를 돌려준다.
Future<EntryFormOutcome?> _openEntryForm(
  BuildContext context,
  EntryFormArgs args,
) => context.push<EntryFormOutcome>(Routes.entry, extra: args);

// 고정 지출 입력 화면을 열고, 닫힐 때의 결과(저장·삭제)를 돌려준다.
Future<TemplateFormOutcome?> _openTemplateForm(
  BuildContext context,
  TemplateFormArgs args,
) => context.push<TemplateFormOutcome>(Routes.template, extra: args);

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
  if (target != null) return location == target ? null : target;
  const entryRoutes = {Routes.loading, Routes.signIn, Routes.start};
  return entryRoutes.contains(location) ? Routes.home : null;
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
      GoRoute(path: Routes.start, builder: (_, _) => const LedgerStartScreen()),
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
      GoRoute(
        path: Routes.entry,
        redirect: (_, state) =>
            state.extra is EntryFormArgs ? null : Routes.entries,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: switch (state.extra) {
            final EntryFormArgs args => EntryFormScreen(args: args),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
      // 열 고정 지출 없이 들어오면 고정 지출 탭으로 보낸다.
      GoRoute(
        path: Routes.template,
        redirect: (_, state) =>
            state.extra is TemplateFormArgs ? null : Routes.templates,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: switch (state.extra) {
            final TemplateFormArgs args => TemplateFormScreen(args: args),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
