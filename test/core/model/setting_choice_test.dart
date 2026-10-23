import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/payment_method.dart';

void main() {
  const living = Category(id: 'c-living', name: '소비');
  const gift = Category(id: 'c-gift', name: '경조사', hidden: true);
  const account = PaymentMethod(
    id: 'p-account',
    name: '공동 통장',
    kind: PaymentKind.account,
  );
  const oldCard = PaymentMethod(
    id: 'p-old',
    name: '예전 카드',
    kind: PaymentKind.card,
    hidden: true,
  );

  test('숨긴 분류는 고르기 목록에서 빠진다', () {
    expect(choosableCategories(const [living, gift]), [living]);
  });

  test('고치는 항목이 처음부터 쓰던 숨긴 분류는 남긴다', () {
    expect(choosableCategories(const [living, gift], keep: {'c-gift', null}), [
      living,
      gift,
    ]);
  });

  test('숨긴 결제수단은 빠지고, 고치는 항목이 쓰던 것은 남긴다', () {
    expect(choosablePaymentMethods(const [account, oldCard]), [account]);
    expect(choosablePaymentMethods(const [account, oldCard], keep: {'p-old'}), [
      account,
      oldCard,
    ]);
  });

  test('분류·결제수단은 값이 같으면 같고, 숨김이 다르면 다르다', () {
    final name = ['소', '비'].join();
    expect(Category(id: 'c-living', name: name), living);
    expect(Category(id: 'c-living', name: name, hidden: true), isNot(living));
    expect(
      PaymentMethod(
        id: 'p-account',
        name: '공동 $name',
        kind: PaymentKind.account,
      ),
      isNot(account),
    );
    expect(
      PaymentMethod(
        id: 'p-old',
        name: ['예전', '카드'].join(' '),
        kind: PaymentKind.card,
        hidden: true,
      ),
      oldCard,
    );
  });
}
