import '../../repository/settings_repository.dart';
import 'rename_member_use_case.dart';
import 'save_category_use_case.dart';
import 'save_payment_method_use_case.dart';
import 'set_category_hidden_use_case.dart';
import 'set_payment_method_hidden_use_case.dart';
import 'watch_categories_use_case.dart';
import 'watch_members_use_case.dart';
import 'watch_payment_methods_use_case.dart';

/// 가계부 설정(이름표·분류·결제수단) UseCase 묶음. 설정 공급자와 설정 시트가 읽는다.
class SettingsUseCases {
  SettingsUseCases(SettingsRepository settings)
    : watchMembers = WatchMembersUseCase(settings),
      watchCategories = WatchCategoriesUseCase(settings),
      watchPaymentMethods = WatchPaymentMethodsUseCase(settings),
      renameMember = RenameMemberUseCase(settings),
      saveCategory = SaveCategoryUseCase(settings),
      setCategoryHidden = SetCategoryHiddenUseCase(settings),
      savePaymentMethod = SavePaymentMethodUseCase(settings),
      setPaymentMethodHidden = SetPaymentMethodHiddenUseCase(settings);

  final WatchMembersUseCase watchMembers;
  final WatchCategoriesUseCase watchCategories;
  final WatchPaymentMethodsUseCase watchPaymentMethods;
  final RenameMemberUseCase renameMember;
  final SaveCategoryUseCase saveCategory;
  final SetCategoryHiddenUseCase setCategoryHidden;
  final SavePaymentMethodUseCase savePaymentMethod;
  final SetPaymentMethodHiddenUseCase setPaymentMethodHidden;
}
