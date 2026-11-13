import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/model/activity.dart';
import '../../domain/model/entry_edit.dart';
import '../../domain/model/expense_template.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/month_ledger.dart';
import '../../domain/model/trashed_entry.dart';
import '../../domain/model/year_month.dart';
import '../activity/firestore_activity_repository.dart';
import '../../domain/activity/activity_summary.dart';
import '../ledger/firestore_ledger_repository.dart';
import '../templates/firestore_templates_repository.dart';
import '../../domain/repository/entries_repository.dart';

class FirestoreEntriesRepository implements EntriesRepository {
  FirestoreEntriesRepository(this._firestore, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;
  final _rejections = RejectionNotices();

  @override
  Stream<RejectedEntry> get rejectedAdds => _rejections.stream;

  /// 지난 실행에서 오프라인으로 더해 아직 서버에 올라가지 않은 새 항목을 찾아, 서버가 거부했으면 [rejectedAdds]로 알린다.
  ///
  /// [add]는 일괄 쓰기의 오류로 거부를 알지만, 그 Future는 그 실행 안에만 있다. 오프라인에서 더하고 앱을 다시 켜면
  /// Firestore가 밀린 쓰기를 올리다 거부돼도 항목이 캐시에서 조용히 빠질 뿐이다.
  /// Firestore는 처음 쓰일 때 밀린 쓰기를 바로 보내서, 화면이 그달을 구독하기 전에 거부가 끝날 수 있다(기기에서 확인).
  /// 그래서 다른 Firestore 작업보다 먼저 부른다(main.dart, 끝나기를 기다리지 않는다).
  ///
  /// 네트워크를 잠깐 끄고 기기 캐시만 훑어 서버를 기다리는 항목 문서를 모은 뒤 다시 켠다. 밀린 쓰기가 끝나면
  /// (서버가 받든 거부하든) 그 문서가 서버에 있는지 보고, 없으면 거부로 알린다. 거부된 문서는 캐시에서 빠져 다음 실행에서
  /// 다시 찾을 수 없으니, 그사이 연결이 끊겨도 건너뛰지 않고 서버가 답할 때까지 기다린다([existsOnServer]).
  /// 캐시 훑기는 서버를 읽지 않고, 기다리던 문서가 있을 때만 문서마다 서버 읽기가 한 번 든다.
  /// 그사이 가계부에서 나가 읽을 수 없는 문서는 알리지 않는다.
  Future<void> checkUnsentFromLastRun() async {
    try {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> waiting = [];
      await _firestore.disableNetwork();
      try {
        for (final kind in EntryKind.values) {
          final cached = await _firestore
              .collectionGroup(entryCollection(kind))
              .get(const GetOptions(source: Source.cache));
          waiting.addAll(
            cached.docs.where((doc) => doc.metadata.hasPendingWrites),
          );
        }
      } finally {
        await _firestore.enableNetwork();
      }
      if (waiting.isEmpty) return;
      await _firestore.waitForPendingWrites();
      // 한 항목의 답이 늦어도 다른 항목의 확인을 막지 않게 한꺼번에 기다린다.
      await Future.wait([for (final doc in waiting) _reportIfRejected(doc)]);
    } on FirebaseException {
      // 기다리는 동안 로그아웃하는 등 확인을 끝낼 수 없다. 알릴 것이 없는 것으로 둔다.
    }
  }

  // 밀린 쓰기가 끝난 뒤 [doc]이 서버에 없으면 거부로 알린다. 서버가 답할 때까지 기다린다([existsOnServer]).
  Future<void> _reportIfRejected(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final place = entryPlaceOf(doc.reference.path);
    if (place == null) return;
    final bool? exists;
    try {
      exists = await existsOnServer(
        doc.reference
            .snapshots(includeMetadataChanges: true)
            .map(
              (snapshot) => (
                exists: snapshot.exists,
                fromCache: snapshot.metadata.isFromCache,
              ),
            ),
      );
    } on FirebaseException {
      // 권한·연결 문제가 아닌 드문 오류라 확인을 끝낼 수 없다. 알릴 것이 없는 것으로 둔다.
      return;
    }
    if (exists == false) {
      _rejections.report(
        rejectedEntryOf(
          (id: doc.id, data: doc.data(), hasPendingWrites: true),
          month: place.month,
          kind: place.kind,
        ),
      );
    }
  }

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
    // 메타데이터 변경까지 들어야, 새 항목을 서버가 받아 '전송 대기'가 풀린 것과 연결이 끊겨 캐시로만 보이게 된 것을 안다.
    Stream<EntrySnapshot> watch(EntryKind kind) =>
        _entries(ledgerId, month, kind)
            .snapshots(includeMetadataChanges: true)
            .map(
              (snapshot) => (
                docs: [
                  for (final doc in snapshot.docs)
                    (
                      id: doc.id,
                      data: doc.data(),
                      hasPendingWrites: doc.metadata.hasPendingWrites,
                    ),
                ],
                fromCache: snapshot.metadata.isFromCache,
              ),
            );

    return Rx.combineLatestList([
      watch(EntryKind.income),
      watch(EntryKind.fixedIncome),
      watch(EntryKind.planned),
      watch(EntryKind.extra),
      watch(EntryKind.cardBill),
    ]).map((snapshots) {
      final [incomes, fixedIncomes, planned, extras, cardBills] = snapshots;
      return monthLedgerFromFirestore(
        incomes: incomes.docs,
        fixedIncomes: fixedIncomes.docs,
        planned: planned.docs,
        extras: extras.docs,
        cardBills: cardBills.docs,
        unsentIds: unsentEntryIds(snapshots),
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
          _rejections.report((
            id: doc.id,
            month: month,
            kind: draft.kind,
            title: draft.title.trim(),
            amount: draft.amount,
          ));
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
    required EntryDraft base,
    required EntryDraft draft,
    required String uid,
    EditConflictChoice? choice,
  }) => _writeOnline(
    ledgerId,
    month,
    draft.kind,
    id,
    uid: uid,
    trashed: false,
    write: (transaction, doc, before) {
      // 화면을 연 뒤 상대가 바꾼 칸은 지키고 내가 바꾼 칸만 쓴다. 같은 칸이 겹치면 쓰지 않고 묻는다.
      final theirs = before == null ? base : EntryDraft.of(before);
      final (:merged, :conflicts) = mergeEntryEdit(
        base: base,
        mine: draft,
        theirs: theirs,
        choice: choice,
      );
      if (conflicts.isNotEmpty) {
        throw EntryEditConflict(fields: conflicts, theirs: theirs, mine: draft);
      }
      transaction.update(doc, entryUpdateData(merged, uid: uid));
      return entryActivity(
        ActivityAction.entryUpdate,
        month: month,
        kind: draft.kind,
        entry: merged,
        before: before == null ? null : theirs,
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
    try {
      return await _firestore.runTransaction(timeout: _onlineTimeout, (
        transaction,
      ) async {
        // 트랜잭션은 읽기를 모두 마친 뒤에 써야 한다.
        final missing =
            <(ExpenseTemplate, DocumentReference<Map<String, dynamic>>)>[];
        for (final template in templates) {
          // 넘겨받은 목록은 기기에 남은 캐시일 수 있다. 그사이 상대가 그만한(지운) 반복 설정으로 다시 만들지 않게,
          // 서버의 반복 설정을 같은 트랜잭션에서 읽어 없으면 건너뛰고 있으면 그 최신 값으로 채운다.
          final saved = await transaction.get(
            _ledger(ledgerId).collection('templates').doc(template.id),
          );
          final current = switch (saved.data()) {
            final data? => templateFromFirestore(saved.id, data),
            null => null,
          };
          if (current == null) continue;
          final doc = _entries(ledgerId, month, current.kind).doc(current.id);
          if (!(await transaction.get(doc)).exists) {
            missing.add((current, doc));
          }
        }
        for (final (template, doc) in missing) {
          transaction.set(
            doc,
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
  EntryKind.fixedIncome => 'fixedIncomes',
  EntryKind.planned => 'planned',
  EntryKind.extra => 'extras',
  EntryKind.cardBill => 'cardBills',
};

/// [kind] 항목의 날짜 필드 이름.
String entryDateField(EntryKind kind) => switch (kind) {
  EntryKind.income || EntryKind.fixedIncome => 'receivedOn',
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
    if (draft.kind case EntryKind.planned || EntryKind.fixedIncome)
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

/// 한 컬렉션의 스냅숏. [fromCache]는 서버와 이어지지 않아 기기 캐시로만 만든 스냅숏인지다.
typedef EntrySnapshot = ({List<EntryDoc> docs, bool fromCache});

/// 연결이 끊긴 채 더해 아직 서버에 올라가지 않은 항목 id([MonthLedger.unsentIds]).
///
/// 서버와 이어진 스냅숏의 대기 문서는 방금 저장해 응답을 기다리는 잠깐이라 넣지 않는다. 그래야 저장할 때마다 표시가 깜빡이지 않는다.
/// 고치기·휴지통·채우기는 트랜잭션이라 서버에 닿은 뒤에야 보이므로, 대기 문서는 새로 더한 항목뿐이다.
Set<String> unsentEntryIds(Iterable<EntrySnapshot> snapshots) => {
  for (final snapshot in snapshots)
    if (snapshot.fromCache)
      for (final doc in snapshot.docs)
        if (doc.hasPendingWrites) doc.id,
};

/// 거부된 새 항목 알림을 [stream]으로 낸다. 같은 항목은 한 번만 알리고, 듣는 쪽이 없을 때 온 알림은
/// 모아 뒀다가 처음 듣는 쪽에 넘긴다(앱을 켤 때의 확인이 홈 화면보다 먼저 끝날 수 있다).
class RejectionNotices {
  late final _controller = StreamController<RejectedEntry>.broadcast(
    onListen: _flush,
  );
  final _reported = <String>{};
  final _unheard = <RejectedEntry>[];

  Stream<RejectedEntry> get stream => _controller.stream;

  void report(RejectedEntry entry) {
    if (!_reported.add(entry.id)) return;
    if (_controller.hasListener) {
      _controller.add(entry);
    } else {
      _unheard.add(entry);
    }
  }

  void _flush() {
    for (final entry in _unheard) {
      _controller.add(entry);
    }
    _unheard.clear();
  }
}

/// 앱을 켤 때의 거부 확인에서 문서가 서버에 있는지. [snapshots]는 그 문서의 구독(메타데이터 변경 포함)을 옮긴 값이다.
///
/// 캐시가 아닌(서버가 답한) 첫 값으로 본다. 연결이 끊겨 있으면 Firestore 구독이 다시 이을 때까지 기다려서,
/// 한 번 읽기(`Source.server`)처럼 통신 오류로 확인 대상을 잃지 않는다.
/// 읽을 권한이 없으면(그사이 가계부에서 나감) null이다. 서버 답 없이 구독이 끝나도 null이다. 다른 오류는 그대로 던진다.
Future<bool?> existsOnServer(
  Stream<({bool exists, bool fromCache})> snapshots,
) async {
  try {
    await for (final snapshot in snapshots) {
      if (!snapshot.fromCache) return snapshot.exists;
    }
    return null;
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') return null;
    rethrow;
  }
}

/// 항목 문서 경로(`ledgers/{가계부}/months/{yyyy-MM}/{종류 컬렉션}/{id}`)에서 달과 종류를 읽는다. 항목 문서가 아니면 null.
({YearMonth month, EntryKind kind})? entryPlaceOf(String path) {
  if (path.split('/') case [
    'ledgers',
    _,
    'months',
    final monthId,
    final collection,
    _,
  ]) {
    final month = YearMonth.tryParse(monthId);
    final kind = EntryKind.values
        .where((kind) => entryCollection(kind) == collection)
        .firstOrNull;
    if (month != null && kind != null) return (month: month, kind: kind);
  }
  return null;
}

/// 거부된 새 항목 문서를 알림 값으로 바꾼다. 제목이 없는 종류(카드 대금)는 빈 제목이다.
RejectedEntry rejectedEntryOf(
  EntryDoc doc, {
  required YearMonth month,
  required EntryKind kind,
}) => (
  id: doc.id,
  month: month,
  kind: kind,
  title: switch (doc.data['title']) {
    final String title => title.trim(),
    _ => '',
  },
  amount: _won(doc.data['amount']),
);

/// 그달 다섯 컬렉션의 문서로 [MonthLedger]를 만든다. 휴지통 항목은 [MonthLedger.trashed]에 따로 모으고,
/// 읽을 수 없는 문서는 뺀다.
///
/// 고정 지출·고정 수입 문서 id는 휴지통 항목과 읽을 수 없는 문서까지 [MonthLedger.plannedIds]·[MonthLedger.fixedIncomeIds]에
/// 모은다. 반복 설정으로 채울 때 그 id의 문서를 다시 만들지 않게 한다.
MonthLedger monthLedgerFromFirestore({
  required List<EntryDoc> incomes,
  List<EntryDoc> fixedIncomes = const [],
  required List<EntryDoc> planned,
  required List<EntryDoc> extras,
  required List<EntryDoc> cardBills,
  Set<String> unsentIds = const {},
}) {
  bool trashed(EntryDoc doc) =>
      entryIsTrashed(doc.data, hasPendingWrites: doc.hasPendingWrites);
  // 공급자가 나눠 쓰는 값이라, 받은 쪽이 목록을 고쳐 알림 없이 값이 바뀌지 않게 모두 바꿀 수 없는 목록으로 만든다.
  List<T> live<T extends Object>(
    List<EntryDoc> docs,
    T? Function(String id, Map<String, dynamic> data) from,
  ) => List.unmodifiable([
    for (final doc in docs)
      if (!trashed(doc)) ?from(doc.id, doc.data),
  ]);
  return MonthLedger(
    incomes: live(incomes, incomeFromFirestore),
    fixedIncomes: live(fixedIncomes, fixedIncomeFromFirestore),
    plannedExpenses: live(planned, plannedExpenseFromFirestore),
    extraExpenses: live(extras, extraExpenseFromFirestore),
    cardBills: live(cardBills, cardBillFromFirestore),
    trashed: List.unmodifiable([
      for (final (kind, docs) in [
        (EntryKind.income, incomes),
        (EntryKind.fixedIncome, fixedIncomes),
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
    ]),
    plannedIds: Set.unmodifiable({for (final doc in planned) doc.id}),
    fixedIncomeIds: Set.unmodifiable({for (final doc in fixedIncomes) doc.id}),
    unsentIds: Set.unmodifiable(unsentIds),
  );
}

/// [kind] 종류의 Firestore 항목 문서를 항목으로 바꾼다. 계산에 쓰는 값이 없거나 잘못됐으면 null.
LedgerEntry? entryFromFirestore(
  EntryKind kind,
  String id,
  Map<String, dynamic> data,
) => switch (kind) {
  EntryKind.income => incomeFromFirestore(id, data),
  EntryKind.fixedIncome => fixedIncomeFromFirestore(id, data),
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

/// Firestore 고정 수입 문서를 [FixedIncome]으로 바꾼다. 누가·금액이 없거나 잘못됐으면 null.
FixedIncome? fixedIncomeFromFirestore(String id, Map<String, dynamic> data) {
  final memberId = data['memberId'];
  final amount = _won(data['amount']);
  if (memberId is! String || amount == null) return null;
  return FixedIncome(
    id: id,
    memberId: memberId,
    title: _title(data),
    amount: amount,
    receivedOn: entryDateFromFirestore(data['receivedOn']),
    dueOn: entryDateFromFirestore(data['dueOn']),
    memo: _memo(data),
  );
}

/// Firestore 추가 수입 문서를 [Income]으로 바꾼다. 누가·금액이 없거나 잘못됐으면 null.
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
