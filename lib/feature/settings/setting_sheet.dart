import 'package:flutter/material.dart';

import '../../core/widget/keep_all.dart';
import '../../domain/model/name_problem.dart';
import 'setting_form.dart';

// 설정을 고치는 아래 시트(이름 바꾸기·분류·결제수단)가 같이 쓰는 틀과 문구.

/// 시트의 최대 폭. 넓은 화면에서는 이 폭으로 가운데 둔다.
const settingSheetMaxWidth = 560.0;

/// 이름 칸 아래에 보여 줄 문구.
String nameProblemMessage(NameProblem problem, {required int maxLength}) =>
    switch (problem) {
      NameProblem.missing => '이름을 입력해 주세요.',
      NameProblem.tooLong => '이름은 $maxLength자까지 쓸 수 있어요.',
      NameProblem.taken => '같은 이름이 이미 있어요.',
    };

String settingFormFailureMessage(SettingFormFailure failure) =>
    switch (failure) {
      SettingFormFailure.offline =>
        '인터넷에 연결된 뒤에 다시 시도해 주세요. 설정은 연결돼 있을 때만 바꿀 수 있어요.',
      SettingFormFailure.gone => '그사이 없어져서 바꾸지 못했어요.',
      SettingFormFailure.save => '저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
    };

/// 시트가 닫힌 뒤 목록 화면이 스낵바로 알릴 문구. 저장은 목록에 바로 보여서 알리지 않는다.
String? settingOutcomeMessage(SettingFormOutcome? outcome) => switch (outcome) {
  SettingFormOutcome.hidden => '숨겼어요. 지난 항목과 합계에는 그대로 남아요.',
  SettingFormOutcome.shown => '다시 보이게 했어요.',
  SettingFormOutcome.saved || null => null,
};

/// 설정 시트를 연다. 탭 막대까지 덮게 앱 맨 위에 띄우고, 넓은 화면에서는 [settingSheetMaxWidth] 폭이다.
/// 시트가 닫히며 돌려준 값을 돌려준다.
Future<T?> showSettingSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: settingSheetMaxWidth),
      builder: builder,
    );

/// 설정 시트의 틀. 제목과 내용을 세로로 쌓고, 키보드가 올라오면 그만큼 올라간다.
class SettingSheet extends StatelessWidget {
  const SettingSheet({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// 시트 안에 보여 줄 실패 한 줄. 스낵바는 시트 뒤에 가려서 시트 안에 둔다.
class SheetFailureText extends StatelessWidget {
  const SheetFailureText(this.failure, {super.key});

  final SettingFormFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        keepAll(settingFormFailureMessage(failure)),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

/// 숨기기·다시 보이기 단추와 그 설명. 숨기면 새로 고를 수 없을 뿐 지난 항목은 그대로라고 알린다.
class HideButton extends StatelessWidget {
  const HideButton({required this.hidden, required this.onPressed, super.key});

  /// 지금 숨겨져 있는지. 숨겨져 있으면 '다시 보이기'다.
  final bool hidden;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        TextButton.icon(
          key: Key(hidden ? 'setting-show' : 'setting-hide'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: onPressed,
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
          label: Text(hidden ? '다시 보이기' : '숨기기'),
        ),
        Text(
          keepAll(
            hidden
                ? '다시 보이게 하면 새 항목과 고정 지출에서 다시 고를 수 있어요.'
                : '숨기면 새 항목과 고정 지출에서 고를 수 없어요. 지난 항목과 합계에는 그대로 남아요.',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}
