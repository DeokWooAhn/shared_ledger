# 심플 공유 가계부

커플·부부가 함께 쓰는 가계부 앱입니다. 두 사람이 같은 가계부에 수입·지출·카드 사용을 기록하고, 이번 달에 얼마를 쓰고 얼마가 남는지 함께 봅니다.

구글 시트로 쓰던 공동 가계부를 앱으로 옮기고 있습니다. **아직 개발 중이며 스토어에 출시되지 않았습니다.**

| 플랫폼 | 최소 지원 | 비고 |
| --- | --- | --- |
| Android | Android 7.0 (API 24) | |
| iOS·iPadOS | iOS 15 | Apple Silicon Mac에서는 iPad 앱으로 실행 |
| Windows | — | 출시 후 웹 버전으로 지원 예정 |

## 주요 기능

### 지금 되는 것

- Google 로그인(Android·iOS), Apple 로그인(iOS)
- 함께 쓸 가계부 만들기, 초대 코드로 상대 초대·참여 (한 가계부에 두 명까지)
- 월 요약 계산 규칙: 현금 유입·유출, 이번 달 지출, 저축, 남는 현금, 카드 이번 달 사용분과 다음 달 청구 예정액
  (시트 수식을 그대로 옮겼고, 화면은 만드는 중)

### 만들 것

- 월 요약·항목 입력 화면, 고정 지출 템플릿, 설정
- 변경 기록과 휴지통, 두 기기 실시간 반영
- Android Apple 로그인, 카카오 로그인, 계정 탈퇴

단계별 계획은 [docs/plan.md](docs/plan.md)에 있습니다.

## 아키텍처

앱이 Firebase Authentication으로 로그인하고 Firestore를 직접 읽고 씁니다. 별도 API 서버는 없고,
누가 무엇을 읽고 쓸 수 있는지는 Firestore 보안 규칙이 정합니다.

```
lib/
  domain/               모델, 월 요약 계산 규칙, 저장소 인터페이스 (순수 Dart)
  data/                 저장소를 Firestore·Firebase Authentication으로 구현
  core/                 공용 공급자(Riverpod), 디자인 토큰(design/app.pen)으로 만든 테마, 공용 위젯
  feature/<기능>/        기능별 화면: View(*_screen.dart) + Notifier(*_notifier.dart)
  main.dart, app.dart   앱 시작점
  router.dart           로그인·가계부 상태에 따라 보여 줄 화면을 정함 (go_router)
  di.dart               저장소 인터페이스에 Firebase 구현을 넣음
testing/                테스트용 가짜 저장소와 도우미
firestore.rules         보안 규칙
firestore-tests/        보안 규칙 테스트 (Firestore 에뮬레이터)
functions/              Cloud Functions (공휴일을 특일 API에서 받아 Firestore에 둔다)
design/                 화면 디자인(Pencil)과 내보낸 이미지
```

Flutter 공식 아키텍처 가이드처럼 패키지 하나 안에서 레이어를 폴더로 나눴습니다.
폴더 간 의존 규칙은 [AGENTS.md](AGENTS.md)의 '프로젝트 구조'(검사: `test/architecture_test.dart`), 컬렉션 구조와 역할별 권한은 [docs/firestore.md](docs/firestore.md)에 있습니다.

## 기술 구성

| 영역 | 사용 |
| --- | --- |
| 앱 | Flutter 3.47.7 (fvm으로 고정), Dart 3.13 |
| 상태 관리 / 화면 이동 | Riverpod 3(화면은 MVVM: View + Notifier) / go_router |
| 서버 | Firebase Authentication, Cloud Firestore (asia-northeast3) |
| 로그인 | google_sign_in, Firebase Apple 로그인 |
| iOS 의존성 | Swift Package Manager |
| 테스트 | flutter_test, Firestore 에뮬레이터 + `@firebase/rules-unit-testing` |
| CI | GitHub Actions |

## 시작하기

필요한 도구:

- [fvm](https://fvm.app) — Flutter 버전은 `.fvmrc`가 정합니다.
- Android Studio, Xcode 27 이상
- 보안 규칙 테스트를 돌리려면 Node.js, Java 21, Firebase CLI

```bash
fvm install
fvm flutter pub get
fvm flutter run
```

- Android Studio에서 열 때는 Settings → Languages & Frameworks → Flutter의 SDK 경로를 프로젝트의 `.fvm/flutter_sdk`로 지정합니다.
  다른 Flutter 버전으로 실행하면 빌드가 실패합니다.
- 저장소의 Firebase 설정은 운영 프로젝트를 가리킵니다. Android Google 로그인은 Firebase에 등록된 서명 키로 빌드해야 동작합니다.

## 검증

```bash
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
```

보안 규칙 테스트, 기기 실행, CI 실패 분석은 [verification 스킬 문서](.claude/skills/verification/SKILL.md)에 있습니다.
PR과 `main` 푸시마다 GitHub Actions가 같은 검사와 보안 규칙 테스트, Android 디버그 빌드를 돌립니다.

## 프로젝트 문서

| 문서 | 내용 |
| --- | --- |
| [docs/plan.md](docs/plan.md) | 결정 사항, 계산 규칙, 화면, 단계별 계획, 출시 요건과 비용 |
| [docs/firestore.md](docs/firestore.md) | Firestore 컬렉션·필드·역할별 권한 |
| [AGENTS.md](AGENTS.md) | 개발 규칙 (AI 에이전트·CodeRabbit·사람이 같이 봄) |
| [.claude/skills/](.claude/skills) | 작업별 절차: 화면 추가(MVVM), 테스트, 검증, Firebase, 코드 리뷰 |

## 라이선스

소스 코드는 열람할 수 있도록 공개되어 있지만, 모든 권리는 저작권자에게 있습니다. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
