import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/budget/month_summary.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/member.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/payment_method.dart';

const principal = Category(
  id: 'c-principal',
  name: '대출원금',
  countsAsSaving: true,
);
const living = Category(id: 'c-living', name: '소비');
const account = PaymentMethod(
  id: 'p-account',
  name: '공동 통장',
  kind: PaymentKind.account,
);
const sharedCard = PaymentMethod(
  id: 'p-shared-card',
  name: '공용 카드',
  kind: PaymentKind.card,
);
const skyCard = PaymentMethod(
  id: 'p-sky-card',
  name: '하늘 카드',
  kind: PaymentKind.card,
);

PlannedExpense planned(
  String id, {
  String categoryId = 'c-living',
  String memberId = 'owner',
  String paymentMethodId = 'p-account',
  int? amount,
}) => PlannedExpense(
  id: id,
  categoryId: categoryId,
  memberId: memberId,
  title: '항목 $id',
  paymentMethodId: paymentMethodId,
  amount: amount,
);

ExtraExpense extra(String id, String paymentMethodId, int amount) =>
    ExtraExpense(
      id: id,
      memberId: 'owner',
      title: '추가 $id',
      paymentMethodId: paymentMethodId,
      amount: amount,
    );

MonthSummary summarize(
  MonthLedger ledger, {
  List<Category> categories = const [principal, living],
  List<PaymentMethod> paymentMethods = const [account, sharedCard, skyCard],
}) => MonthSummary.of(
  ledger,
  categories: categories,
  paymentMethods: paymentMethods,
);

void main() {
  test('분류별 소계는 설정 순서대로 모두 넣고, 지출이 없는 분류는 0원이다', () {
    final summary = summarize(
      MonthLedger(plannedExpenses: [planned('t1', amount: 279000)]),
    );

    expect(summary.categories, [
      (category: principal, amount: 0),
      (category: living, amount: 279000),
    ]);
  });

  test('지워진 분류에 남은 지출은 맨 뒤에 하나로 모은다', () {
    final summary = summarize(
      MonthLedger(
        plannedExpenses: [
          planned('t1', categoryId: 'c-gone', amount: 1000),
          planned('t2', categoryId: 'c-gone-too', amount: 2000),
          planned('t3', amount: 500),
        ],
      ),
    );

    expect(summary.categories.last, (category: null, amount: 3000));
    expect(summary.categories, hasLength(3));
    expect(summary.totals.plannedTotal, 3500);
  });

  test('숨긴 분류는 그달에 쓴 기본 지출이 있을 때만 소계에 넣는다', () {
    const hiddenPrincipal = Category(
      id: 'c-principal',
      name: '대출원금',
      countsAsSaving: true,
      hidden: true,
    );
    final unused = summarize(
      MonthLedger(plannedExpenses: [planned('t1', amount: 1000)]),
      categories: const [hiddenPrincipal, living],
    );
    expect(unused.categories, [(category: living, amount: 1000)]);

    // 금액 미정(0원)이어도 쓴 항목이 있으면 보이고, 숨겨도 저축 집계는 그대로다.
    final used = summarize(
      MonthLedger(
        plannedExpenses: [
          planned('t1', categoryId: 'c-principal'),
          planned('t2', categoryId: 'c-principal', amount: 500000),
        ],
      ),
      categories: const [hiddenPrincipal, living],
    );
    expect(used.categories, [
      (category: hiddenPrincipal, amount: 500000),
      (category: living, amount: 0),
    ]);
    expect(used.totals.saving, 500000);
  });

  test('숨긴 카드로 쓴 돈도 카드 사용분으로 계산한다 (지난 달 숫자가 바뀌지 않는다)', () {
    const hiddenCard = PaymentMethod(
      id: 'p-sky-card',
      name: '하늘 카드',
      kind: PaymentKind.card,
      hidden: true,
    );
    final summary = summarize(
      MonthLedger(extraExpenses: [extra('e1', 'p-sky-card', 30000)]),
      paymentMethods: const [account, hiddenCard],
    );

    expect(summary.cards, [(card: hiddenCard, amount: 30000)]);
    expect(summary.totals.cardUsage, 30000);
    expect(summary.totals.cashOut, 0);
    expect(summary.showsCards, isTrue);
  });

  test('카드별 소계는 이번 달에 쓴 카드만 결제수단 순서대로 넣는다', () {
    final summary = summarize(
      MonthLedger(
        plannedExpenses: [
          planned('t1', paymentMethodId: 'p-sky-card', amount: 99000),
        ],
        extraExpenses: [
          extra('e1', 'p-shared-card', 284000),
          extra('e2', 'p-account', 50000),
        ],
      ),
    );

    expect(summary.cards, [
      (card: sharedCard, amount: 284000),
      (card: skyCard, amount: 99000),
    ]);
    expect(summary.totals.cardUsage, 383000);
  });

  test('카드 결제수단도 카드대금도 없으면 카드 영역을 숨긴다', () {
    expect(
      summarize(
        const MonthLedger(),
        paymentMethods: const [account],
      ).showsCards,
      isFalse,
    );
    expect(summarize(const MonthLedger()).showsCards, isTrue);
    final withBill = summarize(
      const MonthLedger(
        cardBills: [
          CardBill(id: 'b1', memberId: 'owner', cardId: 'gone', amount: 1),
        ],
      ),
      paymentMethods: const [account],
    );
    expect(withBill.showsCards, isTrue);
    expect(withBill.cardBillCount, 1);
  });

  test('숨긴 카드만 있고 그달에 카드로 쓴 돈도 카드대금도 없으면 카드 영역을 숨긴다', () {
    const hiddenCard = PaymentMethod(
      id: 'p-sky-card',
      name: '하늘 카드',
      kind: PaymentKind.card,
      hidden: true,
    );
    expect(
      summarize(
        const MonthLedger(),
        paymentMethods: const [account, hiddenCard],
      ).showsCards,
      isFalse,
    );
  });

  test('금액 미정 기본 지출은 건수를 세고 합계에서는 0원이다', () {
    final summary = summarize(
      MonthLedger(
        plannedExpenses: [
          planned('t1'),
          planned('t2', amount: 0),
          planned('t3', amount: 1000),
          planned('t4'),
        ],
      ),
    );

    expect(summary.unpricedPlannedCount, 2);
    expect(summary.totals.plannedTotal, 1000);
  });

  test('두 사람의 기본 월 지출 소계를 이름표 자리로 꺼낸다', () {
    final summary = summarize(
      MonthLedger(
        plannedExpenses: [
          planned('t1', amount: 1701000),
          planned('t2', memberId: 'partner', amount: 598000),
        ],
      ),
    );

    expect(summary.plannedOf(MemberSlot.owner), 1701000);
    expect(summary.plannedOf(MemberSlot.partner), 598000);
  });

  test('항목이 하나도 없는 달만 빈 달이다', () {
    expect(summarize(const MonthLedger()).isEmpty, isTrue);
    expect(
      summarize(
        const MonthLedger(
          incomes: [
            Income(id: 'i1', memberId: 'owner', title: '월급', amount: 0),
          ],
        ),
      ).isEmpty,
      isFalse,
    );
  });
}
