import '../../model/name_problem.dart';
import '../../model/payment_method.dart';
import '../../repository/settings_repository.dart';

/// 결제수단을 [kind] 종류로 새로 더하거나 [editing]의 이름을 고친다. 온라인에서만 된다.
///
/// 이름이 비었거나 길거나 [methods]의 다른 결제수단(숨긴 것 포함)과 같으면 쓰지 않고 그 문제를 돌려준다([paymentMethodNameProblemOf]).
/// 종류는 만들 때만 정한다. 카드인지에 따라 지난 달 계산이 달라져서 고칠 때는 [kind]를 보지 않는다(규칙의 keepsKind).
/// 새 결제수단은 맨 뒤에 붙고, 고칠 때 이름이 그대로면 쓰지 않는다. 쓰지 못하면 [SettingsWriteException]을 던진다.
class SavePaymentMethodUseCase {
  const SavePaymentMethodUseCase(this._settings);

  final SettingsRepository _settings;

  Future<NameProblem?> call({
    required String ledgerId,
    PaymentMethod? editing,
    required String name,
    required PaymentKind kind,
    required List<PaymentMethod> methods,
    required String uid,
  }) async {
    final problem = paymentMethodNameProblemOf(name, methods, editing: editing);
    if (problem != null) return problem;
    final trimmed = name.trim();
    if (editing == null) {
      await _settings.addPaymentMethod(
        ledgerId: ledgerId,
        draft: (name: trimmed, kind: kind),
        order: methods.length,
        uid: uid,
      );
    } else if (trimmed != editing.name) {
      await _settings.renamePaymentMethod(
        ledgerId: ledgerId,
        id: editing.id,
        name: trimmed,
        uid: uid,
      );
    }
    return null;
  }
}
