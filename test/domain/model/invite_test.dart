import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/invite.dart';
import 'package:shared_ledger/domain/model/ledger.dart';

void main() {
  test('초대 코드는 헷갈리는 글자 없이 10자이고, 보안 규칙이 받는 모양이다', () {
    final random = Random(1);
    for (var i = 0; i < 200; i++) {
      final code = generateInviteCode(random);
      expect(code, hasLength(inviteCodeLength));
      expect(code, matches(RegExp(r'^[A-Za-z0-9]{8,32}$')));
      expect(code, isNot(matches(RegExp('[01OIL]'))));
      expect(isInviteCodeShaped(code), isTrue);
    }
  });

  test('입력한 초대 코드는 공백·하이픈을 빼고 대문자로 맞춘다', () {
    expect(normalizeInviteCode(' abcd-efgh 23 '), 'ABCDEFGH23');
    expect(normalizeInviteCode(''), '');
  });

  test('초대 코드 모양이 아니면 서버에 묻지 않는다', () {
    expect(isInviteCodeShaped('ABCDEFGH23'), isTrue);
    expect(isInviteCodeShaped('ABC'), isFalse);
    expect(isInviteCodeShaped('ABCD/EFGH23'), isFalse);
    expect(isInviteCodeShaped('가나다라마바사아'), isFalse);
  });

  test('유효기간이 지나면 만료다', () {
    final invite = Invite(
      code: 'ABCDEFGH23',
      ledgerId: 'l1',
      role: MemberRole.editor,
      expiresAt: DateTime(2026, 10, 28, 12),
    );
    expect(invite.isExpiredAt(DateTime(2026, 10, 28, 11, 59)), isFalse);
    expect(invite.isExpiredAt(DateTime(2026, 10, 28, 12)), isTrue);
  });
}
