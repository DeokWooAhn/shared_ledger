import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:google_sign_in/google_sign_in.dart';

import 'core/providers/repositories.dart';
import 'data/activity/firestore_activity_repository.dart';
import 'data/auth/firebase_auth_repository.dart';
import 'data/entries/firestore_entries_repository.dart';
import 'data/holidays/firestore_holidays_repository.dart';
import 'data/ledger/firestore_ledger_repository.dart';
import 'data/settings/firestore_settings_repository.dart';
import 'data/templates/firestore_templates_repository.dart';
import 'firebase_options.dart';

/// 저장소 인터페이스(domain)에 Firebase 구현(data)을 넣는다. 앱에서 data를 아는 곳은 여기와 시작점뿐이다.
///
/// 구현은 처음 쓸 때 만든다. Firebase를 초기화한 뒤 [ProviderScope]의 overrides로 넘긴다(main.dart).
/// 항목 저장소([entries])는 앱을 켤 때 다른 Firestore 작업보다 먼저 확인할 것이 있어 시작점이 만들어 넘긴다.
/// [auth]·[firestore]를 넘기면 테스트 전용 Firebase 앱을 쓰고, 생략하면 기본 앱을 쓴다.
List<Override> repositoryOverrides({
  required FirestoreEntriesRepository entries,
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
}) => [
  authRepositoryProvider.overrideWith(
    (ref) => FirebaseAuthRepository(
      auth: auth ?? FirebaseAuth.instance,
      googleSignIn: GoogleSignIn.instance,
      // Android는 google-services.json에서 읽으므로 null이다.
      iosClientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
    ),
  ),
  ledgerRepositoryProvider.overrideWith(
    (ref) => FirestoreLedgerRepository(firestore ?? FirebaseFirestore.instance),
  ),
  settingsRepositoryProvider.overrideWith(
    (ref) =>
        FirestoreSettingsRepository(firestore ?? FirebaseFirestore.instance),
  ),
  entriesRepositoryProvider.overrideWithValue(entries),
  templatesRepositoryProvider.overrideWith(
    (ref) =>
        FirestoreTemplatesRepository(firestore ?? FirebaseFirestore.instance),
  ),
  activityRepositoryProvider.overrideWith(
    (ref) =>
        FirestoreActivityRepository(firestore ?? FirebaseFirestore.instance),
  ),
  holidaysRepositoryProvider.overrideWith(
    (ref) =>
        FirestoreHolidaysRepository(firestore ?? FirebaseFirestore.instance),
  ),
];
