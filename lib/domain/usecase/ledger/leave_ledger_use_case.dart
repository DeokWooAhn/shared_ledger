import '../../model/ledger.dart';
import '../../repository/ledger_repository.dart';

/// 내가([uid]) [ledgerId] 가계부에서 나가고, 무슨 일이 일어났는지 돌려준다([LeaveOutcome]).
///
/// 초대로 들어온 사람은 그냥 나가고, 관리자는 남은 사람에게 관리자를 넘기며, 혼자 쓰던 관리자가 나가면
/// 가계부와 모든 내역이 지워진다. 나간 뒤 남은 가계부가 없으면 화면 이동 규칙(router.dart)이 가계부 시작 화면으로 옮겨서,
/// 초대 코드로 다른 가계부에 들어갈 수 있다. 온라인에서만 되고, 쓰지 못하면 `SettingsWriteException`을 던진다.
class LeaveLedgerUseCase {
  const LeaveLedgerUseCase(this._ledgers);

  final LedgerRepository _ledgers;

  Future<LeaveOutcome> call({required String ledgerId, required String uid}) =>
      _ledgers.leave(ledgerId: ledgerId, uid: uid);
}
