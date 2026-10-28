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
/// - 저장소 자리(core/providers/repositories.dart)는 feature가 보지 못하고 아무도 export하지 않는다.
///   feature는 UseCase 홀더(usecases.dart)로만 저장소에 닿는다(AGENTS.md 'UseCase')
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

/// 저장소 자리. 레이어 표로는 core 안의 파일이라 feature가 볼 수 있어서 따로 막는다.
const _repositorySlots = 'lib/core/providers/repositories.dart';

/// [from] 레이어의 파일이 [directive](import·export)로 [target](lib 안의 경로)을 가리켜도 되는지.
///
/// 저장소 자리는 UseCase 홀더(core)와 조립(앱)만 import한다. export하면 그 파일을 import한 feature가 저장소를 보게 된다.
bool _mayReach(String from, String directive, String target) =>
    target != _repositorySlots ||
    (directive == 'import' && !from.startsWith('feature/'));

// export도 본다. core가 data를 export하면 feature가 core를 거쳐 data를 볼 수 있다.
// 지시문 전체(;까지)를 잡고 그 안의 문자열을 모두 URI로 본다. 따옴표 종류·줄바꿈과 상관없고,
// 조건부 import·export의 대체 URI(`if (dart.library.io) 'b.dart'`)도 빠뜨리지 않는다.
final _directivePattern = RegExp(
  r'^(import|export)\b([^;]*);',
  multiLine: true,
);
final _uriPattern = RegExp(r'''['"]([^'"]+)['"]''');

/// [source]의 import·export 지시문이 가리키는 URI 전부.
List<({String directive, String uri})> _directivesOf(String source) => [
  for (final directive in _directivePattern.allMatches(source))
    for (final uri in _uriPattern.allMatches(directive.group(2)!))
      (directive: directive.group(1)!, uri: uri.group(1)!),
];

typedef _Import = ({
  String file,
  String directive,
  String spec,

  /// 가리키는 lib 안의 경로. 패키지나 lib 밖이면 null.
  String? target,
  String layer,
});

/// lib의 모든 파일과 그 import 대상: (파일, import·export, import 문자열, 대상 경로, 대상 레이어 또는 패키지 이름).
List<_Import> _imports() {
  final result = <_Import>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    for (final (:directive, uri: spec) in _directivesOf(
      file.readAsStringSync(),
    )) {
      if (spec.startsWith('dart:')) continue;
      final String? target;
      if (spec.startsWith('package:shared_ledger/')) {
        target = 'lib/${spec.substring('package:shared_ledger/'.length)}';
      } else if (spec.startsWith('package:')) {
        target = null;
      } else {
        final resolved = File(
          '${file.parent.path}/$spec',
        ).uri.normalizePath().path.replaceAll(r'\', '/');
        final at = resolved.indexOf('lib/');
        target = at < 0 ? null : resolved.substring(at);
      }
      final layer = switch (target) {
        final target? => _layerOf(target),
        null when spec.startsWith('package:') => 'package',
        // lib 밖을 가리키면 어느 레이어도 아니라서 위반으로 잡는다.
        null => 'lib 밖',
      };
      result.add((
        file: path,
        directive: directive,
        spec: spec,
        target: target,
        layer: layer,
      ));
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

  test('feature는 저장소 자리를 import하지 않고, 아무도 저장소 자리를 export하지 않는다', () {
    // 경로를 제대로 풀었는지: 저장소 자리를 import하는 곳(UseCase 홀더, 조립)이 있어야 한다.
    expect(imports.where((i) => i.target == _repositorySlots), isNotEmpty);
    final violations = [
      for (final i in imports)
        if (i.target case final target?
            when !_mayReach(_layerOf(i.file), i.directive, target))
          '${i.file} → ${i.directive} ${i.spec} (UseCase 홀더 usecases.dart를 쓴다)',
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
    expect(_mayImport('core', 'lib 밖'), isFalse);
    expect(_directivesOf("export '../../data/x.dart';"), [
      (directive: 'export', uri: '../../data/x.dart'),
    ]);
    expect(_directivesOf('import "../../data/x.dart" show X;'), [
      (directive: 'import', uri: '../../data/x.dart'),
    ]);
    expect(
      _directivesOf(
        "import 'a.dart'\n    if (dart.library.io) '../core/providers/repositories.dart';",
      ),
      [
        (directive: 'import', uri: 'a.dart'),
        (directive: 'import', uri: '../core/providers/repositories.dart'),
      ],
    );
    expect(_mayReach('feature/entries', 'import', _repositorySlots), isFalse);
    expect(_mayReach('core', 'export', _repositorySlots), isFalse);
    expect(_mayReach('core', 'import', _repositorySlots), isTrue);
    expect(_mayReach('app', 'import', _repositorySlots), isTrue);
    expect(
      _mayReach(
        'feature/entries',
        'import',
        'lib/core/providers/usecases.dart',
      ),
      isTrue,
    );
  });
}
