import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/data/holidays/firestore_holidays_repository.dart';
import 'package:shared_ledger/domain/model/holidays.dart';

void main() {
  group('holidaysFromFirestore', () {
    test('days 표를 그대로 공휴일로 읽는다', () {
      expect(
        holidaysFromFirestore({
          'days': {'2026-10-03': '개천절', '2026-10-09': '한글날'},
          'updatedAt': null,
        }),
        const Holidays({'2026-10-03': '개천절', '2026-10-09': '한글날'}),
      );
    });

    test('문서가 없거나 days가 표가 아니면 빈 해다', () {
      expect(holidaysFromFirestore(null), const Holidays());
      expect(holidaysFromFirestore({}), const Holidays());
      expect(holidaysFromFirestore({'days': '2026-10-03'}), const Holidays());
    });

    test('날짜 모양이 다르거나 이름이 비었거나 문자열이 아닌 줄은 건너뛴다', () {
      expect(
        holidaysFromFirestore({
          'days': {
            '2026-10-03': ' 개천절 ',
            '20261009': '한글날',
            '2026-10-05': '',
            '2026-12-25': 1,
            7: '신정',
          },
        }),
        const Holidays({'2026-10-03': '개천절'}),
      );
    });
  });
}
