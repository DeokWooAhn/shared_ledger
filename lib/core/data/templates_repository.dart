import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/activity.dart';
import '../model/expense_template.dart';
import 'activity_repository.dart';
import 'activity_summary.dart';

/// 고정 지출을 더하거나 고치거나 지우지 못한 이유.
enum TemplateWriteFailure {
  /// 연결이 없거나 서버가 답하지 않는다. 고정 지출은 두 사람의 목록이 엇갈리지 않게 온라인에서만 바꾼다.
  offline,

  /// 그사이 상대가 지웠다.
  notFound,
}

class TemplateWriteException implements Exception {
  const TemplateWriteException(this.reason);

  final TemplateWriteFailure reason;

  @override
  String toString() => 'TemplateWriteException($reason)';
}

/// 고정 지출(템플릿)을 읽고 쓴다. 이 목록으로 새 달의 기본 월 지출이 만들어진다.
///
/// 쓰기는 모두 서버에 바로 닿아야 하는 트랜잭션이라 연결이 없으면
/// [TemplateWriteException]([TemplateWriteFailure.offline])으로 실패한다.
/// 고치거나 지워도 이미 만든 달의 기본 월 지출은 그대로다. 쓸 때마다 변경 기록을 같은 트랜잭션으로 남긴다.
abstract interface class TemplatesRepository {
  /// 가계부의 고정 지출 전부. 순서는 화면이 정한다.
  Stream<List<ExpenseTemplate>> watchTemplates(String ledgerId);

  /// 고정 지출을 더하고 id를 돌려준다. 작성자는 [uid]다.
  Future<String> add({
    required String ledgerId,
    required TemplateDraft draft,
    required String uid,
  });

  /// [id] 고정 지출을 [draft]로 고친다.
  Future<void> update({
    required String ledgerId,
    required String id,
    required TemplateDraft draft,
    required String uid,
  });

  /// [id] 고정 지출을 지운다. 이미 만든 달의 기본 월 지출은 남는다. 변경 기록은 [uid]의 이름으로 남는다.
  Future<void> delete({
    required String ledgerId,
    required String id,
    required String uid,
  });

  /// 지운 [template]를 같은 id로 다시 만든다(되돌리기). 그사이 같은 id의 문서가 생겼으면 그대로 둔다.
  Future<void> restore({
    required String ledgerId,
    required ExpenseTemplate template,
    required String uid,
  });
}

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

  @override
  Future<String> add({
    required String ledgerId,
    required TemplateDraft draft,
    required String uid,
  }) async {
    final doc = _templates(ledgerId).doc();
    await _writeOnline(ledgerId, uid, (transaction) async {
      transaction.set(doc, newTemplateData(draft, uid: uid));
      return templateActivity(ActivityAction.templateCreate, draft);
    });
    return doc.id;
  }

  @override
  Future<void> update({
    required String ledgerId,
    required String id,
    required TemplateDraft draft,
    required String uid,
  }) {
    final doc = _templates(ledgerId).doc(id);
    return _writeOnline(ledgerId, uid, (transaction) async {
      final before = await _existing(transaction, doc);
      transaction.update(doc, templateUpdateData(draft, uid: uid));
      return templateActivity(
        ActivityAction.templateUpdate,
        draft,
        before: before == null ? null : TemplateDraft.of(before),
      );
    });
  }

  @override
  Future<void> delete({
    required String ledgerId,
    required String id,
    required String uid,
  }) {
    final doc = _templates(ledgerId).doc(id);
    return _writeOnline(ledgerId, uid, (transaction) async {
      final template = await _existing(transaction, doc);
      transaction.delete(doc);
      return templateActivity(
        ActivityAction.templateDelete,
        template == null ? null : TemplateDraft.of(template),
      );
    });
  }

  @override
  Future<void> restore({
    required String ledgerId,
    required ExpenseTemplate template,
    required String uid,
  }) {
    final doc = _templates(ledgerId).doc(template.id);
    return _writeOnline(ledgerId, uid, (transaction) async {
      if ((await transaction.get(doc)).exists) return null;
      final draft = TemplateDraft.of(template);
      transaction.set(doc, newTemplateData(draft, uid: uid));
      return templateActivity(ActivityAction.templateRestore, draft);
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

  // 트랜잭션은 서버에 닿아야 끝나서 오프라인이면 실패한다. 연결이 끊긴 채로 오래 기다리지 않게 10초만 기다린다.
  // [write]가 돌려준 변경 기록을 같은 트랜잭션에 남긴다. null이면 아무것도 쓰지 않은 것이라 남기지 않는다.
  Future<void> _writeOnline(
    String ledgerId,
    String uid,
    Future<ActivityDraft?> Function(Transaction transaction) write,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final activity = await write(transaction);
        if (activity == null) return;
        addActivity(
          transaction,
          _firestore,
          ledgerId: ledgerId,
          draft: activity,
          uid: uid,
          now: _now(),
        );
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
/// 그달 기본 월 지출을 만드는 데 쓰는 값(누가·분류·결제수단·예정일)이 없거나 잘못됐거나, 금액이 잘못됐으면 null.
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
