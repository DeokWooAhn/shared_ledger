import '../../model/ledger.dart';
import '../../model/name_problem.dart';
import '../../repository/ledger_repository.dart';

/// [ledger]의 이름을 [name]으로 바꾼다. 관리자([uid])만 할 수 있고(규칙의 ownerManages) 온라인에서만 된다.
///
/// 이름에 문제가 있으면 쓰지 않고 그 문제를 돌려준다([nameProblemOf]). 앞뒤 공백을 뺀 이름이 지금 이름과 같으면 쓰지 않는다.
/// 쓰지 못하면 `SettingsWriteException`을 던진다(연결 없음·가계부 없음).
class RenameLedgerUseCase {
  const RenameLedgerUseCase(this._ledgers);

  final LedgerRepository _ledgers;

  Future<NameProblem?> call({
    required Ledger ledger,
    required String name,
    required String uid,
  }) async {
    final problem = nameProblemOf(name, maxLength: ledgerNameMaxLength);
    if (problem != null) return problem;
    if (name.trim() == ledger.name) return null;
    await _ledgers.rename(ledgerId: ledger.id, name: name, uid: uid);
    return null;
  }
}
