import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/model/household.dart';

/// 가구 홈. 월 요약 화면(3단계)이 생기기 전까지 가구 정보만 보여준다.
class HouseholdHomeScreen extends ConsumerWidget {
  const HouseholdHomeScreen({super.key});

  static String roleLabel(HouseholdRole? role) => switch (role) {
    HouseholdRole.owner => '관리자',
    HouseholdRole.editor => '편집자',
    HouseholdRole.viewer => '보기 전용',
    null => '구성원 아님',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider);
    final user = ref.watch(authUserProvider).value;
    if (household == null || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(household.name),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListTile(
            title: const Text('내 역할'),
            trailing: Text(roleLabel(household.roleOf(user.uid))),
          ),
          ListTile(
            title: const Text('구성원'),
            trailing: Text('${household.memberUids.length}명'),
          ),
          const SizedBox(height: 24),
          const Text('월 요약과 항목 입력 화면은 다음 단계에서 만들어요.'),
        ],
      ),
    );
  }
}
