// 이름(가계부·이름표·분류·결제수단)을 쓰기 전에 하는 검사.

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
