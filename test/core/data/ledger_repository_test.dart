import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/ledger_repository.dart';
import 'package:shared_ledger/core/model/ledger.dart';

void main() {
  test('새 가계부 문서는 보안 규칙이 받는 필드만, 나를 관리자로 담는다', () {
    final data = newLedgerData(name: '우리 가계부', ownerUid: 'me');

    // firestore.rules의 ledgers create 규칙과 같은 필드 목록.
    expect(data.keys.toSet(), {
      'name',
      'ownerUid',
      'roles',
      'memberUids',
      'createdAt',
      'updatedAt',
    });
    expect(data['name'], '우리 가계부');
    expect(data['ownerUid'], 'me');
    expect(data['roles'], isEmpty);
    expect(data['memberUids'], ['me']);
    expect(data['createdAt'], isA<FieldValue>());
    expect(data['updatedAt'], isA<FieldValue>());
  });

  test('Firestore 문서를 가계부로 바꾸고, 알 수 없는 값은 건너뛴다', () {
    final ledger = ledgerFromFirestore('l1', {
      'name': '우리 가계부',
      'ownerUid': 'owner',
      'roles': {'a': 'editor', 'b': 'owner', 'c': 'unknown'},
      'memberUids': ['owner', 'a'],
    });

    expect(ledger.id, 'l1');
    expect(ledger.name, '우리 가계부');
    expect(ledger.ownerUid, 'owner');
    expect(ledger.roles, {'a': MemberRole.editor});

    final broken = ledgerFromFirestore('l2', {'name': 3, 'ownerUid': null});
    expect(broken.name, '');
    expect(broken.ownerUid, '');
    expect(broken.roles, isEmpty);
  });

  test('새 초대 문서는 보안 규칙이 받는 필드만 담는다', () {
    final expiresAt = DateTime.utc(2026, 10, 28, 6);
    final data = newInviteData(
      ledgerId: 'l1',
      role: MemberRole.viewer,
      createdBy: 'me',
      expiresAt: expiresAt,
    );

    // firestore.rules의 invites create 규칙과 같은 필드 목록.
    expect(data.keys.toSet(), {
      'ledgerId',
      'role',
      'createdBy',
      'createdAt',
      'expiresAt',
    });
    expect(data['ledgerId'], 'l1');
    expect(data['role'], 'viewer');
    expect(data['createdBy'], 'me');
    expect(data['createdAt'], isA<FieldValue>());
    expect(data['expiresAt'], Timestamp.fromDate(expiresAt));
  });

  test('초대 문서를 읽고, 모양이 다르면 null이다', () {
    final expiresAt = Timestamp.fromDate(DateTime.utc(2026, 10, 28));
    final invite = inviteFromFirestore('ABCDEFGH23', {
      'ledgerId': 'l1',
      'role': 'editor',
      'expiresAt': expiresAt,
    });
    expect(invite?.code, 'ABCDEFGH23');
    expect(invite?.ledgerId, 'l1');
    expect(invite?.role, MemberRole.editor);
    expect(invite?.expiresAt, expiresAt.toDate());

    expect(
      inviteFromFirestore('X', {
        'ledgerId': 'l1',
        'role': 'owner',
        'expiresAt': expiresAt,
      }),
      isNull,
    );
    expect(
      inviteFromFirestore('X', {'ledgerId': 'l1', 'role': 'editor'}),
      isNull,
    );
  });

  test('참여할 때는 보안 규칙이 받는 필드만, 내 uid로 바꾼다', () {
    final update = joinLedgerUpdate(
      uid: 'me',
      role: MemberRole.viewer,
      code: 'ABCDEFGH23',
    );

    // firestore.rules의 joinsWithInvite가 바꿀 수 있게 한 필드: roles.<내 uid>, memberUids, inviteCode, updatedAt.
    expect(update.keys.toSet(), {
      FieldPath(const ['roles', 'me']),
      'memberUids',
      'inviteCode',
      'updatedAt',
    });
    expect(update[FieldPath(const ['roles', 'me'])], 'viewer');
    expect(update['memberUids'], isA<FieldValue>());
    expect(update['inviteCode'], 'ABCDEFGH23');
    expect(update['updatedAt'], isA<FieldValue>());
  });
}
