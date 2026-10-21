// 한 달 가계부를 이루는 네 가지 항목. 금액 단위는 원이다.

/// 수입 (실제 입금 기준).
class Income {
  const Income({
    required this.id,
    required this.memberId,
    required this.title,
    required this.amount,
    this.receivedOn,
    this.memo,
  });

  final String id;
  final String memberId;
  final String title;
  final int amount;
  final DateTime? receivedOn;
  final String? memo;
}

/// 기본 월 지출. 고정 지출 템플릿에서 매달 만들어진다.
class PlannedExpense {
  const PlannedExpense({
    required this.id,
    required this.categoryId,
    required this.memberId,
    required this.title,
    required this.paymentMethodId,
    this.amount,
    this.paidOn,
    this.memo,
  });

  final String id;
  final String categoryId;
  final String memberId;
  final String title;
  final String paymentMethodId;

  /// 아직 금액을 모르면(예: 관리비) null이고, 합계에서는 0원으로 친다.
  final int? amount;

  /// 실제로 빠져나간 날. 카드가 아닌 지출은 이 값이 있어야 현금 유출에 들어간다.
  final DateTime? paidOn;
  final String? memo;

  bool get isPaid => paidOn != null;
}

/// 추가지출 (예산 밖 지출). 이미 쓴 돈이라 지급 여부를 따로 따지지 않는다.
class ExtraExpense {
  const ExtraExpense({
    required this.id,
    required this.memberId,
    required this.title,
    required this.paymentMethodId,
    required this.amount,
    this.spentOn,
    this.memo,
  });

  final String id;
  final String memberId;
  final String title;
  final String paymentMethodId;
  final int amount;
  final DateTime? spentOn;
  final String? memo;
}

/// 카드대금 (이번 달 실제로 출금된 카드값 = 저번 달 카드 사용분).
class CardBill {
  const CardBill({
    required this.id,
    required this.memberId,
    required this.cardId,
    required this.amount,
    this.paidOn,
    this.memo,
  });

  final String id;
  final String memberId;

  /// 카드 종류의 [PaymentMethod] id.
  final String cardId;
  final int amount;
  final DateTime? paidOn;
  final String? memo;
}
