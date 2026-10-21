import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/household.dart';

void main() {
  const household = Household(
    id: 'h1',
    name: '우리집',
    ownerUid: 'owner',
    roles: {'editor': HouseholdRole.editor, 'viewer': HouseholdRole.viewer},
  );

  test('관리자·편집자·보기 전용의 역할을 알려주고, 구성원이 아니면 null이다', () {
    expect(household.roleOf('owner'), HouseholdRole.owner);
    expect(household.roleOf('editor'), HouseholdRole.editor);
    expect(household.roleOf('viewer'), HouseholdRole.viewer);
    expect(household.roleOf('stranger'), isNull);
  });

  test('보기 전용만 쓸 수 없고, 구성원 관리는 관리자만 할 수 있다', () {
    expect(HouseholdRole.owner.canWrite, isTrue);
    expect(HouseholdRole.editor.canWrite, isTrue);
    expect(HouseholdRole.viewer.canWrite, isFalse);
    expect(HouseholdRole.owner.canManageMembers, isTrue);
    expect(HouseholdRole.editor.canManageMembers, isFalse);
  });

  test('memberUids는 관리자를 맨 앞에 두고 모든 구성원을 담는다', () {
    expect(household.memberUids, ['owner', 'editor', 'viewer']);
  });
}
