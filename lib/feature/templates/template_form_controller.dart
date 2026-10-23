import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/data/templates_repository.dart';
import '../../core/model/expense_template.dart';
import '../../core/model/ledger_entries.dart';
import '../../core/model/member.dart';
import '../../core/widget/won_input.dart';

/// 고정 지출 입력 화면을 여는 값. 새 고정 지출이면 [template]이 null이다.
@immutable
class TemplateFormArgs {
  /// 새 고정 지출을 더한다.
  const TemplateFormArgs.add() : template = null;

  /// 있는 [template]을 고친다.
  const TemplateFormArgs.edit(ExpenseTemplate this.template);

  final ExpenseTemplate? template;

  // 같은 고정 지출을 고치는 화면이면 같은 값으로 본다. 내용이 그사이 바뀌어도 화면은 처음 값으로 시작한다.
  @override
  bool operator ==(Object other) =>
      other is TemplateFormArgs && other.template?.id == template?.id;

  @override
  int get hashCode => template?.id.hashCode ?? 0;
}

/// 저장 전에 입력란 아래에 보여 줄 문제. 금액은 비워 둘 수 있어서(금액 미정) 문제가 없다.
enum TemplateProblem {
  titleMissing,
  titleTooLong,
  categoryMissing,
  paymentMethodMissing,
  dueDayMissing,
}

/// 진행 중인 동작.
enum TemplateFormAction { save, delete }

/// 스낵바로 알릴 일회성 실패.
enum TemplateFormFailure {
  /// 고정 지출은 온라인에서만 바꾼다.
  offline,

  /// 그사이 상대가 지웠다.
  gone,
  save,
  delete,
}

/// 입력 화면이 닫히며 알려 줄 결과. 지웠으면 목록이 '되돌리기'를 띄운다.
enum TemplateFormOutcome { saved, deleted }

/// 저장할 값을 검사한다. 문제가 없으면 빈 집합.
///
/// 제목 길이는 항목과 같이 보안 규칙처럼 UTF-16 단위로 센다(`entryTitleMaxLength`).
Set<TemplateProblem> templateProblemsOf(TemplateDraft draft) {
  final title = draft.title.trim();
  return {
    if (title.isEmpty) TemplateProblem.titleMissing,
    if (title.length > entryTitleMaxLength) TemplateProblem.titleTooLong,
    if (draft.categoryId == null) TemplateProblem.categoryMissing,
    if (draft.paymentMethodId == null) TemplateProblem.paymentMethodMissing,
    if (draft.dueDay == null) TemplateProblem.dueDayMissing,
  };
}

/// 입력 화면 상태. 고른 값(누가·분류·결제수단·예정일)과 진행 상태를 담는다.
/// 금액·내용 글자는 화면의 입력란이 갖고, 저장할 때 넘겨받는다.
@immutable
class TemplateFormState {
  const TemplateFormState({
    required this.memberId,
    this.categoryId,
    this.paymentMethodId,
    this.dueDay,
    this.problems = const {},
    this.pending,
    this.failure,
    this.outcome,
  });

  /// 누구 몫인지. 이름표 자리 이름(`owner`·`partner`).
  final String memberId;
  final String? categoryId;
  final String? paymentMethodId;

  /// 매달 예정일(1~31, 31은 말일).
  final int? dueDay;

  /// 입력란 아래에 보여 줄 문제.
  final Set<TemplateProblem> problems;

  /// 진행 중인 동작. null이면 쉬는 중이다.
  final TemplateFormAction? pending;

  /// 스낵바로 알릴 실패. 화면이 알린 뒤 [TemplateFormController.failureShown]으로 끈다.
  final TemplateFormFailure? failure;

  /// 저장하거나 지워 화면을 닫을 때. 화면이 이 값으로 닫힌다.
  final TemplateFormOutcome? outcome;

  /// 진행 중이거나 이미 끝나 닫히는 중이다. 버튼을 막는다.
  bool get busy => pending != null || outcome != null;

  /// 고른 값과 문제를 바꾼다. 진행 상태는 그대로 둔다.
  TemplateFormState copyWith({
    String? memberId,
    String? categoryId,
    String? paymentMethodId,
    int? dueDay,
    Set<TemplateProblem>? problems,
  }) => TemplateFormState(
    memberId: memberId ?? this.memberId,
    categoryId: categoryId ?? this.categoryId,
    paymentMethodId: paymentMethodId ?? this.paymentMethodId,
    dueDay: dueDay ?? this.dueDay,
    problems: problems ?? this.problems,
    pending: pending,
    failure: failure,
    outcome: outcome,
  );

  /// 진행 상태(진행 중인 동작·실패·결과)를 한꺼번에 바꾼다. 넘기지 않은 것은 비운다.
  TemplateFormState withStatus({
    TemplateFormAction? pending,
    TemplateFormFailure? failure,
    TemplateFormOutcome? outcome,
  }) => TemplateFormState(
    memberId: memberId,
    categoryId: categoryId,
    paymentMethodId: paymentMethodId,
    dueDay: dueDay,
    problems: problems,
    pending: pending,
    failure: failure,
    outcome: outcome,
  );

  @override
  bool operator ==(Object other) =>
      other is TemplateFormState &&
      other.memberId == memberId &&
      other.categoryId == categoryId &&
      other.paymentMethodId == paymentMethodId &&
      other.dueDay == dueDay &&
      setEquals(other.problems, problems) &&
      other.pending == pending &&
      other.failure == failure &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(
    memberId,
    categoryId,
    paymentMethodId,
    dueDay,
    Object.hashAllUnordered(problems),
    pending,
    failure,
    outcome,
  );
}

final templateFormControllerProvider = NotifierProvider.autoDispose
    .family<TemplateFormController, TemplateFormState, TemplateFormArgs>(
      TemplateFormController.new,
    );

/// 고정 지출 입력·수정 화면의 컨트롤러. 새 고정 지출을 더하거나, 있는 것을 고치거나 지운다.
///
/// 고정 지출은 온라인에서만 바꾼다. 고치거나 지워도 이미 만든 달의 기본 월 지출은 그대로다.
/// 끝나면 [TemplateFormState.outcome]을 채우고, 화면이 그 값으로 닫힌다.
class TemplateFormController extends Notifier<TemplateFormState> {
  TemplateFormController(this.args);

  final TemplateFormArgs args;

  @override
  TemplateFormState build() {
    final template = args.template;
    if (template != null) {
      return TemplateFormState(
        memberId: template.memberId,
        categoryId: template.categoryId,
        paymentMethodId: template.paymentMethodId,
        dueDay: template.dueDay,
      );
    }
    // 누가는 처음에 나다. 관리자면 owner, 초대로 들어온 사람이면 partner.
    final uid = ref.read(authUserProvider).value?.uid;
    final ledger = ref.read(currentLedgerProvider);
    final mine = uid == null ? null : ledger?.slotOf(uid);
    return TemplateFormState(memberId: (mine ?? MemberSlot.owner).name);
  }

  /// 누구 몫인지 고른다.
  void selectMember(MemberSlot slot) {
    if (state.busy) return;
    state = state.copyWith(memberId: slot.name);
  }

  /// 분류를 고른다.
  void selectCategory(String id) {
    if (state.busy) return;
    state = state.copyWith(
      categoryId: id,
      problems: {...state.problems}..remove(TemplateProblem.categoryMissing),
    );
  }

  /// 결제수단을 고른다.
  void selectPaymentMethod(String id) {
    if (state.busy) return;
    state = state.copyWith(
      paymentMethodId: id,
      problems: {...state.problems}
        ..remove(TemplateProblem.paymentMethodMissing),
    );
  }

  /// 매달 예정일을 고른다(1~31, 31은 말일). 범위 밖이면 무시한다.
  void selectDueDay(int day) {
    if (state.busy || day < 1 || day > lastDueDay) return;
    state = state.copyWith(
      dueDay: day,
      problems: {...state.problems}..remove(TemplateProblem.dueDayMissing),
    );
  }

  /// 내용 글자를 고치면 그 칸의 문제를 지운다.
  void titleEdited() {
    const cleared = {
      TemplateProblem.titleMissing,
      TemplateProblem.titleTooLong,
    };
    if (!state.problems.any(cleared.contains)) return;
    state = state.copyWith(problems: state.problems.difference(cleared));
  }

  /// 입력란의 [amount]·[title] 글자와 고른 값으로 저장한다. 금액을 비우면 금액 미정이다.
  ///
  /// 입력에 문제가 있으면 [TemplateFormState.problems]로 알리고 저장하지 않는다.
  Future<void> save({required String amount, required String title}) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.busy || uid == null || ledgerId == null) return;
    final draft = TemplateDraft(
      memberId: state.memberId,
      title: title.trim(),
      amount: parseWon(amount),
      categoryId: state.categoryId,
      paymentMethodId: state.paymentMethodId,
      dueDay: state.dueDay,
    );
    final problems = templateProblemsOf(draft);
    if (problems.isNotEmpty) {
      state = state.copyWith(problems: problems);
      return;
    }
    state = state.withStatus(pending: TemplateFormAction.save);
    final repository = ref.read(templatesRepositoryProvider);
    try {
      final template = args.template;
      if (template == null) {
        await repository.add(ledgerId: ledgerId, draft: draft, uid: uid);
      } else {
        await repository.update(
          ledgerId: ledgerId,
          id: template.id,
          draft: draft,
          uid: uid,
        );
      }
      if (!ref.mounted) return;
      state = state.withStatus(outcome: TemplateFormOutcome.saved);
    } on TemplateWriteException catch (e) {
      if (!ref.mounted) return;
      state = state.withStatus(failure: _failureOf(e.reason));
    } catch (e) {
      debugPrint('고정 지출 저장 실패: $e');
      if (!ref.mounted) return;
      state = state.withStatus(failure: TemplateFormFailure.save);
    }
  }

  /// 고치는 고정 지출을 지운다. 이미 만든 달의 기본 월 지출은 남는다.
  Future<void> delete() async {
    final template = args.template;
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (template == null || state.busy || uid == null || ledgerId == null) {
      return;
    }
    state = state.withStatus(pending: TemplateFormAction.delete);
    try {
      await ref
          .read(templatesRepositoryProvider)
          .delete(ledgerId: ledgerId, id: template.id, uid: uid);
      if (!ref.mounted) return;
      state = state.withStatus(outcome: TemplateFormOutcome.deleted);
    } on TemplateWriteException catch (e) {
      if (!ref.mounted) return;
      state = state.withStatus(failure: _failureOf(e.reason));
    } catch (e) {
      debugPrint('고정 지출 삭제 실패: $e');
      if (!ref.mounted) return;
      state = state.withStatus(failure: TemplateFormFailure.delete);
    }
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() =>
      state = state.withStatus(pending: state.pending, outcome: state.outcome);

  static TemplateFormFailure _failureOf(TemplateWriteFailure reason) =>
      switch (reason) {
        TemplateWriteFailure.offline => TemplateFormFailure.offline,
        TemplateWriteFailure.notFound => TemplateFormFailure.gone,
      };
}
