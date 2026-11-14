import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ledger/core/providers/providers.dart';

/// 데이터·사용자 입력 없이 로딩이 멈춘 공급자와 오류 코드만 구분한다.
String maestroStateLabel(Object? value) {
  if (value is AsyncValue<Object?>) {
    if (value.hasError) {
      final error = value.error;
      return 'error:${error is FirebaseException ? error.code : error.runtimeType}';
    }
    return value.isLoading ? 'loading' : 'data';
  }
  return value == null ? 'empty' : 'data';
}

/// 관찰만 하고 공급자 수명·구독·재시도 정책은 바꾸지 않는 테스트 전용 진단이다.
final class MaestroProviderDiagnostics extends ProviderObserver {
  MaestroProviderDiagnostics({required this.log});

  final void Function(String) log;
  final Map<Object, String> _lastStates = {};

  void _record(ProviderObserverContext context, Object? value) {
    final names = <Object, String>{
      authUserProvider: 'auth',
      myLedgersProvider: 'ledgers',
      currentLedgerProvider: 'current-ledger',
      categoriesProvider: 'categories',
      paymentMethodsProvider: 'payment-methods',
      monthLedgerProvider: 'month-ledger',
      monthSummaryProvider: 'month-summary',
    };
    final name =
        names[context.provider] ??
        (context.provider.from == monthLedgerOfProvider
            ? 'month-ledger-source'
            : null);
    if (name == null) return;
    final state = maestroStateLabel(value);
    if (_lastStates[context.provider] == state) return;
    _lastStates[context.provider] = state;
    log('MAESTRO_DATA $name=$state');
  }

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) =>
      _record(context, value);

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) => _record(context, newValue);

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) => _record(context, AsyncError<Object>(error, stackTrace));
}
