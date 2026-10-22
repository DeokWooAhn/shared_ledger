---
name: verification
description: 심플 공유 가계부(shared_ledger)에서 코드를 바꾼 뒤 검증할 때, 테스트를 돌릴 때, 기기·시뮬레이터·로컬 Firestore 에뮬레이터로 실행할 때, GitHub Actions CI 실패 원인을 찾을 때 쓴다. "테스트 돌려줘", "빌드 확인해줘", "기기에서 실행이 안 돼", "CI 왜 실패했어" 같은 요청이 해당된다. 검사 명령(보안 규칙 테스트 포함), 기기 실행, CI 실패 분석 순서가 들어 있다. 테스트를 쓰는 법은 testing 스킬.
---

# 검증

가장 작은 관련 범위부터 검증한다. 실행하지 않은 것을 통과했다고 말하지 않는다.

## 절차

1. 바뀐 동작을 특정한다.
2. 관련 테스트를 찾는다. `test/`는 `lib/`와 같은 구조다.
3. 그 테스트 파일만 먼저 돌린다: `fvm flutter test test/router_test.dart`
4. 필요할 때만 넓힌다.
   - `firestore.rules`를 건드렸으면 보안 규칙 테스트
   - `android/`·`ios/`·`pubspec.yaml`을 건드렸으면 해당 플랫폼 빌드
5. 끝내기 전에 CI와 같은 세 가지(포맷·분석·전체 테스트)를 돌린다.
6. 실행한 명령과 결과를 그대로 보고한다. 실패했으면 실패했다고 말하고 출력을 붙인다.

## 명령

모두 저장소 루트에서 실행한다. 전역 `flutter`가 아니라 `fvm flutter`다(AGENTS.md '환경 함정').

```bash
fvm dart format --output=none --set-exit-if-changed lib test   # CI와 같은 포맷 검사
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
fvm flutter build ios --simulator --debug
```

보안 규칙 테스트는 `demo-` 프로젝트로 에뮬레이터에서만 돌아 실제 프로젝트에 닿지 않는다. 에뮬레이터는 Java 21이 필요한데
이 컴퓨터의 기본 Java는 19라서 Android Studio의 Java를 쓴다.

```bash
npm --prefix firestore-tests ci
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" firebase emulators:exec --only firestore --project demo-shared-ledger "npm --prefix firestore-tests test"
```

## 기기·시뮬레이터 실행

- 실기기가 연결돼 있으면 실기기로, 없으면 에뮬레이터·시뮬레이터로 돌린다: `fvm flutter run -d <기기 id>`
- 실기기가 잠겨 있으면 풀어 달라고 요청한다. 대신 풀지 않는다.
- Android Studio에서 실행이 실패하면 실제로 어느 Flutter로 실행했는지부터 본다. `~/Library/Logs/Google/AndroidStudio*/idea.log`의
  `FlutterApp - ` 줄에 flutter 경로가 찍힌다. `.fvm/flutter_sdk`가 아니면 그게 원인이고, 바뀐 파일은 AGENTS.md '환경 함정'대로 되돌린다.
- **운영 DB 대신 로컬 Firestore 에뮬레이터로 실행할 수 있다.** 규칙을 아직 배포하지 않은 변경을 기기에서 확인하거나
  운영 데이터를 더럽히지 않으려면 이렇게 한다. 로그인은 실제 Firebase Auth를 쓰고, Firestore만 에뮬레이터로 간다.
  1. `JAVA_HOME=… firebase emulators:start --only firestore --project simple-shared-ledger` (백그라운드). 앱과 같은 프로젝트 id여야 한다
  2. 실기기는 `adb reverse tcp:8080 tcp:8080` 후 `--dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1`로 빌드한다.
     Android 에뮬레이터는 `10.0.2.2`, iOS 시뮬레이터는 `127.0.0.1`. 앱은 주소를 바꾸지 않고 그대로 쓴다(`main.dart`의 `automaticHostMapping: false`)
  3. 데이터 비우기: `curl -X DELETE "http://127.0.0.1:8080/emulator/v1/projects/simple-shared-ledger/databases/(default)/documents"`
  4. 규칙을 거치지 않고 시험 데이터 넣기: REST(`/v1/projects/simple-shared-ledger/databases/(default)/documents/...`)에
     `Authorization: Bearer owner` 헤더. 상대 계정이 없을 때 '상대가 만든 가계부와 초대 코드'를 넣어 참여를 확인하는 데 쓴다
  - 에뮬레이터용으로 설치한 앱은 에뮬레이터가 꺼지면 불러오는 중 화면에 멈춘다. 확인이 끝나면 일반 빌드로 다시 설치한다.
- 실제 Google·Apple 로그인과 Firestore 쓰기는 사용자의 계정이 필요하다. 시스템 로그인 창이 뜨는 것까지 확인하고,
  그 뒤는 사용자에게 확인을 부탁한다. 계정 정보를 대신 입력하지 않는다.

## 테스트 작성

작성 기준과 정석 레퍼런스는 testing 스킬에 있다.

## CI 실패 분석

`.github/workflows/ci.yml`의 job별로 본다. `gh run view <id> --log-failed`로 실패한 단계 로그만 가져온다.

| job | 흔한 원인 | 로컬 재현 |
| --- | --- | --- |
| Flutter 포맷·분석·테스트 | 포맷 안 함, `pubspec.lock`이 `pubspec.yaml`과 안 맞음(`--enforce-lockfile`) | 위 명령 세 개, `fvm flutter pub get` 후 `git diff pubspec.lock` |
| Firestore 보안 규칙 테스트 | 규칙과 테스트 불일치, `package-lock.json` 미반영 | 보안 규칙 테스트 명령 |
| Android 디버그 빌드 | Gradle·AGP·Kotlin 버전, 플러그인 캐시 | `fvm flutter clean` 후 `fvm flutter build apk --debug` |

- CI의 Flutter 버전은 `.fvmrc`에서 읽는다. 로컬과 버전이 다르다고 의심되면 `.fvmrc`부터 본다.
- 원인을 고치지 않고 단계를 건너뛰거나 검사를 끄지 않는다.
