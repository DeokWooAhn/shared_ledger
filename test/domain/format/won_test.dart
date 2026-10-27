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
}
