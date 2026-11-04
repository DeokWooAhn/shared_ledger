/// 화면에 보이는 금액. 세 자리마다 쉼표를 넣고 '원'을 붙인다. 예: `2,973,000원`, `-12,000원`
String won(int amount) => '${wonDigits(amount)}원';

/// 세 자리마다 쉼표를 넣은 금액 숫자. 예: `2,973,000`, `-12,000`
String wonDigits(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 좁은 자리(막대 위)에 적는 짧은 금액. 만 원·억 원 단위로 줄이고, 10만 원 아래와 1억 원 이상은 소수 한 자리까지 적는다.
/// 1만 원이 안 되면 [won]과 같다. 예: `8,000원`, `1.5만`, `523만`, `1.2억`, `-30만`
String wonShort(int amount) {
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  // [tenths]를 10으로 나눈 값을 소수 한 자리까지 적는다(.0은 뺀다).
  String decimal(int tenths, String unit) {
    final whole = wonDigits(tenths ~/ 10);
    final rest = tenths % 10;
    return rest == 0 ? '$whole$unit' : '$whole.$rest$unit';
  }

  if (abs < 10000) return won(amount);
  if (abs < 100000) return '$sign${decimal((abs + 500) ~/ 1000, '만')}';
  final man = (abs + 5000) ~/ 10000;
  if (man < 10000) return '$sign${wonDigits(man)}만';
  return '$sign${decimal((abs + 5000000) ~/ 10000000, '억')}';
}
