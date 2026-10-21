/// 가구 안에서의 역할. `firestore.rules`와 같은 권한을 앱에서도 판단하는 데 쓴다.
enum HouseholdRole {
  /// 관리자: 가구마다 한 명. 구성원 관리, 초대, 가구 삭제.
  owner,

  /// 편집자: 읽기·쓰기.
  editor,

  /// 보기 전용: 읽기만.
  viewer;

  bool get canWrite => this != viewer;

  bool get canManageMembers => this == owner;
}

/// 가계부를 같이 쓰는 단위.
///
/// 관리자는 [ownerUid]에만 두고 [roles]에는 넣지 않는다(규칙에서 관리자가 한 명뿐인지
/// 확인하기 위한 구조). [roles] 값은 편집자나 보기 전용이다.
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.ownerUid,
    this.roles = const {},
  });

  final String id;
  final String name;
  final String ownerUid;

  /// 관리자를 뺀 구성원의 역할 (uid → 역할).
  final Map<String, HouseholdRole> roles;

  /// 관리자를 포함한 모든 구성원 uid. Firestore의 `memberUids`와 같다.
  List<String> get memberUids => [ownerUid, ...roles.keys];

  /// 구성원이 아니면 null.
  HouseholdRole? roleOf(String uid) =>
      uid == ownerUid ? HouseholdRole.owner : roles[uid];
}
