import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../model/auth_user.dart';
import '../model/category.dart';
import '../model/ledger.dart';
import '../model/member.dart';
import '../model/payment_method.dart';
import '../model/year_month.dart';
import 'auth_repository.dart';
import 'ledger_repository.dart';
import 'settings_repository.dart';

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

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => FirestoreSettingsRepository(FirebaseFirestore.instance),
);

/// 지금 시각. 테스트에서 날짜를 고정하려고 공급자로 둔다.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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

/// 지금 가계부의 이름표 두 장. 가계부가 없으면 빈 목록.
final membersProvider = StreamProvider<List<Member>>((ref) {
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  if (ledgerId == null) return Stream.value(const []);
  return ref.watch(settingsRepositoryProvider).watchMembers(ledgerId);
});

/// 지금 가계부의 지출 분류. 가계부가 없으면 빈 목록.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  if (ledgerId == null) return Stream.value(const []);
  return ref.watch(settingsRepositoryProvider).watchCategories(ledgerId);
});

/// 지금 가계부의 결제수단. 가계부가 없으면 빈 목록.
final paymentMethodsProvider = StreamProvider<List<PaymentMethod>>((ref) {
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  if (ledgerId == null) return Stream.value(const []);
  return ref.watch(settingsRepositoryProvider).watchPaymentMethods(ledgerId);
});

/// 요약·항목 탭이 같이 보는 달. 처음에는 이번 달이고, 탭을 옮겨도 유지된다.
final selectedMonthProvider = NotifierProvider<SelectedMonth, YearMonth>(
  SelectedMonth.new,
);

/// 보고 있는 달을 바꾼다.
class SelectedMonth extends Notifier<YearMonth> {
  @override
  YearMonth build() => YearMonth.of(ref.read(clockProvider)());

  /// 다음 달로 간다.
  void next() => state = state.next;

  /// 이전 달로 간다.
  void previous() => state = state.previous;
}
