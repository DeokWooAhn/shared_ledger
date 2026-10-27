import '../../model/member.dart';
import '../../model/name_problem.dart';
import '../../repository/settings_repository.dart';

/// [slot] 자리 이름표의 이름을 [name]으로 바꾼다. 관리자·편집자가 두 장 모두 바꿀 수 있고 온라인에서만 된다.
///
/// 이름에 문제가 있으면 쓰지 않고 그 문제를 돌려준다([nameProblemOf]). 앞뒤 공백을 뺀 이름이 [members]의 지금 이름과 같으면 쓰지 않는다.
/// 이름표가 생기기 전에 만든 가계부는 이름표 문서가 없어서, 화면의 역할 이름과 같아 보여도 이름표를 새로 만든다.
/// 쓰지 못하면 [SettingsWriteException]을 던진다.
class RenameMemberUseCase {
  const RenameMemberUseCase(this._settings);

  final SettingsRepository _settings;

  Future<NameProblem?> call({
    required String ledgerId,
    required MemberSlot slot,
    required String name,
    required List<Member> members,
    required String uid,
  }) async {
    final problem = nameProblemOf(name, maxLength: memberNameMaxLength);
    if (problem != null) return problem;
    final current = members.where((m) => m.slot == slot).firstOrNull?.name;
    if (name.trim() == current) return null;
    await _settings.renameMember(
      ledgerId: ledgerId,
      slot: slot,
      name: name,
      uid: uid,
    );
    return null;
  }
}
