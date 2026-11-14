import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ledger/app.dart';
import 'package:shared_ledger/core/providers/clock.dart';
import 'package:shared_ledger/data/entries/firestore_entries_repository.dart';
import 'package:shared_ledger/di.dart';
import 'package:shared_ledger/firebase_options.dart';

import 'maestro_diagnostics.dart';

/// Maestro 전용 시작점. 별도 Firebase 앱과 demo 프로젝트로 로컬 Auth·Firestore만 사용한다.
/// 일반 앱(lib/main.dart)에서는 import하지 않고, 배포 빌드로는 실행할 수 없다.
Future<void> main() async {
  if (!kDebugMode) {
    throw UnsupportedError('Maestro 시작점은 디버그 빌드에서만 실행할 수 있습니다.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('MAESTRO_STARTUP firebase-initializing');
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final app = await Firebase.initializeApp(
    name: 'maestro',
    options: FirebaseOptions(
      // iOS Installations SDK는 에뮬레이터에서도 A로 시작하는 39자 형식을 검사한다. 실제 키가 아니다.
      apiKey: 'A00000000000000000000000000000000000000',
      appId: DefaultFirebaseOptions.currentPlatform.appId,
      messagingSenderId: '1234567890',
      projectId: 'demo-shared-ledger',
    ),
  );
  debugPrint('MAESTRO_STARTUP firebase-ready');
  // Android 에뮬레이터는 호스트의 loopback을 10.0.2.2로 본다. 실기기는 adb reverse를 쓴다.
  const hostOverride = String.fromEnvironment('MAESTRO_FIREBASE_HOST');
  final host = hostOverride.isNotEmpty
      ? hostOverride
      : defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
  if (!{'10.0.2.2', '127.0.0.1', 'localhost'}.contains(host)) {
    throw ArgumentError('Maestro는 로컬 Firebase 에뮬레이터에만 연결할 수 있습니다.');
  }
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(host, 19099, automaticHostMapping: false);
  final firestore = FirebaseFirestore.instanceFor(app: app);
  firestore.useFirestoreEmulator(host, 18080, automaticHostMapping: false);
  // Flow마다 서버 데이터를 새로 준비하므로, 이전 실행의 문서를 캐시에서 그리지 않는다.
  firestore.settings = const Settings(persistenceEnabled: false);
  debugPrint('MAESTRO_STARTUP authenticating');
  await auth.signInWithEmailAndPassword(
    email: 'maestro@example.test',
    password: 'maestro-test-password',
  );
  debugPrint('MAESTRO_STARTUP authenticated');
  runApp(
    ProviderScope(
      observers: [MaestroProviderDiagnostics(log: debugPrint)],
      overrides: [
        ...repositoryOverrides(
          auth: auth,
          firestore: firestore,
          entries: FirestoreEntriesRepository(firestore),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 15, 9)),
      ],
      child: const SharedLedgerApp(),
    ),
  );
}
