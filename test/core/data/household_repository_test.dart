import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/household_repository.dart';
import 'package:shared_ledger/core/model/household.dart';

void main() {
  test('새 가구 문서는 보안 규칙이 받는 필드만, 나를 관리자로 담는다', () {
    final data = newHouseholdData(name: '우리집', ownerUid: 'me');

    // firestore.rules의 households create 규칙과 같은 필드 목록.
    expect(data.keys.toSet(), {
      'name',
      'ownerUid',
      'roles',
      'memberUids',
      'createdAt',
      'updatedAt',
    });
    expect(data['name'], '우리집');
    expect(data['ownerUid'], 'me');
    expect(data['roles'], isEmpty);
    expect(data['memberUids'], ['me']);
    expect(data['createdAt'], isA<FieldValue>());
    expect(data['updatedAt'], isA<FieldValue>());
  });

  test('Firestore 문서를 가구로 바꾸고, 알 수 없는 역할 값은 건너뛴다', () {
    final household = householdFromFirestore('h1', {
      'name': '우리집',
      'ownerUid': 'owner',
      'roles': {'a': 'editor', 'b': 'viewer', 'c': 'owner', 'd': 'unknown'},
      'memberUids': ['owner', 'a', 'b'],
    });

    expect(household.id, 'h1');
    expect(household.name, '우리집');
    expect(household.ownerUid, 'owner');
    expect(household.roles, {
      'a': HouseholdRole.editor,
      'b': HouseholdRole.viewer,
    });
  });
}
