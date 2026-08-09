import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/api_type.dart';
import 'package:PiliPlus/utils/local_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

List<SettingsModel> get privacySettings => [
  NormalModel(
    onTap: (context, setState) {
      if (!Accounts.main.isLogin) {
        SmartDialog.showToast('登录后查看');
        return;
      }
      Get.toNamed('/blackListPage');
    },
    title: '黑名单管理',
    subtitle: '已拉黑用户',
    leading: const Icon(Icons.block),
  ),
  NormalModel(
    onTap: (context, setState) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('清空本地历史'),
          content: const Text(
            '将清除本机保存的观看记录（专注模式历史），不影响云端账号历史。此操作不可撤销。',
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '取消',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Get.back();
                await LocalHistory.clear();
                SmartDialog.showToast('已清空本地观看记录');
              },
              child: const Text('确认清空'),
            ),
          ],
        ),
      );
    },
    title: '清空本地历史',
    subtitle: '仅清除本机专注模式观看记录',
    leading: const Icon(Icons.history_toggle_off_outlined),
  ),
  NormalModel(
    onTap: (context, setState) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('账号模式详情'),
          content: SelectionArea(
            child: SingleChildScrollView(
              child: _getAccountDetail(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text('确认'),
            ),
          ],
        ),
      );
    },
    leading: const Icon(Icons.flag_outlined),
    title: '了解账号模式',
    subtitle: '查看各个账号模式作用的API列表',
  ),
];

Widget _getAccountDetail(BuildContext context) {
  final children = <Widget>[];
  final theme = TextTheme.of(context);
  for (final i in AccountType.values) {
    final url = ApiType.apiTypeSet[i];
    if (url == null) continue;

    children
      ..add(Center(child: Text(i.title, style: theme.titleMedium)))
      ..add(Text(url.join('\n')));
  }
  return Column(
    spacing: 8,
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    children: children,
  );
}
