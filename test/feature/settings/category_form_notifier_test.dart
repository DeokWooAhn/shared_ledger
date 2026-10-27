import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/category.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/feature/settings/category_form_notifier.dart';
import 'package:shared_ledger/feature/settings/setting_form.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
const principal = Category(
  id: 'c-principal',
  name: '대출원금',
  countsAsSaving: true,
);
const spending = Category(id: 'c-spending', name: '소비');
const gift = Category(id: 'c-gift', name: '경조사', hidden: true);

/// 로그인하고 가계부와 분류까지 받은 컨테이너.
Future<ProviderContainer> ready(FakeSettingsRepository settings) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([mine]),
    settings: settings,
  );
  await loadSignedInUser(container);
  container
    ..listen(myLedgersProvider, (_, _) {})
    ..listen(categoriesProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  await container.read(categoriesProvider.future);
  return container;
}

FakeSettingsRepository settingsWith() =>
    FakeSettingsRepository(categories: const [principal, spending, gift]);

/// [args] 시트의 Notifier를 살려 두고 지나간 상태를 기록한다.
(CategoryFormNotifier, List<CategoryFormState>) notifierOf(
  ProviderContainer container,
  CategoryFormArgs args,
) {
  final states = recordStates(container, categoryFormNotifierProvider(args));
  return (container.read(categoryFormNotifierProvider(args).notifier), states);
}

void main() {
  test('새 분류는 저축 집계가 꺼진 채로, 고치기는 그 분류의 값으로 시작한다', () async {
    final container = await ready(settingsWith());

    expect(
      container.read(
        categoryFormNotifierProvider(const CategoryFormArgs.add()),
      ),
      const CategoryFormState(countsAsSaving: false),
    );
    expect(
      container.read(
        categoryFormNotifierProvider(const CategoryFormArgs.edit(principal)),
      ),
      const CategoryFormState(countsAsSaving: true),
    );
  });

  group('더하기', () {
    test('이름과 저축 집계로 맨 뒤(지금 개수, 숨긴 것 포함)에 더한다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      final (notifier, states) = notifierOf(
        container,
        const CategoryFormArgs.add(),
      );

      notifier.setCountsAsSaving(true);
      await notifier.save(' 비상금 ');

      expect(settings.addedCategories, [
        (
          ledgerId: 'l1',
          draft: (name: '비상금', countsAsSaving: true),
          order: 3,
          uid: 'me',
        ),
      ]);
      expect(states.last, isA<CategoryFormState>());
      expect(states.last.outcome, SettingFormOutcome.saved);
      expect(states.map((s) => s.pending), contains(SettingFormAction.save));
    });

    test('이름이 비었거나 20자를 넘거나 다른 분류와 같으면 쓰지 않는다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      final (notifier, _) = notifierOf(container, const CategoryFormArgs.add());
      NameProblem? problem() => container
          .read(categoryFormNotifierProvider(const CategoryFormArgs.add()))
          .problem;

      await notifier.save(' ');
      expect(problem(), NameProblem.missing);
      await notifier.save('가' * 21);
      expect(problem(), NameProblem.tooLong);
      await notifier.save('소비');
      expect(problem(), NameProblem.taken);
      // 숨긴 분류의 이름도 겹치면 안 된다. 다시 보이게 하면 둘이 헷갈린다.
      await notifier.save('경조사');
      expect(problem(), NameProblem.taken);
      expect(settings.addedCategories, isEmpty);

      notifier.nameEdited();
      expect(problem(), isNull);
    });

    test('저장 중에 다시 눌러도 한 번만 더한다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      final (notifier, _) = notifierOf(container, const CategoryFormArgs.add());

      await Future.wait([notifier.save('비상금'), notifier.save('비상금')]);

      expect(settings.addedCategories, hasLength(1));
    });
  });

  group('고치기', () {
    test('자기 이름은 겹침으로 보지 않고, 저축 집계만 바꿔도 쓴다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      final (notifier, _) = notifierOf(
        container,
        const CategoryFormArgs.edit(principal),
      );

      notifier.setCountsAsSaving(false);
      await notifier.save('대출원금');

      expect(settings.updatedCategories, [
        (
          ledgerId: 'l1',
          id: 'c-principal',
          draft: (name: '대출원금', countsAsSaving: false),
          uid: 'me',
        ),
      ]);
      expect(settings.categories.first.countsAsSaving, isFalse);
    });

    test('바꾼 것이 없으면 쓰지 않고 닫는다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      final (notifier, states) = notifierOf(
        container,
        const CategoryFormArgs.edit(spending),
      );

      await notifier.save(' 소비 ');

      expect(settings.updatedCategories, isEmpty);
      expect(states.last.outcome, SettingFormOutcome.saved);
    });

    test('숨기면 hidden 결과로, 다시 보이게 하면 shown 결과로 닫힌다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      final (hide, hideStates) = notifierOf(
        container,
        const CategoryFormArgs.edit(spending),
      );
      final (show, showStates) = notifierOf(
        container,
        const CategoryFormArgs.edit(gift),
      );

      await hide.setHidden(true);
      await show.setHidden(false);

      expect(settings.hiddenChanges, [
        (collection: 'categories', id: 'c-spending', hidden: true, uid: 'me'),
        (collection: 'categories', id: 'c-gift', hidden: false, uid: 'me'),
      ]);
      expect(hideStates.last.outcome, SettingFormOutcome.hidden);
      expect(showStates.last.outcome, SettingFormOutcome.shown);
      expect(settings.categories.map((c) => (c.id, c.hidden)), [
        ('c-principal', false),
        ('c-spending', true),
        ('c-gift', false),
      ]);
    });

    test('연결이 없으면 offline 실패를 남기고 닫지 않는다', () async {
      final settings = settingsWith()..offline = true;
      final container = await ready(settings);
      final (notifier, states) = notifierOf(
        container,
        const CategoryFormArgs.edit(spending),
      );

      await notifier.setHidden(true);

      expect(
        states.last,
        const CategoryFormState(
          countsAsSaving: false,
          failure: SettingFormFailure.offline,
        ),
      );
      expect(states.last.busy, isFalse);
    });

    test('그사이 분류가 없어졌으면 gone, 예상 못 한 오류는 save로 알린다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      const lost = Category(id: 'c-lost', name: '없어진 분류');
      final (gone, goneStates) = notifierOf(
        container,
        const CategoryFormArgs.edit(lost),
      );
      final (broken, brokenStates) = notifierOf(
        container,
        const CategoryFormArgs.edit(spending),
      );

      await gone.save('새 이름');
      settings.failNextWrite = true;
      await broken.save('새 이름');

      expect(goneStates.last.failure, SettingFormFailure.gone);
      expect(brokenStates.last.failure, SettingFormFailure.save);
    });
  });
}
