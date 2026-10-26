import 'dart:async';

import 'package:shared_ledger/core/data/activity_repository.dart';
import 'package:shared_ledger/core/data/activity_summary.dart';
import 'package:shared_ledger/core/data/auth_repository.dart';
import 'package:shared_ledger/core/data/entries_repository.dart';
import 'package:shared_ledger/core/data/holidays_repository.dart';
import 'package:shared_ledger/core/data/ledger_repository.dart';
import 'package:shared_ledger/core/data/settings_repository.dart';
import 'package:shared_ledger/core/data/templates_repository.dart';
import 'package:shared_ledger/core/model/activity.dart';
import 'package:shared_ledger/core/model/auth_user.dart';
import 'package:shared_ledger/core/model/category.dart';
import 'package:shared_ledger/core/model/expense_template.dart';
import 'package:shared_ledger/core/model/holidays.dart';
import 'package:shared_ledger/core/model/invite.dart';
import 'package:shared_ledger/core/model/ledger.dart';
import 'package:shared_ledger/core/model/ledger_entries.dart';
import 'package:shared_ledger/core/model/member.dart';
import 'package:shared_ledger/core/model/month_ledger.dart';
import 'package:shared_ledger/core/model/payment_method.dart';
import 'package:shared_ledger/core/model/trashed_entry.dart';
import 'package:shared_ledger/core/model/year_month.dart';

import 'provider_container.dart' show testNow;

/// 쓸 때마다 변경 기록을 남기는 가짜 저장소. [activity]가 있으면 실제 저장소와 같은 요약으로 남긴다.
///
/// `pumpApp`·`createContainer`가 같은 [FakeActivityRepository]를 이어 준다.
mixin LogsActivity {
  FakeActivityRepository? activity;

  /// 남긴 기록의 id. [activity]가 없으면 null.
  String? logActivity(ActivityDraft draft, String uid) =>
      activity?.log(draft, uid: uid);
}

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
class FakeLedgerRepository with LogsActivity implements LedgerRepository {
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

  /// 가계부 이름을 바꾼 기록.
  final renames = <({String ledgerId, String name})>[];

  /// true면 연결이 없는 것처럼 이름 바꾸기가 [SettingsWriteFailure.offline]으로 실패한다.
  bool offline = false;

  /// true면 다음 이름 바꾸기가 [SettingsWriteException]이 아닌 오류로 실패한다.
  bool failNextRename = false;

  static Never _fail(String what) => throw StateError('$what failed');

  // 실제 가계부처럼 같은 id의 문서를 바꾼다.
  static Ledger _copy(
    Ledger ledger, {
    String? name,
    Map<String, MemberRole>? roles,
  }) => Ledger(
    id: ledger.id,
    name: name ?? ledger.name,
    ownerUid: ledger.ownerUid,
    roles: roles ?? ledger.roles,
    createdAt: ledger.createdAt,
  );

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
    final joined = _copy(current, roles: {...current.roles, uid: target.role});
    if (index >= 0) {
      _ledgers[index] = joined;
    } else {
      _ledgers.add(joined);
    }
    _changes.add(null);
  }

  @override
  Future<void> rename({
    required String ledgerId,
    required String name,
    required String uid,
  }) async {
    if (failNextRename) {
      failNextRename = false;
      _fail('rename');
    }
    if (offline) {
      throw const SettingsWriteException(SettingsWriteFailure.offline);
    }
    final index = _ledgers.indexWhere((l) => l.id == ledgerId);
    if (index < 0) {
      throw const SettingsWriteException(SettingsWriteFailure.notFound);
    }
    renames.add((ledgerId: ledgerId, name: name));
    final before = _ledgers[index].name;
    _ledgers[index] = _copy(_ledgers[index], name: name.trim());
    _changes.add(null);
    logActivity(ledgerRenameActivity(from: before, to: name), uid);
  }
}

/// 화면 테스트용 가짜 설정 저장소. 어느 가계부를 물어도 같은 설정을 돌려준다.
///
/// 실제 저장소처럼 쓰기는 모두 [offline]이면 [SettingsWriteFailure.offline]으로 실패하고,
/// 없는 분류·결제수단을 고치면 [SettingsWriteFailure.notFound]로 실패한다. 이름표는 없으면 새로 만든다.
/// 쓴 값은 실제 저장소처럼 이름 앞뒤 공백을 빼고 목록에 들어가 구독 중인 곳에 다시 알린다.
class FakeSettingsRepository with LogsActivity implements SettingsRepository {
  FakeSettingsRepository({
    List<Member> members = const [
      Member(slot: MemberSlot.owner, name: '하늘'),
      Member(slot: MemberSlot.partner, name: '바다'),
    ],
    List<Category> categories = const [
      Category(id: 'c-principal', name: '대출원금', countsAsSaving: true),
      Category(id: 'c-spending', name: '소비'),
    ],
    List<PaymentMethod> paymentMethods = const [
      PaymentMethod(id: 'p-account', name: '공동 통장', kind: PaymentKind.account),
    ],
  }) : _members = [...members],
       _categories = [...categories],
       _paymentMethods = [...paymentMethods];

  final List<Member> _members;
  final List<Category> _categories;
  final List<PaymentMethod> _paymentMethods;
  final _changes = StreamController<void>.broadcast();

  /// 구독한 가계부 id. 읽기 비용을 확인할 때 쓴다.
  final watched = <String>[];

  /// 쓴 기록. 더한 분류·결제수단은 넘겨받은 순서(order)도 남긴다.
  final renamedMembers =
      <({String ledgerId, MemberSlot slot, String name, String uid})>[];
  final addedCategories =
      <({String ledgerId, CategoryDraft draft, int order, String uid})>[];
  final updatedCategories =
      <({String ledgerId, String id, CategoryDraft draft, String uid})>[];
  final addedPaymentMethods =
      <({String ledgerId, PaymentMethodDraft draft, int order, String uid})>[];
  final renamedPaymentMethods =
      <({String ledgerId, String id, String name, String uid})>[];

  /// 숨기거나 다시 보이게 한 기록. [collection]은 `categories`·`paymentMethods`.
  final hiddenChanges =
      <({String collection, String id, bool hidden, String uid})>[];

  /// true면 연결이 없는 것처럼 모든 쓰기가 실패한다.
  bool offline = false;

  /// true면 다음 쓰기가 [SettingsWriteException]이 아닌 오류(권한 등)로 실패한다.
  bool failNextWrite = false;

  List<Member> get members => List.unmodifiable(_members);
  List<Category> get categories => List.unmodifiable(_categories);
  List<PaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);

  /// 그사이 상대가 바꾼 것처럼 목록을 바꾼다. 넘긴 것만 바꾸고 구독 중인 곳에 다시 알린다.
  void put({
    List<Member>? members,
    List<Category>? categories,
    List<PaymentMethod>? paymentMethods,
  }) {
    if (members != null) _replace(_members, members);
    if (categories != null) _replace(_categories, categories);
    if (paymentMethods != null) _replace(_paymentMethods, paymentMethods);
    _changes.add(null);
  }

  static void _replace<T>(List<T> target, List<T> values) => target
    ..clear()
    ..addAll(values);

  // 구독을 시작하자마자 바뀜을 듣는다(FakeTemplatesRepository.watchTemplates와 같다).
  Stream<T> _watch<T>(String ledgerId, T Function() current) {
    watched.add(ledgerId);
    return Stream.multi((controller) {
      controller.add(current());
      final changes = _changes.stream.listen((_) => controller.add(current()));
      controller.onCancel = changes.cancel;
    });
  }

  @override
  Stream<List<Member>> watchMembers(String ledgerId) =>
      _watch(ledgerId, () => members);

  @override
  Stream<List<Category>> watchCategories(String ledgerId) =>
      _watch(ledgerId, () => categories);

  @override
  Stream<List<PaymentMethod>> watchPaymentMethods(String ledgerId) =>
      _watch(ledgerId, () => paymentMethods);

  @override
  Future<void> renameMember({
    required String ledgerId,
    required MemberSlot slot,
    required String name,
    required String uid,
  }) async {
    _checkOnline();
    renamedMembers.add((ledgerId: ledgerId, slot: slot, name: name, uid: uid));
    final before = _members.where((m) => m.slot == slot).firstOrNull?.name;
    logActivity(memberRenameActivity(from: before, to: name), uid);
    final renamed = Member(slot: slot, name: name.trim());
    put(
      members: [
        for (final s in MemberSlot.values)
          if (s == slot)
            renamed
          else if (_members.where((m) => m.slot == s).firstOrNull
              case final member?)
            member,
      ],
    );
  }

  @override
  Future<String> addCategory({
    required String ledgerId,
    required CategoryDraft draft,
    required int order,
    required String uid,
  }) async {
    _checkOnline();
    addedCategories.add((
      ledgerId: ledgerId,
      draft: draft,
      order: order,
      uid: uid,
    ));
    final id = 'category-new-${addedCategories.length}';
    logActivity(
      categoryActivity(ActivityAction.categoryCreate, draft.name),
      uid,
    );
    put(
      categories: [
        ..._categories,
        Category(
          id: id,
          name: draft.name.trim(),
          countsAsSaving: draft.countsAsSaving,
        ),
      ],
    );
    return id;
  }

  @override
  Future<void> updateCategory({
    required String ledgerId,
    required String id,
    required CategoryDraft draft,
    required String uid,
  }) async {
    _checkOnline();
    final old = _existing(_categories, (c) => c.id == id);
    updatedCategories.add((ledgerId: ledgerId, id: id, draft: draft, uid: uid));
    logActivity(
      categoryUpdateActivity(
        fromName: old.name,
        fromSaving: old.countsAsSaving,
        name: draft.name,
        countsAsSaving: draft.countsAsSaving,
      ),
      uid,
    );
    put(
      categories: [
        for (final category in _categories)
          category.id == id
              ? Category(
                  id: id,
                  name: draft.name.trim(),
                  countsAsSaving: draft.countsAsSaving,
                  hidden: old.hidden,
                )
              : category,
      ],
    );
  }

  @override
  Future<void> setCategoryHidden({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  }) async {
    _checkOnline();
    final old = _existing(_categories, (c) => c.id == id);
    hiddenChanges.add((
      collection: 'categories',
      id: id,
      hidden: hidden,
      uid: uid,
    ));
    logActivity(
      categoryActivity(
        hidden ? ActivityAction.categoryHide : ActivityAction.categoryShow,
        old.name,
      ),
      uid,
    );
    put(
      categories: [
        for (final category in _categories)
          category.id == id
              ? Category(
                  id: id,
                  name: old.name,
                  countsAsSaving: old.countsAsSaving,
                  hidden: hidden,
                )
              : category,
      ],
    );
  }

  @override
  Future<String> addPaymentMethod({
    required String ledgerId,
    required PaymentMethodDraft draft,
    required int order,
    required String uid,
  }) async {
    _checkOnline();
    addedPaymentMethods.add((
      ledgerId: ledgerId,
      draft: draft,
      order: order,
      uid: uid,
    ));
    final id = 'method-new-${addedPaymentMethods.length}';
    logActivity(
      paymentMethodActivity(
        ActivityAction.paymentMethodCreate,
        draft.name,
        draft.kind,
      ),
      uid,
    );
    put(
      paymentMethods: [
        ..._paymentMethods,
        PaymentMethod(id: id, name: draft.name.trim(), kind: draft.kind),
      ],
    );
    return id;
  }

  @override
  Future<void> renamePaymentMethod({
    required String ledgerId,
    required String id,
    required String name,
    required String uid,
  }) async {
    _checkOnline();
    final old = _existing(_paymentMethods, (m) => m.id == id);
    renamedPaymentMethods.add((
      ledgerId: ledgerId,
      id: id,
      name: name,
      uid: uid,
    ));
    logActivity(
      paymentMethodRenameActivity(from: old.name, to: name, kind: old.kind),
      uid,
    );
    _putMethod(
      PaymentMethod(
        id: id,
        name: name.trim(),
        kind: old.kind,
        hidden: old.hidden,
      ),
    );
  }

  @override
  Future<void> setPaymentMethodHidden({
    required String ledgerId,
    required String id,
    required bool hidden,
    required String uid,
  }) async {
    _checkOnline();
    final old = _existing(_paymentMethods, (m) => m.id == id);
    hiddenChanges.add((
      collection: 'paymentMethods',
      id: id,
      hidden: hidden,
      uid: uid,
    ));
    logActivity(
      paymentMethodActivity(
        hidden
            ? ActivityAction.paymentMethodHide
            : ActivityAction.paymentMethodShow,
        old.name,
        old.kind,
      ),
      uid,
    );
    _putMethod(
      PaymentMethod(id: id, name: old.name, kind: old.kind, hidden: hidden),
    );
  }

  void _putMethod(PaymentMethod changed) => put(
    paymentMethods: [
      for (final method in _paymentMethods)
        method.id == changed.id ? changed : method,
    ],
  );

  void _checkOnline() {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write failed');
    }
    if (offline) {
      throw const SettingsWriteException(SettingsWriteFailure.offline);
    }
  }

  static T _existing<T>(List<T> items, bool Function(T) test) =>
      items.where(test).firstOrNull ??
      (throw const SettingsWriteException(SettingsWriteFailure.notFound));
}

/// 화면 테스트용 가짜 항목 저장소. 넣어 둔 달의 항목을 돌려주고, 없는 달은 빈 달이다.
///
/// 실제 저장소처럼 휴지통 항목은 목록에서 빼고 [MonthLedger.trashed]에 둔 [MonthLedger]를 넣는다.
/// [put]으로 바꾸면 구독 중인 곳에 다시 알린다. [MonthLedger.plannedIds]에는 휴지통에 든 기본 월 지출의 id까지 들어간다.
/// 쓰기도 실제 약속을 지킨다: 추가는 [offline]이어도 되고, 고치기·휴지통·꺼내기·완전 삭제·고정 지출로 채우기는 [offline]이면
/// [EntryWriteFailure.offline]으로, 없는 항목(휴지통에 든 항목을 고치거나 휴지통 밖의 항목을 꺼내거나 지울 때 포함)이면
/// [EntryWriteFailure.notFound]로 실패한다. 고정 지출로 채울 때는 그 id의 기본 월 지출이 있으면(휴지통 포함) 건너뛴다.
/// 휴지통에 넣으면 [now]로 넣은 때와 자동으로 지울 때를 적는다([staysInTrash]면 자동으로 지우지 않는다).
class FakeEntriesRepository with LogsActivity implements EntriesRepository {
  FakeEntriesRepository([Map<YearMonth, MonthLedger> months = const {}])
    : _months = {...months};

  final Map<YearMonth, MonthLedger> _months;
  final _changes = StreamController<void>.broadcast();

  /// 지금 시각. 휴지통에 넣은 때와 자동으로 지울 때를 정한다.
  DateTime Function() now = () => testNow;

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
  final purged =
      <({String ledgerId, YearMonth month, EntryKind kind, String id})>[];

  /// 고정 지출로 채운 기록. 넘겨받은 고정 지출 id와 실제로 만든 개수를 남긴다.
  final filled =
      <
        ({
          String ledgerId,
          YearMonth month,
          List<String> templateIds,
          int created,
          String uid,
        })
      >[];

  /// true면 다음 구독이 권한 오류처럼 실패한다.
  bool failNextWatch = false;

  /// true면 연결이 없는 것처럼 고치기·휴지통·꺼내기·완전 삭제가 실패한다. 추가는 된다.
  bool offline = false;

  /// true면 다음 쓰기가 [EntryWriteException]이 아닌 오류(권한 등)로 실패한다.
  bool failNextWrite = false;

  /// true면 다음 추가를 서버가 거부한 것처럼 한다. 실제 저장소처럼 [add]는 성공하고 목록에 들어갔다가,
  /// 서버 응답이 온 뒤처럼 조금 뒤에 빠지며 [rejectedAdds]로 알린다. 같은 일괄 쓰기의 변경 기록도 빠진다.
  bool rejectNextAdd = false;
  final _rejected = StreamController<RejectedEntry>.broadcast();

  @override
  Stream<RejectedEntry> get rejectedAdds => _rejected.stream;

  /// [month]의 항목을 바꾼다. 어느 가계부를 물어도 같은 달이면 같은 항목이다.
  void put(YearMonth month, MonthLedger ledger) {
    _months[month] = ledger;
    _changes.add(null);
  }

  /// [month]의 지금 항목. 휴지통 항목은 [MonthLedger.trashed]에 있다.
  MonthLedger monthOf(YearMonth month) => _months[month] ?? const MonthLedger();

  /// 실제 구독처럼 첫 값을 보내기 전에 변경을 듣기 시작한다. 첫 값을 받자마자 쓴 것(고정 지출 채우기)도 놓치지 않는다.
  @override
  Stream<MonthLedger> watchMonth(String ledgerId, YearMonth month) {
    StreamSubscription<void>? changes;
    late final StreamController<MonthLedger> controller;
    controller = StreamController<MonthLedger>(
      onListen: () {
        watched.add((ledgerId: ledgerId, month: month));
        if (failNextWatch) {
          failNextWatch = false;
          controller.addError(StateError('watchMonth failed'));
          return;
        }
        changes = _changes.stream.listen((_) => controller.add(monthOf(month)));
        controller.add(monthOf(month));
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
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
    final activityId = logActivity(
      entryActivity(
        ActivityAction.entryCreate,
        month: month,
        kind: draft.kind,
        entry: draft,
      ),
      uid,
    );
    if (rejectNextAdd) {
      rejectNextAdd = false;
      scheduleMicrotask(() {
        _edit(
          month,
          draft.kind,
          (entries) => [...entries.where((e) => e.id != id)],
        );
        if (activityId != null) activity?.drop(activityId);
        _rejected.add((id: id, month: month, kind: draft.kind));
      });
    }
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
    final before = _live(month, draft.kind, id);
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
    logActivity(
      entryActivity(
        ActivityAction.entryUpdate,
        month: month,
        kind: draft.kind,
        entry: draft,
        before: EntryDraft.of(before),
      ),
      uid,
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
    final at = now();
    final stays = staysInTrash(
      entry,
      month: month,
      thisMonth: YearMonth.of(at),
    );
    _edit(
      month,
      kind,
      (entries) => [...entries.where((e) => e.id != id)],
      trash: (items) => [
        ...items,
        TrashedEntry(
          entry: entry,
          deletedAt: at,
          purgeAt: stays ? null : at.add(trashRetention),
        ),
      ],
    );
    _logEntry(ActivityAction.entryTrash, month, entry, uid);
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
    final item = _inTrash(month, kind, id);
    restored.add((ledgerId: ledgerId, month: month, kind: kind, id: id));
    _edit(
      month,
      kind,
      (entries) => [...entries, item.entry],
      trash: (items) => [...items.where((i) => i != item)],
    );
    _logEntry(ActivityAction.entryRestore, month, item.entry, uid);
  }

  @override
  Future<void> purge({
    required String ledgerId,
    required YearMonth month,
    required EntryKind kind,
    required String id,
    required String uid,
  }) async {
    _checkOnline();
    final item = _inTrash(month, kind, id);
    purged.add((ledgerId: ledgerId, month: month, kind: kind, id: id));
    _edit(
      month,
      kind,
      (entries) => entries,
      trash: (items) => [...items.where((i) => i != item)],
      forget: id,
    );
    _logEntry(ActivityAction.entryPurge, month, item.entry, uid);
  }

  @override
  Future<int> fillPlanned({
    required String ledgerId,
    required YearMonth month,
    required List<ExpenseTemplate> templates,
    required String uid,
  }) async {
    _checkOnline();
    final existing = monthOf(month).plannedIds;
    final missing = [
      for (final template in templates)
        if (!existing.contains(template.id)) template,
    ];
    filled.add((
      ledgerId: ledgerId,
      month: month,
      templateIds: [for (final template in templates) template.id],
      created: missing.length,
      uid: uid,
    ));
    if (missing.isNotEmpty) {
      _edit(
        month,
        EntryKind.planned,
        (entries) => [
          ...entries,
          for (final template in missing)
            _entryOf(template.id, template.draftFor(month)),
        ],
      );
    }
    return missing.length;
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

  void _logEntry(
    ActivityAction action,
    YearMonth month,
    LedgerEntry entry,
    String uid,
  ) => logActivity(
    entryActivity(
      action,
      month: month,
      kind: entry.kind,
      entry: EntryDraft.of(entry),
    ),
    uid,
  );

  // 휴지통 밖에 있는 [id] 항목. 없으면 실제 저장소처럼 notFound로 실패한다.
  LedgerEntry _live(YearMonth month, EntryKind kind, String id) =>
      _entriesOf(monthOf(month), kind).where((e) => e.id == id).firstOrNull ??
      (throw const EntryWriteException(EntryWriteFailure.notFound));

  // 휴지통에 있는 [id] 항목. 없으면 실제 저장소처럼 notFound로 실패한다.
  TrashedEntry _inTrash(YearMonth month, EntryKind kind, String id) =>
      monthOf(month).trashed
          .where((i) => i.entry.kind == kind && i.entry.id == id)
          .firstOrNull ??
      (throw const EntryWriteException(EntryWriteFailure.notFound));

  // [kind] 목록과 휴지통을 바꾼다. 완전히 지운 문서([forget])는 실제처럼 기본 월 지출 id에서도 빠진다.
  void _edit(
    YearMonth month,
    EntryKind kind,
    List<LedgerEntry> Function(List<LedgerEntry> entries) change, {
    List<TrashedEntry> Function(List<TrashedEntry> items)? trash,
    String? forget,
  }) {
    final ledger = monthOf(month);
    final entries = change(_entriesOf(ledger, kind));
    final trashed = trash == null ? ledger.trashed : trash(ledger.trashed);
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
        trashed: trashed,
        plannedIds: {...ledger.plannedIds}..remove(forget),
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
        dueOn: draft.dueOn,
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

/// 화면 테스트용 가짜 고정 지출 저장소. 어느 가계부를 물어도 같은 목록을 돌려준다.
///
/// 실제 저장소처럼 쓰기는 모두 [offline]이면 [TemplateWriteFailure.offline]으로 실패하고,
/// 없는 고정 지출을 고치거나 지우면 [TemplateWriteFailure.notFound]로 실패한다. 되돌리기는 같은 id가 있으면 그대로 둔다.
class FakeTemplatesRepository with LogsActivity implements TemplatesRepository {
  FakeTemplatesRepository([List<ExpenseTemplate> initial = const []])
    : _templates = [...initial];

  final List<ExpenseTemplate> _templates;
  final _changes = StreamController<void>.broadcast();

  /// 쓴 기록.
  final added = <({String ledgerId, TemplateDraft draft, String uid})>[];
  final updated =
      <({String ledgerId, String id, TemplateDraft draft, String uid})>[];
  final deleted = <({String ledgerId, String id, String uid})>[];
  final restored = <({String ledgerId, String id, String uid})>[];

  /// 구독한 가계부 id.
  final watched = <String>[];

  /// true면 연결이 없는 것처럼 모든 쓰기가 실패한다.
  bool offline = false;

  /// true면 다음 쓰기가 [TemplateWriteException]이 아닌 오류(권한 등)로 실패한다.
  bool failNextWrite = false;

  /// 지금 고정 지출 목록.
  List<ExpenseTemplate> get templates => List.unmodifiable(_templates);

  /// 그사이 상대가 고친 것처럼 목록을 바꾼다. 구독 중인 곳에 다시 알린다.
  void put(List<ExpenseTemplate> templates) {
    _templates
      ..clear()
      ..addAll(templates);
    _changes.add(null);
  }

  // 구독을 시작하자마자 바뀜을 듣는다. 실제 구독처럼 첫 값을 낸 직후에 바뀐 목록도 놓치지 않는다.
  @override
  Stream<List<ExpenseTemplate>> watchTemplates(String ledgerId) {
    watched.add(ledgerId);
    return Stream.multi((controller) {
      controller.add(templates);
      final changes = _changes.stream.listen((_) => controller.add(templates));
      controller.onCancel = changes.cancel;
    });
  }

  @override
  Future<String> add({
    required String ledgerId,
    required TemplateDraft draft,
    required String uid,
  }) async {
    _checkOnline();
    added.add((ledgerId: ledgerId, draft: draft, uid: uid));
    final id = 'template-new-${added.length}';
    put([..._templates, _templateOf(id, draft)]);
    logActivity(templateActivity(ActivityAction.templateCreate, draft), uid);
    return id;
  }

  @override
  Future<void> update({
    required String ledgerId,
    required String id,
    required TemplateDraft draft,
    required String uid,
  }) async {
    _checkOnline();
    final before = _existing(id);
    updated.add((ledgerId: ledgerId, id: id, draft: draft, uid: uid));
    logActivity(
      templateActivity(
        ActivityAction.templateUpdate,
        draft,
        before: TemplateDraft.of(before),
      ),
      uid,
    );
    put([
      for (final template in _templates)
        template.id == id ? _templateOf(id, draft) : template,
    ]);
  }

  @override
  Future<void> delete({
    required String ledgerId,
    required String id,
    required String uid,
  }) async {
    _checkOnline();
    final template = _existing(id);
    deleted.add((ledgerId: ledgerId, id: id, uid: uid));
    put([..._templates.where((t) => t.id != id)]);
    logActivity(
      templateActivity(
        ActivityAction.templateDelete,
        TemplateDraft.of(template),
      ),
      uid,
    );
  }

  @override
  Future<void> restore({
    required String ledgerId,
    required ExpenseTemplate template,
    required String uid,
  }) async {
    _checkOnline();
    restored.add((ledgerId: ledgerId, id: template.id, uid: uid));
    if (_templates.any((t) => t.id == template.id)) return;
    put([..._templates, template]);
    logActivity(
      templateActivity(
        ActivityAction.templateRestore,
        TemplateDraft.of(template),
      ),
      uid,
    );
  }

  void _checkOnline() {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write failed');
    }
    if (offline) {
      throw const TemplateWriteException(TemplateWriteFailure.offline);
    }
  }

  ExpenseTemplate _existing(String id) =>
      _templates.where((t) => t.id == id).firstOrNull ??
      (throw const TemplateWriteException(TemplateWriteFailure.notFound));

  // 저장한 문서를 다시 읽은 것과 같은 고정 지출. 실제 저장소는 제목 앞뒤 공백을 뺀다.
  static ExpenseTemplate _templateOf(String id, TemplateDraft draft) =>
      ExpenseTemplate(
        id: id,
        title: draft.title.trim(),
        amount: draft.amount,
        categoryId: draft.categoryId ?? '',
        paymentMethodId: draft.paymentMethodId ?? '',
        memberId: draft.memberId,
        dueDay: draft.dueDay ?? lastDueDay,
      );
}

/// 화면 테스트용 가짜 변경 기록 저장소. 다른 가짜 저장소가 쓸 때 [log]로 기록을 더한다([LogsActivity]).
///
/// 실제 저장소처럼 새것부터 [ActivityRepository.watchRecent]의 개수만 구독으로 알리고, 더 오래된 것은 [loadOlder]로 읽는다.
/// 남기는 기록의 시간은 [now]에서 기록마다 1분씩 늦춘다(시간이 같은 기록이 없게).
class FakeActivityRepository implements ActivityRepository {
  FakeActivityRepository([List<Activity> initial = const []])
    : _items = [...initial];

  final List<Activity> _items;
  final _changes = StreamController<void>.broadcast();

  /// 처음 기록의 시간.
  DateTime Function() now = () => testNow;

  /// 구독한 가계부 id.
  final watched = <String>[];

  /// '더 보기'로 읽은 기록.
  final loads = <({String ledgerId, DateTime before, int limit})>[];

  /// true면 다음 구독이 권한 오류처럼 실패한다.
  bool failNextWatch = false;

  /// true면 다음 '더 보기'가 실패한다.
  bool failNextLoad = false;

  /// 남긴 기록. 남긴 순서(오래된 것부터)다.
  List<Activity> get activities => List.unmodifiable(_items);

  /// 남긴 기록의 동작과 요약. 남긴 순서다.
  List<ActivityDraft> get logged => [
    for (final item in _items)
      if (item.action case final action?) ActivityDraft(action, item.summary),
  ];

  /// [uid]가 [draft]를 남긴 것처럼 기록을 더하고 id를 돌려준다. 실제 저장소처럼 요약을 규칙의 길이로 자른다.
  String log(ActivityDraft draft, {required String uid}) {
    final id = 'activity-${_items.length + 1}';
    _items.add(
      Activity(
        id: id,
        actorUid: uid,
        action: draft.action,
        summary: clampActivitySummary(draft.summary),
        at: now().add(Duration(minutes: _items.length)),
      ),
    );
    _changes.add(null);
    return id;
  }

  /// 서버가 거부한 일괄 쓰기처럼 [id] 기록을 뺀다.
  void drop(String id) {
    _items.removeWhere((item) => item.id == id);
    _changes.add(null);
  }

  /// 상대가 남긴 것처럼 기록을 바꾼다. 구독 중인 곳에 다시 알린다.
  void put(List<Activity> items) {
    _items
      ..clear()
      ..addAll(items);
    _changes.add(null);
  }

  // 새것부터. 아직 서버에 닿지 않은 기록(시간 없음)이 맨 앞이다.
  List<Activity> get _newestFirst => [..._items]
    ..sort((a, b) {
      final (aAt, bAt) = (a.at, b.at);
      if (aAt == null || bAt == null) {
        return (aAt == null ? 0 : 1) - (bAt == null ? 0 : 1);
      }
      return bAt.compareTo(aAt);
    });

  @override
  Stream<List<Activity>> watchRecent(
    String ledgerId, {
    int limit = activityPageSize,
  }) {
    watched.add(ledgerId);
    if (failNextWatch) {
      failNextWatch = false;
      return Stream.error(StateError('watchRecent failed'));
    }
    return Stream.multi((controller) {
      controller.add([..._newestFirst.take(limit)]);
      final changes = _changes.stream.listen(
        (_) => controller.add([..._newestFirst.take(limit)]),
      );
      controller.onCancel = changes.cancel;
    });
  }

  @override
  Future<List<Activity>> loadOlder(
    String ledgerId, {
    required DateTime before,
    int limit = activityPageSize,
  }) async {
    loads.add((ledgerId: ledgerId, before: before, limit: limit));
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('loadOlder failed');
    }
    return [
      ..._newestFirst
          .where((item) => item.at?.isBefore(before) ?? false)
          .take(limit),
    ];
  }
}

/// 공휴일 가짜. 해마다 정해 둔 공휴일을 내보내고, 구독한 해를 남긴다(읽기 횟수 확인용).
class FakeHolidaysRepository implements HolidaysRepository {
  FakeHolidaysRepository([Map<int, Holidays> years = const {}])
    : _years = {...years};

  final Map<int, Holidays> _years;
  final watched = <int>[];

  @override
  Stream<Holidays> watchYear(int year) {
    watched.add(year);
    return Stream.value(_years[year] ?? const Holidays());
  }
}
