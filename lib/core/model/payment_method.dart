/// 결제수단 종류. 계산에서는 카드인지 아닌지만 구분한다.
enum PaymentKind {
  /// 계좌이체·현금
  account,

  /// 자동이체
  autoTransfer,

  /// 카드. 이번 달 현금 유출에 넣지 않고, 다음 달 카드대금으로 빠져나간다.
  card,
}

/// 가구가 쓰는 결제수단. 카드는 카드마다 하나씩 만든다.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.kind,
  });

  final String id;
  final String name;
  final PaymentKind kind;
}
