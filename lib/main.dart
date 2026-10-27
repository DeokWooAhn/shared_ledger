import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'di.dart';
import 'firebase_options.dart';

/// 개발할 때 운영 DB 대신 로컬 Firestore 에뮬레이터를 쓰려면
/// `--dart-define=FIRESTORE_EMULATOR_HOST=<주소>`를 넘긴다. 주소는 그대로 쓴다.
/// 실기기는 `adb reverse` 후 127.0.0.1, Android 에뮬레이터는 10.0.2.2(방법은 verification 스킬).
/// 디버그 빌드에서만 쓰인다.
const _firestoreEmulatorHost = String.fromEnvironment(
  'FIRESTORE_EMULATOR_HOST',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 시스템 바 뒤까지 그리고, 화면은 SafeArea로 가려지지 않게 한다. 바 색은 app.dart에서 정한다.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode && _firestoreEmulatorHost.isNotEmpty) {
    // 플러그인은 Android에서 localhost·127.0.0.1을 에뮬레이터 주소(10.0.2.2)로 바꾸는데,
    // 실기기에서는 adb reverse로 127.0.0.1을 써야 해서 바꾸지 않게 한다.
    FirebaseFirestore.instance.useFirestoreEmulator(
      _firestoreEmulatorHost,
      8080,
      automaticHostMapping: false,
    );
  }
  runApp(
    ProviderScope(
      overrides: repositoryOverrides(),
      child: const SharedLedgerApp(),
    ),
  );
}
