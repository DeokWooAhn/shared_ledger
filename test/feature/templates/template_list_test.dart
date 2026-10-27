import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/expense_template.dart';
import 'package:shared_ledger/feature/templates/template_list.dart';

ExpenseTemplate template(
  String id, {
  required String categoryId,
  int dueDay = 25,
  int? amount = 1000,
  String title = '고정 지출',
}) => ExpenseTemplate(
  id: id,
  title: title,
  amount: amount,
  categoryId: categoryId,
  paymentMethodId: 'p-account',
  memberId: 'owner',
  dueDay: dueDay,
);

void main() {
  const categories = [
    Category(id: 'c-principal', name: '대출원금', countsAsSaving: true),
    Category(id: 'c-spending', name: '소비'),
    Category(id: 'c-empty', name: '저축/투자', countsAsSaving: true),
  ];

  test('설정의 분류 순서로 묶고, 고정 지출이 없는 분류는 빼고, 지워진 분류는 맨 뒤에 모은다', () {
    final list = TemplateList.of([
      template('a', categoryId: 'c-spending'),
      template('b', categoryId: 'c-gone'),
      template('c', categoryId: 'c-principal'),
    ], categories: categories);

    expect(list.groups.map((g) => g.key), [
      'c-principal',
      'c-spending',
      'none',
    ]);
    expect(list.groups.map((g) => g.title), ['대출원금', '소비', '분류 없음']);
  });

  test('묶음 안에서는 예정일이 이른 것부터, 말일은 맨 뒤, 같은 날이면 제목 순서다', () {
    final list = TemplateList.of([
      template('rent', categoryId: 'c-spending', dueDay: lastDueDay),
      template('phone', categoryId: 'c-spending', dueDay: 21, title: '통신비'),
      template('stream', categoryId: 'c-spending', dueDay: 5),
      template('insurance', categoryId: 'c-spending', dueDay: 21, title: '보험'),
    ], categories: categories);

    expect(list.groups.single.templates.map((t) => t.id), [
      'stream',
      'insurance',
      'phone',
      'rent',
    ]);
  });

  test('합계는 금액 미정을 0원으로 치고, 개수와 금액 미정 개수를 센다', () {
    final list = TemplateList.of([
      template('a', categoryId: 'c-spending', amount: 800000),
      template('b', categoryId: 'c-spending', amount: null),
      template('c', categoryId: 'c-principal', amount: 0),
    ], categories: categories);

    expect(list.total, 800000);
    expect(list.count, 3);
    expect(list.unpricedCount, 1);
    expect(list.isEmpty, isFalse);
    expect(TemplateList.of(const [], categories: categories).isEmpty, isTrue);
  });

  test('예정일 글자는 날짜에 일을 붙이고, 31은 말일이다', () {
    expect(dueDayLabel(1), '1일');
    expect(dueDayLabel(30), '30일');
    expect(dueDayLabel(lastDueDay), '말일');
  });
}
