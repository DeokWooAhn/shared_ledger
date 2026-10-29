import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/activity.dart';
import '../../domain/model/expense_template.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/month_ledger.dart';
import '../../domain/model/trashed_entry.dart';
import '../../domain/model/year_month.dart';
import '../activity/firestore_activity_repository.dart';
import '../../domain/activity/activity_summary.dart';
import '../ledger/firestore_ledger_repository.dart';
import '../../domain/repository/entries_repository.dart';

class FirestoreEntriesRepository implements EntriesRepository {
  FirestoreEntriesRepository(this._firestore, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;
  final _rejectedAdds = StreamController<RejectedEntry>.broadcast();

  @override
  Stream<RejectedEntry> get rejectedAdds => _rejectedAdds.stream;

  DocumentReference<Map<String, dynamic>> _ledger(String ledgerId) =>
      _firestore.collection('ledgers').doc(ledgerId);

  DocumentReference<Map<String, dynamic>> _month(
    String ledgerId,
    YearMonth month,
  ) => _firestore
      .collection('ledgers')
      .doc(ledgerId)
      .collection('months')
      .doc(month.id);

  CollectionReference<Map<String, dynamic>> _entries(
    String ledgerId,
    YearMonth month,
    EntryKind kind,
  ) => _month(ledgerId, month).collection(entryCollection(kind));

  @override
  Stream<MonthLedger> watchMonth(String ledgerId, YearMonth month) {
    Stream<List<EntryDoc>> watch(EntryKind kind) =>
        _entries(ledgerId, month, kind).snapshots().map(
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
      watch(EntryKind.income),
      watch(EntryKind.planned),
      watch(EntryKind.extra),
      watch(EntryKind.cardBill),
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

  @override
  Future<String> add({
    required String ledgerId,
    required YearMonth month,
    required EntryDraft draft,
    required String uid,
    bool recordMonth = false,
  }) async {
    final doc = _entries(ledgerId, month, draft.kind).doc();
    final activity = entryActivity(
      ActivityAction.entryCreate,
      month: month,
      kind: draft.kind,
      entry: draft,
    );
    // 항목과 변경 기록을 한 번의 일괄 쓰기로 해서 함께 쓰이거나 함께 거부된다.
    final batch = _firestore.batch()
      ..set(doc, newEntryData(draft, uid: uid))
      ..set(
        activityCollection(_firestore, ledgerId).doc(),
        newActivityData(activity, uid: uid, now: _now()),
      );
    if (recordMonth) {
      batch.update(_ledger(ledgerId), recordMonthUpdate(month));
    }
    // commit의 Future는 서버가 받아야 끝나서, 기다리면 오프라인에서는 저장이 끝나지 않는다.
    // 캐시에는 바로 들어가므로 기다리지 않는다. 서버가 규칙으로 거부하면 rejectedAdds로 알리고,
    // 예상 못 한 오류는 삼키지 않고 다시 던져 앱의 오류 처리로 보낸다.
    unawaited(
      batch.commit().catchError((Object error, StackTrace stackTrace) {
        if (error is FirebaseException && error.code == 'permission-denied') {
          _rejectedAdds.add((id: doc.id, month: month, kind: draft.kind));
          return;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }),
    );
    return doc.id;
  }

  @override
  Future<void> update({
    required String ledgerId,
    required YearMonth month,
    required String id,
    required EntryDraft draft,
    required String uid,
  }) => _writeOnline(
    ledgerId,
    month,
    draft.kind,
    id,
    uid: uid,
    trashed: false,
    write: (transaction, doc, before) {
      transaction.update(doc, entryUpdateData(draft, uid: uid));
      return entryActivity(
        ActivityAction.entryUpdate,
        month: month,
        kind: draft.kind,
        entry: draft,
        before: before == null ? null : EntryDraft.of(before),
      );
    },
  );

  @override
  Future<void> trash({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
    bool keep = false,
  }) => _writeOnline(
    ledgerId,
    month,
    kind,
    id,
    uid: uid,
    trashed: false,
    write: (transaction, doc, entry) {
      transaction.update(
        doc,
        trashEntryUpdate(
          uid: uid,
          purgeAt: keep ? null : _now().add(trashRetention),
        ),
      );
      return _entryActivity(ActivityAction.entryTrash, month, kind, entry);
    },
  );

  @override
  Future<void> restore({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
  }) => _writeOnline(
    ledgerId,
    month,
    kind,
    id,
    uid: uid,
    trashed: true,
    write: (transaction, doc, entry) {
      transaction.update(doc, restoreEntryUpdate(uid: uid));
      return _entryActivity(ActivityAction.entryRestore, month, kind, entry);
    },
  );

  @override
  Future<void> purge({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
  }) => _writeOnline(
    ledgerId,
    month,
    kind,
    id,
    uid: uid,
    trashed: true,
    write: (transaction, doc, entry) {
      transaction.delete(doc);
      return _entryActivity(ActivityAction.entryPurge, month, kind, entry);
    },
  );

  static ActivityDraft _entryActivity(
    ActivityAction action,
    YearMonth month,
    EntryKind kind,
    LedgerEntry? entry,
  ) => entryActivity(
    action,
    month: month,
    kind: kind,
    entry: entry == null ? null : EntryDraft.of(entry),
  );

  @override
  Future<int> fillPlanned({
    required String ledgerId,
    required YearMonth month,
    required List<ExpenseTemplate> templates,
    required String uid,
    bool recordMonth = false,
  }) async {
    if (templates.isEmpty && !recordMonth) return 0;
    final planned = _entries(ledgerId, month, EntryKind.planned);
    try {
      return await _firestore.runTransaction(timeout: _onlineTimeout, (
        transaction,
      ) async {
        // 트랜잭션은 읽기를 모두 마친 뒤에 써야 한다.
        final missing = <ExpenseTemplate>[];
        for (final template in templates) {
          final current = await transaction.get(planned.doc(template.id));
          if (!current.exists) missing.add(template);
        }
        for (final template in missing) {
          transaction.set(
            planned.doc(template.id),
            newEntryData(template.draftFor(month), uid: uid),
          );
        }
        if (recordMonth) {
          transaction.update(_ledger(ledgerId), recordMonthUpdate(month));
        }
        return missing.length;
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const EntryWriteException(EntryWriteFailure.offline);
      }
      rethrow;
    }
  }

  @override
  Future<Set<YearMonth>> monthsWithEntries(
    String ledgerId,
    Iterable<YearMonth> months,
  ) async {
    Future<bool> hasEntries(YearMonth month) async {
      final found = await Future.wait([
        for (final kind in EntryKind.values)
          _entries(ledgerId, month, kind)
              .limit(1)
              .get(const GetOptions(source: Source.server))
              .then((snapshot) => snapshot.docs.isNotEmpty),
      ]);
      return found.contains(true);
    }

    try {
      final found = <YearMonth>{};
      for (final month in months) {
        if (await hasEntries(month)) found.add(month);
      }
      return found;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const EntryWriteException(EntryWriteFailure.offline);
      }
      rethrow;
    }
  }

  // 트랜잭션은 서버에서 문서를 읽어야 해서 오프라인이면 실패한다. 그래서 온라인에서만 고치는 데 쓴다.
  // 읽은 문서가 없거나 휴지통 상태가 [trashed]와 다르면(그사이 상대가 바꿈) 고치지 않는다.
  // [write]는 읽은 항목(모양이 잘못됐으면 null)으로 문서를 고치고 남길 변경 기록을 돌려준다. 기록도 같은 트랜잭션에 쓴다.
  Future<void> _writeOnline(
    String ledgerId,
    YearMonth month,
    EntryKind kind,
    String id, {
    required String uid,
    required bool trashed,
    required ActivityDraft Function(
      Transaction transaction,
      DocumentReference<Map<String, dynamic>> doc,
      LedgerEntry? current,
    )
    write,
  }) async {
    final doc = _entries(ledgerId, month, kind).doc(id);
    try {
      await _firestore.runTransaction(timeout: _onlineTimeout, (
        transaction,
      ) async {
        final current = (await transaction.get(doc)).data();
        if (current == null ||
            entryIsTrashed(current, hasPendingWrites: false) != trashed) {
          throw const EntryWriteException(EntryWriteFailure.notFound);
        }
        final activity = write(
          transaction,
          doc,
          entryFromFirestore(kind, id, current),
        );
        addActivity(
          transaction,
          _firestore,
          ledgerId: ledgerId,
          draft: activity,
          uid: uid,
          now: _now(),
        );
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const EntryWriteException(EntryWriteFailure.offline);
      }
      rethrow;
    }
  }

  // 연결이 끊긴 채로 오래 기다리지 않게 한다. 기본값은 30초다.
  static const _onlineTimeout = Duration(seconds: 10);
}

/// [kind] 항목의 Firestore 컬렉션 이름.
String entryCollection(EntryKind kind) => switch (kind) {
  EntryKind.income => 'incomes',
  EntryKind.planned => 'planned',
  EntryKind.extra => 'extras',
  EntryKind.cardBill => 'cardBills',
};

/// [kind] 항목의 날짜 필드 이름.
String entryDateField(EntryKind kind) => switch (kind) {
  EntryKind.income => 'receivedOn',
  EntryKind.planned || EntryKind.cardBill => 'paidOn',
  EntryKind.extra => 'spentOn',
};

/// 새 항목 문서. `firestore.rules`의 항목 create 규칙(validEntry, createdNow)과 필드가 같아야 한다.
///
/// 그 종류가 쓰는 칸만 넣고, 비어 있는 선택 칸(금액 미정, 날짜, 메모)은 넣지 않는다.
Map<String, Object> newEntryData(EntryDraft draft, {required String uid}) => {
  for (final MapEntry(:key, :value) in _entryFields(draft).entries)
    if (value != null) key: value,
  'createdBy': uid,
  'updatedBy': uid,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// 항목을 고칠 때 쓰는 값. 그 종류가 쓰는 칸을 모두 다시 쓰고, 비운 선택 칸은 필드를 지운다.
/// 만든 사람·시간은 그대로 두고 고친 사람·시간만 바꾼다(규칙의 updatedNow).
Map<Object, Object> entryUpdateData(EntryDraft draft, {required String uid}) =>
    {
      for (final MapEntry(:key, :value) in _entryFields(draft).entries)
        key: value ?? FieldValue.delete(),
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

/// 휴지통에 넣을 때 쓰는 값. 넣을 때만 서버 시간으로 쓴다.
///
/// [purgeAt]이 있으면 그때 Firestore TTL 정책이 문서를 지운다. null이면 자동으로 지우지 않는다([staysInTrash]).
Map<Object, Object> trashEntryUpdate({
  required String uid,
  DateTime? purgeAt,
}) => {
  'deletedAt': FieldValue.serverTimestamp(),
  'purgeAt': ?(purgeAt == null ? null : Timestamp.fromDate(purgeAt)),
  'updatedBy': uid,
  'updatedAt': FieldValue.serverTimestamp(),
};

/// 휴지통에서 꺼낼 때 쓰는 값. `deletedAt`을 null로 쓰지 않고 필드를 지운다. 자동으로 지울 때(`purgeAt`)도 지운다.
Map<Object, Object> restoreEntryUpdate({required String uid}) => {
  'deletedAt': FieldValue.delete(),
  'purgeAt': FieldValue.delete(),
  'updatedBy': uid,
  'updatedAt': FieldValue.serverTimestamp(),
};

// 종류마다 쓰는 칸(docs/firestore.md의 항목 표). 값이 null이면 비어 있는 칸이다.
Map<String, Object?> _entryFields(EntryDraft draft) {
  final memo = draft.memo?.trim() ?? '';
  final date = draft.date;
  final dueOn = draft.dueOn;
  return {
    'memberId': draft.memberId,
    'amount': draft.amount,
    if (draft.kind != EntryKind.cardBill) 'title': draft.title.trim(),
    if (draft.kind == EntryKind.planned) 'categoryId': draft.categoryId,
    if (draft.kind case EntryKind.planned || EntryKind.extra)
      'paymentMethodId': draft.paymentMethodId,
    if (draft.kind == EntryKind.cardBill) 'cardId': draft.cardId,
    entryDateField(draft.kind): date == null
        ? null
        : entryDateToFirestore(date),
    if (draft.kind == EntryKind.planned)
      'dueOn': dueOn == null ? null : entryDateToFirestore(dueOn),
    'memo': memo.isEmpty ? null : memo,
  };
}

/// 항목 문서 하나. [hasPendingWrites]는 내가 고친 내용이 아직 서버에 닿지 않았는지다.
typedef EntryDoc = ({
  String id,
  Map<String, dynamic> data,
  bool hasPendingWrites,
});

/// 그달 네 컬렉션의 문서로 [MonthLedger]를 만든다. 휴지통 항목은 [MonthLedger.trashed]에 따로 모으고,
/// 읽을 수 없는 문서는 뺀다.
///
/// 고정 지출 문서 id는 휴지통 항목과 읽을 수 없는 문서까지 [MonthLedger.plannedIds]에 모은다.
/// 고정 지출로 채울 때 그 id의 문서를 다시 만들지 않게 한다.
MonthLedger monthLedgerFromFirestore({
  required List<EntryDoc> incomes,
  required List<EntryDoc> planned,
  required List<EntryDoc> extras,
  required List<EntryDoc> cardBills,
}) {
  bool trashed(EntryDoc doc) =>
      entryIsTrashed(doc.data, hasPendingWrites: doc.hasPendingWrites);
  List<T> live<T extends Object>(
    List<EntryDoc> docs,
    T? Function(String id, Map<String, dynamic> data) from,
  ) => [
    for (final doc in docs)
      if (!trashed(doc)) ?from(doc.id, doc.data),
  ];
  return MonthLedger(
    incomes: live(incomes, incomeFromFirestore),
    plannedExpenses: live(planned, plannedExpenseFromFirestore),
    extraExpenses: live(extras, extraExpenseFromFirestore),
    cardBills: live(cardBills, cardBillFromFirestore),
    trashed: [
      for (final (kind, docs) in [
        (EntryKind.income, incomes),
        (EntryKind.planned, planned),
        (EntryKind.extra, extras),
        (EntryKind.cardBill, cardBills),
      ])
        for (final doc in docs)
          if (trashed(doc))
            if (entryFromFirestore(kind, doc.id, doc.data) case final entry?)
              TrashedEntry(
                entry: entry,
                deletedAt: _time(doc.data['deletedAt']),
                purgeAt: _time(doc.data['purgeAt']),
              ),
    ],
    plannedIds: {for (final doc in planned) doc.id},
  );
}

/// [kind] 종류의 Firestore 항목 문서를 항목으로 바꾼다. 계산에 쓰는 값이 없거나 잘못됐으면 null.
LedgerEntry? entryFromFirestore(
  EntryKind kind,
  String id,
  Map<String, dynamic> data,
) => switch (kind) {
  EntryKind.income => incomeFromFirestore(id, data),
  EntryKind.planned => plannedExpenseFromFirestore(id, data),
  EntryKind.extra => extraExpenseFromFirestore(id, data),
  EntryKind.cardBill => cardBillFromFirestore(id, data),
};

DateTime? _time(Object? value) => value is Timestamp ? value.toDate() : null;

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

/// Firestore 고정 지출 문서를 [PlannedExpense]로 바꾼다.
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
    dueOn: entryDateFromFirestore(data['dueOn']),
    memo: _memo(data),
  );
}

/// Firestore 추가 지출 문서를 [ExtraExpense]로 바꾼다. 누가·결제수단·금액이 없거나 잘못됐으면 null.
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

/// Firestore 카드 대금 문서를 [CardBill]로 바꾼다. 누가·카드·금액이 없거나 잘못됐으면 null.
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
