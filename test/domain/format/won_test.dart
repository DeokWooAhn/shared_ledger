import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/format/won.dart';

void main() {
  test('금액은 세 자리마다 쉼표를 넣고 원을 붙인다', () {
    expect(won(0), '0원');
    expect(won(999), '999원');
    expect(won(1000), '1,000원');
    expect(won(2973000), '2,973,000원');
    expect(won(123456789012), '123,456,789,012원');
  });

  test('음수는 앞에 빼기 표시를 붙인다', () {
    expect(won(-500), '-500원');
    expect(won(-1234567), '-1,234,567원');
  });

  test('짧은 금액은 만·억 단위로 줄이고, 10만 아래와 1억 이상은 소수 한 자리까지 적는다', () {
    expect(wonShort(8000), '8,000원');
    expect(wonShort(10000), '1만');
    expect(wonShort(15000), '1.5만');
    expect(wonShort(99960), '10만');
    expect(wonShort(5234000), '523만');
    expect(wonShort(25062000), '2,506만');
    expect(wonShort(123400000), '1.2억');
    expect(wonShort(-300000), '-30만');
  });
}
