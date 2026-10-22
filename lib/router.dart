import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/data/providers.dart';
import 'core/model/auth_user.dart';
import 'core/model/ledger.dart';
import 'core/widget/loading_screen.dart';
import 'feature/auth/sign_in_screen.dart';
import 'feature/entries/entries_screen.dart';
import 'feature/home/home_shell.dart';
import 'feature/ledger/ledger_start_screen.dart';
import 'feature/settings/settings_screen.dart';
import 'feature/summary/summary_screen.dart';
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
  HomeTab.entries => const EntriesScreen(),
  HomeTab.templates => const TemplatesScreen(),
  HomeTab.settings => const SettingsScreen(),
};

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
            HomeShell(navigationShell: navigationShell),
        branches: [
          for (final tab in HomeTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: Routes.of(tab),
                  builder: (_, _) => _tabScreen(tab),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
