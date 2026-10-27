import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/usecases.dart';
import '../../domain/repository/templates_repository.dart';
import '../../domain/model/expense_template.dart';

/// 스낵바로 알릴 일회성 실패.
enum TemplatesFailure {
  /// 되돌리기는 온라인에서만 된다.
  restoreOffline,
  restore,
}

/// 고정 지출 탭 상태. 목록은 공급자(templatesProvider)에서 그리고, 여기에는 동작의 진행 상태만 둔다.
@immutable
class TemplatesState {
  const TemplatesState({this.restoring = false, this.failure});

  /// 지운 고정 지출을 되돌리는 중이다.
  final bool restoring;

  /// 스낵바로 알릴 실패. 화면이 알린 뒤 [TemplatesNotifier.failureShown]으로 끈다.
  final TemplatesFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is TemplatesState &&
      other.restoring == restoring &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(restoring, failure);
}

final templatesNotifierProvider =
    NotifierProvider.autoDispose<TemplatesNotifier, TemplatesState>(
      TemplatesNotifier.new,
    );

/// 고정 지출 탭의 Notifier. 입력 화면에서 지운 고정 지출을 '되돌리기'로 살린다.
class TemplatesNotifier extends Notifier<TemplatesState> {
  @override
  TemplatesState build() => const TemplatesState();

  /// 지운 [template]를 같은 id로 다시 만든다. 온라인에서만 된다.
  Future<void> restore(ExpenseTemplate template) async {
    final uid = ref.read(authUserProvider).value?.uid;
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (state.restoring || uid == null || ledgerId == null) return;
    state = const TemplatesState(restoring: true);
    try {
      await ref
          .read(templateUseCasesProvider)
          .restoreTemplate(ledgerId: ledgerId, template: template, uid: uid);
      if (!ref.mounted) return;
      state = const TemplatesState();
    } on TemplateWriteException catch (e) {
      if (!ref.mounted) return;
      state = TemplatesState(
        failure: switch (e.reason) {
          TemplateWriteFailure.offline => TemplatesFailure.restoreOffline,
          // 되돌리기는 없는 문서를 만드는 것이라 notFound로 실패하지 않는다.
          TemplateWriteFailure.notFound => TemplatesFailure.restore,
        },
      );
    } catch (e) {
      debugPrint('고정 지출 되돌리기 실패: $e');
      if (!ref.mounted) return;
      state = const TemplatesState(failure: TemplatesFailure.restore);
    }
  }

  /// 화면이 실패를 알린 뒤 부른다.
  void failureShown() => state = TemplatesState(restoring: state.restoring);
}
