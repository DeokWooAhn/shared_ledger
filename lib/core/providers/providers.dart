import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/budget/month_summary.dart';
import '../../domain/model/activity.dart';
import '../../domain/model/auth_user.dart';
import '../../domain/model/category.dart';
import '../../domain/model/expense_template.dart';
import '../../domain/model/holidays.dart';
import '../../domain/model/ledger.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/member.dart';
import '../../domain/model/month_ledger.dart';
import '../../domain/model/payment_method.dart';
import '../../domain/model/year_month.dart';
import '../../domain/repository/entries_repository.dart';
import 'clock.dart';
import 'usecases.dart';

// 저장소 공급자(repositories.dart)는 내보내지 않는다. 화면과 Notifier는 UseCase 홀더(usecases.dart)로만 저장소에 닿는다.
export 'clock.dart';

/// 로그인한 사용자. 로그아웃 상태면 null.
final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authUseCasesProvider).watchAuthUser(),
);

/// 내가 속한 가계부 목록. 로그아웃 상태면 빈 목록.
final myLedgersProvider = StreamProvider<List<Ledger>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(ledgerUseCasesProvider).watchMyLedgers(user.uid);
});

/// 지금 보고 있는 가계부. 고르는 규칙은 `SelectCurrentLedgerUseCase`(먼저 만든 것)다.
final currentLedgerProvider = Provider<Ledger?>((ref) {
  final ledgers = ref.watch(myLedgersProvider).value;
  if (ledgers == null) return null;
  return ref.watch(ledgerUseCasesProvider).selectCurrentLedger(ledgers);
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
  return ref.watch(settingsUseCasesProvider).watchMembers(ledgerId);
});

/// 지금 가계부의 지출 분류. 가계부가 없으면 빈 목록.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  if (ledgerId == null) return Stream.value(const []);
  return ref.watch(settingsUseCasesProvider).watchCategories(ledgerId);
});

/// 지금 가계부의 결제수단. 가계부가 없으면 빈 목록.
final paymentMethodsProvider = StreamProvider<List<PaymentMethod>>((ref) {
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  if (ledgerId == null) return Stream.value(const []);
  return ref.watch(settingsUseCasesProvider).watchPaymentMethods(ledgerId);
});

/// 지금 가계부의 반복 설정(고정 지출·고정 수입). 가계부가 없으면 빈 목록.
///
/// 항목 입력 화면, 휴지통, 설정의 분류·결제수단 시트와 새 달을 채우는 홈 틀이 같이 읽어서 구독은 한 벌뿐이다.
final templatesProvider = StreamProvider<List<ExpenseTemplate>>((ref) {
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  if (ledgerId == null) return Stream.value(const []);
  return ref.watch(templateUseCasesProvider).watchTemplates(ledgerId);
});

/// 가계부가 있는 달(가계부 탭에서 추가했거나 항목이 들어간 적 있는 달, [Ledger.months]). 오래된 것부터 정렬돼 있다.
///
/// 요약·항목 탭(과 휴지통)은 이 달들만 오가고, 가계부 탭이 이 목록을 보여준다. 이번 달이라도 추가하지 않았으면 없다.
/// 목록을 아직 모으지 않은 가계부(months가 null)거나 가계부가 없으면 null이고, 그때는 달을 가리지 않는다.
/// 달력은 이 목록과 상관없이 모든 달을 보여준다.
final ledgerMonthsProvider = Provider<List<YearMonth>?>((ref) {
  final months = ref.watch(currentLedgerProvider.select((l) => l?.months));
  if (months == null) return null;
  return [...months]..sort();
});

/// 요약·항목 탭이 같이 보는 달. 탭을 옮겨도 유지된다.
///
/// 처음에는 가계부가 있는 달 가운데 이번 달에 가장 가까운 달이다(이번 달이 있으면 이번 달, [nearestMonth]).
/// 달 목록이 바뀌어 보던 달이 목록에서 빠지면(다른 가계부로 옮김 등) 다시 가장 가까운 달로 옮긴다.
final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, YearMonth>(
      SelectedMonthNotifier.new,
    );

/// 보고 있는 달을 바꾼다.
class SelectedMonthNotifier extends Notifier<YearMonth> {
  @override
  YearMonth build() {
    ref.listen(ledgerMonthsProvider, (_, months) {
      if (months == null || months.isEmpty || months.contains(state)) return;
      state = nearestMonth(months, state) ?? state;
    });
    final thisMonth = YearMonth.of(ref.read(clockProvider)());
    return nearestMonth(
          ref.read(ledgerMonthsProvider) ?? const [],
          thisMonth,
        ) ??
        thisMonth;
  }

  /// 다음 달로 간다.
  void next() => state = state.next;

  /// 이전 달로 간다.
  void previous() => state = state.previous;

  /// [month]로 바로 간다(달력의 '오늘', 달 고르기).
  void select(YearMonth month) => state = month;
}

/// 항목 탭의 세 칸. 수입 칸은 고정 수입과 추가 수입을, 지출 칸은 고정 지출과 추가 지출을 구역으로 나눠 함께 보여준다.
enum EntryTab {
  income([EntryKind.fixedIncome, EntryKind.income]),
  expense([EntryKind.planned, EntryKind.extra]),
  cardBill([EntryKind.cardBill]);

  const EntryTab(this.kinds);

  /// 이 칸에 보이는 종류. 보이는 순서다.
  final List<EntryKind> kinds;

  /// + 버튼이 이 칸에서 여는 종류. 수입·지출 칸은 자주 적는 추가 수입·추가 지출이다(입력 화면의 종류 칸에서 바꾼다).
  EntryKind get addKind => switch (this) {
    EntryTab.income => EntryKind.income,
    EntryTab.expense => EntryKind.extra,
    EntryTab.cardBill => EntryKind.cardBill,
  };
}

/// 항목 탭에서 보고 있는 칸. 처음에는 지출이다.
///
/// + 버튼이 항목 탭에서 눌리면 이 칸의 [EntryTab.addKind]로 입력 화면을 연다. 탭을 옮겨도 유지된다.
final selectedEntryTabProvider =
    NotifierProvider<SelectedEntryTabNotifier, EntryTab>(
      SelectedEntryTabNotifier.new,
    );

/// 항목 탭에서 보는 칸을 바꾼다.
class SelectedEntryTabNotifier extends Notifier<EntryTab> {
  @override
  EntryTab build() => EntryTab.expense;

  void select(EntryTab tab) => state = tab;
}

/// 서버가 받지 않은 새 항목. 오프라인 추가는 기다리지 않아서 거부는 나중에 여기로 온다. 홈 틀이 듣고 알린다.
final rejectedEntriesProvider = StreamProvider<RejectedEntry>(
  (ref) => ref.watch(entryUseCasesProvider).watchRejectedEntries(),
);

/// 지금 가계부의 [YearMonth] 달 항목(휴지통 제외). 가계부가 없으면 빈 달이다.
///
/// 아무도 읽지 않으면 구독을 끊는다. 같은 달은 여러 화면이 읽어도 구독이 한 벌이라,
/// 달력이 앞뒤 달을 미리 읽어 두면 달을 옮길 때 [monthLedgerProvider]가 기다리지 않고 바로 그 값을 쓴다.
final monthLedgerOfProvider = StreamProvider.autoDispose
    .family<MonthLedger, YearMonth>((ref, month) {
      final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
      if (ledgerId == null) return Stream.value(const MonthLedger());
      return ref.watch(entryUseCasesProvider).watchMonth(ledgerId, month);
    });

/// 보고 있는 달의 항목(휴지통 제외). 가계부가 없으면 빈 달이다.
///
/// 요약·항목 탭이 이 공급자 하나를 같이 읽어서 그달 구독은 한 벌뿐이다. 달을 옮기면 이전 달 구독을 끊는다
/// (달력이 그 달을 아직 읽고 있으면 남는다). 새 달을 아직 받지 못했으면 이전 달 값 대신 불러오는 중이다.
final monthLedgerProvider = Provider<AsyncValue<MonthLedger>>(
  (ref) => ref.watch(monthLedgerOfProvider(ref.watch(selectedMonthProvider))),
);

/// 보고 있는 달의 요약. 항목·분류·결제수단으로 계산한다(`CalculateMonthSummaryUseCase`).
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
      ref
          .watch(summaryUseCasesProvider)
          .calculateMonthSummary(
            ledger,
            categories: categories,
            paymentMethods: paymentMethods,
          ),
    );
  }
  return const AsyncLoading();
});

/// [int]년 공휴일. 달력이 그해를 보는 동안만 구독한다(문서 하나). 로그인하지 않았으면(규칙이 막는다) 빈 해다.
final holidaysOfYearProvider = StreamProvider.autoDispose.family<Holidays, int>(
  (ref, year) {
    final uid = ref.watch(authUserProvider.select((user) => user.value?.uid));
    if (uid == null) return Stream.value(const Holidays());
    return ref.watch(holidayUseCasesProvider).watchHolidays(year);
  },
);

/// 지금 가계부의 최근 변경 기록([activityPageSize]건, 새것부터). 가계부가 없으면 빈 목록.
///
/// 계속 늘어나는 목록이라 변경 기록 화면이 열려 있을 때만 구독한다(autoDispose). 더 오래된 기록은 화면이 따로 읽는다.
final recentActivityProvider = StreamProvider.autoDispose<List<Activity>>((
  ref,
) {
  final ledgerId = ref.watch(currentLedgerProvider.select((l) => l?.id));
  if (ledgerId == null) return Stream.value(const []);
  return ref.watch(activityUseCasesProvider).watchRecentActivity(ledgerId);
});
