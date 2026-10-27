// 기존 구글 시트와 같은 구성(항목 수, 분류, 결제수단, 지급 여부)으로 만든 10월·11월 예시 데이터.
// 금액은 모두 가상이다. 실제 가계부 금액은 이 공개 저장소에 넣지 않는다.
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/ledger_entries.dart';
import 'package:shared_ledger/domain/model/month_ledger.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';

const memberA = 'member-a';
const memberB = 'member-b';
const shared = 'member-shared';

const loanPrincipal = 'loan-principal';
const loanInterest = 'loan-interest';
const savingInvest = 'saving-invest';
const living = 'living';

const sheetCategories = [
  Category(id: loanPrincipal, name: '대출원금', countsAsSaving: true),
  Category(id: loanInterest, name: '대출이자'),
  Category(id: savingInvest, name: '저축/투자', countsAsSaving: true),
  Category(id: living, name: '소비'),
];

const account = 'account';
const autoTransfer = 'auto-transfer';
const card = 'card';
const card1 = 'card-1';
const card2 = 'card-2';
const card3 = 'card-3';

const sheetPaymentMethods = [
  PaymentMethod(id: account, name: '계좌/현금', kind: PaymentKind.account),
  PaymentMethod(id: autoTransfer, name: '자동이체', kind: PaymentKind.autoTransfer),
  // 시트는 지출의 결제수단을 '카드' 하나로만 적는다.
  PaymentMethod(id: card, name: '카드', kind: PaymentKind.card),
  PaymentMethod(id: card1, name: '카드1', kind: PaymentKind.card),
  PaymentMethod(id: card2, name: '카드2', kind: PaymentKind.card),
  PaymentMethod(id: card3, name: '카드3', kind: PaymentKind.card),
];

var _seq = 0;
String _id() => 'e${_seq++}';

DateTime _d(int month, int day) => DateTime(2026, month, day);

PlannedExpense _planned(
  String categoryId,
  String memberId,
  String title,
  String paymentMethodId,
  int? amount, {
  DateTime? paidOn,
}) => PlannedExpense(
  id: _id(),
  categoryId: categoryId,
  memberId: memberId,
  title: title,
  paymentMethodId: paymentMethodId,
  amount: amount,
  paidOn: paidOn,
);

ExtraExpense _extra(
  String memberId,
  String title,
  String paymentMethodId,
  int amount, {
  DateTime? spentOn,
}) => ExtraExpense(
  id: _id(),
  memberId: memberId,
  title: title,
  paymentMethodId: paymentMethodId,
  amount: amount,
  spentOn: spentOn,
);

Income _income(String memberId, String title, int amount, DateTime on) =>
    Income(
      id: _id(),
      memberId: memberId,
      title: title,
      amount: amount,
      receivedOn: on,
    );

// 10월: A의 실비보험(10/25 예정)만 아직 빠져나가지 않았다(지급일 없음).
final october2026 = MonthLedger(
  incomes: [
    _income(memberA, '월급', 3200000, _d(9, 25)),
    _income(memberB, '월급', 2450000, _d(9, 21)),
    _income(memberB, '피복비', 300000, _d(9, 25)),
    _income(memberB, '명절비', 150000, _d(9, 15)),
    _income(shared, '상품권 현금화', 200000, _d(9, 21)),
    _income(shared, '사은품', 50000, _d(9, 27)),
  ],
  plannedExpenses: [
    _planned(
      loanPrincipal,
      memberA,
      '대출1 원금',
      account,
      250000,
      paidOn: _d(10, 14),
    ),
    _planned(
      loanInterest,
      memberA,
      '대출1 이자',
      account,
      480000,
      paidOn: _d(10, 14),
    ),
    _planned(
      loanPrincipal,
      memberA,
      '대출2 원금',
      account,
      300000,
      paidOn: _d(10, 1),
    ),
    _planned(
      loanPrincipal,
      memberB,
      '대출3 원금',
      account,
      400000,
      paidOn: _d(10, 10),
    ),
    _planned(
      loanInterest,
      memberB,
      '대출3 이자',
      account,
      60000,
      paidOn: _d(10, 10),
    ),
    _planned(savingInvest, shared, '적금', account, 200000, paidOn: _d(10, 1)),
    _planned(living, shared, '관리비', card, null),
    _planned(living, shared, '인터넷', card, 33000),
    _planned(living, shared, '정수기', card, 25900),
    _planned(living, memberA, '통신비', card, 55000),
    _planned(living, memberB, '통신비', card, 49500),
    _planned(living, memberA, '종합보험', account, 98000, paidOn: _d(10, 5)),
    _planned(living, memberA, '실비보험', account, 31200),
    _planned(living, memberB, '종합보험', card, 72000),
    _planned(living, memberB, '실비보험', account, 28800, paidOn: _d(10, 1)),
    _planned(living, memberB, '구독 서비스', card, 14900),
    _planned(living, shared, '멤버십', card, 7900),
    _planned(living, shared, '차량 서비스', card, 9900),
    _planned(living, shared, '생활비', account, 400000, paidOn: _d(10, 1)),
    _planned(living, shared, '기름값', card, 120000, paidOn: _d(10, 1)),
    _planned(living, shared, '가족 모임', account, 50000, paidOn: _d(10, 1)),
    _planned(living, memberA, '용돈', account, 300000, paidOn: _d(10, 1)),
    _planned(living, memberB, '용돈', account, 300000, paidOn: _d(10, 1)),
    _planned(living, memberA, '교통비', card, 80000),
    _planned(living, memberB, '교통비', account, 70000, paidOn: _d(10, 1)),
  ],
  extraExpenses: [
    _extra(memberB, '축의금', account, 100000),
    _extra(memberB, '축의금', account, 50000),
    _extra(memberA, '축의금', account, 100000),
    _extra(memberA, '축의금', account, 50000),
    _extra(memberA, '자동차 검사', account, 45000),
    _extra(memberA, '조카 용돈', account, 30000),
    _extra(memberA, '명절 선물', account, 120000),
    _extra(memberA, '미용실', account, 25000),
    _extra(memberB, '자동차 보험', card, 12500, spentOn: _d(10, 5)),
    _extra(shared, '채소', card, 8700, spentOn: _d(10, 12)),
    _extra(memberB, '온라인 장보기', card, 43200, spentOn: _d(10, 12)),
    _extra(shared, '생활용품', card, 6000, spentOn: _d(10, 13)),
  ],
  cardBills: [
    CardBill(
      id: _id(),
      memberId: memberA,
      cardId: card1,
      amount: 650000,
      paidOn: _d(10, 14),
    ),
    CardBill(
      id: _id(),
      memberId: memberB,
      cardId: card2,
      amount: 420000,
      paidOn: _d(10, 14),
    ),
    CardBill(
      id: _id(),
      memberId: memberB,
      cardId: card3,
      amount: 280000,
      paidOn: _d(10, 13),
    ),
  ],
);

// 11월: B의 월급과 카드대금은 아직 비어 있다(0원이라 생략). 대출1·기름값·가족 모임 금액과
// 적금 결제수단(자동이체)이 10월과 다르다.
final november2026 = MonthLedger(
  incomes: [_income(memberA, '월급', 3200000, _d(10, 23))],
  plannedExpenses: [
    _planned(
      loanPrincipal,
      memberA,
      '대출1 원금',
      account,
      260000,
      paidOn: _d(11, 14),
    ),
    _planned(
      loanInterest,
      memberA,
      '대출1 이자',
      account,
      470000,
      paidOn: _d(11, 14),
    ),
    _planned(
      loanPrincipal,
      memberA,
      '대출2 원금',
      account,
      300000,
      paidOn: _d(11, 1),
    ),
    _planned(
      loanPrincipal,
      memberB,
      '대출3 원금',
      account,
      400000,
      paidOn: _d(11, 10),
    ),
    _planned(
      loanInterest,
      memberB,
      '대출3 이자',
      account,
      60000,
      paidOn: _d(11, 10),
    ),
    _planned(
      savingInvest,
      shared,
      '적금',
      autoTransfer,
      200000,
      paidOn: _d(11, 1),
    ),
    _planned(living, shared, '관리비', card, null),
    _planned(living, shared, '인터넷', card, 33000),
    _planned(living, shared, '정수기', card, 25900),
    _planned(living, memberA, '통신비', card, 55000),
    _planned(living, memberB, '통신비', card, 49500),
    _planned(living, memberA, '종합보험', account, 98000, paidOn: _d(11, 5)),
    _planned(living, memberA, '실비보험', account, 31200, paidOn: _d(11, 25)),
    _planned(living, memberB, '종합보험', card, 72000),
    _planned(living, memberB, '실비보험', account, 28800, paidOn: _d(11, 1)),
    _planned(living, memberB, '구독 서비스', card, 14900),
    _planned(living, shared, '멤버십', card, 7900),
    _planned(living, shared, '차량 서비스', card, 9900),
    _planned(living, shared, '생활비', account, 400000, paidOn: _d(11, 1)),
    _planned(living, shared, '기름값', card, 150000, paidOn: _d(11, 1)),
    _planned(living, shared, '가족 모임', account, 80000, paidOn: _d(11, 1)),
    _planned(living, memberA, '용돈', account, 300000, paidOn: _d(11, 1)),
    _planned(living, memberB, '용돈', account, 300000, paidOn: _d(11, 1)),
    _planned(living, memberA, '교통비', card, 80000),
    _planned(living, memberB, '교통비', account, 70000, paidOn: _d(11, 1)),
  ],
);
