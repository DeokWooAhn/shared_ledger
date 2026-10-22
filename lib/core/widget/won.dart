/// 화면에 보이는 금액. 세 자리마다 쉼표를 넣고 '원'을 붙인다. 예: `2,973,000원`, `-12,000원`
String won(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  buffer.write('원');
  return buffer.toString();
}
