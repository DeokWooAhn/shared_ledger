import '../../model/ledger.dart';
import '../../repository/ledger_repository.dart';

/// [uid]가 속한 가계부 목록을 지켜본다. 먼저 만든 가계부가 앞에 온다.
class WatchMyLedgersUseCase {
  const WatchMyLedgersUseCase(this._ledgers);

  final LedgerRepository _ledgers;

  Stream<List<Ledger>> call(String uid) => _ledgers.watchMyLedgers(uid);
}
