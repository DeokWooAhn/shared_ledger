/// 한 달 요약 숫자. 기존 구글 시트의 상단 요약, 카드 소계, 고정 지출 소계에 해당한다.
class BudgetSummary {
  const BudgetSummary({
    required this.cashIn,
    required this.spending,
    required this.cashOut,
    required this.saving,
    required this.paidSaving,
    required this.cardUsage,
    required this.cardBillTotal,
    required this.plannedTotal,
    required this.plannedByCategory,
    required this.plannedByMember,
    required this.cardUsageByCard,
    required this.spendingByPaymentMethod,
  });

  /// 현금 유입: 추가 수입 전체 + 받음 완료인 고정 수입.
  final int cashIn;

  /// 이번 달 지출: 고정 지출 전체 + 추가 지출 전체 (결제수단 상관없음).
  final int spending;

  /// 현금 유출: 카드가 아니면서 지급된 고정 지출 + 카드가 아닌 추가 지출 + 카드 대금.
  final int cashOut;

  /// 저축: '저축으로 집계'가 켜진 분류의 고정 지출 합계.
  final int saving;

  /// 저축 중 실제로 빠져나간 것: 카드로 낸 것(쓴 달에 센다)과 지급 완료한 것. 통계의 '그동안 모은 돈'이 쓴다.
  /// 지급 전 저축은 아직 통장에 있어 [remainingCash]에 들어 있으므로, 둘을 더할 때 두 번 세지 않게 뺀다.
  final int paidSaving;

  /// 이번 달 카드 사용분 (다음 달 청구 예정): 카드로 낸 고정 지출 + 추가 지출.
  final int cardUsage;

  /// 저번 달 카드 사용분 (이번 달 출금): 카드 대금 합계.
  final int cardBillTotal;

  /// 고정 지출 합계.
  final int plannedTotal;

  /// 고정 지출 소계 (분류 id → 금액).
  final Map<String, int> plannedByCategory;

  /// 고정 지출 소계 (구성원 id → 금액).
  final Map<String, int> plannedByMember;

  /// 이번 달 카드 사용분 (카드 결제수단 id → 금액).
  final Map<String, int> cardUsageByCard;

  /// 이번 달 지출의 결제수단별 소계 (결제수단 id → 금액). 고정 지출 + 추가 지출.
  final Map<String, int> spendingByPaymentMethod;

  /// 남는 현금: 현금 유입 − 현금 유출. 음수일 수 있다.
  int get remainingCash => cashIn - cashOut;

  /// 이번 달에 모은 돈: 빠져나간 저축 + 남는 현금. 음수일 수 있다.
  int get saved => paidSaving + remainingCash;
}
