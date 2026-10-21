import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

/// 앱 최상위 위젯. 화면 구성은 router.dart에 있다.
class SharedLedgerApp extends ConsumerWidget {
  const SharedLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '심플 공유 가계부',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4AA596)),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
