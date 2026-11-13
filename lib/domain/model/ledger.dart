import 'member.dart';
import 'year_month.dart';

/// 한 가계부에 들어올 수 있는 사람 수. 커플·부부 가계부라 두 명이다.
/// `firestore.rules`의 maxMembers와 같다.
const ledgerMaxMembers = 2;

/// 가계부 이름 길이 제한. `firestore.rules`의 validName과 같다.
const ledgerNameMaxLength = 40;

/// 가계부 안에서의 역할. `firestore.rules`와 같은 권한을 앱에서도 판단하는 데 쓴다.
enum MemberRole {
  /// 관리자: 가계부를 만든 사람(관리자가 나가며 넘겼으면 넘겨받은 사람). 이름 변경, 구성원 관리, 초대.
  owner,

  /// 편집자: 읽기·쓰기.
  editor,

  /// 보기 전용: 읽기만.
  viewer;

  bool get canWrite => this != viewer;

  bool get canManageMembers => this == owner;
}

/// [Ledger.leaveOutcomeOf]: 구성원이 가계부에서 나가면 일어나는 일. 규칙의 leavesSelf·ownerHandsOver·ownerClosesAlone과 같다.
enum LeaveOutcome {
  /// 초대로 들어온 사람(편집자·보기 전용)이 나간다. 관리자는 그대로다.
  memberLeaves,

  /// 관리자가 나가고 남은 사람이 관리자가 된다(보기 전용이었어도).
  handsOver,

  /// 혼자 쓰던 관리자가 나간다. 구성원이 비고 서버 함수가 가계부와 모든 내역을 지운다.
  closes,
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
    this.ownerSlot = MemberSlot.owner,
    this.createdAt,
    this.months,
  });

  final String id;
  final String name;
  final String ownerUid;

  /// 관리자가 앉은 이름표 자리(Firestore `ownerSlot`, 없으면 owner). 초대로 들어온 사람은 다른 자리에 앉는다.
  ///
  /// 처음에는 owner 자리이고, 관리자가 나가며 넘기면 넘겨받은 사람이 앉아 있던 자리로 바뀐다([LeaveOutcome.handsOver]).
  /// 항목의 '누가'가 자리로 적혀 있어서 사람을 옮기지 않고 관리자 자리를 바꾼다.
  final MemberSlot ownerSlot;

  /// 가계부를 만든 때. 방금 만들어 서버 시간이 아직 없으면 null.
  final DateTime? createdAt;

  /// 관리자를 뺀 구성원의 역할 (uid → 역할).
  final Map<String, MemberRole> roles;

  /// 항목이 들어간 적 있는 달(Firestore `months`). 홈·내역 탭은 이 달들과 이번 달만 오간다.
  ///
  /// null이면 목록을 아직 모으지 않은 가계부(목록이 생기기 전에 만든 것)라 달을 가리지 않는다.
  /// 쓰기 권한이 있는 사람이 앱을 열면 그때 한 번 모은다.
  final Set<YearMonth>? months;

  /// [month]에 항목을 넣을 때 [months]에 그달을 더해야 하는지. 목록을 아직 모으지 않았으면 더하지 않는다
  /// (모을 때 같이 찾는다).
  bool needsToRecord(YearMonth month) => switch (months) {
    final months? => !months.contains(month),
    null => false,
  };

  /// 관리자를 포함한 모든 구성원 uid. Firestore의 `memberUids`와 같다.
  List<String> get memberUids => [ownerUid, ...roles.keys];

  /// 두 명이 다 찼는지. 다 차면 초대 코드를 만들 수도, 참여할 수도 없다.
  bool get isFull => memberUids.length >= ledgerMaxMembers;

  /// 구성원이 아니면 null.
  MemberRole? roleOf(String uid) =>
      uid == ownerUid ? MemberRole.owner : roles[uid];

  /// [uid]가 가계부 이름을 바꿀 수 있는지. 관리자만 된다(규칙의 ownerManages).
  bool canRename(String uid) => roleOf(uid)?.canManageMembers ?? false;

  /// [uid]가 초대 코드를 만들 수 있는지. 관리자이고 자리가 남아 있어야 한다.
  bool canInvite(String uid) =>
      (roleOf(uid)?.canManageMembers ?? false) && !isFull;

  /// [slot] 자리에 있는 사람의 uid. 아무도 없으면(상대가 아직 들어오지 않았거나 나감) null.
  String? uidOf(MemberSlot slot) =>
      slot == ownerSlot ? ownerUid : roles.keys.firstOrNull;

  /// [uid]의 이름표 자리. 관리자면 [ownerSlot], 초대로 들어온 사람이면 다른 자리, 구성원이 아니면 null.
  MemberSlot? slotOf(String uid) => switch (roleOf(uid)) {
    MemberRole.owner => ownerSlot,
    MemberRole.editor || MemberRole.viewer => ownerSlot.other,
    null => null,
  };

  /// [uid]가 나가면 일어나는 일. 구성원이 아니면 null.
  LeaveOutcome? leaveOutcomeOf(String uid) => switch (roleOf(uid)) {
    MemberRole.editor || MemberRole.viewer => LeaveOutcome.memberLeaves,
    MemberRole.owner when roles.isNotEmpty => LeaveOutcome.handsOver,
    MemberRole.owner => LeaveOutcome.closes,
    null => null,
  };
}
