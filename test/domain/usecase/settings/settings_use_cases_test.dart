import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/member.dart';
import 'package:shared_ledger/domain/model/name_problem.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/domain/repository/settings_repository.dart';
import 'package:shared_ledger/domain/usecase/settings/settings_use_cases.dart';

import '../../../../testing/fakes.dart';

const principal = Category(
  id: 'c-principal',
  name: '대출원금',
  countsAsSaving: true,
);
const spending = Category(id: 'c-spending', name: '소비');
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
const members = [
  Member(slot: MemberSlot.owner, name: '하늘'),
  Member(slot: MemberSlot.partner, name: '바다'),
];

void main() {
  test('이름표·분류·결제수단을 그 가계부 것으로 지켜본다', () async {
    final settings = FakeSettingsRepository(
      categories: const [principal, spending],
      paymentMethods: const [account],
    );
    final useCases = SettingsUseCases(settings);

    expect(await useCases.watchMembers('l1').first, members);
    expect(await useCases.watchCategories('l1').first, [principal, spending]);
    expect(await useCases.watchPaymentMethods('l1').first, [account]);
    expect(settings.watched, ['l1', 'l1', 'l1']);
  });

  group('이름표 이름 바꾸기', () {
    test('바꾸면 그 자리 이름표에 쓴다', () async {
      final settings = FakeSettingsRepository();

      final problem = await SettingsUseCases(settings).renameMember(
        ledgerId: 'l1',
        slot: MemberSlot.partner,
        name: ' 구름 ',
        members: members,
        uid: 'me',
      );

      expect(problem, isNull);
      expect(settings.renamedMembers, [
        (ledgerId: 'l1', slot: MemberSlot.partner, name: ' 구름 ', uid: 'me'),
      ]);
    });

    test('10자를 넘거나 지금 이름과 같으면 쓰지 않는다', () async {
      final settings = FakeSettingsRepository();
      final useCases = SettingsUseCases(settings);
      Future<NameProblem?> rename(String name) => useCases.renameMember(
        ledgerId: 'l1',
        slot: MemberSlot.owner,
        name: name,
        members: members,
        uid: 'me',
      );

      expect(await rename('가' * 11), NameProblem.tooLong);
      expect(await rename(' 하늘 '), isNull);
      expect(settings.renamedMembers, isEmpty);
    });

    test('이름표가 없던 가계부는 이름이 같아 보여도 이름표를 새로 만든다', () async {
      final settings = FakeSettingsRepository(members: const []);

      await SettingsUseCases(settings).renameMember(
        ledgerId: 'l1',
        slot: MemberSlot.partner,
        name: defaultPartnerName,
        members: const [],
        uid: 'me',
      );

      expect(settings.renamedMembers.single.name, defaultPartnerName);
    });
  });

  group('분류 저장', () {
    const categories = [principal, spending, gift];

    test('새 분류는 이름의 앞뒤 공백을 빼고 맨 뒤에 붙인다', () async {
      final settings = FakeSettingsRepository();

      final problem = await SettingsUseCases(settings).saveCategory(
        ledgerId: 'l1',
        name: ' 여행 ',
        countsAsSaving: true,
        categories: categories,
        uid: 'me',
      );

      expect(problem, isNull);
      expect(settings.addedCategories, [
        (
          ledgerId: 'l1',
          draft: (name: '여행', countsAsSaving: true),
          order: 3,
          uid: 'me',
        ),
      ]);
    });

    test('숨긴 분류를 포함해 다른 분류와 이름이 같으면 쓰지 않는다', () async {
      final settings = FakeSettingsRepository();

      final problem = await SettingsUseCases(settings).saveCategory(
        ledgerId: 'l1',
        name: '경조사',
        countsAsSaving: false,
        categories: categories,
        uid: 'me',
      );

      expect(problem, NameProblem.taken);
      expect(settings.addedCategories, isEmpty);
    });

    test('고치는 분류는 제 이름과 겹쳐도 되고, 바뀐 것만 쓴다', () async {
      final settings = FakeSettingsRepository();
      final useCases = SettingsUseCases(settings);

      await useCases.saveCategory(
        ledgerId: 'l1',
        editing: principal,
        name: '대출원금',
        countsAsSaving: false,
        categories: categories,
        uid: 'me',
      );

      expect(settings.updatedCategories, [
        (
          ledgerId: 'l1',
          id: 'c-principal',
          draft: (name: '대출원금', countsAsSaving: false),
          uid: 'me',
        ),
      ]);
    });

    test('바꾼 것이 없으면 쓰지 않는다', () async {
      final settings = FakeSettingsRepository();

      final problem = await SettingsUseCases(settings).saveCategory(
        ledgerId: 'l1',
        editing: spending,
        name: ' 소비 ',
        countsAsSaving: false,
        categories: categories,
        uid: 'me',
      );

      expect(problem, isNull);
      expect(settings.updatedCategories, isEmpty);
    });

    test('숨기거나 다시 보이게 한다', () async {
      final settings = FakeSettingsRepository(categories: categories);
      final useCases = SettingsUseCases(settings);

      await useCases.setCategoryHidden(
        ledgerId: 'l1',
        id: 'c-spending',
        hidden: true,
        uid: 'me',
      );
      await useCases.setCategoryHidden(
        ledgerId: 'l1',
        id: 'c-gift',
        hidden: false,
        uid: 'me',
      );

      expect(settings.hiddenChanges, [
        (collection: 'categories', id: 'c-spending', hidden: true, uid: 'me'),
        (collection: 'categories', id: 'c-gift', hidden: false, uid: 'me'),
      ]);
    });

    test('연결이 없으면 저장소의 실패를 그대로 던진다', () async {
      final useCases = SettingsUseCases(
        FakeSettingsRepository()..offline = true,
      );

      await expectLater(
        useCases.saveCategory(
          ledgerId: 'l1',
          name: '여행',
          countsAsSaving: false,
          categories: categories,
          uid: 'me',
        ),
        throwsA(isA<SettingsWriteException>()),
      );
    });
  });

  group('결제수단 저장', () {
    const methods = [account, oldCard];

    test('새 결제수단은 고른 종류로 맨 뒤에 붙인다', () async {
      final settings = FakeSettingsRepository();

      final problem = await SettingsUseCases(settings).savePaymentMethod(
        ledgerId: 'l1',
        name: ' 하늘 카드 ',
        kind: PaymentKind.card,
        methods: methods,
        uid: 'me',
      );

      expect(problem, isNull);
      expect(settings.addedPaymentMethods, [
        (
          ledgerId: 'l1',
          draft: (name: '하늘 카드', kind: PaymentKind.card),
          order: 2,
          uid: 'me',
        ),
      ]);
    });

    test('숨긴 결제수단과 이름이 같거나 20자를 넘으면 쓰지 않는다', () async {
      final settings = FakeSettingsRepository();
      final useCases = SettingsUseCases(settings);
      Future<NameProblem?> save(String name) => useCases.savePaymentMethod(
        ledgerId: 'l1',
        name: name,
        kind: PaymentKind.card,
        methods: methods,
        uid: 'me',
      );

      expect(await save('예전 카드'), NameProblem.taken);
      expect(await save('가' * 21), NameProblem.tooLong);
      expect(settings.addedPaymentMethods, isEmpty);
    });

    test('고칠 때는 이름만 바꾸고, 이름이 그대로면 쓰지 않는다', () async {
      final settings = FakeSettingsRepository(paymentMethods: methods);
      final useCases = SettingsUseCases(settings);
      Future<NameProblem?> rename(String name) => useCases.savePaymentMethod(
        ledgerId: 'l1',
        editing: account,
        name: name,
        kind: PaymentKind.card,
        methods: methods,
        uid: 'me',
      );

      await rename(' 공동 통장 ');
      await rename('생활비 통장');

      expect(settings.renamedPaymentMethods, [
        (ledgerId: 'l1', id: 'p-account', name: '생활비 통장', uid: 'me'),
      ]);
      expect(settings.paymentMethods.first.kind, PaymentKind.account);
    });

    test('숨기거나 다시 보이게 한다', () async {
      final settings = FakeSettingsRepository(paymentMethods: methods);

      await SettingsUseCases(settings).setPaymentMethodHidden(
        ledgerId: 'l1',
        id: 'p-old',
        hidden: false,
        uid: 'me',
      );

      expect(settings.hiddenChanges, [
        (collection: 'paymentMethods', id: 'p-old', hidden: false, uid: 'me'),
      ]);
    });
  });
}
