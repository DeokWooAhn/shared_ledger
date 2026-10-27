import '../../model/auth_user.dart';
import '../../model/member.dart';
import '../../repository/ledger_repository.dart';

/// [owner]를 관리자로 하는 가계부를 만들고 id를 돌려준다. 이름 검사는 화면의 폼이 끝낸 뒤 부른다.
///
/// 이름은 앞뒤 공백을 뺀다. 이름표의 내 이름은 로그인 이름으로 정하고([ownerMemberName]), 설정 탭에서 바꾼다.
class CreateLedgerUseCase {
  const CreateLedgerUseCase(this._ledgers);

  final LedgerRepository _ledgers;

  Future<String> call({required String name, required AuthUser owner}) =>
      _ledgers.create(
        name: name.trim(),
        ownerUid: owner.uid,
        ownerName: ownerMemberName(owner.displayName),
      );
}
