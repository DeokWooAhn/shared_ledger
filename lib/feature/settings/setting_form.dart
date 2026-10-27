import '../../domain/repository/settings_repository.dart';

// 설정을 고치는 시트(이름 바꾸기·분류·결제수단)의 Notifier가 같이 쓰는 문제·실패와 검사.

/// 이름 칸 아래에 보여 줄 문제.
enum NameProblem {
  missing,
  tooLong,

  /// 같은 목록에 같은 이름이 있다(숨긴 것 포함).
  taken,
}

/// [name]을 검사한다. 문제가 없으면 null.
///
/// 앞뒤 공백을 뺀 이름으로 본다. 길이는 보안 규칙처럼 UTF-16 단위로 센다(`entryTitleMaxLength`와 같다).
/// [taken]은 같은 목록의 다른 이름들이다.
NameProblem? nameProblemOf(
  String name, {
  required int maxLength,
  Iterable<String> taken = const [],
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return NameProblem.missing;
  if (trimmed.length > maxLength) return NameProblem.tooLong;
  if (taken.any((other) => other.trim() == trimmed)) return NameProblem.taken;
  return null;
}

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
