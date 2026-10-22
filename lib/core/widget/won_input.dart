import 'package:flutter/services.dart';

import 'won.dart';

/// 금액 입력란이 받는 자릿수. 999,999,999,999원(1조 원 미만)까지다.
const wonInputMaxDigits = 12;

/// 금액 입력란의 글자를 원 단위 정수로 바꾼다. 숫자가 없으면 null.
int? parseWon(String text) {
  final digits = text.replaceAll(RegExp('[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// 금액 입력란의 처음 글자. 예: `186000` → `186,000`, null → 빈 칸
String wonInputText(int? amount) => amount == null ? '' : wonDigits(amount);

/// 금액 입력란에 숫자만 받고 세 자리마다 쉼표를 넣는다. 앞의 0은 지우고, [wonInputMaxDigits]자리를 넘으면 받지 않는다.
///
/// 쉼표가 들어가거나 빠져도 커서는 같은 숫자 뒤에 둔다.
class WonInputFormatter extends TextInputFormatter {
  const WonInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text
        .replaceAll(RegExp('[^0-9]'), '')
        .replaceFirst(RegExp('^0+(?=[0-9])'), '');
    if (digits.length > wonInputMaxDigits) return oldValue;
    final amount = parseWon(digits);
    final text = wonInputText(amount);
    // 커서 앞에 있던 숫자 개수만큼 새 글자에서 숫자를 세어 그 뒤에 커서를 둔다.
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final before = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp('[^0-9]'), '')
        .replaceFirst(RegExp('^0+'), '')
        .length;
    var offset = 0;
    for (var seen = 0; offset < text.length && seen < before; offset++) {
      if (text[offset] != ',') seen++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
