import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/invite.dart';
import '../../domain/model/ledger.dart';
import '../../domain/model/member.dart';
import '../../domain/model/year_month.dart';
import '../../domain/activity/activity_summary.dart';
import '../settings/firestore_settings_repository.dart';
import '../../domain/repository/settings_repository.dart';
import '../../domain/repository/ledger_repository.dart';

class FirestoreLedgerRepository implements LedgerRepository {
  FirestoreLedgerRepository(
    this._firestore, {
    Random? random,
    DateTime Function()? now,
  }) : _random = random ?? Random.secure(),
       _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final Random _random;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _ledgers =>
      _firestore.collection('ledgers');

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('invites');

  @override
  Stream<List<Ledger>> watchMyLedgers(String uid) => _ledgers
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((snapshot) {
        final docs = [...snapshot.docs]..sort(_byCreatedAt);
        return [
          for (final doc in docs) ledgerFromFirestore(doc.id, doc.data()),
        ];
      });

  @override
  Future<String> create({
    required String name,
    required String ownerUid,
    required String ownerName,
    required YearMonth firstMonth,
  }) async {
    final ref = _ledgers.doc(newLedgerId(ownerUid, _ledgers.doc().id));
    final batch = _firestore.batch()
      ..set(
        ref,
        newLedgerData(name: name, ownerUid: ownerUid, firstMonth: firstMonth),
      );
    for (final doc in defaultSettingDocs(uid: ownerUid, ownerName: ownerName)) {
      batch.set(ref.collection(doc.collection).doc(doc.id), doc.data);
    }
    await batch.commit();
    return ref.id;
  }

  @override
  Future<Invite> createInvite({
    required String ledgerId,
    required MemberRole role,
    required String createdBy,
  }) async {
    final code = generateInviteCode(_random);
    // 기기 시계가 서버보다 조금 빨라도 규칙의 '7일 이내'를 넘지 않게 한 시간 여유를 둔다.
    final expiresAt = _now().add(inviteValidity - const Duration(hours: 1));
    await _invites
        .doc(code)
        .set(
          newInviteData(
            ledgerId: ledgerId,
            role: role,
            createdBy: createdBy,
            expiresAt: expiresAt,
          ),
        );
    return Invite(
      code: code,
      ledgerId: ledgerId,
      role: role,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> joinWithInvite({
    required String code,
    required String uid,
  }) async {
    if (!isInviteCodeShaped(code)) {
      throw const JoinLedgerException(JoinFailure.notFound);
    }
    final data = (await _invites.doc(code).get()).data();
    final invite = data == null ? null : inviteFromFirestore(code, data);
    if (invite == null) throw const JoinLedgerException(JoinFailure.notFound);
    if (invite.isExpiredAt(_now())) {
      throw const JoinLedgerException(JoinFailure.expired);
    }
    try {
      await _ledgers
          .doc(invite.ledgerId)
          .update(joinLedgerUpdate(uid: uid, role: invite.role, code: code));
    } on FirebaseException catch (e) {
      // 참여 전에는 가계부를 읽을 수 없어 자리가 남았는지 미리 알 수 없다.
      // 규칙이 거부하거나 가계부가 없으면 들어갈 자리가 없는 것으로 안내한다.
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        throw const JoinLedgerException(JoinFailure.unavailable);
      }
      rethrow;
    }
  }

  @override
  Future<void> rename({
    required String ledgerId,
    required String name,
    required String uid,
  }) {
    final doc = _ledgers.doc(ledgerId);
    return runSettingsWrite(
      _firestore,
      ledgerId: ledgerId,
      uid: uid,
      now: _now(),
      write: (transaction) async {
        final current = (await transaction.get(doc)).data();
        if (current == null) {
          throw const SettingsWriteException(SettingsWriteFailure.notFound);
        }
        transaction.update(doc, ledgerRenameUpdate(name));
        return ledgerRenameActivity(
          from: switch (current['name']) {
            final String name => name,
            _ => null,
          },
          to: name,
        );
      },
    );
  }

  @override
  Future<LeaveOutcome> leave({
    required String ledgerId,
    required String uid,
  }) async {
    final doc = _ledgers.doc(ledgerId);
    late LeaveOutcome outcome;
    await runSettingsWrite(
      _firestore,
      ledgerId: ledgerId,
      uid: uid,
      now: _now(),
      write: (transaction) async {
        final Map<String, dynamic>? data;
        try {
          data = (await transaction.get(doc)).data();
        } on FirebaseException catch (e) {
          // 구성원이 아니면(이미 나갔거나 내보내짐) 규칙이 읽기를 막는다. 지워진 가계부도 같다.
          if (e.code == 'permission-denied') {
            throw const SettingsWriteException(SettingsWriteFailure.notFound);
          }
          rethrow;
        }
        final ledger = data == null ? null : ledgerFromFirestore(doc.id, data);
        final left = ledger?.leaveOutcomeOf(uid);
        if (ledger == null || left == null) {
          throw const SettingsWriteException(SettingsWriteFailure.notFound);
        }
        outcome = left;
        transaction.update(doc, ledgerLeaveUpdate(ledger, uid));
        // 변경 기록은 쓰기 권한이 있어야 남길 수 있다(규칙은 나가기 전의 가계부로 본다).
        final canWrite = ledger.roleOf(uid)?.canWrite ?? false;
        return canWrite ? ledgerLeaveActivity(left) : null;
      },
    );
    return outcome;
  }

  @override
  Future<void> recordMonths({
    required String ledgerId,
    required Iterable<YearMonth> months,
  }) {
    final doc = _ledgers.doc(ledgerId);
    return _firestore.runTransaction((transaction) async {
      final current = (await transaction.get(doc)).data()?['months'];
      transaction.update(doc, {
        'months': {
          if (current is List) ...current.whereType<String>(),
          for (final month in months) month.id,
        }.toList(),
      });
    });
  }

  // 방금 만든 가계부는 서버 시간이 아직 없어서(null) 맨 뒤로 보낸다.
  static int _byCreatedAt(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final aTime = a.data()['createdAt'];
    final bTime = b.data()['createdAt'];
    if (aTime is Timestamp && bTime is Timestamp) return aTime.compareTo(bTime);
    if (aTime is Timestamp) return -1;
    if (bTime is Timestamp) return 1;
    return a.id.compareTo(b.id);
  }
}

/// 새 가계부 ID. 만든 사람 uid로 시작한다('uid_무작위', [randomId]는 Firestore 자동 ID).
///
/// 보안 규칙이 이 모양만 받는다. 옛 가계부의 무작위 ID나 남의 uid로 시작하는 ID로는 만들 수 없게 해서,
/// 예전 규칙으로 지워져 하위 문서만 남은 ID를 다른 사람이 다시 만들어 남은 내역을 읽지 못하게 한다(`docs/firestore.md`).
String newLedgerId(String ownerUid, String randomId) => '${ownerUid}_$randomId';

/// 가계부를 만들 때 쓰는 문서. `firestore.rules`의 ledgers create 규칙과 필드가 같아야 한다.
Map<String, Object> newLedgerData({
  required String name,
  required String ownerUid,
  required YearMonth firstMonth,
}) => {
  'name': name,
  'ownerUid': ownerUid,
  'roles': <String, String>{},
  'memberUids': [ownerUid],
  // 새 가계부는 처음 고른 달 하나로 시작한다(규칙의 createsMonths). 목록이 있어서 따로 모을 필요가 없다.
  'months': [firstMonth.id],
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// [month]에 항목을 넣을 때 가계부의 항목 있는 달 목록(`months`)에 그달을 더하는 값. 규칙의 recordsMonths가 받는다.
/// 이미 있으면 바뀌지 않는다.
Map<String, Object> recordMonthUpdate(YearMonth month) => {
  'months': FieldValue.arrayUnion([month.id]),
};

/// 가계부 이름을 바꿀 때 쓰는 값. 규칙의 ownerManages가 받는 필드(이름·고친 시간)와 같아야 한다.
Map<String, Object> ledgerRenameUpdate(String name) => {
  'name': name.trim(),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// [uid]가 [ledger]에서 나갈 때 가계부 문서에 쓰는 값. 규칙의 leavesSelf·ownerHandsOver·ownerClosesAlone이 받는 필드와 같다.
///
/// - 초대로 들어온 사람: 자기 역할과 uid만 뺀다.
/// - 관리자(상대 있음): 남은 사람을 관리자로 하고, 그 사람이 앉아 있던 이름표 자리를 관리자 자리([Ledger.ownerSlot])로 적는다.
/// - 관리자(혼자): 구성원을 비운다. 서버 함수(`deleteClosedLedger`)가 하위 문서까지 지운다.
///
/// [uid]가 구성원이 아니면 [StateError].
Map<Object, Object> ledgerLeaveUpdate(Ledger ledger, String uid) =>
    switch (ledger.leaveOutcomeOf(uid)) {
      LeaveOutcome.memberLeaves => {
        FieldPath(['roles', uid]): FieldValue.delete(),
        'memberUids': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      LeaveOutcome.handsOver => {
        'ownerUid': ledger.roles.keys.first,
        'roles': <String, String>{},
        'memberUids': [ledger.roles.keys.first],
        'ownerSlot': ledger.ownerSlot.other.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      LeaveOutcome.closes => {
        'memberUids': <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      },
      null => throw StateError('구성원이 아니라 나갈 수 없다'),
    };

/// Firestore 문서를 [Ledger]로 바꾼다. 알 수 없는 역할 값은 건너뛴다.
Ledger ledgerFromFirestore(String id, Map<String, dynamic> data) {
  final rawRoles = data['roles'];
  final roles = <String, MemberRole>{};
  if (rawRoles is Map) {
    for (final MapEntry(:key, :value) in rawRoles.entries) {
      final role = _invitedRole(value);
      if (key is String && role != null) roles[key] = role;
    }
  }
  final name = data['name'];
  final ownerUid = data['ownerUid'];
  final createdAt = data['createdAt'];
  final months = data['months'];
  return Ledger(
    id: id,
    name: name is String ? name : '',
    ownerUid: ownerUid is String ? ownerUid : '',
    roles: roles,
    // 관리자를 넘긴 적이 없으면 없다. 모르는 값도 처음 자리(owner)로 본다.
    ownerSlot:
        MemberSlot.values.asNameMap()[data['ownerSlot']] ?? MemberSlot.owner,
    createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    // 모양이 다른 달 값은 건너뛴다. 목록 자체가 없거나 목록이 아니면 아직 모으지 않은 가계부다.
    months: months is List
        ? {
            for (final month in months)
              if (month is String) ?YearMonth.tryParse(month),
          }
        : null,
  );
}

/// 초대 코드를 만들 때 쓰는 문서. `firestore.rules`의 invites create 규칙과 필드가 같아야 한다.
Map<String, Object> newInviteData({
  required String ledgerId,
  required MemberRole role,
  required String createdBy,
  required DateTime expiresAt,
}) {
  assert(role != MemberRole.owner, '관리자 역할로는 초대할 수 없다');
  return {
    'ledgerId': ledgerId,
    'role': role.name,
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(expiresAt),
  };
}

/// Firestore 초대 문서를 [Invite]로 바꾼다. 필드가 빠졌거나 모양이 다르면 null.
Invite? inviteFromFirestore(String code, Map<String, dynamic> data) {
  final ledgerId = data['ledgerId'];
  final role = _invitedRole(data['role']);
  final expiresAt = data['expiresAt'];
  if (ledgerId is! String || role == null || expiresAt is! Timestamp) {
    return null;
  }
  return Invite(
    code: code,
    ledgerId: ledgerId,
    role: role,
    expiresAt: expiresAt.toDate(),
  );
}

/// 초대 코드로 참여할 때 가계부 문서에 쓰는 값. 규칙의 joinsWithInvite가 받는 필드와 같아야 한다.
Map<Object, Object> joinLedgerUpdate({
  required String uid,
  required MemberRole role,
  required String code,
}) => {
  FieldPath(['roles', uid]): role.name,
  'memberUids': FieldValue.arrayUnion([uid]),
  'inviteCode': code,
  'updatedAt': FieldValue.serverTimestamp(),
};

// 초대로 받을 수 있는 역할만 읽는다. 관리자는 ownerUid로만 정해진다.
MemberRole? _invitedRole(Object? value) => switch (value) {
  'editor' => MemberRole.editor,
  'viewer' => MemberRole.viewer,
  _ => null,
};
