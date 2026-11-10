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
///
/// 이름은 가계부를 만든 때의 것이다. 관리자가 나가며 관리자를 넘기면 넘겨받은 사람은 앉아 있던 [partner] 자리에 그대로 있고
/// (지난 항목의 '누가'가 맞도록), 가계부가 관리자 자리를 따로 적는다(`Ledger.ownerSlot`). 나간 사람의 자리는 이름표와
/// 지난 항목을 남긴 채 비고, 다음에 초대로 들어오는 사람이 이어받는다.
enum MemberSlot {
  /// 가계부를 만든 사람(관리자).
  owner,

  /// 초대 코드로 들어온 사람.
  partner;

  /// 다른 한 자리.
  MemberSlot get other => switch (this) {
    owner => partner,
    partner => owner,
  };
}

/// [members]에서 [slot] 자리의 이름표.
///
/// 이름표를 아직 못 받았거나 이름표가 생기기 전(2026-10-22 이전)에 만든 가계부면 역할 이름('관리자', '상대')으로 만든다.
Member memberIn(List<Member> members, MemberSlot slot) =>
    members.where((m) => m.slot == slot).firstOrNull ??
    Member(
      slot: slot,
      name: switch (slot) {
        MemberSlot.owner => '관리자',
        MemberSlot.partner => defaultPartnerName,
      },
    );

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
