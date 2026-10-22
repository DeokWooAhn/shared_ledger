import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/ledger_entries.dart';
import '../model/month_ledger.dart';
import '../model/year_month.dart';

/// 가계부 항목(수입·기본 월 지출·추가지출·카드대금)을 읽는다. 쓰기는 항목 입력 화면을 만들 때 넣는다.
abstract interface class EntriesRepository {
  /// [month] 한 달의 항목. 휴지통에 넣은 항목은 뺀다.
  ///
  /// 그달의 하위 컬렉션 네 개만 구독한다. 다른 달의 항목은 읽지 않는다.
  Stream<MonthLedger> watchMonth(String ledgerId, YearMonth month);
}

class FirestoreEntriesRepository implements EntriesRepository {
  FirestoreEntriesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<MonthLedger> watchMonth(String ledgerId, YearMonth month) {
    final monthDoc = _firestore
        .collection('ledgers')
        .doc(ledgerId)
        .collection('months')
        .doc(month.id);
    Stream<List<EntryDoc>> watch(String collection) => monthDoc
        .collection(collection)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              (
                id: doc.id,
                data: doc.data(),
                hasPendingWrites: doc.metadata.hasPendingWrites,
              ),
          ],
        );
    return combineLatest([
      watch('incomes'),
      watch('planned'),
      watch('extras'),
      watch('cardBills'),
    ]).map((docs) {
      final [incomes, planned, extras, cardBills] = docs;
      return monthLedgerFromFirestore(
        incomes: incomes,
        planned: planned,
        extras: extras,
        cardBills: cardBills,
      );
    });
  }
}

/// 항목 문서 하나. [hasPendingWrites]는 내가 고친 내용이 아직 서버에 닿지 않았는지다.
typedef EntryDoc = ({
  String id,
  Map<String, dynamic> data,
  bool hasPendingWrites,
});

/// 그달 네 컬렉션의 문서로 [MonthLedger]를 만든다. 휴지통 항목과 읽을 수 없는 문서는 뺀다.
MonthLedger monthLedgerFromFirestore({
  required List<EntryDoc> incomes,
  required List<EntryDoc> planned,
  required List<EntryDoc> extras,
  required List<EntryDoc> cardBills,
}) {
  List<T> live<T extends Object>(
    List<EntryDoc> docs,
    T? Function(String id, Map<String, dynamic> data) from,
  ) => [
    for (final doc in docs)
      if (!entryIsTrashed(doc.data, hasPendingWrites: doc.hasPendingWrites))
        ?from(doc.id, doc.data),
  ];
  return MonthLedger(
    incomes: live(incomes, incomeFromFirestore),
    plannedExpenses: live(planned, plannedExpenseFromFirestore),
    extraExpenses: live(extras, extraExpenseFromFirestore),
    cardBills: live(cardBills, cardBillFromFirestore),
  );
}

/// 휴지통에 넣은 항목인지. `deletedAt`에 값이 있으면 휴지통이다.
///
/// `deletedAt`은 서버 시간이라, 방금 휴지통에 넣고 아직 서버에 닿지 않은 문서는 값이 null로 읽힌다.
/// 그래서 고친 내용이 서버에 닿기 전([hasPendingWrites])에는 필드가 있기만 해도 휴지통으로 본다.
/// 앱은 휴지통에 넣을 때만 이 필드를 쓰고, 꺼낼 때는 필드를 지운다.
bool entryIsTrashed(
  Map<String, dynamic> data, {
  required bool hasPendingWrites,
}) =>
    data['deletedAt'] != null ||
    (hasPendingWrites && data.containsKey('deletedAt'));

/// Firestore 수입 문서를 [Income]으로 바꾼다. 누가·금액이 없거나 잘못됐으면 null.
Income? incomeFromFirestore(String id, Map<String, dynamic> data) {
  final memberId = data['memberId'];
  final amount = _won(data['amount']);
  if (memberId is! String || amount == null) return null;
  return Income(
    id: id,
    memberId: memberId,
    title: _title(data),
    amount: amount,
    receivedOn: entryDateFromFirestore(data['receivedOn']),
    memo: _memo(data),
  );
}

/// Firestore 기본 월 지출 문서를 [PlannedExpense]로 바꾼다.
/// 금액은 비어 있으면 미정(null)이고, 누가·분류·결제수단이 없거나 금액이 잘못됐으면 null.
PlannedExpense? plannedExpenseFromFirestore(
  String id,
  Map<String, dynamic> data,
) {
  final memberId = data['memberId'];
  final categoryId = data['categoryId'];
  final paymentMethodId = data['paymentMethodId'];
  final rawAmount = data['amount'];
  final amount = _won(rawAmount);
  if (memberId is! String ||
      categoryId is! String ||
      paymentMethodId is! String ||
      (rawAmount != null && amount == null)) {
    return null;
  }
  return PlannedExpense(
    id: id,
    categoryId: categoryId,
    memberId: memberId,
    title: _title(data),
    paymentMethodId: paymentMethodId,
    amount: amount,
    paidOn: entryDateFromFirestore(data['paidOn']),
    memo: _memo(data),
  );
}

/// Firestore 추가지출 문서를 [ExtraExpense]로 바꾼다. 누가·결제수단·금액이 없거나 잘못됐으면 null.
ExtraExpense? extraExpenseFromFirestore(String id, Map<String, dynamic> data) {
  final memberId = data['memberId'];
  final paymentMethodId = data['paymentMethodId'];
  final amount = _won(data['amount']);
  if (memberId is! String || paymentMethodId is! String || amount == null) {
    return null;
  }
  return ExtraExpense(
    id: id,
    memberId: memberId,
    title: _title(data),
    paymentMethodId: paymentMethodId,
    amount: amount,
    spentOn: entryDateFromFirestore(data['spentOn']),
    memo: _memo(data),
  );
}

/// Firestore 카드대금 문서를 [CardBill]로 바꾼다. 누가·카드·금액이 없거나 잘못됐으면 null.
CardBill? cardBillFromFirestore(String id, Map<String, dynamic> data) {
  final memberId = data['memberId'];
  final cardId = data['cardId'];
  final amount = _won(data['amount']);
  if (memberId is! String || cardId is! String || amount == null) return null;
  return CardBill(
    id: id,
    memberId: memberId,
    cardId: cardId,
    amount: amount,
    paidOn: entryDateFromFirestore(data['paidOn']),
    memo: _memo(data),
  );
}

/// 항목의 날짜를 Firestore 값(`2026-10-25`)으로 바꾼다.
/// 날짜만 필요해서, 두 사람의 시간대가 달라도 날짜가 바뀌지 않게 문자열로 둔다.
String entryDateToFirestore(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// [entryDateToFirestore]로 적은 날짜를 읽는다. 형식이 다르거나 없는 날(2월 30일)이면 null.
DateTime? entryDateFromFirestore(Object? value) {
  if (value is! String || !_entryDatePattern.hasMatch(value)) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  // DateTime은 2월 30일을 3월 2일로 넘겨 버리므로, 다시 적어 보고 같을 때만 받는다.
  final date = DateTime(parsed.year, parsed.month, parsed.day);
  return entryDateToFirestore(date) == value ? date : null;
}

final _entryDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// 금액 칸. 보안 규칙과 같이 0 이상의 정수(원)만 받는다.
int? _won(Object? value) => switch (value) {
  final int won when won >= 0 => won,
  _ => null,
};

// 제목·메모는 계산에 쓰지 않아서, 없거나 잘못됐어도 항목은 살린다.
String _title(Map<String, dynamic> data) => switch (data['title']) {
  final String title => title,
  _ => '',
};

String? _memo(Map<String, dynamic> data) => switch (data['memo']) {
  final String memo => memo,
  _ => null,
};

/// 여러 스트림의 최신 값을 묶는다. 모든 스트림이 한 번씩 값을 낸 뒤부터, 하나라도 바뀌면 묶음을 다시 낸다.
///
/// 오류는 그대로 넘기고, 모든 스트림이 끝나면 함께 끝난다. 구독을 끊으면 모든 스트림의 구독을 끊는다.
Stream<List<T>> combineLatest<T extends Object>(List<Stream<T>> streams) {
  final latest = List<T?>.filled(streams.length, null);
  final subscriptions = <StreamSubscription<T>>[];
  var done = 0;
  late final StreamController<List<T>> controller;
  controller = StreamController<List<T>>(
    onListen: () {
      for (final (index, stream) in streams.indexed) {
        subscriptions.add(
          stream.listen(
            (value) {
              latest[index] = value;
              final values = [for (final value in latest) ?value];
              if (values.length == streams.length) controller.add(values);
            },
            onError: controller.addError,
            onDone: () {
              done++;
              if (done == streams.length) unawaited(controller.close());
            },
          ),
        );
      }
    },
    onPause: () {
      for (final subscription in subscriptions) {
        subscription.pause();
      }
    },
    onResume: () {
      for (final subscription in subscriptions) {
        subscription.resume();
      }
    },
    onCancel: () => Future.wait([
      for (final subscription in subscriptions) subscription.cancel(),
    ]),
  );
  return controller.stream;
}
