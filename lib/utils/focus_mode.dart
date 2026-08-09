import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// Focus mode: slim UI (推荐 + 历史 + 我的), hide related feed,
/// force background playback. User prefs under the toggled keys
/// are left untouched — overrides are applied via [Pref] getters.
abstract final class FocusMode {
  static const List<NavigationBarType> navBars = [
    NavigationBarType.home,
    NavigationBarType.history,
    NavigationBarType.mine,
  ];

  static const List<HomeTabType> homeTabs = [HomeTabType.rcmd];

  static final RxBool enabled = Pref.enableFocusMode.obs;

  static bool get isEnabled => Pref.enableFocusMode;

  static Future<void> setEnabled(bool value) async {
    await GStorage.setting.put(SettingBoxKey.enableFocusMode, value);
    applyLive();
  }

  static Future<void> toggle() => setEnabled(!isEnabled);

  /// Re-apply layout + player flags after the pref flag changes.
  static void applyLive() {
    enabled.value = Pref.enableFocusMode;
    _applyPlayerFlags();
    // Home tabs first so the next shell rebuild sees a valid TabController.
    try {
      Get.find<HomeController>().reconfigureTabs();
    } catch (_) {}
    try {
      Get.find<MainController>().reconfigureLayout();
    } catch (_) {}
    SmartDialog.showToast(enabled.value ? '已开启专注模式' : '已关闭专注模式');
  }

  static void _applyPlayerFlags() {
    final bg = Pref.continuePlayInBackground;
    final related = Pref.showRelatedVideo;
    final audioSvc = Pref.enableBackgroundPlay;

    videoPlayerServiceHandler?.enableBackgroundPlay = audioSvc;

    final player = PlPlayerController.instance;
    if (player != null) {
      player
        ..continuePlayInBackground.value = bg
        ..showRelatedVideo = related;
    }
  }
}
