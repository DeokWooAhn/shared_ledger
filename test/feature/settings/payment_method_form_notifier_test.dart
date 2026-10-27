import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/providers/providers.dart';
import 'package:shared_ledger/domain/model/auth_user.dart';
import 'package:shared_ledger/domain/model/ledger.dart';
import 'package:shared_ledger/domain/model/name_problem.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';
import 'package:shared_ledger/feature/settings/payment_method_form_notifier.dart';
import 'package:shared_ledger/feature/settings/setting_form.dart';

import '../../../testing/fakes.dart';
import '../../../testing/provider_container.dart';

const me = AuthUser(uid: 'me');
const mine = Ledger(id: 'l1', name: '우리 가계부', ownerUid: 'me');
const account = PaymentMethod(
  id: 'p-account',
  name: '공동 통장',
  kind: PaymentKind.account,
);
const skyCard = PaymentMethod(
  id: 'p-sky',
  name: '하늘 카드',
  kind: PaymentKind.card,
);

/// 로그인하고 가계부와 결제수단까지 받은 컨테이너.
Future<ProviderContainer> ready(FakeSettingsRepository settings) async {
  final container = createContainer(
    auth: FakeAuthRepository(signedIn: me),
    ledgers: FakeLedgerRepository([mine]),
    settings: settings,
  );
  await loadSignedInUser(container);
  container
    ..listen(myLedgersProvider, (_, _) {})
    ..listen(paymentMethodsProvider, (_, _) {});
  await container.read(myLedgersProvider.future);
  await container.read(paymentMethodsProvider.future);
  return container;
}

FakeSettingsRepository settingsWith() =>
    FakeSettingsRepository(paymentMethods: const [account, skyCard]);

(PaymentMethodFormNotifier, List<PaymentMethodFormState>) notifierOf(
  ProviderContainer container,
  PaymentMethodFormArgs args,
) {
  final states = recordStates(
    container,
    paymentMethodFormNotifierProvider(args),
  );
  return (
    container.read(paymentMethodFormNotifierProvider(args).notifier),
    states,
  );
}

void main() {
  test('새 결제수단은 종류를 고르지 않은 채로, 고치기는 그 종류로 시작한다', () async {
    final container = await ready(settingsWith());

    expect(
      container.read(
        paymentMethodFormNotifierProvider(const PaymentMethodFormArgs.add()),
      ),
      const PaymentMethodFormState(),
    );
    expect(
      container
          .read(
            paymentMethodFormNotifierProvider(
              const PaymentMethodFormArgs.edit(skyCard),
            ),
          )
          .kind,
      PaymentKind.card,
    );
  });

  group('더하기', () {
    test('카드를 골라 이름과 함께 맨 뒤에 더한다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      final (notifier, states) = notifierOf(
        container,
        const PaymentMethodFormArgs.add(),
      );

      notifier.selectKind(PaymentKind.card);
      await notifier.save(' 바다 카드 ');

      expect(settings.addedPaymentMethods, [
        (
          ledgerId: 'l1',
          draft: (name: '바다 카드', kind: PaymentKind.card),
          order: 2,
          uid: 'me',
        ),
      ]);
      expect(states.last.outcome, SettingFormOutcome.saved);
      expect(settings.paymentMethods.last.kind, PaymentKind.card);
    });

    test('종류를 고르지 않거나 이름이 겹치면 둘 다 알리고 쓰지 않는다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      const args = PaymentMethodFormArgs.add();
      final (notifier, _) = notifierOf(container, args);

      await notifier.save('하늘 카드');

      expect(
        container.read(paymentMethodFormNotifierProvider(args)),
        const PaymentMethodFormState(
          problem: NameProblem.taken,
          kindMissing: true,
        ),
      );
      expect(settings.addedPaymentMethods, isEmpty);

      // 종류를 고르면 그 안내만 지우고, 이름 문제는 남는다.
      notifier.selectKind(PaymentKind.account);
      expect(
        container.read(paymentMethodFormNotifierProvider(args)),
        const PaymentMethodFormState(
          kind: PaymentKind.account,
          problem: NameProblem.taken,
        ),
      );
    });

    test('이름이 20자를 넘으면 쓰지 않는다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      const args = PaymentMethodFormArgs.add();
      final (notifier, _) = notifierOf(container, args);

      notifier.selectKind(PaymentKind.card);
      await notifier.save('카' * 21);

      expect(
        container.read(paymentMethodFormNotifierProvider(args)).problem,
        NameProblem.tooLong,
      );
      expect(settings.addedPaymentMethods, isEmpty);
    });
  });

  group('고치기', () {
    test('이름만 바꾸고 종류는 바꿀 수 없다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      const args = PaymentMethodFormArgs.edit(skyCard);
      final (notifier, states) = notifierOf(container, args);

      notifier.selectKind(PaymentKind.account);
      await notifier.save('하늘 체크카드');

      expect(settings.renamedPaymentMethods, [
        (ledgerId: 'l1', id: 'p-sky', name: '하늘 체크카드', uid: 'me'),
      ]);
      expect(settings.paymentMethods.last, isA<PaymentMethod>());
      expect(settings.paymentMethods.last.kind, PaymentKind.card);
      expect(states.last.outcome, SettingFormOutcome.saved);
    });

    test('숨기면 hidden 결과로 닫히고, 연결이 없으면 offline으로 남는다', () async {
      final settings = settingsWith();
      final container = await ready(settings);
      final (hide, hideStates) = notifierOf(
        container,
        const PaymentMethodFormArgs.edit(skyCard),
      );

      settings.offline = true;
      await hide.setHidden(true);
      expect(hideStates.last.failure, SettingFormFailure.offline);
      expect(settings.hiddenChanges, isEmpty);

      settings.offline = false;
      await hide.setHidden(true);
      expect(settings.hiddenChanges, [
        (collection: 'paymentMethods', id: 'p-sky', hidden: true, uid: 'me'),
      ]);
      expect(hideStates.last.outcome, SettingFormOutcome.hidden);
    });
  });
}
