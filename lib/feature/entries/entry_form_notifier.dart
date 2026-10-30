import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repository/entries_repository.dart';
import '../../domain/repository/templates_repository.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/model/expense_template.dart';
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

  /// 새 항목의 처음 날짜. 고정 지출은 지급 전으로 시작해서 쓰지 않는다.
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

/// 진행 중인 동작. [stop]은 고정 지출 그만하기다.
enum EntryFormAction { save, trash, stop }

/// 스낵바로 알릴 일회성 실패.
enum EntryFormFailure {
  /// 고치기·휴지통은 온라인에서만 된다.
  offline,

  /// 그사이 상대가 휴지통에 넣었거나 지웠다.
  gone,
  save,
  trash,
  stop,
}

/// 입력 화면이 닫히며 알려 줄 결과. 휴지통에 넣었거나 고정 지출을 그만했으면 목록이 '되돌리기'를 띄운다.
sealed class EntryFormOutcome {
  const EntryFormOutcome();

  static const saved = EntrySaved();
  static const trashed = EntryTrashed();
}

/// 저장했다.
final class EntrySaved extends EntryFormOutcome {
  const EntrySaved();
}

/// 휴지통에 넣었다.
final class EntryTrashed extends EntryFormOutcome {
  const EntryTrashed();
}

/// 고정 지출·고정 수입을 그만했다. 되돌리기에 쓸 그만하기 전의 반복 설정과 휴지통에 넣은 달을 담는다.
final class FixedEntryStopped extends EntryFormOutcome {
  const FixedEntryStopped({required this.template, required this.months});

  final ExpenseTemplate template;
  final List<YearMonth> months;
}

/// 입력 화면 상태. 고른 값(종류·누가·분류·결제수단·카드·날짜·매달 예정일)과 진행 상태를 담는다.
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
    this.dueDay,
    this.amountForLater = false,
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

  /// 받은 날·지급한 날·쓴 날·출금일. 고정 지출은 이 값이 있으면 지급 완료, 고정 수입은 받음 완료다.
  final DateTime? date;

  /// 고정 지출·고정 수입의 매달 예정일(1~31, 31은 말일). 고치는 항목에서 아직 고르지 않았으면 null이고,
  /// 그때는 반복 설정의 예정일을 쓴다([EntryFormNotifier.templateOf]).
  final int? dueDay;

  /// 고치는 고정 지출·고정 수입의 금액을 다음 달부터도 쓸지('다음 달부터도 이 금액으로'). 끄면 그달만 바뀐다.
  final bool amountForLater;

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

  /// 고정 지출의 지급 완료·고정 수입의 받음 완료 스위치.
  bool get paid => date != null;

  /// 고른 값과 문제를 바꾼다. 날짜와 진행 상태는 그대로 둔다.
  EntryFormState copyWith({
    String? memberId,
    String? categoryId,
    String? paymentMethodId,
    String? cardId,
    int? dueDay,
    bool? amountForLater,
    Set<EntryProblem>? problems,
  }) => EntryFormState(
    kind: kind,
    memberId: memberId ?? this.memberId,
    categoryId: categoryId ?? this.categoryId,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    cardId: cardId ?? this.cardId,
    date: date,
    dueDay: dueDay ?? this.dueDay,
    amountForLater: amountForLater ?? this.amountForLater,
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
    dueDay: dueDay,
    amountForLater: amountForLater,
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
    dueDay: dueDay,
    amountForLater: amountForLater,
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
      other.dueDay == dueDay &&
      other.amountForLater == amountForLater &&
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
    dueDay,
    amountForLater,
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
/// 고정 지출·고정 수입은 반복 설정과 함께 더하고 고치며, 지우는 대신 그만한다(`TemplateUseCases`). 반복 설정이 없는
/// 옛 고정 지출과 그만한 뒤 남은 항목은 다른 항목처럼 고치고 휴지통에 넣는다. 새 항목은 오프라인에서도 더할 수 있고,
/// 반복 설정 쓰기와 고치기·휴지통은
/// 온라인에서만 된다(docs/plan.md). 끝나면 [EntryFormState.outcome]을 채우고, 화면이 그 값으로 닫힌다.
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
  // 고정 지출·고정 수입은 지급 전·받기 전으로 시작한다.
  DateTime? _defaultDate(EntryKind kind) {
    if (kind.isFixed) return null;
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

  /// 고치는 고정 지출·고정 수입의 반복 설정. 새 항목이거나, 고정 지출·고정 수입이 아니거나,
  /// 반복 설정이 없으면(옛 고정 지출, 그만한 뒤 남은 항목) null이다.
  ///
  /// 반복 설정 목록을 아직 받지 못했으면 null이다. 화면은 같은 값을 공급자에서 직접 그린다.
  ExpenseTemplate? templateOf(List<ExpenseTemplate>? templates) {
    final entry = args.entry;
    if (entry == null || !entry.kind.isFixed) return null;
    return templates
        ?.where((t) => t.id == entry.id && t.kind == entry.kind)
        .firstOrNull;
  }

  /// 고정 지출·고정 수입의 매달 예정일을 고른다.
  void selectDueDay(int day) {
    if (state.busy) return;
    state = state.copyWith(
      dueDay: day,
      problems: {...state.problems}..remove(EntryProblem.dueDayMissing),
    );
  }

  /// 고치는 고정 지출·고정 수입의 금액을 다음 달부터도 쓸지 정한다.
  void setAmountForLater(bool value) {
    if (state.busy) return;
    state = state.copyWith(amountForLater: value);
  }

  /// 누구 몫인지 고른다.
  void selectMember(MemberSlot slot) {
    if (state.busy) return;
    state = state.copyWith(memberId: slot.name);
  }

  /// 고정 지출의 분류를 고른다.
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

  /// 카드 대금이 빠져나간 카드를 고른다.
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

  /// 날짜를 비운다. 고정 지출·고정 수입이면 지급 전·받기 전이 된다.
  void clearDate() {
    if (state.busy) return;
    state = state.withDate(null);
  }

  /// 고정 지출의 지급 완료·고정 수입의 받음 완료 스위치. 켜면 지급한 날·받은 날을 오늘로 채우고
  /// (그달 밖이면 그달 첫날·말일), 끄면 비운다.
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
      EntryTextField.amount => {
        EntryProblem.amountMissing,
        EntryProblem.amountNegative,
      },
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
  /// 입력에 문제가 있으면 [EntryFormState.problems]로 알리고 저장하지 않는다([entryProblemsOf], 고정 지출·고정 수입은
  /// [fixedEntryProblemsOf]). 새 고정 지출·고정 수입은 반복 설정과 함께 더하고, 반복 설정이 있는 것은 반복 설정과 함께
  /// 고친다. 둘 다 온라인에서만 된다. 다른 새 항목은 서버를 기다리지 않아 오프라인에서도 바로 끝나고,
  /// 고치기는 온라인에서만 된다(`SaveEntryUseCase`).
  Future<void> save({
    required String amount,
    required String title,
    required String memo,
  }) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledger = ref.read(currentLedgerProvider);
    if (state.busy || uid == null || ledger == null) return;
    final entry = args.entry;
    // 고치는 고정 지출·고정 수입은 반복 설정이 있는지 봐야 한다. 목록을 아직 받지 않았으면 받아 온다.
    var templates = ref.read(templatesProvider).value;
    if (entry != null && entry.kind.isFixed && templates == null) {
      state = state.withStatus(pending: EntryFormAction.save);
      try {
        templates = await _templates();
      } catch (e) {
        debugPrint('반복 설정 읽기 실패: $e');
        if (ref.mounted) {
          state = state.withStatus(failure: EntryFormFailure.save);
        }
        return;
      }
      if (!ref.mounted) return;
      state = state.withStatus();
    }
    final template = templateOf(templates);
    final fixed = state.kind.isFixed && (entry == null || template != null);
    final dueDay = state.dueDay ?? template?.dueDay;
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
      // 반복 설정이 없는 고정 지출·고정 수입의 예정일은 입력 화면에서 고치지 않고 그대로 둔다.
      dueOn: switch (entry) {
        PlannedExpense(:final dueOn) || FixedIncome(:final dueOn) => dueOn,
        _ => null,
      },
      memo: trimmedMemo.isEmpty ? null : trimmedMemo,
    );
    final problems = fixed
        ? fixedEntryProblemsOf(draft, dueDay: dueDay)
        : entryProblemsOf(draft);
    if (problems.isNotEmpty) {
      state = state.copyWith(problems: problems);
      return;
    }
    state = state.withStatus(pending: EntryFormAction.save);
    final templateUseCases = ref.read(templateUseCasesProvider);
    try {
      final refused = switch ((fixed, template)) {
        (true, null) => await templateUseCases.addFixedEntry(
          ledger: ledger,
          month: args.month,
          entry: draft,
          dueDay: dueDay,
          uid: uid,
        ),
        (true, final template?) => await templateUseCases.updateFixedEntry(
          ledger: ledger,
          month: args.month,
          template: template,
          entry: draft,
          dueDay: dueDay,
          amountForLater: state.amountForLater,
          uid: uid,
        ),
        (false, _) =>
          await ref
              .read(entryUseCasesProvider)
              .saveEntry(
                ledger: ledger,
                month: args.month,
                id: entry?.id,
                draft: draft,
                uid: uid,
              ),
      };
      if (!ref.mounted) return;
      state = refused.isEmpty
          ? state.withStatus(outcome: EntryFormOutcome.saved)
          : state.withStatus().copyWith(problems: refused);
    } on EntryWriteException catch (e) {
      if (!ref.mounted) return;
      state = state.withStatus(failure: _failureOf(e.reason));
    } on TemplateWriteException catch (e) {
      if (!ref.mounted) return;
      state = state.withStatus(failure: _templateFailureOf(e.reason));
    } catch (e) {
      debugPrint('항목 저장 실패: $e');
      if (!ref.mounted) return;
      state = state.withStatus(failure: EntryFormFailure.save);
    }
  }

  /// 고치는 항목을 휴지통에 넣는다. 온라인에서만 된다. 반복 설정이 있는 고정 지출·고정 수입은 [stop]으로 그만한다.
  ///
  /// 화면이 반복 설정 목록을 받기 전에 눌렸을 수 있어서, 목록을 다시 받아 반복 설정이 있으면 휴지통에 넣지 않는다
  /// (그 항목만 숨겨지고 반복 설정이 남지 않게). 화면은 목록을 받으면 '그만하기'로 바뀐다.
  Future<void> trash() async {
    final entry = args.entry;
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (entry == null || state.busy || uid == null || ledgerId == null) return;
    state = state.withStatus(pending: EntryFormAction.trash);
    try {
      final templates = await _templates();
      if (templateOf(templates) != null) {
        if (!ref.mounted) return;
        state = state.withStatus(failure: EntryFormFailure.trash);
        return;
      }
      await ref
          .read(entryUseCasesProvider)
          .trashEntry(
            ledgerId: ledgerId,
            month: args.month,
            entry: entry,
            templateIds: {for (final template in templates) template.id},
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

  /// 고치는 고정 지출·고정 수입을 이 달부터 그만한다. 반복 설정을 지우고 이 달과 뒤 달의 지급 전·받기 전 항목을
  /// 휴지통에 넣는다.
  /// 온라인에서만 된다. 끝나면 되돌리기에 쓸 값을 [FixedEntryStopped]로 남긴다.
  Future<void> stop() async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledger = ref.read(currentLedgerProvider);
    if (state.busy || uid == null || ledger == null) return;
    state = state.withStatus(pending: EntryFormAction.stop);
    try {
      // 그사이 상대가 그만했으면 반복 설정이 없다.
      final template = templateOf(await _templates());
      if (template == null) {
        throw const TemplateWriteException(TemplateWriteFailure.notFound);
      }
      final months = await ref
          .read(templateUseCasesProvider)
          .stopFixedEntry(
            ledger: ledger,
            month: args.month,
            id: template.id,
            uid: uid,
          );
      if (!ref.mounted) return;
      state = state.withStatus(
        outcome: FixedEntryStopped(template: template, months: months),
      );
    } on TemplateWriteException catch (e) {
      if (!ref.mounted) return;
      state = state.withStatus(failure: _templateFailureOf(e.reason));
    } catch (e) {
      debugPrint('반복 설정 그만하기 실패: $e');
      if (!ref.mounted) return;
      state = state.withStatus(failure: EntryFormFailure.stop);
    }
  }

  // 반복 설정 목록. 아무도 듣지 않는 공급자는 멈춰 있어 값을 기다리면 끝나지 않으니, 받는 동안 직접 듣는다.
  Future<List<ExpenseTemplate>> _templates() async {
    final templates = ref.listen(templatesProvider.future, (_, _) {});
    try {
      return await templates.read();
    } finally {
      templates.close();
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

  static EntryFormFailure _templateFailureOf(TemplateWriteFailure reason) =>
      switch (reason) {
        TemplateWriteFailure.offline => EntryFormFailure.offline,
        TemplateWriteFailure.notFound => EntryFormFailure.gone,
      };
}
