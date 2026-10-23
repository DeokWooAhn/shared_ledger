import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/settings_repository.dart';
import 'package:shared_ledger/feature/settings/setting_form.dart';

void main() {
  group('이름 검사', () {
    test('앞뒤 공백을 뺀 이름이 비면 missing이다', () {
      expect(nameProblemOf('   ', maxLength: 20), NameProblem.missing);
    });

    test('최대 길이까지는 되고, 넘으면 tooLong이다 (앞뒤 공백은 세지 않는다)', () {
      expect(nameProblemOf(' ${'가' * 20} ', maxLength: 20), isNull);
      expect(nameProblemOf('가' * 21, maxLength: 20), NameProblem.tooLong);
    });

    test('길이는 규칙처럼 UTF-16 단위로 세서 이모지는 두 글자다', () {
      expect(nameProblemOf('💳' * 5, maxLength: 10), isNull);
      expect(nameProblemOf('💳' * 6, maxLength: 10), NameProblem.tooLong);
    });

    test('같은 목록에 앞뒤 공백을 뺀 같은 이름이 있으면 taken이다', () {
      expect(
        nameProblemOf(' 소비 ', maxLength: 20, taken: const ['대출원금', '소비']),
        NameProblem.taken,
      );
      expect(nameProblemOf('소비2', maxLength: 20, taken: const ['소비']), isNull);
    });
  });

  test('저장소의 실패를 화면용 실패로 바꾼다', () {
    expect(
      settingFormFailureOf(SettingsWriteFailure.offline),
      SettingFormFailure.offline,
    );
    expect(
      settingFormFailureOf(SettingsWriteFailure.notFound),
      SettingFormFailure.gone,
    );
  });
}
