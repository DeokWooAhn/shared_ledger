import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'back_circle_button.dart';
import 'keep_all.dart';
import 'labeled_field.dart';
import 'won_input.dart';

// 뒤로 단추로 닫는 전체 화면 입력(항목 입력·고정 지출 입력)이 같이 쓰는 부품. 디자인은 design/app/05.

/// 입력 화면 맨 위의 뒤로 단추와 제목.
class FormNavBar extends StatelessWidget {
  const FormNavBar({required this.title, required this.closeKey, super.key});

  final String title;

  /// 테스트에서 뒤로 단추를 찾을 키.
  final Key closeKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          BackCircleButton(key: closeKey),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// 큰 글자의 금액 입력란. 숫자만 받고 세 자리마다 쉼표를 넣는다.
/// [optional]이면 비워 둘 수 있다(금액 미정).
///
/// 디자인처럼 '원'을 숫자 바로 뒤에 붙이려고 입력란은 글자 폭만큼만 두고 밑줄은 줄 전체에 직접 그린다.
/// (InputDecoration의 suffix는 초점이 있을 때만 나타나는데, LabeledField 안에서 나타났다 사라지면
/// Flutter 3.47의 semantics 단언이 깨진다.)
class WonAmountField extends StatefulWidget {
  const WonAmountField({
    required this.controller,
    required this.fieldKey,
    required this.optional,
    required this.autofocus,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
    this.textInputAction,
    this.onEditingComplete,
    this.identifier,
    super.key,
  });

  final TextEditingController controller;

  /// 테스트에서 입력란을 찾을 키.
  final Key fieldKey;
  final bool optional;
  final bool autofocus;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;

  /// 키보드의 완료 키 종류. [onEditingComplete]로 다음 칸에 초점을 옮길 때 [TextInputAction.next]를 준다.
  final TextInputAction? textInputAction;

  /// 키보드의 완료 키를 눌렀을 때. null이면 [textInputAction]의 기본 동작을 따른다.
  final VoidCallback? onEditingComplete;

  /// 실제 기기의 접근성 계층에서 입력란을 찾을 식별자.
  final String? identifier;

  @override
  State<WonAmountField> createState() => _WonAmountFieldState();
}

class _WonAmountFieldState extends State<WonAmountField> {
  // 초점에 따라 밑줄 색이 바뀌는 것은 이 칸에서만 쓰는 상태다.
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() => setState(() {});

  // 줄 어디를 눌러도 입력을 받는다. 초점은 남은 채 키보드만 내려가 있으면 requestFocus가 아무것도 하지 않아서
  // 키보드를 직접 다시 띄운다.
  void _showKeyboard() {
    if (_focus.hasFocus) {
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    } else {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final errorText = widget.errorText;
    final helper = widget.optional ? '비워 두면 금액 미정으로 저장돼요.' : null;
    final number = theme.textTheme.headlineMedium?.copyWith(fontSize: 36);
    final (lineColor, lineWidth) = errorText != null
        ? (scheme.error, _focus.hasFocus ? 2.0 : 1.0)
        : _focus.hasFocus
        ? (scheme.tertiary, 2.0)
        : (scheme.outline, 1.0);
    return LabeledField(
      label: '금액',
      identifier: widget.identifier,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          // 숫자 오른쪽 빈 곳을 눌러도 입력란에 들어가게 한다. 화면 읽기 도구에는 입력란만 알린다.
          // 입력란의 일부로 쳐서, 이 줄을 눌러도 아래의 '밖을 누르면 키보드를 닫는' 동작이 일어나지 않게 한다.
          TextFieldTapRegion(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              excludeFromSemantics: true,
              onTap: widget.enabled ? _showKeyboard : null,
              child: Container(
                padding: EdgeInsets.only(bottom: 12 - (lineWidth - 1)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: lineColor, width: lineWidth),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  spacing: 4,
                  children: [
                    Flexible(
                      child: IntrinsicWidth(
                        child: TextField(
                          key: widget.fieldKey,
                          controller: widget.controller,
                          focusNode: _focus,
                          enabled: widget.enabled,
                          autofocus: widget.autofocus,
                          keyboardType: TextInputType.number,
                          textInputAction: widget.textInputAction,
                          onEditingComplete: widget.onEditingComplete,
                          // 입력 중에 다른 곳을 누르거나 스크롤하면 키보드를 닫는다. 초점이 남으면 다음 그리기 때
                          // 입력란이 커서를 보이려고 화면을 되돌린다.
                          onTapOutside: (_) => _focus.unfocus(),
                          inputFormatters: const [WonInputFormatter()],
                          style: number,
                          // 밑줄은 줄 전체에 직접 그리므로 테마의 바탕·테두리를 모두 끈다.
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText: widget.optional ? '금액 미정' : '0',
                            hintStyle: number?.copyWith(
                              color: context.appColors.textMuted,
                            ),
                          ),
                          onChanged: widget.onChanged,
                        ),
                      ),
                    ),
                    // 화면 읽기 도구에는 숫자만 읽힌다.
                    ExcludeSemantics(
                      child: Text(
                        '원',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (errorText != null)
            Text(
              errorText,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            )
          else if (helper != null)
            Text(keepAll(helper), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 이름표와 고르기 단추 묶음. 단추마다 고른 상태를 화면 읽기 도구에 알린다.
class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    required this.label,
    required this.children,
    this.errorText,
    this.empty,
    this.note,
    this.noteKey,
    super.key,
  });

  final String label;
  final List<Widget> children;
  final String? errorText;

  /// 고를 것이 없을 때의 안내.
  final String? empty;

  /// 단추 아래 안내 상자(카드 결제 안내).
  final String? note;

  /// 테스트에서 안내 상자를 찾을 키.
  final Key? noteKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final errorText = this.errorText;
    final empty = this.empty;
    final note = this.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Semantics(
          header: true,
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        if (empty != null)
          Text(keepAll(empty), style: theme.textTheme.bodySmall)
        else
          Wrap(spacing: 8, runSpacing: 8, children: children),
        if (errorText != null)
          Text(
            errorText,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        if (note != null)
          Container(
            key: noteKey,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              spacing: 6,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: scheme.onPrimaryContainer,
                ),
                Expanded(
                  child: Text(
                    keepAll(note),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 고르기 단추. 고르면 버튼 색(primary)으로 채우고 체크 표시를 붙인다(색만으로 구분하지 않는다).
/// 단추는 높이 40이지만 누르는 곳은 48이다(Material 칩의 기본 여백).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.identifier,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  /// 실제 기기의 접근성 계층에서 선택 단추를 찾을 식별자.
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.primary;
    final onSelected = this.onSelected;
    return ChoiceChip(
      label: Text(label, semanticsIdentifier: identifier),
      selected: selected,
      onSelected: onSelected == null ? null : (_) => onSelected(),
      showCheckmark: true,
      checkmarkColor: scheme.onPrimary,
      selectedColor: fill,
      disabledColor: selected ? fill : scheme.surfaceContainerLowest,
      backgroundColor: scheme.surfaceContainerLowest,
      side: BorderSide(color: selected ? fill : scheme.outline),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? scheme.onPrimary : scheme.onSurface,
      ),
    );
  }
}
