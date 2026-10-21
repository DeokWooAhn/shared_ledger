import 'package:flutter/material.dart';

/// 입력란 위에 이름표를 붙인다. 디자인은 입력란 안에 떠 있는 라벨 대신 위에 따로 둔다.
class LabeledField extends StatelessWidget {
  const LabeledField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
