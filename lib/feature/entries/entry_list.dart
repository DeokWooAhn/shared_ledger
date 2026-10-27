import '../../domain/model/category.dart';
import '../../domain/model/ledger_entries.dart';
import '../../domain/model/month_ledger.dart';

/// 항목 탭 목록의 한 묶음. 기본 월 지출은 분류마다 묶고, 다른 종류는 제목 없는 한 묶음이다.
class EntryGroup {
  const EntryGroup({
    required this.entries,
    required this.total,
    this.title,
    this.countsAsSaving = false,
    this.key = 'all',
  });

  /// 묶음 제목. 기본 월 지출은 분류 이름('분류 없음' 포함)이고, 다른 종류는 null이다.
  final String? title;

  /// 저축으로 세는 분류의 묶음인지. '저축' 표시를 붙인다.
  final bool countsAsSaving;
  final List<LedgerEntry> entries;

  /// 묶음 합계(원). 금액 미정은 0원으로 친다.
  final int total;

  /// 목록에서 묶음을 구분하는 값. 분류 id이거나, 지워진 분류는 `none`, 묶지 않으면 `all`.
  final String key;
}

/// 항목 탭에 그릴 한 종류의 목록. 건수와 합계, 기본 월 지출이면 지급 전 건수까지 담는다.
class EntryList {
  const EntryList({
    required this.groups,
    required this.count,
    required this.total,
    this.unpaidCount = 0,
  });

  /// 한 달 항목에서 [kind] 종류의 목록을 만든다.
  ///
  /// 기본 월 지출은 설정의 분류 순서로 묶고, 설정에서 지워진 분류에 남은 항목은 맨 뒤 '분류 없음'에 모은다.
  /// 묶음 안에서는 제목 순서다. 다른 종류는 날짜가 늦은 것부터, 날짜가 없으면 맨 뒤다.
  factory EntryList.of(
    EntryKind kind,
    MonthLedger ledger, {
    required List<Category> categories,
  }) {
    final entries = switch (kind) {
      EntryKind.income => ledger.incomes,
      EntryKind.planned => ledger.plannedExpenses,
      EntryKind.extra => ledger.extraExpenses,
      EntryKind.cardBill => ledger.cardBills,
    };
    final total = _sum(entries);
    if (kind != EntryKind.planned) {
      final sorted = [...entries]..sort(_byDateDesc);
      return EntryList(
        groups: [
          if (sorted.isNotEmpty) EntryGroup(entries: sorted, total: total),
        ],
        count: entries.length,
        total: total,
      );
    }
    final planned = ledger.plannedExpenses;
    final known = {for (final category in categories) category.id};
    final orphans = planned.where((e) => !known.contains(e.categoryId));
    return EntryList(
      groups: [
        for (final category in categories)
          if (planned.where((e) => e.categoryId == category.id).toList()
              case final inCategory when inCategory.isNotEmpty)
            EntryGroup(
              key: category.id,
              title: category.name,
              countsAsSaving: category.countsAsSaving,
              entries: inCategory..sort(_byTitle),
              total: _sum(inCategory),
            ),
        if (orphans.isNotEmpty)
          EntryGroup(
            key: 'none',
            title: '분류 없음',
            entries: orphans.toList()..sort(_byTitle),
            total: _sum(orphans),
          ),
      ],
      count: planned.length,
      total: total,
      unpaidCount: planned.where((e) => !e.isPaid).length,
    );
  }

  final List<EntryGroup> groups;
  final int count;
  final int total;

  /// 지급하지 않은 기본 월 지출 건수. 다른 종류는 0이다.
  final int unpaidCount;

  bool get isEmpty => count == 0;
}

int _sum(Iterable<LedgerEntry> entries) =>
    entries.fold(0, (sum, entry) => sum + (entry.amount ?? 0));

String _titleOf(LedgerEntry entry) => switch (entry) {
  Income(:final title) ||
  PlannedExpense(:final title) ||
  ExtraExpense(:final title) => title,
  CardBill() => '',
};

int _byTitle(LedgerEntry a, LedgerEntry b) {
  final byTitle = _titleOf(a).compareTo(_titleOf(b));
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}

int _byDateDesc(LedgerEntry a, LedgerEntry b) {
  final (aDate, bDate) = (a.date, b.date);
  if (aDate != null && bDate != null && aDate != bDate) {
    return bDate.compareTo(aDate);
  }
  if (aDate == null && bDate != null) return 1;
  if (aDate != null && bDate == null) return -1;
  return _byTitle(a, b);
}
