import 'dart:math';

import 'ledger.dart';

/// 초대 코드를 쓸 수 있는 기간. `firestore.rules`는 만든 때부터 7일 이내만 받는다.
const inviteValidity = Duration(days: 7);

/// 초대 코드 길이. 규칙은 영문·숫자 8~32자를 받는다.
const inviteCodeLength = 10;

/// 초대 코드에 쓰는 글자. 서로 헷갈리는 0·O, 1·I·L은 뺐다.
const inviteCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// 가계부에 들어올 사람에게 주는 초대 코드.
class Invite {
  const Invite({
    required this.code,
    required this.ledgerId,
    required this.role,
    required this.expiresAt,
  });

  final String code;
  final String ledgerId;

  /// 들어오면 받을 역할. 편집자나 보기 전용이다.
  final MemberRole role;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}

/// 추측하기 어려운 초대 코드를 만든다. 실제 앱에서는 [Random.secure]를 넘긴다.
String generateInviteCode(Random random) => String.fromCharCodes([
  for (var i = 0; i < inviteCodeLength; i++)
    inviteCodeAlphabet.codeUnitAt(random.nextInt(inviteCodeAlphabet.length)),
]);

/// 사람이 입력한 초대 코드를 정리한다. 공백·하이픈을 빼고 대문자로 바꾼다.
String normalizeInviteCode(String input) =>
    input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// 정리한 코드가 초대 코드 모양인지. 아니면 서버에 묻지 않고 바로 안내한다.
bool isInviteCodeShaped(String code) =>
    RegExp(r'^[A-Z0-9]{8,32}$').hasMatch(code);
