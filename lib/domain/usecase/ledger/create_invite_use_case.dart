import '../../model/invite.dart';
import '../../model/ledger.dart';
import '../../repository/ledger_repository.dart';

/// [ledgerId]에 [role]로 들어올 사람을 위한 초대 코드를 만든다. 관리자([createdBy])만 할 수 있다.
class CreateInviteUseCase {
  const CreateInviteUseCase(this._ledgers);

  final LedgerRepository _ledgers;

  Future<Invite> call({
    required String ledgerId,
    required MemberRole role,
    required String createdBy,
  }) => _ledgers.createInvite(
    ledgerId: ledgerId,
    role: role,
    createdBy: createdBy,
  );
}
