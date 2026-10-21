import 'package:flutter/material.dart';

/// 입력란 위에 이름표를 붙인다. 디자인은 입력란 안에 떠 있는 라벨 대신 위에 따로 둔다.
///
/// 이름표가 입력란 밖에 있어서, 화면 읽기 도구가 입력란만 읽으면 무엇을 넣는 칸인지 모른다.
/// [MergeSemantics]로 이름표와 입력란을 한 덩어리로 읽게 한다.
class LabeledField extends StatelessWidget {
  const LabeledField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
