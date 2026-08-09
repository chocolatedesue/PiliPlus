import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/history/tab.dart';
import 'package:PiliPlus/pages/common/multi_select/multi_select_controller.dart';
import 'package:PiliPlus/pages/history/base_controller.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/local_history.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class HistoryController
    extends MultiSelectController<HistoryData, HistoryItemModel>
    with GetSingleTickerProviderStateMixin {
  HistoryController(this.type, {this.useLocalHistory = false});

  /// Focus / local-only path. Cloud controllers keep the default false.
  final bool useLocalHistory;

  /// Shared across root / embedded / typed History surfaces. Permanent so a
  /// disposing page never tears down base while another surface still uses it
  /// (YQH-74 D2-history-embed). Local and cloud use separate tags.
  late final baseCtr = Get.put(
    HistoryBaseController(useLocalHistory: useLocalHistory),
    tag: useLocalHistory ? 'local' : 'cloud',
    permanent: true,
  );

  Account get account => baseCtr.account;

  final String? type;
  TabController? tabController;
  late RxList<HistoryTab> tabs = <HistoryTab>[].obs;

  int? max;
  int? viewAt;

  /// Local keyword filter (title + authorName). Not the cloud /search route.
  final RxString localQuery = ''.obs;

  /// Local structured filter on `history.business` (`all` = no filter).
  final RxString localBusiness = 'all'.obs;

  static const List<({String value, String label})> businessFilters = [
    (value: 'all', label: '全部类型'),
    (value: 'archive', label: '视频'),
    (value: 'pgc', label: '番剧'),
    (value: 'live', label: '直播'),
    (value: 'article', label: '专栏'),
    (value: 'cheese', label: '课堂'),
  ];

  @override
  RxInt get rxCount => baseCtr.checkedCount;

  @override
  RxBool get enableMultiSelect => baseCtr.enableMultiSelect;

  @override
  void onInit() {
    super.onInit();
    if (!useLocalHistory) {
      historyStatus();
    }
    queryData();
  }

  @override
  Future<void> onRefresh() {
    max = null;
    viewAt = null;
    return super.onRefresh();
  }

  @override
  List<HistoryItemModel>? getDataList(HistoryData response) {
    return response.list;
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<HistoryData> response) {
    HistoryData data = response.response;
    isEnd = data.list.isNullOrEmpty;
    if (useLocalHistory) {
      // Local list is fully loaded in one shot.
      isEnd = true;
      return false;
    }
    max = data.list?.lastOrNull?.history.oid;
    viewAt = data.list?.lastOrNull?.viewAt;

    if (isRefresh && type == null) {
      if (tabs.isEmpty && data.tab?.isNotEmpty == true) {
        tabs.value = data.tab!;
        tabController = TabController(
          length: data.tab!.length + 1,
          vsync: this,
        );
      }
    }

    return false;
  }

  // 观看历史暂停状态
  Future<void> historyStatus() async {
    final res = await UserHttp.historyStatus(account: account);
    if (res case Success(:final response)) {
      baseCtr.pauseStatus.value = response;
      GStorage.localCache.put(LocalCacheKey.historyPause, response);
    } else {
      res.toast();
    }
  }

  // 删除某条历史记录
  void delHistory(HistoryItemModel item) {
    _onDelete({item});
  }

  // 删除已看历史记录
  void onDelViewedHistory() {
    final viewedList = loadingState.value.dataOrNull
        ?.where((e) => e.progress == -1)
        .toSet();
    if (viewedList != null && viewedList.isNotEmpty) {
      _onDelete(viewedList);
    } else {
      SmartDialog.showToast('无已看记录');
    }
  }

  Future<void> _onDelete(Set<HistoryItemModel> removeList) async {
    if (useLocalHistory) {
      LocalHistory.removeMany(removeList);
      afterDelete(removeList);
      SmartDialog.showToast('已删除');
      return;
    }
    SmartDialog.showLoading(msg: '请求中');
    final res = await UserHttp.delHistory(
      removeList
          .map((item) => '${item.history.business}_${item.kid}')
          .join(','),
      account: account,
    );
    SmartDialog.dismiss();
    if (res.isSuccess) {
      afterDelete(removeList);
      SmartDialog.showToast('已删除');
    } else {
      res.toast();
    }
  }

  // 删除选中的记录
  @override
  void onRemove() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('提示'),
      content: const Text('确认删除所选历史记录吗？'),
      onConfirm: () => _onDelete(allChecked.toSet()),
    );
  }

  void applyLocalFilters({String? query, String? business}) {
    if (query != null) localQuery.value = query;
    if (business != null) localBusiness.value = business;
    onReload();
  }

  @override
  Future<LoadingState<HistoryData>> customGetData() async {
    if (useLocalHistory) {
      final list = LocalHistory.list(
        query: localQuery.value,
        business: localBusiness.value == 'all' ? null : localBusiness.value,
        desc: true,
      );
      // Optional type tab filter for typed child pages.
      final filtered = type == null || type == 'all'
          ? list
          : list.where((e) => e.history.business == type).toList();
      return Success(HistoryData(list: filtered));
    }
    return UserHttp.historyList(
      type: type ?? 'all',
      max: max,
      viewAt: viewAt,
      account: account,
    );
  }

  @override
  void onClose() {
    tabController?.dispose();
    super.onClose();
  }

  @override
  Future<void> onReload() {
    scrollController.jumpToTop();
    return super.onReload();
  }
}
