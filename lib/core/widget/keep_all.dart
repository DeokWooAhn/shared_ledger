import 'package:flutter/widgets.dart';

/// 줄바꿈을 막는 보이지 않는 글자(WORD JOINER, U+2060).
const _wordJoiner = '\u2060';

/// 한글 문장이 단어 중간에서 줄바뀌지 않게 한다(CSS의 `word-break: keep-all`).
///
/// Flutter는 한글을 글자마다 줄바꿈할 수 있는 곳으로 봐서 '초 / 대 코드'처럼 끊는다.
/// 공백이 아닌 글자 사이에 [_wordJoiner]를 넣어 공백에서만 줄이 바뀌게 한다.
/// 한 단어가 한 줄보다 길면 Flutter가 그 단어 안에서 끊는다.
///
/// 화면에 그릴 문장에만 쓴다. 저장하거나 비교하는 값, 입력란 내용에는 쓰지 않는다.
String keepAll(String text) {
  final buffer = StringBuffer();
  String? previous;
  // 이모지처럼 여러 코드 포인트로 된 글자를 쪼개지 않도록 글자(grapheme) 단위로 본다.
  for (final char in text.characters) {
    if (previous != null && !_isSpace(previous) && !_isSpace(char)) {
      buffer.write(_wordJoiner);
    }
    buffer.write(char);
    previous = char;
  }
  return buffer.toString();
}

/// [keepAll]의 결과가 null일 수도 있는 문구(입력란 오류 등)에 쓴다.
String? keepAllOrNull(String? text) => text == null ? null : keepAll(text);

bool _isSpace(String char) => char.trim().isEmpty;
