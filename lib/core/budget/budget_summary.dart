/// 한 달 요약 숫자. 기존 구글 시트의 상단 요약, 카드 소계, 기본 월 지출 소계에 해당한다.
class BudgetSummary {
  const BudgetSummary({
    required this.cashIn,
    required this.spending,
    required this.cashOut,
    required this.saving,
    required this.cardUsage,
    required this.cardBillTotal,
    required this.plannedTotal,
    required this.plannedByCategory,
    required this.plannedByMember,
    required this.cardUsageByCard,
  });

  /// 현금 유입: 수입 합계.
  final int cashIn;

  /// 이번 달 지출: 기본 월 지출 전체 + 추가지출 전체 (결제수단 상관없음).
  final int spending;

  /// 현금 유출: 카드가 아니면서 지급된 기본 지출 + 카드가 아닌 추가지출 + 카드대금.
  final int cashOut;

  /// 저축: '저축으로 집계'가 켜진 분류의 기본 지출 합계.
  final int saving;

  /// 이번 달 카드 사용분 (다음 달 청구 예정): 카드로 낸 기본 지출 + 추가지출.
  final int cardUsage;

  /// 저번 달 카드 사용분 (이번 달 출금): 카드대금 합계.
  final int cardBillTotal;

  /// 기본 월 지출 합계.
  final int plannedTotal;

  /// 기본 월 지출 소계 (분류 id → 금액).
  final Map<String, int> plannedByCategory;

  /// 기본 월 지출 소계 (구성원 id → 금액).
  final Map<String, int> plannedByMember;

  /// 이번 달 카드 사용분 (카드 결제수단 id → 금액).
  final Map<String, int> cardUsageByCard;

  /// 남는 현금: 현금 유입 − 현금 유출. 음수일 수 있다.
  int get remainingCash => cashIn - cashOut;
}
