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

/// 초대 코드 입력란 아래에 보여 줄 문제. 입력 검사와 참여 실패를 한곳에서 다룬다.
enum InviteCodeProblem {
  empty,
  malformed,

  /// 코드가 없거나 관리자가 지웠다.
  notFound,
  expired,

  /// 두 명이 다 찼거나 가계부가 없어졌다.
  unavailable,
}

/// 입력한 초대 코드를 서버에 묻기 전에 검사한다. 문제가 없으면 null.
InviteCodeProblem? inviteCodeProblemOf(String input) {
  final code = normalizeInviteCode(input);
  if (code.isEmpty) return InviteCodeProblem.empty;
  if (!isInviteCodeShaped(code)) return InviteCodeProblem.malformed;
  return null;
}
