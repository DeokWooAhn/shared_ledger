import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repository/entries_repository.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/member.dart';
import '../../domain/model/year_month.dart';
import '../../core/widget/won_input.dart';

/// 입력 화면을 여는 값. 새 항목이면 [entry]가 null이다.
@immutable
class EntryFormArgs {
  /// [month]에 [kind] 항목을 새로 더한다. [date]를 주면(달력에서 고른 날) 날짜를 그날로 채운다.
  const EntryFormArgs.add({required this.kind, required this.month, this.date})
    : entry = null;

  /// [month]에 있는 [entry]를 고친다. 종류는 바꿀 수 없다.
  EntryFormArgs.edit({required LedgerEntry this.entry, required this.month})
    : kind = entry.kind,
      date = null;

  final EntryKind kind;

  /// 항목이 들어가는(들어 있는) 달.
  final YearMonth month;
  final LedgerEntry? entry;

  /// 새 항목의 처음 날짜. 기본 월 지출은 지급 전으로 시작해서 쓰지 않는다.
  final DateTime? date;

  // 같은 항목을 고치는 화면이면 같은 값으로 본다. 항목 내용이 그사이 바뀌어도 화면은 처음 값으로 시작한다.
  @override
  bool operator ==(Object other) =>
      other is EntryFormArgs &&
      other.kind == kind &&
      other.month == month &&
      other.entry?.id == entry?.id &&
      other.date == date;

  @override
  int get hashCode => Object.hash(kind, month, entry?.id, date);
}

/// 글자를 고치면 그 칸의 문제를 지우는 입력란.
enum EntryTextField { amount, title, memo }

/// 진행 중인 동작.
enum EntryFormAction { save, trash }

/// 스낵바로 알릴 일회성 실패.
enum EntryFormFailure {
  /// 고치기·휴지통은 온라인에서만 된다.
  offline,

  /// 그사이 상대가 휴지통에 넣었거나 지웠다.
  gone,
  save,
  trash,
}

/// 입력 화면이 닫히며 알려 줄 결과. 휴지통에 넣었으면 목록이 '되돌리기'를 띄운다.
enum EntryFormOutcome { saved, trashed }

/// 입력 화면 상태. 고른 값(종류·누가·분류·결제수단·카드·날짜)과 진행 상태를 담는다.
/// 금액·내용·메모 글자는 화면의 입력란이 갖고, 저장할 때 넘겨받는다.
@immutable
class EntryFormState {
  const EntryFormState({
    required this.kind,
    required this.memberId,
    this.categoryId,
    this.paymentMethodId,
    this.cardId,
    this.date,
    this.problems = const {},
    this.pending,
    this.failure,
    this.outcome,
  });

  final EntryKind kind;

  /// 누구 몫인지. 이름표 자리 이름(`owner`·`partner`).
  final String memberId;
  final String? categoryId;
  final String? paymentMethodId;
  final String? cardId;

  /// 받은 날·지급한 날·쓴 날·출금일. 기본 월 지출은 이 값이 있으면 지급 완료다.
  final DateTime? date;

  /// 입력란 아래에 보여 줄 문제.
  final Set<EntryProblem> problems;

  /// 진행 중인 동작. null이면 쉬는 중이다.
  final EntryFormAction? pending;

  /// 스낵바로 알릴 실패. 화면이 알린 뒤 [EntryFormNotifier.failureShown]으로 끈다.
  final EntryFormFailure? failure;

  /// 저장하거나 휴지통에 넣어 화면을 닫을 때. 화면이 이 값으로 닫힌다.
  final EntryFormOutcome? outcome;

  /// 진행 중이거나 이미 끝나 닫히는 중이다. 버튼을 막는다.
  bool get busy => pending != null || outcome != null;

  /// 기본 월 지출의 지급 완료 스위치.
  bool get paid => date != null;

  /// 고른 값과 문제를 바꾼다. 날짜와 진행 상태는 그대로 둔다.
  EntryFormState copyWith({
    String? memberId,
    String? categoryId,
    String? paymentMethodId,
    String? cardId,
    Set<EntryProblem>? problems,
  }) => EntryFormState(
    kind: kind,
    memberId: memberId ?? this.memberId,
    categoryId: categoryId ?? this.categoryId,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    cardId: cardId ?? this.cardId,
    date: date,
    problems: problems ?? this.problems,
    pending: pending,
    failure: failure,
    outcome: outcome,
  );

  /// 날짜를 바꾼다. null이면 날짜를 비운다.
  EntryFormState withDate(DateTime? date) => EntryFormState(
    kind: kind,
    memberId: memberId,
    categoryId: categoryId,
    paymentMethodId: paymentMethodId,
    cardId: cardId,
    date: date,
    problems: problems,
    pending: pending,
    failure: failure,
    outcome: outcome,
  );

  /// 진행 상태(진행 중인 동작·실패·결과)를 한꺼번에 바꾼다. 넘기지 않은 것은 비운다.
  EntryFormState withStatus({
    EntryFormAction? pending,
    EntryFormFailure? failure,
    EntryFormOutcome? outcome,
  }) => EntryFormState(
    kind: kind,
    memberId: memberId,
    categoryId: categoryId,
    paymentMethodId: paymentMethodId,
    cardId: cardId,
    date: date,
    problems: problems,
    pending: pending,
    failure: failure,
    outcome: outcome,
  );

  @override
  bool operator ==(Object other) =>
      other is EntryFormState &&
      other.kind == kind &&
      other.memberId == memberId &&
      other.categoryId == categoryId &&
      other.paymentMethodId == paymentMethodId &&
      other.cardId == cardId &&
      other.date == date &&
      setEquals(other.problems, problems) &&
      other.pending == pending &&
      other.failure == failure &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(
    kind,
    memberId,
    categoryId,
    paymentMethodId,
    cardId,
    date,
    Object.hashAllUnordered(problems),
    pending,
    failure,
    outcome,
  );
}

final entryFormNotifierProvider = NotifierProvider.autoDispose
    .family<EntryFormNotifier, EntryFormState, EntryFormArgs>(
      EntryFormNotifier.new,
    );

/// 항목 입력·수정 화면의 Notifier. 새 항목을 더하거나, 있는 항목을 고치거나 휴지통에 넣는다.
///
/// 새 항목은 오프라인에서도 더할 수 있고, 고치기·휴지통은 온라인에서만 된다(docs/plan.md).
/// 끝나면 [EntryFormState.outcome]을 채우고, 화면이 그 값으로 닫힌다.
class EntryFormNotifier extends Notifier<EntryFormState> {
  EntryFormNotifier(this.args);

  final EntryFormArgs args;

  @override
  EntryFormState build() {
    final entry = args.entry;
    if (entry != null) {
      final draft = EntryDraft.of(entry);
      return EntryFormState(
        kind: draft.kind,
        memberId: draft.memberId,
        categoryId: draft.categoryId,
        paymentMethodId: draft.paymentMethodId,
        cardId: draft.cardId,
        date: draft.date,
      );
    }
    // 누가는 처음에 나다. 관리자면 owner, 초대로 들어온 사람이면 partner.
    final uid = ref.read(authUserProvider).value?.uid;
    final ledger = ref.read(currentLedgerProvider);
    final mine = uid == null ? null : ledger?.slotOf(uid);
    return EntryFormState(
      kind: args.kind,
      memberId: (mine ?? MemberSlot.owner).name,
      date: _defaultDate(args.kind),
    );
  }

  DateTime get _today {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  // 새 항목의 날짜: 달력에서 고른 날이 있으면 그날, 없으면 보는 달이 이번 달일 때 오늘, 아니면 비운다.
  // 기본 월 지출은 지급 전으로 시작한다.
  DateTime? _defaultDate(EntryKind kind) {
    if (kind == EntryKind.planned) return null;
    final picked = args.date;
    if (picked != null) return DateTime(picked.year, picked.month, picked.day);
    final today = _today;
    return YearMonth.of(today) == args.month ? today : null;
  }

  /// 종류를 바꾼다. 새 항목에서만 된다. 누가·결제수단은 남기고, 분류·카드·날짜는 그 종류의 처음 값으로 돌린다.
  void selectKind(EntryKind kind) {
    if (args.entry != null || state.busy || kind == state.kind) return;
    final keepsPayment = kind == EntryKind.planned || kind == EntryKind.extra;
    state = EntryFormState(
      kind: kind,
      memberId: state.memberId,
      paymentMethodId: keepsPayment ? state.paymentMethodId : null,
      date: _defaultDate(kind),
    );
  }

  /// 누구 몫인지 고른다.
  void selectMember(MemberSlot slot) {
    if (state.busy) return;
    state = state.copyWith(memberId: slot.name);
  }

  /// 기본 월 지출의 분류를 고른다.
  void selectCategory(String id) {
    if (state.busy) return;
    state = state.copyWith(
      categoryId: id,
      problems: {...state.problems}..remove(EntryProblem.categoryMissing),
    );
  }

  /// 결제수단을 고른다.
  void selectPaymentMethod(String id) {
    if (state.busy) return;
    state = state.copyWith(
      paymentMethodId: id,
      problems: {...state.problems}..remove(EntryProblem.paymentMethodMissing),
    );
  }

  /// 카드대금이 빠져나간 카드를 고른다.
  void selectCard(String id) {
    if (state.busy) return;
    state = state.copyWith(
      cardId: id,
      problems: {...state.problems}..remove(EntryProblem.cardMissing),
    );
  }

  /// 날짜를 고른다. 시각은 버리고 날짜만 남긴다.
  void selectDate(DateTime date) {
    if (state.busy) return;
    state = state.withDate(DateTime(date.year, date.month, date.day));
  }

  /// 날짜를 비운다. 기본 월 지출이면 지급 전이 된다.
  void clearDate() {
    if (state.busy) return;
    state = state.withDate(null);
  }

  /// 기본 월 지출의 지급 완료 스위치. 켜면 지급한 날을 오늘로 채우고(그달 밖이면 그달 첫날·말일), 끄면 비운다.
  void setPaid(bool paid) {
    if (state.busy) return;
    state = state.withDate(paid ? _clampToMonth(_today) : null);
  }

  DateTime _clampToMonth(DateTime day) {
    final month = args.month;
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    if (day.isBefore(first)) return first;
    if (day.isAfter(last)) return last;
    return day;
  }

  /// 글자를 고치면 그 칸의 문제를 지운다.
  void textEdited(EntryTextField field) {
    final cleared = switch (field) {
      EntryTextField.amount => {EntryProblem.amountMissing},
      EntryTextField.title => {
        EntryProblem.titleMissing,
        EntryProblem.titleTooLong,
      },
      EntryTextField.memo => {EntryProblem.memoTooLong},
    };
    if (!state.problems.any(cleared.contains)) return;
    state = state.copyWith(problems: state.problems.difference(cleared));
  }

  /// 입력란의 [amount]·[title]·[memo] 글자와 고른 값으로 저장한다.
  ///
  /// 입력에 문제가 있으면 [EntryFormState.problems]로 알리고 저장하지 않는다([entryProblemsOf]).
  /// 새 항목은 서버를 기다리지 않아 오프라인에서도 바로 끝난다. 고치기는 온라인에서만 된다(`SaveEntryUseCase`).
  Future<void> save({
    required String amount,
    required String title,
    required String memo,
  }) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledger = ref.read(currentLedgerProvider);
    if (state.busy || uid == null || ledger == null) return;
    final trimmedMemo = memo.trim();
    final draft = EntryDraft(
      kind: state.kind,
      memberId: state.memberId,
      amount: parseWon(amount),
      title: title.trim(),
      categoryId: state.categoryId,
      paymentMethodId: state.paymentMethodId,
      cardId: state.cardId,
      date: state.date,
      // 고정 지출에서 옮긴 예정일은 입력 화면에서 고치지 않고 그대로 둔다.
      dueOn: switch (args.entry) {
        PlannedExpense(:final dueOn) => dueOn,
        _ => null,
      },
      memo: trimmedMemo.isEmpty ? null : trimmedMemo,
    );
    final problems = entryProblemsOf(draft);
    if (problems.isNotEmpty) {
      state = state.copyWith(problems: problems);
      return;
    }
    state = state.withStatus(pending: EntryFormAction.save);
    try {
      final refused = await ref
          .read(entryUseCasesProvider)
          .saveEntry(
            ledger: ledger,
            month: args.month,
            id: args.entry?.id,
            draft: draft,
            uid: uid,
          );
      if (!ref.mounted) return;
      state = refused.isEmpty
          ? state.withStatus(outcome: EntryFormOutcome.saved)
          : state.withStatus().copyWith(problems: refused);
    } on EntryWriteException catch (e) {
      if (!ref.mounted) return;
      state = state.withStatus(failure: _failureOf(e.reason));
    } catch (e) {
      debugPrint('항목 저장 실패: $e');
      if (!ref.mounted) return;
      state = state.withStatus(failure: EntryFormFailure.save);
    }
  }

  /// 고치는 항목을 휴지통에 넣는다. 온라인에서만 된다.
  Future<void> trash() async {
    final entry = args.entry;
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (entry == null || state.busy || uid == null || ledgerId == null) return;
    state = state.withStatus(pending: EntryFormAction.trash);
    try {
      await ref
          .read(entryUseCasesProvider)
          .trashEntry(
            ledgerId: ledgerId,
            month: args.month,
            entry: entry,
            uid: uid,
          );
      if (!ref.mounted) return;
      state = state.withStatus(outcome: EntryFormOutcome.trashed);
    } on EntryWriteException catch (e) {
      if (!ref.mounted) return;
      state = state.withStatus(failure: _failureOf(e.reason));
    } catch (e) {
      debugPrint('항목 휴지통 넣기 실패: $e');
      if (!ref.mounted) return;
      state = state.withStatus(failure: EntryFormFailure.trash);
    }
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() =>
      state = state.withStatus(pending: state.pending, outcome: state.outcome);

  static EntryFormFailure _failureOf(EntryWriteFailure reason) =>
      switch (reason) {
        EntryWriteFailure.offline => EntryFormFailure.offline,
        EntryWriteFailure.notFound => EntryFormFailure.gone,
      };
}
