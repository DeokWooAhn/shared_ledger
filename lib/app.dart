import 'package:flutter/material.dart';

/// 앱 최상위 위젯. 화면 이동과 테마는 기능이 생기면서 여기에 붙인다.
class SharedLedgerApp extends StatelessWidget {
  const SharedLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '심플 공유 가계부',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4AA596)),
      home: const Scaffold(body: Center(child: Text('심플 공유 가계부'))),
    );
  }
}
