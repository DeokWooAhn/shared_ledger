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
List<Override> repositoryOverrides() => [
  authRepositoryProvider.overrideWith(
    (ref) => FirebaseAuthRepository(
      auth: FirebaseAuth.instance,
      googleSignIn: GoogleSignIn.instance,
      // Android는 google-services.json에서 읽으므로 null이다.
      iosClientId: DefaultFirebaseOptions.currentPlatform.iosClientId,
    ),
  ),
  ledgerRepositoryProvider.overrideWith(
    (ref) => FirestoreLedgerRepository(FirebaseFirestore.instance),
  ),
  settingsRepositoryProvider.overrideWith(
    (ref) => FirestoreSettingsRepository(FirebaseFirestore.instance),
  ),
  entriesRepositoryProvider.overrideWith(
    (ref) => FirestoreEntriesRepository(FirebaseFirestore.instance),
  ),
  templatesRepositoryProvider.overrideWith(
    (ref) => FirestoreTemplatesRepository(FirebaseFirestore.instance),
  ),
  activityRepositoryProvider.overrideWith(
    (ref) => FirestoreActivityRepository(FirebaseFirestore.instance),
  ),
  holidaysRepositoryProvider.overrideWith(
    (ref) => FirestoreHolidaysRepository(FirebaseFirestore.instance),
  ),
];
