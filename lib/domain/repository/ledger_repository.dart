import '../model/invite.dart';
import '../model/ledger.dart';
import '../model/year_month.dart';

/// 초대 코드로 참여하지 못한 이유.
enum JoinFailure {
  /// 코드가 없거나 관리자가 지웠다.
  notFound,

  /// 유효기간이 지났다.
  expired,

  /// 두 명이 다 찼거나 그사이 가계부가 없어졌다. 보안 규칙이 참여를 거부한 경우다.
  unavailable,
}

class JoinLedgerException implements Exception {
  const JoinLedgerException(this.reason);

  final JoinFailure reason;

  @override
  String toString() => 'JoinLedgerException($reason)';
}

abstract interface class LedgerRepository {
  /// 내가 속한 가계부 목록. 먼저 만든 가계부가 앞에 온다.
  Stream<List<Ledger>> watchMyLedgers(String uid);

  /// 나를 관리자로 하는 가계부를 만들고 id를 돌려준다.
  ///
  /// 기본 설정(이름표 두 장, 기본 분류·결제수단)도 같이 만든다. 이름표의 내 이름은 [ownerName]이다.
  /// 둘 중 하나만 생기는 일이 없게 한 번의 일괄 쓰기로 한다.
  Future<String> create({
    required String name,
    required String ownerUid,
    required String ownerName,
  });

  /// [ledgerId]에 [role]로 들어올 사람을 위한 초대 코드를 만든다. 관리자만 할 수 있다.
  Future<Invite> createInvite({
    required String ledgerId,
    required MemberRole role,
    required String createdBy,
  });

  /// 초대 코드로 가계부에 들어간다. 들어가지 못하면 [JoinLedgerException]을 던진다.
  Future<void> joinWithInvite({required String code, required String uid});

  /// 가계부 이름을 [name]으로 바꾼다. 관리자([uid])만 할 수 있다(규칙의 ownerManages).
  ///
  /// 다른 설정처럼 온라인에서만 되고 변경 기록을 같이 남긴다. 연결이 없으면 `SettingsWriteException`(`SettingsWriteFailure.offline`),
  /// 가계부가 없어졌으면 `SettingsWriteFailure.notFound`로 실패한다(settings_repository.dart).
  Future<void> rename({
    required String ledgerId,
    required String name,
    required String uid,
  });

  /// 목록을 아직 모으지 않은 가계부([Ledger.months]가 null)에 항목 있는 달 [months]를 처음 적는다.
  ///
  /// 그사이 상대가 더한 달은 지우지 않고 합친다. 서버에서 읽어 합치는 트랜잭션이라 온라인에서만 되고,
  /// 쓰기 권한이 있는 사람만 할 수 있다(규칙의 recordsMonths). 변경 기록은 남기지 않는다.
  Future<void> recordMonths({
    required String ledgerId,
    required Iterable<YearMonth> months,
  });
}
