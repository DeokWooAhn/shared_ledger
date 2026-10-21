import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/household_repository.dart';
import '../../core/data/providers.dart';

/// 가구 이름 검사. 통과하면 null, 아니면 안내 문구.
String? validateHouseholdName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return '가구 이름을 입력해 주세요.';
  if (name.length > householdNameMaxLength) {
    return '가구 이름은 $householdNameMaxLength자까지 쓸 수 있어요.';
  }
  return null;
}

/// 첫 가구 만들기. 만든 사람이 관리자가 된다.
class CreateHouseholdScreen extends ConsumerStatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  ConsumerState<CreateHouseholdScreen> createState() =>
      _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends ConsumerState<CreateHouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: '우리집');
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authUserProvider).value;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(householdRepositoryProvider)
          .create(name: _name.text.trim(), ownerUid: user.uid);
      // 가구 목록이 바뀌면 화면 이동 규칙이 홈으로 옮긴다.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가구를 만들지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
      debugPrint('가구 만들기 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가구 만들기'),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('가계부를 함께 쓸 가구를 만들어요. 가족은 만든 뒤에 초대할 수 있어요.'),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('household-name'),
                controller: _name,
                enabled: !_busy,
                maxLength: householdNameMaxLength,
                decoration: const InputDecoration(labelText: '가구 이름'),
                validator: validateHouseholdName,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('create-household'),
                onPressed: _busy ? null : _create,
                child: const Text('만들기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
