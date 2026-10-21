/// 한 가계부에 들어올 수 있는 사람 수. 커플·부부 가계부라 두 명이다.
/// `firestore.rules`의 maxMembers와 같다.
const ledgerMaxMembers = 2;

/// 가계부 이름 길이 제한. `firestore.rules`의 validName과 같다.
const ledgerNameMaxLength = 40;

/// 가계부 안에서의 역할. `firestore.rules`와 같은 권한을 앱에서도 판단하는 데 쓴다.
enum MemberRole {
  /// 관리자: 가계부를 만든 사람. 구성원 관리, 초대, 가계부 삭제.
  owner,

  /// 편집자: 읽기·쓰기.
  editor,

  /// 보기 전용: 읽기만.
  viewer;

  bool get canWrite => this != viewer;

  bool get canManageMembers => this == owner;
}

/// 두 사람이 함께 쓰는 가계부.
///
/// 관리자는 [ownerUid]에만 두고 [roles]에는 넣지 않는다(규칙에서 관리자가 한 명뿐인지
/// 확인하기 위한 구조). [roles] 값은 편집자나 보기 전용이다.
class Ledger {
  const Ledger({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.roles = const {},
  });

  final String id;
  final String name;
  final String ownerUid;

  /// 관리자를 뺀 구성원의 역할 (uid → 역할).
  final Map<String, MemberRole> roles;

  /// 관리자를 포함한 모든 구성원 uid. Firestore의 `memberUids`와 같다.
  List<String> get memberUids => [ownerUid, ...roles.keys];

  /// 두 명이 다 찼는지. 다 차면 초대 코드를 만들 수도, 참여할 수도 없다.
  bool get isFull => memberUids.length >= ledgerMaxMembers;

  /// 구성원이 아니면 null.
  MemberRole? roleOf(String uid) =>
      uid == ownerUid ? MemberRole.owner : roles[uid];

  /// [uid]가 초대 코드를 만들 수 있는지. 관리자이고 자리가 남아 있어야 한다.
  bool canInvite(String uid) =>
      (roleOf(uid)?.canManageMembers ?? false) && !isFull;
}
