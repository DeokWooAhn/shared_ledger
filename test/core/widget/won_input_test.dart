import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/widget/won_input.dart';

// 입력란에 글자를 넣은 것처럼 포맷터를 부른다. [cursor]는 바뀐 글자에서의 커서 위치(기본은 끝).
TextEditingValue type(String before, String after, {int? cursor}) =>
    const WonInputFormatter().formatEditUpdate(
      TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      ),
      TextEditingValue(
        text: after,
        selection: TextSelection.collapsed(offset: cursor ?? after.length),
      ),
    );

void main() {
  group('금액 글자 읽기', () {
    test('쉼표를 빼고 원 단위 정수로 읽고, 숫자가 없으면 null이다', () {
      expect(parseWon('186,000'), 186000);
      expect(parseWon('0'), 0);
      expect(parseWon(''), isNull);
      expect(parseWon(' , '), isNull);
    });

    test('처음 글자는 쉼표를 넣은 숫자이고, 금액이 없으면 빈 칸이다', () {
      expect(wonInputText(1234567), '1,234,567');
      expect(wonInputText(0), '0');
      expect(wonInputText(null), '');
    });
  });

  group('금액 입력란 포맷터', () {
    test('세 자리마다 쉼표를 넣고 커서를 끝에 둔다', () {
      final value = type('18,600', '18,6000');

      expect(value.text, '186,000');
      expect(value.selection.baseOffset, 7);
    });

    test('숫자가 아닌 글자는 버리고 앞의 0은 지운다', () {
      expect(type('', '1a2-3').text, '123');
      expect(type('0', '05').text, '5');
      expect(type('', '000').text, '0');
    });

    test('가운데 숫자를 지워도 커서는 같은 숫자 뒤에 남는다', () {
      // '1,234,567'에서 '4' 뒤의 커서로 4를 지운 경우.
      final value = type('1,234,567', '1,23,567', cursor: 4);

      expect(value.text, '123,567');
      expect(value.selection.baseOffset, 3);
    });

    test('12자리를 넘으면 받지 않는다', () {
      expect(type('', '999999999999').text, '999,999,999,999');
      expect(
        type('999,999,999,999', '999,999,999,9999').text,
        '999,999,999,999',
      );
    });

    test('다 지우면 빈 칸이다', () {
      expect(type('1', '').text, '');
    });
  });
}
