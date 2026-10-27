import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 레이어 규칙(AGENTS.md '프로젝트 구조'). 패키지 하나 안에서 폴더로 나눈 구조라 빌드가 막아 주지 않아서,
/// lib의 import를 읽어 어기면 실패한다.
///
/// - domain: 다른 레이어와 패키지를 import하지 않는다(순수 Dart, dart: 만)
/// - data: domain과 Firebase 패키지만
/// - core: domain과 Flutter·Riverpod만. data·feature는 못 본다
/// - feature/<기능>: domain·core와 자기 기능 폴더, Flutter·Riverpod·go_router만. data와 다른 기능은 못 본다
/// - lib 바로 아래(main·app·router·di): 모두 조립하는 자리라 제한이 없다
///
/// 새 패키지를 들이면(먼저 승인을 받는다) 여기 허용 목록도 같이 고친다.
const _allowedPackages = <String, Set<String>>{
  'domain': {},
  'data': {'cloud_firestore', 'firebase_auth', 'google_sign_in'},
  'core': {'flutter', 'flutter_riverpod'},
  'feature': {'flutter', 'flutter_riverpod', 'go_router'},
};

/// lib 안의 파일이 속한 레이어. 기능 폴더는 'feature/<기능>'.
String _layerOf(String libPath) {
  final parts = libPath.split('/');
  if (parts.length == 2) return 'app';
  if (parts[1] == 'feature') return 'feature/${parts[2]}';
  return parts[1];
}

bool _mayImport(String from, String to) => switch (from) {
  'domain' => to == 'domain',
  'data' => to == 'domain' || to == 'data',
  'core' => to == 'domain' || to == 'core',
  _ when from.startsWith('feature/') =>
    to == 'domain' || to == 'core' || to == from,
  _ => true,
};

final _importPattern = RegExp(r"^import '([^']+)'", multiLine: true);

/// lib의 모든 파일과 그 import 대상: (파일, import 문자열, 대상 레이어 또는 패키지 이름).
List<({String file, String spec, String layer})> _imports() {
  final result = <({String file, String spec, String layer})>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    for (final match in _importPattern.allMatches(file.readAsStringSync())) {
      final spec = match.group(1)!;
      if (spec.startsWith('dart:')) continue;
      if (spec.startsWith('package:shared_ledger/')) {
        final target = 'lib/${spec.substring('package:shared_ledger/'.length)}';
        result.add((file: path, spec: spec, layer: _layerOf(target)));
      } else if (spec.startsWith('package:')) {
        result.add((file: path, spec: spec, layer: 'package'));
      } else {
        final target = File(
          '${file.parent.path}/$spec',
        ).uri.normalizePath().path.replaceAll(r'\', '/');
        final relative = target.substring(target.indexOf('lib/'));
        result.add((file: path, spec: spec, layer: _layerOf(relative)));
      }
    }
  }
  return result;
}

String _packageOf(String spec) => spec.substring(8).split('/').first;

void main() {
  final imports = _imports();

  test('lib의 파일을 찾는다(검사가 빈 목록으로 통과하지 않게)', () {
    expect(imports.map((i) => _layerOf(i.file)).toSet(), {
      'app',
      'domain',
      'data',
      'core',
      for (final i in imports)
        if (_layerOf(i.file).startsWith('feature/')) _layerOf(i.file),
    });
  });

  test('레이어는 정해진 방향으로만 import한다', () {
    final violations = [
      for (final i in imports)
        if (i.layer != 'package' && !_mayImport(_layerOf(i.file), i.layer))
          '${i.file} → ${i.spec} (${_layerOf(i.file)}는 ${i.layer}를 볼 수 없다)',
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('레이어마다 허용한 패키지만 import한다', () {
    final violations = [
      for (final i in imports)
        if (i.layer == 'package')
          if (_allowedPackages[_layerOf(i.file).split('/').first]
              case final allowed? when !allowed.contains(_packageOf(i.spec)))
            '${i.file} → ${i.spec}',
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('규칙 검사가 실제로 잡아낸다', () {
    expect(_mayImport('domain', 'data'), isFalse);
    expect(_mayImport('core', 'data'), isFalse);
    expect(_mayImport('feature/entries', 'data'), isFalse);
    expect(_mayImport('feature/entries', 'feature/settings'), isFalse);
    expect(_mayImport('feature/entries', 'core'), isTrue);
    expect(_mayImport('app', 'data'), isTrue);
  });
}
