/// 이름표 이름 길이 제한. `firestore.rules`의 validMember와 같다.
const memberNameMaxLength = 10;

/// 상대가 들어오기 전의 이름표 이름. 설정 탭에서 바꾼다.
const defaultPartnerName = '상대';

/// 새 가계부의 이름표에 쓸 내 이름. 로그인 이름을 [memberNameMaxLength]자로 자르고, 없으면 '나'.
String ownerMemberName(String? displayName) {
  final name = displayName?.trim() ?? '';
  if (name.isEmpty) return '나';
  return String.fromCharCodes(name.runes.take(memberNameMaxLength)).trim();
}

/// 가계부의 두 사람 자리. Firestore 이름표 문서 id(`members/owner`, `members/partner`)와 같다.
///
/// 항목의 '누가'는 이 자리로 적는다. 상대가 초대로 들어오기 전에도 상대 몫을 적을 수 있고,
/// 들어오면 그 사람이 [partner]가 된다.
enum MemberSlot {
  /// 가계부를 만든 사람(관리자).
  owner,

  /// 초대 코드로 들어온 사람.
  partner,
}

/// 두 사람의 이름표(하늘·바다처럼 화면에 보일 이름).
class Member {
  const Member({required this.slot, required this.name});

  final MemberSlot slot;
  final String name;

  /// 동그라미 안에 보일 첫 글자. 이름이 비어 있으면 빈 문자열.
  String get initial => String.fromCharCodes(name.trim().runes.take(1));

  @override
  bool operator ==(Object other) =>
      other is Member && other.slot == slot && other.name == name;

  @override
  int get hashCode => Object.hash(slot, name);
}
