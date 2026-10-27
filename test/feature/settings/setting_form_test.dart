import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/repository/settings_repository.dart';
import 'package:shared_ledger/feature/settings/setting_form.dart';

void main() {
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
