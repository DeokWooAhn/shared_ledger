import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'router.dart';

/// 앱 최상위 위젯. 화면 구성은 router.dart, 색과 글자는 core/theme에 있다.
class SharedLedgerApp extends ConsumerWidget {
  const SharedLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '심플 공유 가계부',
      theme: buildAppTheme(),
      // 시스템 바 스타일은 화면 위·아래 끝의 AnnotatedRegion으로 정해진다. 앱 바가 없는
      // 화면과 내비게이션 바에도 같은 값이 가도록 앱 전체를 감싼다.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: appSystemOverlayStyle,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
