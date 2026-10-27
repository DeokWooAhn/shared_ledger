import '../../domain/model/category.dart';
import '../../domain/model/expense_template.dart';

/// 예정일 글자. 예: '25일', '말일'
String dueDayLabel(int dueDay) => dueDay == lastDueDay ? '말일' : '$dueDay일';

/// 고정 지출 탭의 한 묶음(분류 하나).
class TemplateGroup {
  const TemplateGroup({
    required this.key,
    required this.title,
    required this.templates,
  });

  /// 목록에서 묶음을 구분하는 값. 분류 id이거나, 지워진 분류는 `none`.
  final String key;

  /// 분류 이름. 지워진 분류는 '분류 없음'.
  final String title;
  final List<ExpenseTemplate> templates;
}

/// 고정 지출 탭에 그릴 목록. 매달 나가는 돈 합계와 개수, 금액 미정 개수를 담는다.
class TemplateList {
  const TemplateList({
    required this.groups,
    required this.count,
    required this.total,
    required this.unpricedCount,
  });

  /// 설정의 분류 순서로 묶고, 설정에서 지워진 분류의 고정 지출은 맨 뒤 '분류 없음'에 모은다.
  /// 묶음 안에서는 예정일이 이른 것부터(말일은 맨 뒤), 같으면 제목 순서다.
  factory TemplateList.of(
    List<ExpenseTemplate> templates, {
    required List<Category> categories,
  }) {
    final known = {for (final category in categories) category.id};
    final orphans = templates.where((t) => !known.contains(t.categoryId));
    return TemplateList(
      groups: [
        for (final category in categories)
          if (templates.where((t) => t.categoryId == category.id).toList()
              case final inCategory when inCategory.isNotEmpty)
            TemplateGroup(
              key: category.id,
              title: category.name,
              templates: inCategory..sort(_byDueDay),
            ),
        if (orphans.isNotEmpty)
          TemplateGroup(
            key: 'none',
            title: '분류 없음',
            templates: orphans.toList()..sort(_byDueDay),
          ),
      ],
      count: templates.length,
      total: templates.fold(0, (sum, t) => sum + (t.amount ?? 0)),
      unpricedCount: templates.where((t) => t.amount == null).length,
    );
  }

  final List<TemplateGroup> groups;
  final int count;

  /// 매달 나가는 돈(원). 금액 미정은 0원으로 친다.
  final int total;

  /// 금액 미정 개수.
  final int unpricedCount;

  bool get isEmpty => count == 0;
}

int _byDueDay(ExpenseTemplate a, ExpenseTemplate b) {
  final byDay = a.dueDay.compareTo(b.dueDay);
  if (byDay != 0) return byDay;
  final byTitle = a.title.compareTo(b.title);
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}
