import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../model/auth_user.dart';
import '../model/household.dart';
import 'auth_repository.dart';
import 'household_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(
    auth: FirebaseAuth.instance,
    googleSignIn: GoogleSignIn.instance,
    // Android는 google-services.json에서 읽으므로 null이다.
    iosClientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
  ),
);

final householdRepositoryProvider = Provider<HouseholdRepository>(
  (ref) => FirestoreHouseholdRepository(FirebaseFirestore.instance),
);

/// 로그인한 사용자. 로그아웃 상태면 null.
final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// 내가 속한 가구 목록. 로그아웃 상태면 빈 목록.
final myHouseholdsProvider = StreamProvider<List<Household>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(householdRepositoryProvider).watchMyHouseholds(user.uid);
});

/// 지금 보고 있는 가구. 가구 전환은 나중에 만들고, 지금은 먼저 만든 가구를 쓴다.
final currentHouseholdProvider = Provider<Household?>((ref) {
  final households = ref.watch(myHouseholdsProvider).value;
  return households == null || households.isEmpty ? null : households.first;
});
