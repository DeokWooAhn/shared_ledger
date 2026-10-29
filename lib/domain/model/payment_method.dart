import 'name_problem.dart';

/// 결제수단 이름 길이 제한. `firestore.rules`의 validPaymentMethod와 같다.
const paymentMethodNameMaxLength = 20;

/// 결제수단 종류. 계산에서는 카드인지 아닌지만 구분한다.
///
/// 만든 뒤에는 바꿀 수 없다(규칙의 keepsKind). 카드인지에 따라 지난 달 계산이 달라진다.
enum PaymentKind {
  /// 계좌이체·현금
  account,

  /// 자동이체
  autoTransfer,

  /// 카드. 이번 달 현금 유출에 넣지 않고, 다음 달 카드 대금으로 빠져나간다.
  card,
}

/// 가계부에서 쓰는 결제수단. 카드는 카드마다 하나씩 만든다.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.kind,
    this.hidden = false,
  });

  final String id;
  final String name;
  final PaymentKind kind;

  /// 숨긴 결제수단. 새 항목·고정 지출에서 고를 수 없지만, 지난 항목과 합계에는 그대로 쓰인다.
  /// 지우면 그 카드로 쓴 돈이 현금 유출로 바뀌어서 지우지 않고 숨긴다.
  final bool hidden;

  @override
  bool operator ==(Object other) =>
      other is PaymentMethod &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(id, name, kind, hidden);
}

/// 새로 고를 수 있는 결제수단. 숨긴 결제수단은 빼되, [keep]에 있는 id(고치는 항목이 처음부터 쓰던 것)는 남긴다.
List<PaymentMethod> choosablePaymentMethods(
  List<PaymentMethod> methods, {
  Set<String?> keep = const {},
}) => [
  for (final method in methods)
    if (!method.hidden || keep.contains(method.id)) method,
];

/// 결제수단 이름 [name]을 검사한다. 문제가 없으면 null.
///
/// [methods](숨긴 것 포함)에서 고치는 결제수단 [editing] 말고 다른 결제수단과 이름이 겹치면 안 된다.
NameProblem? paymentMethodNameProblemOf(
  String name,
  List<PaymentMethod> methods, {
  PaymentMethod? editing,
}) => nameProblemOf(
  name,
  maxLength: paymentMethodNameMaxLength,
  taken: [
    for (final other in methods)
      if (other.id != editing?.id) other.name,
  ],
);
