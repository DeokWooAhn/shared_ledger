import 'dart:async';

import 'package:shared_ledger/core/data/auth_repository.dart';
import 'package:shared_ledger/core/data/household_repository.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/household.dart';

/// 화면 테스트용 가짜 로그인. 로그인하면 [signInAs]로 바뀐다.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? signedIn}) : _user = signedIn;

  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser signInAs = const AuthUser(uid: 'me');
  bool cancelNextSignIn = false;
  int googleCalls = 0;
  int appleCalls = 0;
  int signOutCalls = 0;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<bool> signInWithGoogle() async {
    googleCalls++;
    return _signIn();
  }

  @override
  Future<bool> signInWithApple() async {
    appleCalls++;
    return _signIn();
  }

  Future<bool> _signIn() async {
    if (cancelNextSignIn) return false;
    _set(signInAs);
    return true;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _set(null);
  }

  void _set(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }
}

/// 화면 테스트용 가짜 가구 저장소.
class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository([List<Household> initial = const []])
    : _households = [...initial];

  final List<Household> _households;
  final _changes = StreamController<void>.broadcast();
  final created = <({String name, String ownerUid})>[];

  List<Household> _of(String uid) =>
      _households.where((h) => h.memberUids.contains(uid)).toList();

  @override
  Stream<List<Household>> watchMyHouseholds(String uid) async* {
    yield _of(uid);
    await for (final _ in _changes.stream) {
      yield _of(uid);
    }
  }

  @override
  Future<String> create({
    required String name,
    required String ownerUid,
  }) async {
    created.add((name: name, ownerUid: ownerUid));
    final id = 'household-${created.length}';
    _households.add(Household(id: id, name: name, ownerUid: ownerUid));
    _changes.add(null);
    return id;
  }
}
