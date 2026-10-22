import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../budget/month_summary.dart';
import '../model/auth_user.dart';
import '../model/category.dart';
import '../model/ledger.dart';
import '../model/ledger_entries.dart';
import '../model/member.dart';
import '../model/month_ledger.dart';
import '../model/payment_method.dart';
import '../model/year_month.dart';
import 'auth_repository.dart';
import 'entries_repository.dart';
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

final entriesRepositoryProvider = Provider<EntriesRepository>(
  (ref) => FirestoreEntriesRepository(FirebaseFirestore.instance),
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

/// 지금 가계부에서 내 역할. 로그아웃했거나 가계부가 없으면 null.
///
/// 화면에서 쓰기 버튼을 감출 때 쓴다. 실제로 막는 것은 보안 규칙이다.
final myRoleProvider = Provider<MemberRole?>((ref) {
  final uid = ref.watch(authUserProvider.select((user) => user.value?.uid));
  final ledger = ref.watch(currentLedgerProvider);
  return uid == null ? null : ledger?.roleOf(uid);
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

/// 항목 탭에서 보고 있는 종류. 처음에는 기본 월 지출이다.
///
/// + 버튼이 항목 탭에서 눌리면 이 종류로 입력 화면을 연다. 탭을 옮겨도 유지된다.
final selectedEntryKindProvider =
    NotifierProvider<SelectedEntryKind, EntryKind>(SelectedEntryKind.new);

/// 항목 탭에서 보는 종류를 바꾼다.
class SelectedEntryKind extends Notifier<EntryKind> {
  @override
  EntryKind build() => EntryKind.planned;

  void select(EntryKind kind) => state = kind;
}

/// 서버가 받지 않은 새 항목. 오프라인 추가는 기다리지 않아서 거부는 나중에 여기로 온다. 홈 틀이 듣고 알린다.
final rejectedEntriesProvider = StreamProvider<RejectedEntry>(
  (ref) => ref.watch(entriesRepositoryProvider).rejectedAdds,
);

/// 보고 있는 달의 항목(휴지통 제외). 가계부가 없으면 빈 달이다.
///
/// 요약·항목 탭이 이 공급자 하나를 같이 읽어서 그달 구독은 한 벌뿐이다. 달을 옮기면 이전 달 구독을 끊는다.
final monthLedgerProvider = StreamProvider<MonthLedger>((ref) {
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  final month = ref.watch(selectedMonthProvider);
  if (ledgerId == null) return Stream.value(const MonthLedger());
  return ref.watch(entriesRepositoryProvider).watchMonth(ledgerId, month);
});

/// 보고 있는 달의 요약. 항목·분류·결제수단으로 계산한다.
///
/// 셋 중 하나라도 실패하면 실패, 아직 받지 못했으면 불러오는 중이다. 달을 옮긴 직후에도 불러오는 중이라
/// 새 달의 항목이 오기 전에 이전 달 숫자를 보여주지 않는다.
final monthSummaryProvider = Provider<AsyncValue<MonthSummary>>((ref) {
  final ledger = ref.watch(monthLedgerProvider);
  final categories = ref.watch(categoriesProvider);
  final paymentMethods = ref.watch(paymentMethodsProvider);
  for (final AsyncValue<Object> value in [ledger, categories, paymentMethods]) {
    if (value case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
  }
  if ((ledger, categories, paymentMethods) case (
    AsyncData(value: final ledger),
    AsyncData(value: final categories),
    AsyncData(value: final paymentMethods),
  )) {
    return AsyncData(
      MonthSummary.of(
        ledger,
        categories: categories,
        paymentMethods: paymentMethods,
      ),
    );
  }
  return const AsyncLoading();
});
