# Maestro 기본 테스트

실제 Android·iOS 앱의 입력과 화면 이동을 Maestro로 검증한다. 테스트 전용 시작점
`testing/maestro_main.dart`에서 실제 Firebase 저장소 구현을 쓰되, Auth·Firestore는 로컬 에뮬레이터에 연결한다.
서버 없이 도는 Flutter 위젯 테스트와 별도로, 기기 → 앱 → Firebase SDK → 보안 규칙 → 저장 → 화면 반영을 확인한다.

## 범위

| Flow | 확인하는 것 |
| --- | --- |
| `01_navigation.yaml` | 앱 실행, 홈·내역·통계·설정 이동, 수입·남는 현금 표시 |
| `02_entry_save_edit.yaml` | 추가 지출 저장·수정, 목록·홈 요약 반영, 서버의 제목·금액·결제수단 |
| `03_trash_restore.yaml` | 휴지통 이동·복원, 목록·합계 변화, 서버의 삭제 상태 |

로컬과 GitHub Actions에서 실행한다. CI는 아래 경로 기준으로 Android·iOS smoke를 선택 실행한다.
저장소 ruleset의 새 필수 검사 등록과 릴리스 배포 관문은 별도 설정이다.
태그 `smoke`는 이 프로젝트에서 로컬 Firebase까지 포함한 기본 검증을 뜻한다.
실제 Google·Apple 로그인, 두 기기 간 동시 편집, 오프라인 복구, Cloud Functions는 이 세 Flow에 포함되지 않는다.

## 준비

- 프로젝트 고정 Flutter SDK를 실행하는 fvm
- Maestro CLI 2.1.0, Firebase CLI, Java 21 이상
- Android: Android SDK·adb와 연결된 기기 또는 실행 중인 에뮬레이터
- iOS: Xcode와 실행 중인 iOS 시뮬레이터(Maestro 2.1.0 기준)

새 Flutter 패키지는 필요 없다. macOS에서 JAVA_HOME이 없으면 실행 스크립트가 Android Studio의 JBR을 쓴다.
실기기가 연결돼 있으면 우선 사용한다. 잠긴 기기는 사용자가 풀어야 한다. 스토어판을 지우거나 교체하지 않는다.

## 실행

저장소 루트에서 실행한다. 기기 ID는 `adb devices -l`이나 `xcrun simctl list devices booted`로 확인한다.

```bash
bash scripts/maestro-smoke.sh android emulator-5554
bash scripts/maestro-smoke.sh ios <시뮬레이터-UDID>
```

스크립트는 테스트 전용 디버그 앱을 새로 빌드·설치한 뒤 Firebase 에뮬레이터와 Flow 세 개를 실행한다.
Android 실기기는 두 Firebase 포트에 `adb reverse`를 설정한다. 에뮬레이터 프로세스는 CLI가 테스트 후 종료한다.
직접 켠 Android 에뮬레이터·iOS 시뮬레이터도 확인이 끝나면 종료한다.

테스트 앱은 일반 개발 앱과 앱 ID가 같으므로 전용 테스트 기기나 시뮬레이터 사용을 권한다.
앱의 로컬 데이터를 지우는 `clearState`는 사용하지 않는다. 테스트 후 일반 개발 앱을 쓰려면 `lib/main.dart`로 다시 빌드·설치한다.
일반 배포 빌드는 `lib/main.dart`를 사용한다. 테스트 시작점은 디버그에서만 실행된다.

결과는 `build/maestro/android/`·`build/maestro/ios/`의 JUnit `results.xml`과 `artifacts/`에 남는다.
CI iOS 실행은 세 Flow를 한 Maestro 호출로 실행하고 `debug/`와 앱 로그도 남긴다.
`diagnostics/summary.json`에는 도구·기기·프로세스·스크린샷·통합 로그 수집의 종료 코드와 새 크래시 보고서 목록을 기록한다.
테스트가 실패해도 Firebase 에뮬레이터 종료 전에 진단을 수집하고, 수집 실패가 원래 실패 코드를 덮어쓰지 않는다.
앱 로그의 `MAESTRO_STARTUP`과 `MAESTRO_DATA`는 초기화 단계·구독 상태·오류 코드만 기록한다. 금액·메모·계정 값은 기록하지 않는다.
실행하지 못한 플랫폼은 검증 완료로 보지 않는다.
Maestro 명령은 Android·iOS를 포함해 순서대로 실행한다. 동시에 실행하면 기기 드라이버 연결이 충돌할 수 있고,
Flow 시작 시 공용 Firebase 테스트 데이터를 초기화하므로 다른 Flow의 상태도 바뀐다.

## Firebase와 테스트 데이터

- 프로젝트 ID는 `demo-shared-ledger`, Firebase 앱 이름은 `maestro`로 고정한다. 운영 앱의 기본 Firebase 앱과 분리한다.
- `firebase.maestro.json`의 전용 포트: Auth 19099, Firestore 18080, 허브 14400, 로그 14500.
- 앱은 loopback 또는 Android 에뮬레이터의 호스트 주소만 받는다. Firestore 영속 캐시는 끈다.
- Android의 로컬 HTTP는 디버그 전용 network security 설정에서 위 세 주소만 허용한다. 릴리스 설정에는 넣지 않는다.
- Flow 시작마다 앱을 끄고, 전용 demo 프로젝트의 계정·문서를 비운 뒤 가상 데이터를 넣는다.
  기존 개발 에뮬레이터와 동시에 실행할 때도 이 전용 포트는 다른 용도로 사용하지 않는다.
- 직전 앱의 listen 연결이 닫힐 때 Firestore 초기화가 HTTP 499(CANCELLED)로 실패할 수 있다. HTTP 499·500일 때 이 초기화 DELETE만
  최대 세 번 요청하고, 다른 오류나 계속되는 서버 오류는 실패로 처리한다. 앱의 쓰기·화면 검증은 재시도하지 않는다.
- 초기 픽스처는 Emulator REST API의 관리자 접근으로 준비한다. 이후 앱의 추가·수정·휴지통·복원은
  저장소의 실제 `firestore.rules`를 적용받는다. 보안 규칙을 완화하지 않는다.
- 새 항목은 서버 응답 전에 화면에 반영된다. `subflows/verify_entry.yaml`은 화면 합계를 계속 확인하며
  서버의 제목·금액·결제수단·휴지통 상태가 일치할 때까지 읽기만 반복한다(Android 30초, iOS 120초).
  즉시 재요청 몇 번으로 저장 실패를 판정하지 않는다. 마지막 `assertTrue`가 필수이며, 중복 항목·HTTP 오류는 즉시 실패한다.
  `MAESTRO_VERIFY`에는 일치 상태·문서 개수·경과 시간만 남기고 입력값은 기록하지 않는다.
  iOS CI에서 연결의 `READ_CLOSE` 후 30초 뒤 `Connection reset by peer`가 기록됐고, 그동안 새 쓰기가
  서버에 반영되지 않았다. 저장 전 75초 유휴를 둔 별도 재현에서도 서버 확인에 약 88초가 걸렸고, 120초 기한에서 저장·수정 검증이 통과했다.
  [Firebase 에뮬레이터의 유사 keepalive 재현 보고](https://github.com/firebase/firebase-tools/issues/11238)도
  iOS 쓰기 확인에 120초를 사용한다. 정확한 GOAWAY 원인까지 확인한 것은 아니며, 성공하면 즉시 넘어가고 쓰기를 재시도하지 않는다.
- 테스트 계정과 비밀번호는 에뮬레이터에서만 쓰는 공개 가상 값이다. 개인 계정이나 운영 토큰을 넣지 않는다.
- 앱이 보는 날짜는 2026-10-15로 고정한다. 가상 수입 1,000,000원과 지출 23,000원에서 시작한다.
  Android의 `inputText`가 한글을 지원하지 않아서 Flow가 입력하는 제목만 영문이다.

## CI 실행 조건

`.github/workflows/ci.yml`의 `Maestro 실행 조건 확인`이 PR 전체 변경을 비교한다.
`main` 푸시는 이전 커밋부터의 변경을 보고, 수동 실행은 항상 smoke를 실행한다.
워크플로 전체의 `paths` 필터를 쓰지 않아서 기존 포맷·분석·단위 테스트·보안 규칙·빌드 검사는 계속 실행된다.

| 변경 경로 | Maestro |
| --- | --- |
| `lib/**`, `assets/**` | 실행: 화면·상태·경로·계산·저장소 동작 |
| `android/**`, `ios/**`, `.fvmrc`, `pubspec.yaml`, `pubspec.lock` | 실행: 앱 설정·의존성 |
| `firestore.rules`, `firestore.indexes.json`, `firebase.maestro.json` | 실행: 저장·권한·에뮬레이터 |
| `.maestro/**`, `testing/maestro_main.dart`, `testing/maestro_diagnostics.dart`, `scripts/maestro-smoke.sh`, `.github/scripts/**`, `.github/workflows/ci.yml` | 실행: 테스트·CI 자체 |
| 문서·디자인 원본·`test/**`·`functions/**`·`firestore-tests/**`만 변경 | smoke 생략: 각 영역의 기존 CI 검사는 유지 |

위 실행 경로에 변경이 하나라도 있으면 세 Flow를 모두 실행한다. 공용 탭·상태·요약이 연결돼 있어 화면별로 하나만 고르지 않는다.
삭제·이름 변경도 감지한다. 판별 규칙은 `.github/scripts/maestro_changes.py`, 회귀 검사는 같은 폴더의 Python 테스트에 있다.
초기화·서버 상태 검증의 실패 처리는 같은 폴더의 `test_maestro_reset.py`·`test_maestro_verify.py`가 실제 스크립트로 검사한다.

`Maestro 스모크 테스트`는 Flutter를 `.fvmrc` 버전으로 설치하고 전용 디버그 APK를 빌드한다.
APK는 기존 Android CI와 같은 JDK 17로 빌드하고, Firebase·Maestro 실행 전에 JDK 21로 전환한다.
Maestro 2.1.0·Firebase CLI 15.20.0을 사용하고, API 34 Android 에뮬레이터에서 로컬 Firebase와 실행한다.
첫 탭 이동 Flow로 앱을 워밍업한 뒤 smoke 세 개를 실행한다.

iOS는 같은 변경 조건에서 `iOS Maestro 스모크 테스트`를 Xcode 27이 설치된 `xcode-27` 러너의 iPhone 시뮬레이터로 실행한다.
고정 Flutter SDK로 `testing/maestro_main.dart`를 빌드하고, 로컬 Auth·Firestore와 같은 세 Flow를 검증한다.
이 프로젝트의 Xcode 27 요구사항에 맞춰 러너를 선택한다. iPhone 17 Pro를 우선 사용하고 없으면 설치된 최신 iPhone 시뮬레이터를 사용한다.
결과와 앱 로그는 `ios-maestro-smoke-results` artifact에 7일간 남기고 시뮬레이터를 종료한다.
iOS 실행에는 `STARTUP_TIMEOUT_MS=60000`을 전달한다. 새 CI 기기의 앱·Firebase SDK 초기화와
첫 데이터 구독이 약 40초 걸린 실패 기록에 따른 예산이며, 조건이 충족되면 바로 진행한다.
호스트 REST 준비가 빨라도 앱의 초기화가 끝난 것은 아니다. Android는 30초를 유지한다.
별도 iOS 워밍업 CLI는 실행하지 않는다. 연속 CLI 실행 사이에 XCTest 드라이버 연결이 끊겨
본 Flow의 `stopApp`부터 실패했던 기록이 있어, 한 드라이버 세션으로 세 Flow를 검증한다.
Android 결과는 실패 여부와 관계없이 `maestro-smoke-results` artifact에 스크린샷·JUnit·logcat·에뮬레이터 로그를 7일간 보관한다.
Android 캐시에는 부팅 후 패키지 작업이 안정된 AVD 스냅샷을 남긴다.

## 화면 식별자

Flutter `Key`는 Maestro에 노출되지 않으므로 `Semantics.identifier` 또는 `Text.semanticsIdentifier`를 사용한다.
Android·iOS가 같은 식별자를 사용하며 좌표나 번역된 버튼 문구로 요소를 찾지 않는다.

| 위치 | 식별자 |
| --- | --- |
| 하단·옆 탭 | `tab-home`, `tab-entries`, `tab-stats`, `tab-settings` |
| 항목 추가 | `add-entry` |
| 입력란·저장·휴지통 | `entry-amount`, `entry-title`, `entry-save`, `entry-trash` |
| 입력 화면 결제수단 | `entry-method-<id>` |
| 내역 제목·금액 | `entry-title-<id>`, `entry-amount-<id>` |
| 홈 남는 현금·통계 수입 | `remaining-cash`, `stats-income` |
| 휴지통 열기·제목·복원 | `open-trash`, `trash-title-<id>`, `restore-<id>` |

화면을 바꾼 뒤에는 `maestro --device <id> hierarchy --compact`로 식별자가 실제로 보이는지 확인하고 Flow를 다시 실행한다.
앱 문제로 실패하면 단언을 느슨하게 하거나 임의 대기를 늘려 통과시키지 않는다.
떠 있는 탭 막대가 단추를 가릴 수 있으므로, 설정의 휴지통 이동은 `scrollUntilVisible`의 `centerElement: true`로
대상을 본문 가운데에 놓은 뒤 누른다. 단순히 화면 안에 있다는 판정만으로 가려지지 않았다고 볼 수 없다.

## ahn-cc-kit과의 관계

`maestro-e2e`의 공통 시작 Flow, ID 기반 선택, 플랫폼별 실행·결과 보관 방식을 참고했다.
현재 플러그인의 화면 감지·테스트 모드 예시는 Compose·SwiftUI 전제라 Flutter에 그대로 적용되지 않는다.
이 작업은 `.claude/settings.json`의 플러그인 활성화나 MCP 등록을 바꾸지 않는다.
