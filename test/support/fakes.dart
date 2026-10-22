import 'dart:async';

import 'package:shared_ledger/core/data/auth_repository.dart';
import 'package:shared_ledger/core/data/ledger_repository.dart';
import 'package:shared_ledger/core/data/settings_repository.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/invite.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/member.dart';
import 'package:shared_ledger/core/model/payment_method.dart';

/// 화면 테스트용 가짜 로그인. 로그인하면 [signInAs]로 바뀐다.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? signedIn}) : _user = signedIn;

  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser signInAs = const AuthUser(uid: 'me');
  bool cancelNextSignIn = false;

  /// true면 다음 로그인이 오류로 실패한다(취소와 다름).
  bool failNextSignIn = false;

  /// true면 다음 로그아웃이 실패한다.
  bool failNextSignOut = false;
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
    if (failNextSignIn) {
      failNextSignIn = false;
      throw StateError('sign-in failed');
    }
    if (cancelNextSignIn) return false;
    _set(signInAs);
    return true;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failNextSignOut) {
      failNextSignOut = false;
      throw StateError('sign-out failed');
    }
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
  final created = <({String name, String ownerUid, String ownerName})>[];
  final invites = <({String ledgerId, MemberRole role, String createdBy})>[];
  final joins = <({String code, String uid})>[];

  /// 참여할 수 있는 초대 코드 → 들어갈 가계부와 받을 역할.
  final joinable = <String, ({Ledger ledger, MemberRole role})>{};

  /// 값을 넣으면 다음 참여가 이 이유로 실패한다.
  JoinFailure? nextJoinFailure;

  /// true면 다음 호출이 네트워크 오류처럼 [JoinLedgerException]이 아닌 오류로 실패한다.
  bool failNextCreate = false;
  bool failNextInvite = false;
  bool failNextJoin = false;

  static Never _fail(String what) => throw StateError('$what failed');

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
    required String ownerName,
  }) async {
    if (failNextCreate) {
      failNextCreate = false;
      _fail('create');
    }
    created.add((name: name, ownerUid: ownerUid, ownerName: ownerName));
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
    if (failNextInvite) {
      failNextInvite = false;
      _fail('createInvite');
    }
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
    if (failNextJoin) {
      failNextJoin = false;
      _fail('joinWithInvite');
    }
    final failure = nextJoinFailure;
    nextJoinFailure = null;
    if (failure != null) throw JoinLedgerException(failure);
    final target = joinable[code];
    if (target == null) throw const JoinLedgerException(JoinFailure.notFound);
    // 실제 저장소처럼: 이미 있는 가계부면 그 문서를 바꾸고, 두 명이 찼거나 이미 구성원이면
    // 보안 규칙이 거부하므로 unavailable로 실패한다.
    final index = _ledgers.indexWhere((l) => l.id == target.ledger.id);
    final current = index >= 0 ? _ledgers[index] : target.ledger;
    if (current.isFull || current.memberUids.contains(uid)) {
      throw const JoinLedgerException(JoinFailure.unavailable);
    }
    final joined = Ledger(
      id: current.id,
      name: current.name,
      ownerUid: current.ownerUid,
      roles: {...current.roles, uid: target.role},
    );
    if (index >= 0) {
      _ledgers[index] = joined;
    } else {
      _ledgers.add(joined);
    }
    _changes.add(null);
  }
}

/// 화면 테스트용 가짜 설정 저장소. 어느 가계부를 물어도 같은 설정을 돌려준다.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.members = const [
      Member(slot: MemberSlot.owner, name: '하늘'),
      Member(slot: MemberSlot.partner, name: '바다'),
    ],
    this.categories = const [
      Category(id: 'c-principal', name: '대출원금', countsAsSaving: true),
      Category(id: 'c-spending', name: '소비'),
    ],
    this.paymentMethods = const [
      PaymentMethod(id: 'p-account', name: '공동 통장', kind: PaymentKind.account),
    ],
  });

  final List<Member> members;
  final List<Category> categories;
  final List<PaymentMethod> paymentMethods;

  /// 구독한 가계부 id. 읽기 비용을 확인할 때 쓴다.
  final watched = <String>[];

  @override
  Stream<List<Member>> watchMembers(String ledgerId) {
    watched.add(ledgerId);
    return Stream.value(members);
  }

  @override
  Stream<List<Category>> watchCategories(String ledgerId) {
    watched.add(ledgerId);
    return Stream.value(categories);
  }

  @override
  Stream<List<PaymentMethod>> watchPaymentMethods(String ledgerId) {
    watched.add(ledgerId);
    return Stream.value(paymentMethods);
  }
}
