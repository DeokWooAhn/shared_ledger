import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/data/settings/firestore_settings_repository.dart';
import 'package:shared_ledger/domain/model/member.dart';
import 'package:shared_ledger/domain/model/payment_method.dart';

void main() {
  group('새 가계부의 기본 설정', () {
    final docs = defaultSettingDocs(uid: 'me', ownerName: '하늘');

    List<Map<String, Object>> dataIn(String collection) => [
      for (final doc in docs)
        if (doc.collection == collection) doc.data,
    ];

    test('이름표는 owner·partner 두 장이고, 상대 이름은 상대다', () {
      final members = [
        for (final doc in docs)
          if (doc.collection == 'members') (doc.id, doc.data['name']),
      ];
      expect(members, [('owner', '하늘'), ('partner', '상대')]);
    });

    test('분류는 시트와 같은 4개이고, 대출원금·저축/투자만 저축으로 센다', () {
      expect(
        [
          for (final data in dataIn('categories'))
            (data['name'], data['countsAsSaving'], data['order']),
        ],
        [
          ('대출원금', true, 0),
          ('대출이자', false, 1),
          ('저축/투자', true, 2),
          ('소비', false, 3),
        ],
      );
    });

    test('결제수단은 공동 통장과 자동이체이고, 카드는 넣지 않는다', () {
      expect(
        [
          for (final data in dataIn('paymentMethods'))
            (data['name'], data['kind'], data['order']),
        ],
        [('공동 통장', 'account', 0), ('자동이체', 'autoTransfer', 1)],
      );
    });

    test('문서마다 정해진 필드만 담는다', () {
      const audit = {'createdBy', 'updatedBy', 'createdAt', 'updatedAt'};
      final fields = {
        'members': {'name', ...audit},
        'categories': {'name', 'countsAsSaving', 'order', ...audit},
        'paymentMethods': {'name', 'kind', 'order', ...audit},
      };
      for (final doc in docs) {
        expect(doc.data.keys.toSet(), fields[doc.collection], reason: doc.id);
      }
    });

    test('모든 문서는 보안 규칙의 공통 기록 필드를 나와 서버 시간으로 담는다', () {
      for (final doc in docs) {
        expect(doc.data['createdBy'], 'me');
        expect(doc.data['updatedBy'], 'me');
        expect(doc.data['createdAt'], isA<FieldValue>());
        expect(doc.data['updatedAt'], isA<FieldValue>());
      }
      // 이름표만 id를 정하고, 나머지는 저장소가 새 id를 만든다.
      expect(
        docs.where((doc) => doc.id != null).map((doc) => doc.collection),
        everyElement('members'),
      );
    });
  });

  group('Firestore 문서 읽기', () {
    test('이름표는 owner·partner id만 읽고, 모르는 id나 이름 없는 문서는 건너뛴다', () {
      expect(
        memberFromFirestore('partner', {'name': '바다'}),
        const Member(slot: MemberSlot.partner, name: '바다'),
      );
      expect(memberFromFirestore('third', {'name': '셋째'}), isNull);
      expect(memberFromFirestore('owner', {'name': 3}), isNull);
    });

    test('분류는 저축 여부가 true일 때만 저축으로 보고, 이름이 없으면 건너뛴다', () {
      final category = categoryFromFirestore('c1', {
        'name': '저축/투자',
        'countsAsSaving': true,
      });
      expect(category?.id, 'c1');
      expect(category?.countsAsSaving, isTrue);
      expect(
        categoryFromFirestore('c2', {
          'name': '소비',
          'countsAsSaving': 'yes',
        })?.countsAsSaving,
        isFalse,
      );
      expect(categoryFromFirestore('c3', {}), isNull);
    });

    test('숨김은 true일 때만 숨긴 것으로 보고, 없거나 다른 값이면 보이는 것이다', () {
      expect(
        categoryFromFirestore('c1', {'name': '소비', 'hidden': true})?.hidden,
        isTrue,
      );
      expect(categoryFromFirestore('c2', {'name': '소비'})?.hidden, isFalse);
      expect(
        paymentMethodFromFirestore('p1', {
          'name': '카드',
          'kind': 'card',
          'hidden': true,
        })?.hidden,
        isTrue,
      );
      expect(
        paymentMethodFromFirestore('p2', {
          'name': '카드',
          'kind': 'card',
          'hidden': 'yes',
        })?.hidden,
        isFalse,
      );
    });

    test('결제수단은 모르는 종류면 건너뛴다', () {
      expect(
        paymentMethodFromFirestore('p1', {'name': '카드', 'kind': 'card'})?.kind,
        PaymentKind.card,
      );
      expect(
        paymentMethodFromFirestore('p2', {'name': '상품권', 'kind': 'voucher'}),
        isNull,
      );
    });

    test('순서가 없거나 숫자가 아니면 맨 뒤로 보낸다', () {
      expect(settingOrder({'order': 2}), 2);
      expect(settingOrder({}), greaterThan(1000));
      expect(settingOrder({'order': '1'}), greaterThan(1000));
    });
  });

  group('설정 쓰기 데이터', () {
    const audit = {'createdBy', 'updatedBy', 'createdAt', 'updatedAt'};
    const edited = {'updatedBy', 'updatedAt'};

    // 만들 때는 나와 서버 시간, 고칠 때는 고친 사람과 서버 시간만 쓴다(규칙의 createdNow·updatedNow).
    void expectCreatedBy(Map<String, Object> data, String uid) {
      expect(data['createdBy'], uid);
      expect(data['updatedBy'], uid);
      expect(data['createdAt'], FieldValue.serverTimestamp());
      expect(data['updatedAt'], FieldValue.serverTimestamp());
    }

    void expectUpdatedBy(Map<String, Object> data, String uid) {
      expect(data['updatedBy'], uid);
      expect(data['updatedAt'], FieldValue.serverTimestamp());
    }

    test('새 이름표는 이름과 기록 필드만 담고, 이름 앞뒤 공백을 뺀다', () {
      final data = newMemberData(' 바다 ', uid: 'me');

      expect(data.keys.toSet(), {'name', ...audit});
      expect(data['name'], '바다');
      expectCreatedBy(data, 'me');
    });

    test('이름표 이름을 바꿀 때는 이름과 고친 기록만 쓴다', () {
      final data = memberRenameUpdate(' 바다 ', uid: 'me');

      expect(data.keys.toSet(), {'name', ...edited});
      expect(data['name'], '바다');
      expectUpdatedBy(data, 'me');
    });

    test('새 분류는 규칙이 받는 필드(이름·저축 집계·순서)만 담는다', () {
      final data = newCategoryData(
        (name: ' 경조사 ', countsAsSaving: true),
        order: 4,
        uid: 'me',
      );

      expect(data.keys.toSet(), {'name', 'countsAsSaving', 'order', ...audit});
      expect(data['name'], '경조사');
      expect(data['countsAsSaving'], isTrue);
      expect(data['order'], 4);
      expectCreatedBy(data, 'me');
    });

    test('분류를 고칠 때는 이름과 저축 집계만 바꾸고 순서·숨김은 그대로 둔다', () {
      final data = categoryUpdateData((
        name: '경조사비',
        countsAsSaving: false,
      ), uid: 'me');

      expect(data.keys.toSet(), {'name', 'countsAsSaving', ...edited});
      expect(data['countsAsSaving'], isFalse);
      expectUpdatedBy(data, 'me');
    });

    test('새 결제수단은 규칙이 받는 필드(이름·종류·순서)만 담는다', () {
      final data = newPaymentMethodData(
        (name: ' 하늘 카드 ', kind: PaymentKind.card),
        order: 2,
        uid: 'me',
      );

      expect(data.keys.toSet(), {'name', 'kind', 'order', ...audit});
      expect(data['name'], '하늘 카드');
      expect(data['kind'], 'card');
      expect(data['order'], 2);
      expectCreatedBy(data, 'me');
    });

    test('결제수단 이름을 바꿀 때는 종류를 쓰지 않는다 (규칙이 종류 변경을 막는다)', () {
      final data = paymentMethodRenameUpdate('바다 카드', uid: 'me');

      expect(data.keys.toSet(), {'name', ...edited});
      expect(data['name'], '바다 카드');
      expectUpdatedBy(data, 'me');
    });

    test('숨기기와 다시 보이기는 숨김과 고친 기록만 쓴다', () {
      for (final hidden in [true, false]) {
        final data = settingHiddenUpdate(hidden: hidden, uid: 'me');

        expect(data.keys.toSet(), {'hidden', ...edited});
        expect(data['hidden'], hidden);
        expectUpdatedBy(data, 'me');
      }
    });
  });
}
