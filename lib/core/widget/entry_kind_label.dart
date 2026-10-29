import '../../domain/model/ledger_entries.dart';
import '../providers/providers.dart';

/// 화면에 보이는 항목 종류 이름. 항목 탭과 휴지통이 같이 쓴다.
String entryKindLabel(EntryKind kind) => switch (kind) {
  EntryKind.income => '수입',
  EntryKind.planned => '고정 지출',
  EntryKind.extra => '추가 지출',
  EntryKind.cardBill => '카드 대금',
};

/// 항목 탭의 칸 이름.
String entryTabLabel(EntryTab tab) => switch (tab) {
  EntryTab.income => '수입',
  EntryTab.expense => '지출',
  EntryTab.cardBill => '카드 대금',
};
