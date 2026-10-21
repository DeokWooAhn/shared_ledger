import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/data/providers.dart';
import 'core/model/auth_user.dart';
import 'core/model/ledger.dart';
import 'core/widget/loading_screen.dart';
import 'feature/auth/sign_in_screen.dart';
import 'feature/ledger/ledger_home_screen.dart';
import 'feature/ledger/ledger_start_screen.dart';

abstract final class Routes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const start = '/start';
  static const home = '/';
}

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
      GoRoute(path: Routes.home, builder: (_, _) => const LedgerHomeScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
