import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ledger/core/data/settings_repository.dart';
import 'package:shared_ledger/core/model/member.dart';
import 'package:shared_ledger/core/model/payment_method.dart';

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
}
