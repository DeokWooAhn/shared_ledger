import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/repository/settings_repository.dart';
import '../../domain/model/name_problem.dart';
import '../../domain/model/payment_method.dart';
import '../../domain/usecase/settings/settings_use_cases.dart';
import 'setting_form.dart';

/// 결제수단 시트를 여는 값. 새 결제수단이면 [method]가 null이다.
@immutable
class PaymentMethodFormArgs {
  /// 새 결제수단(카드 포함)을 더한다.
  const PaymentMethodFormArgs.add() : method = null;

  /// 있는 [method]를 고친다. 종류는 바꿀 수 없다.
  const PaymentMethodFormArgs.edit(PaymentMethod this.method);

  final PaymentMethod? method;

  // 같은 결제수단을 고치는 시트면 같은 값으로 본다.
  @override
  bool operator ==(Object other) =>
      other is PaymentMethodFormArgs && other.method?.id == method?.id;

  @override
  int get hashCode => method?.id.hashCode ?? 0;
}

/// 결제수단 시트 상태. 고른 종류와 진행 상태를 담는다. 이름 글자는 시트의 입력란이 갖는다.
@immutable
class PaymentMethodFormState {
  const PaymentMethodFormState({
    this.kind,
    this.problem,
    this.kindMissing = false,
    this.pending,
    this.failure,
    this.outcome,
  });

  /// 결제수단 종류. 새 결제수단은 처음에 고르지 않은 상태이고, 만든 뒤에는 바꿀 수 없다.
  final PaymentKind? kind;

  /// 이름 칸 아래에 보여 줄 문제.
  final NameProblem? problem;

  /// 종류를 고르지 않고 저장하려 했다.
  final bool kindMissing;

  /// 진행 중인 동작. null이면 쉬는 중이다.
  final SettingFormAction? pending;

  /// 하지 못한 이유. 시트 안에 바로 보여주고, 다시 하거나 이름을 고치면 지운다.
  final SettingFormFailure? failure;

  /// 저장하거나 숨겨 시트를 닫을 때. 시트가 이 값으로 닫힌다.
  final SettingFormOutcome? outcome;

  /// 진행 중이거나 이미 끝나 닫히는 중이다. 버튼을 막는다.
  bool get busy => pending != null || outcome != null;

  /// 상태를 바꾼다. 넘기지 않은 문제·진행 상태는 비운다.
  PaymentMethodFormState next({
    PaymentKind? kind,
    NameProblem? problem,
    bool kindMissing = false,
    SettingFormAction? pending,
    SettingFormFailure? failure,
    SettingFormOutcome? outcome,
  }) => PaymentMethodFormState(
    kind: kind ?? this.kind,
    problem: problem,
    kindMissing: kindMissing,
    pending: pending,
    failure: failure,
    outcome: outcome,
  );

  @override
  bool operator ==(Object other) =>
      other is PaymentMethodFormState &&
      other.kind == kind &&
      other.problem == problem &&
      other.kindMissing == kindMissing &&
      other.pending == pending &&
      other.failure == failure &&
      other.outcome == outcome;

  @override
  int get hashCode =>
      Object.hash(kind, problem, kindMissing, pending, failure, outcome);
}

final paymentMethodFormNotifierProvider = NotifierProvider.autoDispose
    .family<
      PaymentMethodFormNotifier,
      PaymentMethodFormState,
      PaymentMethodFormArgs
    >(PaymentMethodFormNotifier.new);

/// 결제수단 시트의 Notifier. 결제수단(카드 포함)을 더하거나 이름을 고치고, 숨기거나 다시 보이게 한다.
/// 온라인에서만 된다.
///
/// 종류는 만들 때만 고른다. 카드인지에 따라 지난 달 계산이 달라져서 바꿀 수 없고(규칙의 keepsKind),
/// 같은 이유로 지우지 않고 숨긴다. 끝나면 [PaymentMethodFormState.outcome]을 채우고, 시트가 그 값으로 닫힌다.
class PaymentMethodFormNotifier extends Notifier<PaymentMethodFormState> {
  PaymentMethodFormNotifier(this.args);

  final PaymentMethodFormArgs args;

  @override
  PaymentMethodFormState build() =>
      PaymentMethodFormState(kind: args.method?.kind);

  /// 새 결제수단의 종류를 고른다. 있는 결제수단은 바꿀 수 없어 무시한다.
  void selectKind(PaymentKind kind) {
    if (state.busy || args.method != null) return;
    state = state.next(kind: kind, problem: state.problem);
  }

  /// 이름을 고치면 이름 칸의 문제와 실패 안내를 지운다.
  void nameEdited() {
    if (state.busy || (state.problem == null && state.failure == null)) return;
    state = state.next(kindMissing: state.kindMissing);
  }

  /// 입력란의 [name]과 고른 종류로 저장한다. 새 결제수단은 맨 뒤에 붙고, 이름이 그대로면 쓰지 않고 닫는다
  /// (`SavePaymentMethodUseCase`).
  ///
  /// 이름이 비었거나 길거나 다른 결제수단(숨긴 것 포함)과 같으면 [PaymentMethodFormState.problem]으로,
  /// 새 결제수단의 종류를 고르지 않았으면 [PaymentMethodFormState.kindMissing]으로 알린다.
  Future<void> save(String name) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.busy || uid == null || ledgerId == null) return;
    final method = args.method;
    final methods = ref.read(paymentMethodsProvider).value ?? const [];
    final problem = paymentMethodNameProblemOf(name, methods, editing: method);
    final kind = state.kind;
    if (problem != null || kind == null) {
      state = state.next(problem: problem, kindMissing: kind == null);
      return;
    }
    await _write(
      SettingFormAction.save,
      SettingFormOutcome.saved,
      (settings) => settings.savePaymentMethod(
        ledgerId: ledgerId,
        editing: method,
        name: name,
        kind: kind,
        methods: methods,
        uid: uid,
      ),
    );
  }

  /// 고치는 결제수단을 숨기거나([hidden]이 true) 다시 보이게 한다.
  Future<void> setHidden(bool hidden) async {
    final method = args.method;
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (method == null || state.busy || uid == null || ledgerId == null) {
      return;
    }
    await _write(
      hidden ? SettingFormAction.hide : SettingFormAction.show,
      hidden ? SettingFormOutcome.hidden : SettingFormOutcome.shown,
      (settings) async {
        await settings.setPaymentMethodHidden(
          ledgerId: ledgerId,
          id: method.id,
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
      debugPrint('결제수단 저장 실패: $e');
      if (!ref.mounted) return;
      state = state.next(failure: SettingFormFailure.save);
    }
  }
}
