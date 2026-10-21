import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/ledger.dart';

void main() {
  const shared = Ledger(
    id: 'l1',
    name: '우리 가계부',
    ownerUid: 'owner',
    roles: {'partner': MemberRole.viewer},
  );
  const solo = Ledger(id: 'l2', name: '우리 가계부', ownerUid: 'owner');

  test('관리자·구성원의 역할을 알려주고, 구성원이 아니면 null이다', () {
    expect(shared.roleOf('owner'), MemberRole.owner);
    expect(shared.roleOf('partner'), MemberRole.viewer);
    expect(shared.roleOf('stranger'), isNull);
  });

  test('보기 전용만 쓸 수 없고, 구성원 관리는 관리자만 할 수 있다', () {
    expect(MemberRole.owner.canWrite, isTrue);
    expect(MemberRole.editor.canWrite, isTrue);
    expect(MemberRole.viewer.canWrite, isFalse);
    expect(MemberRole.owner.canManageMembers, isTrue);
    expect(MemberRole.editor.canManageMembers, isFalse);
  });

  test('memberUids는 관리자를 맨 앞에 두고 모든 구성원을 담는다', () {
    expect(shared.memberUids, ['owner', 'partner']);
  });

  test('두 명이 다 차면 가득 찬 가계부다', () {
    expect(ledgerMaxMembers, 2);
    expect(solo.isFull, isFalse);
    expect(shared.isFull, isTrue);
  });

  test('초대 코드는 자리가 남은 가계부의 관리자만 만들 수 있다', () {
    expect(solo.canInvite('owner'), isTrue);
    expect(shared.canInvite('owner'), isFalse);
    expect(shared.canInvite('partner'), isFalse);
    expect(solo.canInvite('stranger'), isFalse);
  });
}
