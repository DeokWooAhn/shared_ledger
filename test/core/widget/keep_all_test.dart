import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/widget/keep_all.dart';

const wordJoiner = '\u2060';

void main() {
  test('공백이 아닌 글자 사이에만 줄바꿈을 막는 글자를 넣는다', () {
    expect(keepAll('초대 코드'), '초$wordJoiner대 코$wordJoiner드');
    expect(
      keepAll('들어와요.'),
      '들$wordJoiner어$wordJoiner와$wordJoiner요$wordJoiner.',
    );
  });

  test('막는 글자를 빼면 원래 문장과 같다', () {
    const text = '한 사람이 가계부를 만들고,\n다른 한 사람은 초대 코드로 들어와요.';
    expect(keepAll(text).replaceAll(wordJoiner, ''), text);
  });

  test('공백·줄바꿈 양옆과 한 글자, 빈 문자열에는 넣지 않는다', () {
    expect(keepAll(''), '');
    expect(keepAll('가'), '가');
    expect(keepAll('가 나\n다'), '가 나\n다');
  });

  test('이모지처럼 여러 코드 포인트로 된 글자는 쪼개지 않는다', () {
    const family = '👨‍👩‍👧';
    expect(keepAll('$family가족'), '$family$wordJoiner가$wordJoiner족');
  });

  test('null은 그대로 둔다', () {
    expect(keepAllOrNull(null), isNull);
    expect(keepAllOrNull('가나'), '가$wordJoiner나');
  });

  testWidgets('좁은 폭에서 단어 중간이 아니라 공백에서 줄이 바뀐다', (tester) async {
    // 테스트 글꼴은 글자마다 폭이 글자 크기(10)와 같다. 폭 35면 한 줄에 세 칸이 들어간다.
    String firstLine(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 35);
      final end = painter.getLineBoundary(const TextPosition(offset: 0)).end;
      painter.dispose();
      return text.substring(0, end).replaceAll(wordJoiner, '').trim();
    }

    // 그냥 두면 '나다라'가 갈려 '가 나'까지 첫 줄에 들어간다.
    expect(firstLine('가 나다라'), '가 나');
    expect(firstLine(keepAll('가 나다라')), '가');
  });
}
