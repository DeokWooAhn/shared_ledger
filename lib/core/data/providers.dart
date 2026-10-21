import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../model/auth_user.dart';
import '../model/ledger.dart';
import 'auth_repository.dart';
import 'ledger_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(
    auth: FirebaseAuth.instance,
    googleSignIn: GoogleSignIn.instance,
    // Android는 google-services.json에서 읽으므로 null이다.
    iosClientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
  ),
);

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => FirestoreLedgerRepository(FirebaseFirestore.instance),
);

/// 로그인한 사용자. 로그아웃 상태면 null.
final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// 내가 속한 가계부 목록. 로그아웃 상태면 빈 목록.
final myLedgersProvider = StreamProvider<List<Ledger>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(ledgerRepositoryProvider).watchMyLedgers(user.uid);
});

/// 지금 보고 있는 가계부. 커플 가계부라 보통 하나이고, 여럿이면 먼저 만든 것을 쓴다.
final currentLedgerProvider = Provider<Ledger?>((ref) {
  final ledgers = ref.watch(myLedgersProvider).value;
  return ledgers == null || ledgers.isEmpty ? null : ledgers.first;
});
