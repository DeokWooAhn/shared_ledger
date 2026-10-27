import 'name_problem.dart';

/// 분류 이름 길이 제한. `firestore.rules`의 validCategory와 같다.
const categoryNameMaxLength = 20;

/// 지출 분류 (예: 대출원금, 대출이자, 저축/투자, 소비).
///
/// 가계부마다 직접 정한다. [countsAsSaving]이 켜진 분류의 기본 지출은
/// 월 요약의 '저축'에 합산된다.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.countsAsSaving = false,
    this.hidden = false,
  });

  final String id;
  final String name;

  /// 이 분류의 지출을 저축으로 볼지. 시트에서는 '저축/투자'와 '대출원금'이 해당한다.
  final bool countsAsSaving;

  /// 숨긴 분류. 새 항목·고정 지출에서 고를 수 없지만, 지난 항목과 합계에는 그대로 쓰인다.
  /// 지난 항목이 가리키고 있어서 분류는 지우지 않고 숨긴다.
  final bool hidden;

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.name == name &&
      other.countsAsSaving == countsAsSaving &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(id, name, countsAsSaving, hidden);
}

/// 새로 고를 수 있는 분류. 숨긴 분류는 빼되, [keep]에 있는 id(고치는 항목이 처음부터 쓰던 분류)는 남긴다.
List<Category> choosableCategories(
  List<Category> categories, {
  Set<String?> keep = const {},
}) => [
  for (final category in categories)
    if (!category.hidden || keep.contains(category.id)) category,
];

/// 분류 이름 [name]을 검사한다. 문제가 없으면 null.
///
/// [categories](숨긴 것 포함)에서 고치는 분류 [editing] 말고 다른 분류와 이름이 겹치면 안 된다.
NameProblem? categoryNameProblemOf(
  String name,
  List<Category> categories, {
  Category? editing,
}) => nameProblemOf(
  name,
  maxLength: categoryNameMaxLength,
  taken: [
    for (final other in categories)
      if (other.id != editing?.id) other.name,
  ],
);
