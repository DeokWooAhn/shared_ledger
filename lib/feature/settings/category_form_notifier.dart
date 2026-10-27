import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/repository/settings_repository.dart';
import '../../domain/model/category.dart';
import '../../domain/model/name_problem.dart';
import '../../domain/usecase/settings/settings_use_cases.dart';
import 'setting_form.dart';

/// 분류 시트를 여는 값. 새 분류면 [category]가 null이다.
@immutable
class CategoryFormArgs {
  /// 새 분류를 더한다.
  const CategoryFormArgs.add() : category = null;

  /// 있는 [category]를 고친다.
  const CategoryFormArgs.edit(Category this.category);

  final Category? category;

  // 같은 분류를 고치는 시트면 같은 값으로 본다. 내용이 그사이 바뀌어도 시트는 처음 값으로 시작한다.
  @override
  bool operator ==(Object other) =>
      other is CategoryFormArgs && other.category?.id == category?.id;

  @override
  int get hashCode => category?.id.hashCode ?? 0;
}

/// 분류 시트 상태. 저축 집계 여부와 진행 상태를 담는다. 이름 글자는 시트의 입력란이 갖는다.
@immutable
class CategoryFormState {
  const CategoryFormState({
    required this.countsAsSaving,
    this.problem,
    this.pending,
    this.failure,
    this.outcome,
  });

  /// 이 분류의 기본 지출을 월 요약의 저축에 넣을지.
  final bool countsAsSaving;

  /// 이름 칸 아래에 보여 줄 문제.
  final NameProblem? problem;

  /// 진행 중인 동작. null이면 쉬는 중이다.
  final SettingFormAction? pending;

  /// 하지 못한 이유. 시트 안에 바로 보여주고, 다시 하거나 이름을 고치면 지운다.
  final SettingFormFailure? failure;

  /// 저장하거나 숨겨 시트를 닫을 때. 시트가 이 값으로 닫힌다.
  final SettingFormOutcome? outcome;

  /// 진행 중이거나 이미 끝나 닫히는 중이다. 버튼을 막는다.
  bool get busy => pending != null || outcome != null;

  /// 상태를 바꾼다. 넘기지 않은 문제·진행 상태는 비운다.
  CategoryFormState next({
    bool? countsAsSaving,
    NameProblem? problem,
    SettingFormAction? pending,
    SettingFormFailure? failure,
    SettingFormOutcome? outcome,
  }) => CategoryFormState(
    countsAsSaving: countsAsSaving ?? this.countsAsSaving,
    problem: problem,
    pending: pending,
    failure: failure,
    outcome: outcome,
  );

  @override
  bool operator ==(Object other) =>
      other is CategoryFormState &&
      other.countsAsSaving == countsAsSaving &&
      other.problem == problem &&
      other.pending == pending &&
      other.failure == failure &&
      other.outcome == outcome;

  @override
  int get hashCode =>
      Object.hash(countsAsSaving, problem, pending, failure, outcome);
}

final categoryFormNotifierProvider = NotifierProvider.autoDispose
    .family<CategoryFormNotifier, CategoryFormState, CategoryFormArgs>(
      CategoryFormNotifier.new,
    );

/// 분류 시트의 Notifier. 분류를 더하거나 고치고, 숨기거나 다시 보이게 한다. 온라인에서만 된다.
///
/// 분류는 지우지 않는다. 숨긴 분류는 새 항목·고정 지출에서 고를 수 없지만 지난 항목과 합계에는 그대로 쓰인다.
/// 끝나면 [CategoryFormState.outcome]을 채우고, 시트가 그 값으로 닫힌다.
class CategoryFormNotifier extends Notifier<CategoryFormState> {
  CategoryFormNotifier(this.args);

  final CategoryFormArgs args;

  @override
  CategoryFormState build() =>
      CategoryFormState(countsAsSaving: args.category?.countsAsSaving ?? false);

  /// 저축으로 집계할지 정한다.
  void setCountsAsSaving(bool value) {
    if (state.busy) return;
    state = state.next(countsAsSaving: value, problem: state.problem);
  }

  /// 이름을 고치면 이름 칸의 문제와 실패 안내를 지운다.
  void nameEdited() {
    if (state.busy || (state.problem == null && state.failure == null)) return;
    state = state.next();
  }

  /// 입력란의 [name]과 고른 값으로 저장한다. 새 분류는 맨 뒤에 붙고, 바뀐 것이 없으면 쓰지 않고 닫는다(`SaveCategoryUseCase`).
  ///
  /// 이름이 비었거나 길거나 다른 분류(숨긴 것 포함)와 같으면 [CategoryFormState.problem]으로 알린다.
  Future<void> save(String name) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.busy || uid == null || ledgerId == null) return;
    final category = args.category;
    final categories = ref.read(categoriesProvider).value ?? const [];
    final problem = categoryNameProblemOf(name, categories, editing: category);
    if (problem != null) {
      state = state.next(problem: problem);
      return;
    }
    final countsAsSaving = state.countsAsSaving;
    await _write(
      SettingFormAction.save,
      SettingFormOutcome.saved,
      (settings) => settings.saveCategory(
        ledgerId: ledgerId,
        editing: category,
        name: name,
        countsAsSaving: countsAsSaving,
        categories: categories,
        uid: uid,
      ),
    );
  }

  /// 고치는 분류를 숨기거나([hidden]이 true) 다시 보이게 한다.
  Future<void> setHidden(bool hidden) async {
    final category = args.category;
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (category == null || state.busy || uid == null || ledgerId == null) {
      return;
    }
    await _write(
      hidden ? SettingFormAction.hide : SettingFormAction.show,
      hidden ? SettingFormOutcome.hidden : SettingFormOutcome.shown,
      (settings) async {
        await settings.setCategoryHidden(
          ledgerId: ledgerId,
          id: category.id,
          hidden: hidden,
          uid: uid,
        );
        return null;
      },
    );
  }

  // [write]가 이름 문제를 돌려주면 쓰지 않은 것이라 그 문제를 보여 준다.
  Future<void> _write(
    SettingFormAction action,
    SettingFormOutcome outcome,
    Future<NameProblem?> Function(SettingsUseCases settings) write,
  ) async {
    state = state.next(pending: action);
    try {
      final problem = await write(ref.read(settingsUseCasesProvider));
      if (!ref.mounted) return;
      state = problem == null
          ? state.next(outcome: outcome)
          : state.next(problem: problem);
    } on SettingsWriteException catch (e) {
      if (!ref.mounted) return;
      state = state.next(failure: settingFormFailureOf(e.reason));
    } catch (e) {
      debugPrint('분류 저장 실패: $e');
      if (!ref.mounted) return;
      state = state.next(failure: SettingFormFailure.save);
    }
  }
}
