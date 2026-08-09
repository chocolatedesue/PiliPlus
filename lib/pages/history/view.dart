import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/keep_alive_wrapper.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show tabBarScrollPhysics;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/history/controller.dart';
import 'package:PiliPlus/pages/history/widgets/item.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.type, this.embedded = false});

  final String? type;

  /// When true (e.g. Focus home tab), skip outer [SimpleScaffold]/AppBar to
  /// avoid a double app bar under [HomePage]. History actions stay available
  /// via an in-body toolbar.
  final bool embedded;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with AutomaticKeepAliveClientMixin, GridMixin {
  late final HistoryController _historyController;
  late final bool _useLocal;
  late final TextEditingController _filterCtrl;

  @override
  void initState() {
    super.initState();
    // Focus path: pure local store. Normal-mode cloud path unchanged.
    _useLocal = Pref.enableFocusMode || widget.embedded;
    _filterCtrl = TextEditingController();
    _historyController = Get.put(
      HistoryController(widget.type, useLocalHistory: _useLocal),
      tag: _useLocal
          ? 'local_${widget.type ?? 'all'}'
          : (widget.type ?? 'all'),
    );
  }

  HistoryController currCtr([int? index]) {
    try {
      index ??= _historyController.tabController!.index;
      if (index != 0) {
        final type = _historyController.tabs[index - 1].type;
        return Get.find<HistoryController>(
          tag: _useLocal ? 'local_$type' : type,
        );
      }
    } catch (_) {}
    return _historyController;
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    // Do not Get.delete HistoryBaseController here — it is permanent and shared
    // by home-embed, bottom-nav, and /history (YQH-74 D2-history-embed).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final padding = MediaQuery.viewPaddingOf(context);
    Widget child = refreshIndicator(
      onRefresh: _historyController.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _historyController.scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              top: 7,
              bottom: padding.bottom + 100,
            ),
            sliver: Obx(
              () => _buildBody(_historyController.loadingState.value),
            ),
          ),
        ],
      ),
    );
    if (widget.type != null) {
      return child;
    }
    return Obx(
      () {
        final enableMultiSelect =
            _historyController.baseCtr.enableMultiSelect.value;
        final body = Padding(
          padding: .only(left: padding.left, right: padding.right),
          child: Obx(() {
            final tabs = _historyController.tabs;
            if (tabs.isEmpty) {
              if (!widget.embedded) {
                if (!_useLocal) return child;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocalFilterBar,
                    Expanded(child: child),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEmbeddedToolbar,
                  if (_useLocal) _buildLocalFilterBar,
                  ?_buildPauseTip,
                  Expanded(child: child),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded) _buildEmbeddedToolbar,
                if (_useLocal) _buildLocalFilterBar,
                ?_buildPauseTip,
                TabBar(
                  controller: _historyController.tabController,
                  onTap: (index) {
                    if (!_historyController.tabController!.indexIsChanging) {
                      currCtr().scrollController.animToTop();
                    } else {
                      if (enableMultiSelect) {
                        currCtr(
                          _historyController.tabController!.previousIndex,
                        ).handleSelect();
                      }
                    }
                  },
                  tabs: [
                    const Tab(text: '全部'),
                    ...tabs.map((item) => Tab(text: item.name)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    physics: enableMultiSelect
                        ? const NeverScrollableScrollPhysics()
                        : tabBarScrollPhysics,
                    controller: _historyController.tabController,
                    horizontalDragGestureRecognizer:
                        CustomHorizontalDragGestureRecognizer.new,
                    children: [
                      KeepAliveWrapper(child: child),
                      ...tabs.map(
                        (item) => HistoryPage(type: item.type),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        );

        if (widget.embedded) {
          return popScope(
            canPop: !enableMultiSelect,
            onPopInvokedWithResult: (didPop, result) {
              if (enableMultiSelect) {
                currCtr().handleSelect();
              }
            },
            child: body,
          );
        }

        return popScope(
          canPop: !enableMultiSelect,
          onPopInvokedWithResult: (didPop, result) {
            if (enableMultiSelect) {
              currCtr().handleSelect();
            }
          },
          child: SimpleScaffold(
            appBar: MultiSelectAppBarWidget(
              visible: enableMultiSelect,
              ctr: currCtr(),
              child: _buildAppBar,
            ),
            body: body,
          ),
        );
      },
    );
  }

  /// Inline local keyword + business filter (never opens cloud /search).
  Widget get _buildLocalFilterBar {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _filterCtrl,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '筛选标题 / UP',
                  prefixIcon: const Icon(Icons.filter_list, size: 18),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.onSecondaryContainer
                      .withValues(alpha: 0.06),
                ),
                onChanged: (v) =>
                    _historyController.applyLocalFilters(query: v),
                onSubmitted: (v) =>
                    _historyController.applyLocalFilters(query: v),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Obx(() {
            final current = _historyController.localBusiness.value;
            final label = HistoryController.businessFilters
                .firstWhere(
                  (e) => e.value == current,
                  orElse: () => HistoryController.businessFilters.first,
                )
                .label;
            return PopupMenuButton<String>(
              tooltip: '按类型筛选',
              initialValue: current,
              onSelected: (v) =>
                  _historyController.applyLocalFilters(business: v),
              itemBuilder: (_) => HistoryController.businessFilters
                  .map(
                    (e) => PopupMenuItem(
                      value: e.value,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Compact actions when nested under Home (no second AppBar).
  Widget get _buildEmbeddedToolbar {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '观看记录',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          // Cloud / global search hidden in focus-local path (AC4).
          if (!_useLocal)
            IconButton(
              tooltip: '搜索',
              onPressed: () => Get.toNamed('/historySearch'),
              icon: const Icon(Icons.search_outlined),
            ),
          PopupMenuButton(
            itemBuilder: (_) => [
              if (!_useLocal)
                PopupMenuItem(
                  onTap: () =>
                      _historyController.baseCtr.onPauseHistory(context),
                  child: Text(
                    !_historyController.baseCtr.pauseStatus.value
                        ? '暂停观看记录'
                        : '恢复观看记录',
                  ),
                ),
              PopupMenuItem(
                onTap: () => _historyController.baseCtr.onClearHistory(
                  context,
                  () {
                    _historyController.loadingState.value = const Success(null);
                    if (_historyController.tabController != null) {
                      for (final item in _historyController.tabs) {
                        try {
                          Get.find<HistoryController>(
                            tag: _useLocal
                                ? 'local_${item.type}'
                                : item.type,
                          ).loadingState.value = const Success(
                            null,
                          );
                        } catch (_) {}
                      }
                    }
                  },
                ),
                child: Text(_useLocal ? '清空本地观看记录' : '清空观看记录'),
              ),
              PopupMenuItem(
                onTap: currCtr().onDelViewedHistory,
                child: const Text('删除已看记录'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  AppBar get _buildAppBar => AppBar(
    title: Text(_useLocal ? '本地观看记录' : '观看记录'),
    actions: [
      if (!_useLocal)
        IconButton(
          tooltip: '搜索',
          onPressed: () => Get.toNamed('/historySearch'),
          icon: const Icon(Icons.search_outlined),
        ),
      PopupMenuButton(
        itemBuilder: (_) => [
          if (!_useLocal)
            PopupMenuItem(
              onTap: () => _historyController.baseCtr.onPauseHistory(context),
              child: Text(
                !_historyController.baseCtr.pauseStatus.value
                    ? '暂停观看记录'
                    : '恢复观看记录',
              ),
            ),
          PopupMenuItem(
            onTap: () => _historyController.baseCtr.onClearHistory(
              context,
              () {
                _historyController.loadingState.value = const Success(null);
                if (_historyController.tabController != null) {
                  for (final item in _historyController.tabs) {
                    try {
                      Get.find<HistoryController>(
                        tag: _useLocal ? 'local_${item.type}' : item.type,
                      ).loadingState.value = const Success(
                        null,
                      );
                    } catch (_) {}
                  }
                }
              },
            ),
            child: Text(_useLocal ? '清空本地观看记录' : '清空观看记录'),
          ),
          PopupMenuItem(
            onTap: currCtr().onDelViewedHistory,
            child: const Text('删除已看记录'),
          ),
        ],
      ),
      const SizedBox(width: 6),
    ],
  );

  Widget _buildBody(LoadingState<List<HistoryItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    _historyController.onLoadMore();
                  }
                  final item = response[index];
                  return HistoryItem(
                    item: item,
                    ctr: _historyController,
                    onDelete: (kid, business) =>
                        _historyController.delHistory(item),
                  );
                },
                itemCount: response.length,
              )
            : HttpError(onReload: _historyController.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: _historyController.onReload,
      ),
    };
  }

  PreferredSizeWidget? get _buildPauseTip {
    if (_useLocal) return null;
    if (_historyController.baseCtr.pauseStatus.value) {
      final theme = Theme.of(context).colorScheme;
      return PreferredSize(
        preferredSize: const Size.fromHeight(38),
        child: Container(
          height: 38,
          color: theme.secondaryContainer.withValues(alpha: 0.8),
          padding: const EdgeInsets.only(left: 16, right: 6),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  strutStyle: const StrutStyle(height: 1, leading: 0),
                  style: TextStyle(
                    height: 1,
                    color: theme.onSecondaryContainer,
                  ),
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.onSecondaryContainer,
                        ),
                      ),
                      const TextSpan(text: ' 历史记录功能已关闭'),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _historyController.baseCtr.onPauseHistory(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
                  ),
                  child: Text(
                    '点击开启',
                    strutStyle: const StrutStyle(height: 1, leading: 0),
                    style: TextStyle(height: 1, color: theme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return null;
  }

  @override
  bool get wantKeepAlive => widget.type != null || widget.embedded;
}
