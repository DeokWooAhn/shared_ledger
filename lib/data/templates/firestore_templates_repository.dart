import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/model/activity.dart';
import '../../domain/model/expense_template.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/trashed_entry.dart';
import '../../domain/model/year_month.dart';
import '../activity/firestore_activity_repository.dart';
import '../../domain/activity/activity_summary.dart';
import '../entries/firestore_entries_repository.dart';
import '../ledger/firestore_ledger_repository.dart';
import '../../domain/repository/templates_repository.dart';

class FirestoreTemplatesRepository implements TemplatesRepository {
  FirestoreTemplatesRepository(this._firestore, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> _templates(String ledgerId) =>
      _firestore.collection('ledgers').doc(ledgerId).collection('templates');

  @override
  Stream<List<ExpenseTemplate>> watchTemplates(String ledgerId) =>
      _templates(ledgerId).snapshots().map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            ?templateFromFirestore(doc.id, doc.data()),
        ],
      );

  DocumentReference<Map<String, dynamic>> _planned(
    String ledgerId,
    YearMonth month,
    String id,
  ) => _firestore
      .collection('ledgers')
      .doc(ledgerId)
      .collection('months')
      .doc(month.id)
      .collection(entryCollection(EntryKind.planned))
      .doc(id);

  @override
  Future<String> add({
    required String ledgerId,
    required YearMonth month,
    required TemplateDraft draft,
    required EntryDraft entry,
    required List<YearMonth> laterMonths,
    required String uid,
    bool recordMonth = false,
  }) async {
    // 새 id라 뒤 달에 같은 id의 항목이 있을 수 없어서 읽지 않고 만든다.
    final doc = _templates(ledgerId).doc();
    await _writeOnline(ledgerId, uid, (transaction) async {
      transaction.set(doc, newTemplateData(draft, uid: uid));
      transaction.set(
        _planned(ledgerId, month, doc.id),
        newEntryData(entry, uid: uid),
      );
      for (final later in laterMonths) {
        transaction.set(
          _planned(ledgerId, later, doc.id),
          newEntryData(laterEntryDraft(draft, later), uid: uid),
        );
      }
      if (recordMonth) {
        transaction.update(
          _firestore.collection('ledgers').doc(ledgerId),
          recordMonthUpdate(month),
        );
      }
      return [templateActivity(ActivityAction.templateCreate, draft)];
    });
    return doc.id;
  }

  @override
  Future<void> update({
    required String ledgerId,
    required String id,
    required YearMonth month,
    required TemplateDraft draft,
    required EntryDraft entry,
    required List<YearMonth> laterMonths,
    required String uid,
  }) {
    final doc = _templates(ledgerId).doc(id);
    final current = _planned(ledgerId, month, id);
    return _writeOnline(ledgerId, uid, (transaction) async {
      // 트랜잭션은 읽기를 모두 마친 뒤에 써야 한다.
      final before = await _existing(transaction, doc);
      final entryBefore = await _liveEntry(transaction, current);
      final later = await _unpaidLater(transaction, ledgerId, id, laterMonths);
      final beforeDraft = before == null ? null : TemplateDraft.of(before);
      final amountChanged = beforeDraft?.amount != draft.amount;
      transaction.update(doc, templateUpdateData(draft, uid: uid));
      transaction.update(current, entryUpdateData(entry, uid: uid));
      for (final (month, laterDoc) in later) {
        transaction.update(
          laterDoc,
          laterEntryUpdate(draft, month, uid: uid, withAmount: amountChanged),
        );
      }
      final entryBeforeDraft = entryBefore == null
          ? null
          : EntryDraft.of(entryBefore);
      return [
        if (beforeDraft != draft)
          templateActivity(
            ActivityAction.templateUpdate,
            draft,
            before: beforeDraft,
          ),
        if (entryBeforeDraft != entry)
          entryActivity(
            ActivityAction.entryUpdate,
            month: month,
            kind: EntryKind.planned,
            entry: entry,
            before: entryBeforeDraft,
          ),
      ];
    });
  }

  @override
  Future<List<YearMonth>> stop({
    required String ledgerId,
    required String id,
    required YearMonth month,
    required List<YearMonth> laterMonths,
    required String uid,
  }) async {
    final doc = _templates(ledgerId).doc(id);
    final current = _planned(ledgerId, month, id);
    var trashed = <YearMonth>[];
    await _writeOnline(ledgerId, uid, (transaction) async {
      final template = await _existing(transaction, doc);
      final entry = await _liveEntry(transaction, current);
      final later = await _unpaidLater(transaction, ledgerId, id, laterMonths);
      // 그달 항목은 이미 지급했으면 실제로 나간 돈이라 남기고, 지급 전이면 뒤 달과 같이 휴지통에 넣는다.
      // 반복 설정을 지워 다시 만들어지지 않으니 휴지통 항목은 보통처럼 자동으로 지워지게 한다.
      final targets = [if (entry?.isPaid != true) (month, current), ...later];
      final purgeAt = _now().add(trashRetention);
      transaction.delete(doc);
      for (final (_, entryDoc) in targets) {
        transaction.update(
          entryDoc,
          trashEntryUpdate(uid: uid, purgeAt: purgeAt),
        );
      }
      trashed = [for (final (month, _) in targets) month];
      return [
        templateActivity(
          ActivityAction.templateDelete,
          template == null ? null : TemplateDraft.of(template),
        ),
      ];
    });
    return trashed;
  }

  @override
  Future<void> resume({
    required String ledgerId,
    required ExpenseTemplate template,
    required List<YearMonth> months,
    required String uid,
  }) {
    final doc = _templates(ledgerId).doc(template.id);
    return _writeOnline(ledgerId, uid, (transaction) async {
      final exists = (await transaction.get(doc)).exists;
      final inTrash = <DocumentReference<Map<String, dynamic>>>[];
      for (final month in months) {
        final entryDoc = _planned(ledgerId, month, template.id);
        final data = (await transaction.get(entryDoc)).data();
        if (data != null && entryIsTrashed(data, hasPendingWrites: false)) {
          inTrash.add(entryDoc);
        }
      }
      final draft = TemplateDraft.of(template);
      if (!exists) transaction.set(doc, newTemplateData(draft, uid: uid));
      for (final entryDoc in inTrash) {
        transaction.update(entryDoc, restoreEntryUpdate(uid: uid));
      }
      return [
        if (!exists) templateActivity(ActivityAction.templateRestore, draft),
      ];
    });
  }

  // 그사이 지워졌으면 notFound로 실패한다. 문서는 있는데 모양이 잘못됐으면 null(기록에는 빈 값으로 남긴다).
  static Future<ExpenseTemplate?> _existing(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    final data = (await transaction.get(doc)).data();
    if (data == null) {
      throw const TemplateWriteException(TemplateWriteFailure.notFound);
    }
    return templateFromFirestore(doc.id, data);
  }

  // 휴지통 밖에 있는 그달 항목. 없거나 휴지통에 있으면(그사이 상대가 바꿈) notFound로 실패한다. 모양이 잘못됐으면 null.
  static Future<PlannedExpense?> _liveEntry(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    final data = (await transaction.get(doc)).data();
    if (data == null || entryIsTrashed(data, hasPendingWrites: false)) {
      throw const TemplateWriteException(TemplateWriteFailure.notFound);
    }
    return switch (entryFromFirestore(EntryKind.planned, doc.id, data)) {
      final PlannedExpense entry => entry,
      _ => null,
    };
  }

  // [laterMonths]에서 휴지통 밖에 있는 지급 전 [id] 항목. 지급한 것은 실제로 나간 돈이라 건드리지 않는다.
  Future<List<(YearMonth, DocumentReference<Map<String, dynamic>>)>>
  _unpaidLater(
    Transaction transaction,
    String ledgerId,
    String id,
    List<YearMonth> laterMonths,
  ) async {
    final unpaid = <(YearMonth, DocumentReference<Map<String, dynamic>>)>[];
    for (final month in laterMonths) {
      final doc = _planned(ledgerId, month, id);
      final data = (await transaction.get(doc)).data();
      if (data == null || entryIsTrashed(data, hasPendingWrites: false)) {
        continue;
      }
      if (entryFromFirestore(EntryKind.planned, id, data) case PlannedExpense(
        isPaid: false,
      )) {
        unpaid.add((month, doc));
      }
    }
    return unpaid;
  }

  // 트랜잭션은 서버에 닿아야 끝나서 오프라인이면 실패한다. 연결이 끊긴 채로 오래 기다리지 않게 10초만 기다린다.
  // [write]가 돌려준 변경 기록을 같은 트랜잭션에 남긴다. 빈 목록이면 남기지 않는다.
  Future<void> _writeOnline(
    String ledgerId,
    String uid,
    Future<List<ActivityDraft>> Function(Transaction transaction) write,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        for (final activity in await write(transaction)) {
          addActivity(
            transaction,
            _firestore,
            ledgerId: ledgerId,
            draft: activity,
            uid: uid,
            now: _now(),
          );
        }
      }, timeout: const Duration(seconds: 10));
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const TemplateWriteException(TemplateWriteFailure.offline);
      }
      rethrow;
    }
  }
}

/// 새 고정 지출 문서. `firestore.rules`의 validTemplate·createdNow와 필드가 같아야 한다.
///
/// 금액이 비어 있으면(금액 미정) 넣지 않는다.
Map<String, Object> newTemplateData(
  TemplateDraft draft, {
  required String uid,
}) => {
  for (final MapEntry(:key, :value) in _templateFields(draft).entries)
    if (value != null) key: value,
  'createdBy': uid,
  'updatedBy': uid,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// 고정 지출을 고칠 때 쓰는 값. 모든 칸을 다시 쓰고, 비운 금액은 필드를 지운다.
/// 만든 사람·시간은 그대로 두고 고친 사람·시간만 바꾼다(규칙의 updatedNow).
Map<Object, Object> templateUpdateData(
  TemplateDraft draft, {
  required String uid,
}) => {
  for (final MapEntry(:key, :value) in _templateFields(draft).entries)
    key: value ?? FieldValue.delete(),
  'updatedBy': uid,
  'updatedAt': FieldValue.serverTimestamp(),
};

/// 이미 만들어진 뒤 달에 넣을 고정 지출 항목(지급 전). 반복 설정 [draft]로 [month]의 예정일을 정한다.
EntryDraft laterEntryDraft(TemplateDraft draft, YearMonth month) => EntryDraft(
  kind: EntryKind.planned,
  memberId: draft.memberId,
  amount: draft.amount,
  title: draft.title.trim(),
  categoryId: draft.categoryId,
  paymentMethodId: draft.paymentMethodId,
  dueOn: switch (draft.dueDay) {
    final day? => dueDateIn(month, day),
    null => null,
  },
);

/// 뒤 달의 지급 전 고정 지출을 반복 설정 [draft]에 맞출 때 쓰는 값. 반복 설정이 정하는 칸만 바꾸고 지급·메모는 그대로 둔다.
/// [withAmount]면 금액도 맞춘다(비운 금액은 필드를 지운다). 고친 사람·시간도 바꾼다(규칙의 updatedNow).
Map<Object, Object> laterEntryUpdate(
  TemplateDraft draft,
  YearMonth month, {
  required String uid,
  required bool withAmount,
}) => {
  'title': draft.title.trim(),
  'memberId': draft.memberId,
  'categoryId': ?draft.categoryId,
  'paymentMethodId': ?draft.paymentMethodId,
  if (draft.dueDay case final day?)
    'dueOn': entryDateToFirestore(dueDateIn(month, day)),
  if (withAmount) 'amount': draft.amount ?? FieldValue.delete(),
  'updatedBy': uid,
  'updatedAt': FieldValue.serverTimestamp(),
};

// 고정 지출이 쓰는 칸(docs/firestore.md의 templates 표). 값이 null이면 비어 있는 칸이다.
Map<String, Object?> _templateFields(TemplateDraft draft) => {
  'title': draft.title.trim(),
  'amount': draft.amount,
  'categoryId': draft.categoryId,
  'paymentMethodId': draft.paymentMethodId,
  'memberId': draft.memberId,
  'dueDay': draft.dueDay,
};

/// Firestore 고정 지출 문서를 [ExpenseTemplate]로 바꾼다.
///
/// 그달 고정 지출을 만드는 데 쓰는 값(누가·분류·결제수단·예정일)이 없거나 잘못됐거나, 금액이 잘못됐으면 null.
/// 금액이 비어 있으면 금액 미정이다. 제목은 없어도 빈 제목으로 살린다.
ExpenseTemplate? templateFromFirestore(String id, Map<String, dynamic> data) {
  final memberId = data['memberId'];
  final categoryId = data['categoryId'];
  final paymentMethodId = data['paymentMethodId'];
  final rawAmount = data['amount'];
  final amount = switch (rawAmount) {
    final int won when won >= 0 => won,
    _ => null,
  };
  final dueDay = switch (data['dueDay']) {
    final int day when day >= 1 && day <= lastDueDay => day,
    _ => null,
  };
  if (memberId is! String ||
      categoryId is! String ||
      paymentMethodId is! String ||
      dueDay == null ||
      (rawAmount != null && amount == null)) {
    return null;
  }
  return ExpenseTemplate(
    id: id,
    title: switch (data['title']) {
      final String title => title,
      _ => '',
    },
    amount: amount,
    categoryId: categoryId,
    paymentMethodId: paymentMethodId,
    memberId: memberId,
    dueDay: dueDay,
  );
}
