import '../../domain/repository/settings_repository.dart';

// 설정을 고치는 시트(이름 바꾸기·분류·결제수단)의 Notifier가 같이 쓰는 실패와 진행 상태.
// 이름 검사(NameProblem)는 domain의 name_problem.dart에 있다.

/// 스낵바로 알릴 일회성 실패.
enum SettingFormFailure {
  /// 설정은 온라인에서만 바꾼다.
  offline,

  /// 그사이 고칠 것이 없어졌다.
  gone,
  save,
}

/// 저장소의 실패를 화면용 실패로 바꾼다.
SettingFormFailure settingFormFailureOf(SettingsWriteFailure reason) =>
    switch (reason) {
      SettingsWriteFailure.offline => SettingFormFailure.offline,
      SettingsWriteFailure.notFound => SettingFormFailure.gone,
    };

/// 분류·결제수단 시트에서 진행 중인 동작.
enum SettingFormAction { save, hide, show }

/// 분류·결제수단 시트가 닫히며 알려 줄 결과. 숨기거나 다시 보이게 했으면 목록이 스낵바로 알린다.
enum SettingFormOutcome { saved, hidden, shown }
