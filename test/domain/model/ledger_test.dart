import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/year_month.dart';
import 'package:shared_ledger/domain/model/member.dart';

void main() {
  const shared = Ledger(
    id: 'l1',
    name: '우리 가계부',
    ownerUid: 'owner',
    roles: {'partner': MemberRole.viewer},
  );
  const solo = Ledger(id: 'l2', name: '우리 가계부', ownerUid: 'owner');

  test('관리자는 owner 이름표, 초대로 들어온 사람은 partner 이름표다', () {
    expect(shared.slotOf('owner'), MemberSlot.owner);
    expect(shared.slotOf('partner'), MemberSlot.partner);
    expect(shared.slotOf('stranger'), isNull);
    expect(shared.uidOf(MemberSlot.owner), 'owner');
    expect(shared.uidOf(MemberSlot.partner), 'partner');
    expect(solo.uidOf(MemberSlot.partner), isNull);
  });

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

  test('가계부 이름은 관리자만 바꿀 수 있다 (규칙의 ownerManages)', () {
    const edited = Ledger(
      id: 'l3',
      name: '우리 가계부',
      ownerUid: 'owner',
      roles: {'partner': MemberRole.editor},
    );
    expect(edited.canRename('owner'), isTrue);
    expect(edited.canRename('partner'), isFalse);
    expect(shared.canRename('partner'), isFalse);
    expect(shared.canRename('stranger'), isFalse);
  });

  test('항목 있는 달 목록에 없는 달만 더하고, 목록을 아직 모으지 않았으면 더하지 않는다', () {
    final ledger = Ledger(
      id: 'l1',
      name: '우리 가계부',
      ownerUid: 'me',
      months: {const YearMonth(2026, 10)},
    );

    expect(ledger.needsToRecord(const YearMonth(2026, 11)), isTrue);
    expect(ledger.needsToRecord(const YearMonth(2026, 10)), isFalse);
    expect(
      const Ledger(
        id: 'l2',
        name: '우리 가계부',
        ownerUid: 'me',
      ).needsToRecord(const YearMonth(2026, 11)),
      isFalse,
    );
  });
}
