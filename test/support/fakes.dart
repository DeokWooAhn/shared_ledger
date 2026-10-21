import 'dart:async';

import 'package:shared_ledger/core/data/auth_repository.dart';
import 'package:shared_ledger/core/data/ledger_repository.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/invite.dart';
import 'package:shared_ledger/core/model/ledger.dart';

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

/// 화면 테스트용 가짜 가계부 저장소.
class FakeLedgerRepository implements LedgerRepository {
  FakeLedgerRepository([List<Ledger> initial = const []])
    : _ledgers = [...initial];

  final List<Ledger> _ledgers;
  final _changes = StreamController<void>.broadcast();
  final created = <({String name, String ownerUid})>[];
  final invites = <({String ledgerId, MemberRole role, String createdBy})>[];
  final joins = <({String code, String uid})>[];

  /// 참여할 수 있는 초대 코드 → 들어갈 가계부와 받을 역할.
  final joinable = <String, ({Ledger ledger, MemberRole role})>{};

  /// 값을 넣으면 다음 참여가 이 이유로 실패한다.
  JoinFailure? nextJoinFailure;

  List<Ledger> _of(String uid) =>
      _ledgers.where((l) => l.memberUids.contains(uid)).toList();

  @override
  Stream<List<Ledger>> watchMyLedgers(String uid) async* {
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
    final id = 'ledger-${created.length}';
    _ledgers.add(Ledger(id: id, name: name, ownerUid: ownerUid));
    _changes.add(null);
    return id;
  }

  @override
  Future<Invite> createInvite({
    required String ledgerId,
    required MemberRole role,
    required String createdBy,
  }) async {
    invites.add((ledgerId: ledgerId, role: role, createdBy: createdBy));
    return Invite(
      code: 'TESTCODE${invites.length}A',
      ledgerId: ledgerId,
      role: role,
      expiresAt: DateTime(2026, 10, 28, 15, 5),
    );
  }

  @override
  Future<void> joinWithInvite({
    required String code,
    required String uid,
  }) async {
    joins.add((code: code, uid: uid));
    final failure = nextJoinFailure;
    nextJoinFailure = null;
    if (failure != null) throw JoinLedgerException(failure);
    final target = joinable[code];
    if (target == null) throw const JoinLedgerException(JoinFailure.notFound);
    final ledger = target.ledger;
    _ledgers.add(
      Ledger(
        id: ledger.id,
        name: ledger.name,
        ownerUid: ledger.ownerUid,
        roles: {...ledger.roles, uid: target.role},
      ),
    );
    _changes.add(null);
  }
}
