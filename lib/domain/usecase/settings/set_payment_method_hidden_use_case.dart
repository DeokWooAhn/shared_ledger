import '../../repository/settings_repository.dart';

/// [id] 결제수단을 숨기거나([hidden]이 true) 다시 보이게 한다. 온라인에서만 된다.
///
/// 결제수단은 지우지 않는다. 지우면 그 카드로 쓴 돈이 현금 유출로 바뀌어 지난 달 숫자가 달라진다.
class SetPaymentMethodHiddenUseCase {
  const SetPaymentMethodHiddenUseCase(this._settings);

  final SettingsRepository _settings;

  Future<void> call({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  }) => _settings.setPaymentMethodHidden(
    ledgerId: ledgerId,
    id: id,
    hidden: hidden,
    uid: uid,
  );
}
