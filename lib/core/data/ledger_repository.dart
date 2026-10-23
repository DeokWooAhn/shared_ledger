import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/invite.dart';
import '../model/ledger.dart';
import 'settings_repository.dart';

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

  /// 가계부 이름을 [name]으로 바꾼다. 관리자만 할 수 있다(규칙의 ownerManages).
  ///
  /// 다른 설정처럼 온라인에서만 된다. 연결이 없으면 [SettingsWriteException]([SettingsWriteFailure.offline]),
  /// 가계부가 없어졌으면 [SettingsWriteFailure.notFound]로 실패한다.
  Future<void> rename({required String ledgerId, required String name});
}

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
  }) async {
    final ref = _ledgers.doc();
    final batch = _firestore.batch()
      ..set(ref, newLedgerData(name: name, ownerUid: ownerUid));
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
  Future<void> rename({required String ledgerId, required String name}) {
    final doc = _ledgers.doc(ledgerId);
    return runSettingsWrite(_firestore, (transaction) async {
      if (!(await transaction.get(doc)).exists) {
        throw const SettingsWriteException(SettingsWriteFailure.notFound);
      }
      transaction.update(doc, ledgerRenameUpdate(name));
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

/// 가계부를 만들 때 쓰는 문서. `firestore.rules`의 ledgers create 규칙과 필드가 같아야 한다.
Map<String, Object> newLedgerData({
  required String name,
  required String ownerUid,
}) => {
  'name': name,
  'ownerUid': ownerUid,
  'roles': <String, String>{},
  'memberUids': [ownerUid],
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// 가계부 이름을 바꿀 때 쓰는 값. 규칙의 ownerManages가 받는 필드(이름·고친 시간)와 같아야 한다.
Map<String, Object> ledgerRenameUpdate(String name) => {
  'name': name.trim(),
  'updatedAt': FieldValue.serverTimestamp(),
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
  return Ledger(
    id: id,
    name: name is String ? name : '',
    ownerUid: ownerUid is String ? ownerUid : '',
    roles: roles,
    createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
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
