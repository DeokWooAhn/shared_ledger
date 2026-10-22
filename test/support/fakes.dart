import 'dart:async';

import 'package:shared_ledger/core/data/auth_repository.dart';
import 'package:shared_ledger/core/data/entries_repository.dart';
import 'package:shared_ledger/core/data/ledger_repository.dart';
import 'package:shared_ledger/core/data/settings_repository.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/invite.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/member.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/payment_method.dart';
import 'package:shared_ledger/core/model/year_month.dart';

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

/// 화면 테스트용 가짜 항목 저장소. 넣어 둔 달의 항목을 돌려주고, 없는 달은 빈 달이다.
///
/// 실제 저장소처럼 휴지통 항목은 이미 빠진 [MonthLedger]를 넣는다. [put]으로 바꾸면 구독 중인 곳에 다시 알린다.
/// 쓰기도 실제 약속을 지킨다: 추가는 [offline]이어도 되고, 고치기·휴지통·꺼내기는 [offline]이면
/// [EntryWriteFailure.offline]으로, 없는 항목(휴지통에 든 항목을 고칠 때 포함)이면 [EntryWriteFailure.notFound]로 실패한다.
class FakeEntriesRepository implements EntriesRepository {
  FakeEntriesRepository([Map<YearMonth, MonthLedger> months = const {}])
    : _months = {...months};

  final Map<YearMonth, MonthLedger> _months;
  final _trash = <(YearMonth, EntryKind, String), LedgerEntry>{};
  final _changes = StreamController<void>.broadcast();

  /// 구독한 가계부와 달. 읽기 비용(그달만 구독하는지)을 확인할 때 쓴다.
  final watched = <({String ledgerId, YearMonth month})>[];

  /// 쓴 기록. 어느 가계부·달에 누가 무엇을 했는지 본다.
  final added =
      <({String ledgerId, YearMonth month, EntryDraft draft, String uid})>[];
  final updated =
      <
        ({
          String ledgerId,
          YearMonth month,
          String id,
          EntryDraft draft,
          String uid,
        })
      >[];
  final trashed =
      <({String ledgerId, YearMonth month, EntryKind kind, String id})>[];
  final restored =
      <({String ledgerId, YearMonth month, EntryKind kind, String id})>[];

  /// true면 다음 구독이 권한 오류처럼 실패한다.
  bool failNextWatch = false;

  /// true면 연결이 없는 것처럼 고치기·휴지통·꺼내기가 실패한다. 추가는 된다.
  bool offline = false;

  /// true면 다음 쓰기가 [EntryWriteException]이 아닌 오류(권한 등)로 실패한다.
  bool failNextWrite = false;

  /// [month]의 항목을 바꾼다. 어느 가계부를 물어도 같은 달이면 같은 항목이다.
  void put(YearMonth month, MonthLedger ledger) {
    _months[month] = ledger;
    _changes.add(null);
  }

  /// [month]의 지금 항목(휴지통 제외).
  MonthLedger monthOf(YearMonth month) => _months[month] ?? const MonthLedger();

  @override
  Stream<MonthLedger> watchMonth(String ledgerId, YearMonth month) async* {
    watched.add((ledgerId: ledgerId, month: month));
    if (failNextWatch) {
      failNextWatch = false;
      throw StateError('watchMonth failed');
    }
    yield monthOf(month);
    await for (final _ in _changes.stream) {
      yield monthOf(month);
    }
  }

  @override
  Future<String> add({
    required String ledgerId,
    required YearMonth month,
    required EntryDraft draft,
    required String uid,
  }) async {
    _failIfAsked();
    added.add((ledgerId: ledgerId, month: month, draft: draft, uid: uid));
    final id = 'entry-${added.length}';
    _edit(month, draft.kind, (entries) => [...entries, _entryOf(id, draft)]);
    return id;
  }

  @override
  Future<void> update({
    required String ledgerId,
    required YearMonth month,
    required String id,
    required EntryDraft draft,
    required String uid,
  }) async {
    _checkOnline();
    _live(month, draft.kind, id);
    updated.add((
      ledgerId: ledgerId,
      month: month,
      id: id,
      draft: draft,
      uid: uid,
    ));
    _edit(
      month,
      draft.kind,
      (entries) => [
        for (final entry in entries)
          entry.id == id ? _entryOf(id, draft) : entry,
      ],
    );
  }

  @override
  Future<void> trash({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
  }) async {
    _checkOnline();
    final entry = _live(month, kind, id);
    trashed.add((ledgerId: ledgerId, month: month, kind: kind, id: id));
    _trash[(month, kind, id)] = entry;
    _edit(month, kind, (entries) => [...entries.where((e) => e.id != id)]);
  }

  @override
  Future<void> restore({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
  }) async {
    _checkOnline();
    final entry = _trash.remove((month, kind, id));
    if (entry == null) {
      throw const EntryWriteException(EntryWriteFailure.notFound);
    }
    restored.add((ledgerId: ledgerId, month: month, kind: kind, id: id));
    _edit(month, kind, (entries) => [...entries, entry]);
  }

  void _failIfAsked() {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write failed');
    }
  }

  void _checkOnline() {
    _failIfAsked();
    if (offline) throw const EntryWriteException(EntryWriteFailure.offline);
  }

  // 휴지통 밖에 있는 [id] 항목. 없으면 실제 저장소처럼 notFound로 실패한다.
  LedgerEntry _live(YearMonth month, EntryKind kind, String id) =>
      _entriesOf(monthOf(month), kind).where((e) => e.id == id).firstOrNull ??
      (throw const EntryWriteException(EntryWriteFailure.notFound));

  void _edit(
    YearMonth month,
    EntryKind kind,
    List<LedgerEntry> Function(List<LedgerEntry> entries) change,
  ) {
    final ledger = monthOf(month);
    final entries = change(_entriesOf(ledger, kind));
    put(
      month,
      MonthLedger(
        incomes: kind == EntryKind.income
            ? entries.whereType<Income>().toList()
            : ledger.incomes,
        plannedExpenses: kind == EntryKind.planned
            ? entries.whereType<PlannedExpense>().toList()
            : ledger.plannedExpenses,
        extraExpenses: kind == EntryKind.extra
            ? entries.whereType<ExtraExpense>().toList()
            : ledger.extraExpenses,
        cardBills: kind == EntryKind.cardBill
            ? entries.whereType<CardBill>().toList()
            : ledger.cardBills,
      ),
    );
  }

  static List<LedgerEntry> _entriesOf(MonthLedger ledger, EntryKind kind) =>
      switch (kind) {
        EntryKind.income => ledger.incomes,
        EntryKind.planned => ledger.plannedExpenses,
        EntryKind.extra => ledger.extraExpenses,
        EntryKind.cardBill => ledger.cardBills,
      };

  // 저장한 문서를 다시 읽은 것과 같은 항목. 실제 저장소는 메모 앞뒤 공백을 빼고 빈 메모는 저장하지 않는다.
  static LedgerEntry _entryOf(String id, EntryDraft draft) {
    final memo = draft.memo?.trim();
    final note = memo == null || memo.isEmpty ? null : memo;
    final title = draft.title.trim();
    return switch (draft.kind) {
      EntryKind.income => Income(
        id: id,
        memberId: draft.memberId,
        title: title,
        amount: draft.amount ?? 0,
        receivedOn: draft.date,
        memo: note,
      ),
      EntryKind.planned => PlannedExpense(
        id: id,
        categoryId: draft.categoryId ?? '',
        memberId: draft.memberId,
        title: title,
        paymentMethodId: draft.paymentMethodId ?? '',
        amount: draft.amount,
        paidOn: draft.date,
        memo: note,
      ),
      EntryKind.extra => ExtraExpense(
        id: id,
        memberId: draft.memberId,
        title: title,
        paymentMethodId: draft.paymentMethodId ?? '',
        amount: draft.amount ?? 0,
        spentOn: draft.date,
        memo: note,
      ),
      EntryKind.cardBill => CardBill(
        id: id,
        memberId: draft.memberId,
        cardId: draft.cardId ?? '',
        amount: draft.amount ?? 0,
        paidOn: draft.date,
        memo: note,
      ),
    };
  }
}
