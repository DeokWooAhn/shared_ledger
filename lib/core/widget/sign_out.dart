import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/usecases.dart';
import 'keep_all.dart';

/// 로그아웃하고, 실패하면 스낵바로 알린다.
/// 성공하면 화면 이동 규칙(router.dart)이 로그인 화면으로 옮긴다.
Future<void> signOutWithFeedback(BuildContext context, WidgetRef ref) async {
  // await 뒤에는 context가 사라졌을 수 있어서 미리 잡아 둔다.
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(authUseCasesProvider).signOut();
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(keepAll('로그아웃하지 못했어요. 잠시 후 다시 시도해 주세요.'))),
    );
    debugPrint('로그아웃 실패: $e');
  }
}
