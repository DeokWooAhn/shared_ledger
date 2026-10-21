/// 지출 분류 (예: 대출원금, 대출이자, 저축/투자, 소비).
///
/// 가계부마다 직접 정한다. [countsAsSaving]이 켜진 분류의 기본 지출은
/// 월 요약의 '저축'에 합산된다.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.countsAsSaving = false,
  });

  final String id;
  final String name;

  /// 이 분류의 지출을 저축으로 볼지. 시트에서는 '저축/투자'와 '대출원금'이 해당한다.
  final bool countsAsSaving;
}
