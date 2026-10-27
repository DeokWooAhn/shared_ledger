import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/member.dart';

void main() {
  test('내 이름표 이름은 로그인 이름의 앞뒤 공백을 빼고 10자까지, 없으면 나', () {
    expect(ownerMemberName(' 하늘 '), '하늘');
    expect(ownerMemberName('가나다라마바사아자차카'), '가나다라마바사아자차');
    expect(ownerMemberName('가나다라마바사아자 차카'), '가나다라마바사아자');
    expect(ownerMemberName(null), '나');
    expect(ownerMemberName('   '), '나');
  });

  test('동그라미에는 이름의 첫 글자를 보여준다', () {
    expect(const Member(slot: MemberSlot.owner, name: ' 하늘').initial, '하');
    expect(const Member(slot: MemberSlot.partner, name: '😀바다').initial, '😀');
  });

  test('이름표를 받지 못했으면 역할 이름(관리자·상대)으로 만든다', () {
    const sky = Member(slot: MemberSlot.owner, name: '하늘');

    expect(memberIn(const [sky], MemberSlot.owner), sky);
    expect(
      memberIn(const [sky], MemberSlot.partner),
      const Member(slot: MemberSlot.partner, name: '상대'),
    );
    expect(
      memberIn(const [], MemberSlot.owner),
      const Member(slot: MemberSlot.owner, name: '관리자'),
    );
  });
}
