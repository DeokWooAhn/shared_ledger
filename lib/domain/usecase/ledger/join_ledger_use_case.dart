import '../../model/invite.dart';
import '../../repository/ledger_repository.dart';

/// 입력한 초대 코드로 [uid]가 가계부에 들어간다. 들어갔으면 null, 들어가지 못했으면 그 이유를 돌려준다.
///
/// 코드는 정리해서(공백·하이픈 빼고 대문자) 보낸다. 비었거나 모양이 다르면 서버에 묻지 않는다([inviteCodeProblemOf]).
/// 코드가 없거나 지났거나 자리가 없는 것([JoinFailure])도 문제로 바꿔 돌려주고, 예상하지 못한 오류는 그대로 던진다.
class JoinLedgerUseCase {
  const JoinLedgerUseCase(this._ledgers);

  final LedgerRepository _ledgers;

  Future<InviteCodeProblem?> call({
    required String input,
    required String uid,
  }) async {
    final problem = inviteCodeProblemOf(input);
    if (problem != null) return problem;
    try {
      await _ledgers.joinWithInvite(code: normalizeInviteCode(input), uid: uid);
      return null;
    } on JoinLedgerException catch (e) {
      return switch (e.reason) {
        JoinFailure.notFound => InviteCodeProblem.notFound,
        JoinFailure.expired => InviteCodeProblem.expired,
        JoinFailure.unavailable => InviteCodeProblem.unavailable,
      };
    }
  }
}
