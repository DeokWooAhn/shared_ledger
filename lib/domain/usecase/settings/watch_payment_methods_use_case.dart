import '../../model/payment_method.dart';
import '../../repository/settings_repository.dart';

/// [ledgerId] 가계부의 결제수단을 지켜본다. 정한 순서대로, 숨긴 결제수단도 함께 온다.
class WatchPaymentMethodsUseCase {
  const WatchPaymentMethodsUseCase(this._settings);

  final SettingsRepository _settings;

  Stream<List<PaymentMethod>> call(String ledgerId) =>
      _settings.watchPaymentMethods(ledgerId);
}
