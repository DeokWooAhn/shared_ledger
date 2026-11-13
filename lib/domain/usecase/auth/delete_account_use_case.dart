import '../../repository/auth_repository.dart';
import '../../repository/ledger_repository.dart';
import '../../repository/settings_repository.dart';

/// 탈퇴한다. 다시 로그인을 취소하면 아무것도 바꾸지 않고 false를 돌려준다.
///
/// 1. 지금 로그인 방법으로 한 번 더 로그인해 본인인지 확인한다(Firebase가 최근 로그인을 요구한다).
/// 2. 내 가계부([ledgerIds]) 모두에서 나간다(`LeaveLedgerUseCase`와 같다). 함께 쓰는 가계부는 상대가 이어 쓰고
///    (관리자였으면 상대가 관리자가 된다), 혼자 쓰던 가계부는 모든 내역과 함께 지워진다. 그사이 이미 나간 가계부는 건너뛴다.
/// 3. 계정을 지운다. 성공하면 로그아웃 상태가 되어 화면 이동 규칙(router.dart)이 로그인 화면으로 옮긴다.
///
/// 다른 계정으로 다시 로그인하면 `AccountDeletionException`, 가계부에서 나가지 못하면 `SettingsWriteException`을 던진다.
/// 어느 단계에서 실패해도 계정은 남아 있어 다시 시도할 수 있다.
class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._auth, this._ledgers);

  final AuthRepository _auth;
  final LedgerRepository _ledgers;

  Future<bool> call({
    required String uid,
    required Iterable<String> ledgerIds,
  }) async {
    if (!await _auth.reauthenticate()) return false;
    for (final ledgerId in ledgerIds) {
      try {
        await _ledgers.leave(ledgerId: ledgerId, uid: uid);
      } on SettingsWriteException catch (e) {
        // 그사이 다른 기기에서 나갔거나 가계부가 지워졌으면 나갈 것이 없다.
        if (e.reason != SettingsWriteFailure.notFound) rethrow;
      }
    }
    await _auth.deleteAccount();
    return true;
  }
}
