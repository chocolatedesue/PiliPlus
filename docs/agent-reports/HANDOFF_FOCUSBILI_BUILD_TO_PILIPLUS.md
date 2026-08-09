# Handoff：FocuBili 构建体系 → PiliPlus（专注 fork）+ 公开库

**日期：** 2026-08-09 UTC  
**作者会话：** yqh1 Grok / paseo（PiliPlus cwd）+ yqh2 FocuBili 云构建  
**下一步目标：** 把 FocuBili 的**云构建 / ABI split / 技能与脚本**移植到当前 PiliPlus（含 Focus Mode），并用 `gh` 在 **chocolatedesue** 下建**公开**仓库。

---

## 1. 一句话结论

| 源 | 状态 |
|----|------|
| **FocuBili** 构建技能与云流水线 | 已在 yqh2 验证通过（Android split + Windows GHA + macOS CM + 335 tests） |
| **PiliPlus** Focus Mode | 本地未提交改动（推荐/历史/我的 + 关相关推荐 + 强制后台播放） |
| **公开 fork 仓库** | **尚未创建**；`gh` 当前登录 **chocolatedesue**（yqh1/yqh2 均可，以有 `repo` scope 的为准） |

下一位 agent **不要**往上游 `bggRGjQaUbCoE/PiliPlus` 强推专注 fork；应 `gh repo create` 新公开库（建议名见下），再迁 CI。

---

## 2. 机器与路径

| 主机 | 角色 | 关键路径 |
|------|------|----------|
| **yqh1** | 本会话主工作区 | `/home/cnic/work/PiliPlus`（Focus 改动在此） |
| **yqh1** | FocuBili 浅克隆 | `/home/cnic/work/FocuBili` |
| **yqh2** | Flutter 3.44.9 + 已跑通云构建与产物 | `/home/cnic/work/FocuBili` |
| 网络 | yqh2 → GitHub HTTPS 偶发不通 | 用 CM/GHA 云端拉代码；yqh1 `gh` 多为 SSH |

### 凭证（勿写入仓库、勿在日志打全量）

| 用途 | 位置 | 说明 |
|------|------|------|
| GitHub CLI | `gh auth status` → **chocolatedesue** | scopes 至少 `repo`；发 GHA 需 `workflow`（yqh2 上曾有；yqh1 若缺则 `gh auth refresh -s workflow`） |
| Codemagic | yqh2 `~/.cmtoken`（`CM_API_TOKEN=...` 或纯 token） | FocuBili App ID：`6a769232581b36b2411fd1e6`（**PiliPlus 新库要新建 CM App，ID 会变**） |
| 镜像（yqh2 Flutter） | `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` → flutter-io.cn | 可选 |

### FocuBili 已成功构建快照（yqh2，供对照）

```
/home/cnic/work/FocuBili/artifacts/
  android-split/
    FocuBili-v1.2.0-android-arm64-v8a.apk      # 真机优先
    FocuBili-v1.2.0-android-armeabi-v7a.apk
    FocuBili-v1.2.0-android-x86_64.apk
  windows/FocuBili-master-windows.zip
  # macOS：CM build 6a77e8b956bff8120c2421a6 成功（本地目录以 yqh2 当时下载为准）
  # 旧 fat：FocuBili-android-b4.apk — 不要当正式发版
```

- Android CM buildId 示例：`6a77e8e668c245a89a38060f`  
- Windows GHA run 示例：`31290854698`  
- FocuBili HEAD（构建时）：`e405f9d` `chore: add project focubili-build skill...`

---

## 3. PiliPlus 当前代码状态（Focus Mode）

**工作区：** `/home/cnic/work/PiliPlus`  
**upstream remote：** `origin` → `https://github.com/bggRGjQaUbCoE/PiliPlus.git`（`main`）  
**基线提交（改动基于）：** `8fa622eb8` 一带 `main`

### 未提交变更（handoff 时）

**已修改：**

- `lib/models/common/nav_bar_config.dart` — `history` 导航项 + `displayLabel`（Focus 下首页→推荐）
- `lib/pages/home/controller.dart` / `view.dart` — Focus 仅 `rcmd` Tab + layoutEpoch
- `lib/pages/main/controller.dart` / `view.dart` — Focus 底栏 + 热更新 layoutEpoch
- `lib/pages/mine/controller.dart` / `view.dart` — 历史优先切 Tab；专注模式快捷开关
- `lib/pages/setting/models/style_settings.dart` / `view.dart` — 设置项「专注模式」
- `lib/plugin/pl_player/controller.dart` — `showRelatedVideo` 可写
- `lib/utils/storage_key.dart` / `storage_pref.dart` — `enableFocusMode` 及 Pref 覆盖

**新增：**

- `lib/utils/focus_mode.dart` — 一键开关总控

### Focus 行为摘要

开启后（**不永久改写**用户原 tab/nav 排序存储，运行时覆盖）：

1. 底栏：`推荐(home)` / `历史` / `我的`（无动态等）
2. 首页：仅推荐流，隐藏直播/热门/分区/番剧等多 Tab
3. `showRelatedVideo` → false  
4. `continuePlayInBackground` / `enableBackgroundPlay` → true  
5. 入口：设置 → 外观样式 → 专注模式；我的页靶心图标

### 已知缺口 / 风险

- 本机未跑 `flutter analyze`（yqh1 当时无 Flutter；yqh2 有 Flutter 但工作区在 FocuBili）
- 与上游 PiliPlus 已有 GHA（`win_x64.yml` / `mac.yml` / `linux_x64.yml` / `build.yml` / `ios.yml`）并存时，**移植 CM 技能要改名/对齐，避免重复冲突**
- 媒体依赖大量 git path / 自建 media_kit fork，云构建要能拉 GitHub 子依赖

---

## 4. 要从 FocuBili 移植的构建资产

### 权威文档 / 技能（先读）

| 路径（FocuBili） | 用途 |
|------------------|------|
| `.grok/skills/focubili-build/SKILL.md` | Agent 构建操作手册 |
| `.grok/skills/focubili-build/scripts/trigger_cloud_builds.sh` | 一键触发 CM + GHA |
| `.grok/skills/focubili-build/references/build-matrix.md` | 矩阵速查 |
| `docs/CODEMAGIC.md` | CM 说明 + curl CLI |
| `codemagic.yaml` | `android-apk` / `macos-build` / `windows-build` |
| `.github/workflows/windows-build.yml` | GHA Windows（Focu 侧） |
| `scripts/fetch_codemagic_android_split.sh` | 拉 split APK 并重命名 |
| `scripts/publish_github_release.sh` | 上传 Release + SHA256SUMS |
| `scripts/download_release.sh` | 下 Release |
| `android/app/build.gradle` 中 `splits.abi` + `universalApk false` | 禁止 fat 发布包 |

### 硬性产品规则（移植后仍遵守）

1. Android 发版 **只要** `flutter build apk --release --split-per-abi`  
2. **禁止**把 fat `app-release.apk` 当正式资产  
3. ABI：`armeabi-v7a` / `arm64-v8a`（多数真机）/ `x86_64`  
4. Token / keystore **永不进 git**  
5. Windows：优先 **GHA**；CM `windows_x2` 免费常不可用  
6. Android+macOS：CM **mac_mini_m2** 免费友好  

### PiliPlus 已有 CI（移植时对照，勿盲目覆盖）

```
.github/workflows/
  build.yml
  ios.yml
  linux_x64.yml
  mac.yml
  win_x64.yml
```

**建议策略：**

- **保留**上游多平台 workflow 作参考/继续用  
- **新增或改写**一层「发版友好」脚本 + 可选 `codemagic.yaml`  
- 技能改名为例如 `piliplus-build` / `focus-pili-build`，文案与 `PACKAGE_NAME`、仓库名全部替换  
- 触发脚本里的 `REPO` / `CM_APP_ID` / artifact 前缀改为新库名  

---

## 5. 下一步执行清单（建议顺序）

### Phase A — 公开库（gh）

在 **chocolatedesue** 下创建公开库（名称请最终确认，推荐其一）：

| 候选名 | 说明 |
|--------|------|
| `FocusPili` / `FocusPiliPlus` | 强调专注 fork |
| `PiliPlus-Focus` | 一眼看出上游关系 |
| `FocuPili` | 与 FocuBili 命名对称（易混，次选） |

**推荐命令骨架（确认名与是否从当前目录推送）：**

```bash
cd /home/cnic/work/PiliPlus

# 1) 确认账号
gh auth status
# 若缺 workflow scope：
# gh auth refresh -h github.com -s workflow -s repo

# 2) 提交 Focus 改动（仅本地 commit；先别 push 到 upstream origin）
git checkout -b focus/mode-and-ci
# … add/commit Focus 文件 …

# 3) 建公开空库并设 remote（示例名 FocusPiliPlus）
gh repo create chocolatedesue/FocusPiliPlus \
  --public \
  --description "PiliPlus fork with Focus Mode — non-official Bilibili client" \
  --source=. \
  --remote=focus \
  --push=false

# 若 create 不能 --source（已有 origin），则：
# gh repo create chocolatedesue/FocusPiliPlus --public --description "..."
# git remote add focus git@github.com:chocolatedesue/FocusPiliPlus.git

# 4) 推送
git push -u focus focus/mode-and-ci:main
# 或保留 main 与 focus 分支策略，二选一写进 README
```

**注意：**

- `origin` 仍指向上游时，**默认 push 会推错**；务必用独立 remote（`focus`）或改 `origin` 前二次确认。  
- README 必须写清：**非官方**、基于 PiliPlus、许可证遵循上游（GPL 等）。  
- 不要把上游 Issues 机器人/私密 CI secret 假设为可用。

### Phase B — 提交 Focus 代码

最小提交集合见 §3。建议 commit message：

```
feat: add Focus Mode (slim nav, history tab, hide related, bg play)
```

可选第二提交：

```
ci: port FocuBili-style split APK and release scripts
```

### Phase C — 移植构建（对照 FocuBili skill）

1. 复制并改名：
   - `.grok/skills/focubili-build` → `.grok/skills/piliplus-build`（或 focus 专用名）
   - `scripts/*` 三件套，替换 `FocuBili` / `chocolatedesue/FocuBili` / App ID
2. 新增 `codemagic.yaml`：
   - `PACKAGE_NAME` 用 PiliPlus 实际 applicationId（读 `android/app/build.gradle.kts`）
   - workflow 名可保留 `android-apk` / `macos-build`
   - 入口：`flutter pub get` → analyze → test（若测试过重可 CM 只 analyze+build，但要在 skill 写明）
3. Android Gradle：确认/启用 `splits.abi` + `universalApk false`（与现有 kts 合并，勿破坏上游签名逻辑）
4. Windows：对齐现有 `win_x64.yml` 或引入 Focu 的 artifact 命名；skill 写清 `gh workflow run` 的 **精确 workflow 名**
5. 在 Codemagic 网页 **添加新 GitHub App 仓库**，把新 `CM_APP_ID` 写进 skill（不要写 token）
6. yqh2 触发试构建：
   ```bash
   bash .grok/skills/<skill>/scripts/trigger_cloud_builds.sh android windows macos
   ```
7. `fetch_codemagic_android_split.sh` + `publish_github_release.sh` 打首个 tag（如 `v0.1.0-focus`）

### Phase D — 验收标准

- [ ] 公开库可浏览，LICENSE/README 合规  
- [ ] Focus 开关可开关，底栏与相关推荐/后台播放符合 §3  
- [ ] CM Android 产出 **3 个 ABI APK**，无 fat  
- [ ] GHA Windows zip 可下载  
- [ ]（可选）macOS zip  
- [ ] skill 文档中的 REPO/APP_ID/命令与真实一致  
- [ ] `gh release` 含 SHA256SUMS  

---

## 6. 参考命令速查（FocuBili 已验证）

```bash
# yqh2
export PATH="$HOME/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

cd /home/cnic/work/FocuBili
bash .grok/skills/focubili-build/scripts/trigger_cloud_builds.sh android
bash .grok/skills/focubili-build/scripts/trigger_cloud_builds.sh macos
gh workflow run "Windows Build" -R chocolatedesue/FocuBili --ref master

# 拉 Android split
./scripts/fetch_codemagic_android_split.sh <buildId> ./artifacts/android-split 1.2.0
```

PiliPlus 移植后把 `chocolatedesue/FocuBili` 全部换成新库 slug。

---

## 7. 产品定位建议（写进新库 README）

- **上游：** [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 第三方 B 站客户端  
- **本 fork：** 增加 **专注模式（Focus Mode）**，弱化推荐干扰；构建/发版流程参考 [FocuBili](https://github.com/chocolatedesue/FocuBili)  
- **非官方**；遵守平台与当地法律  
- Focus ≠ 完整 FocuBili 产品（学习清单/专注闹钟等未整体搬入，除非后续单独立项）

---

## 8. 明确不要做的事

1. 向 `bggRGjQaUbCoE/PiliPlus` 提「整库替换 CI」类破坏性 PR（除非用户明确要求）  
2. 提交 `~/.cmtoken`、keystore、`key.properties`  
3. 发版上传 fat APK  
4. 在 handoff 或 commit 里粘贴任何 token  
5. 假设 yqh2 能本地 `flutter build apk`（缺 JDK/Android SDK）— APK 走 CM  

---

## 9. 给下一任 Agent 的启动提示词（可复制）

```text
读取 /home/cnic/work/PiliPlus/docs/agent-reports/HANDOFF_FOCUSBILI_BUILD_TO_PILIPLUS.md
并阅读 /home/cnic/work/FocuBili/.grok/skills/focubili-build/SKILL.md

任务：
1. 确认 gh 账号 chocolatedesue，创建公开库（与用户确认仓库名，默认 FocusPiliPlus）
2. 提交 PiliPlus 工作区已有 Focus Mode 改动到新库（remote 勿推错 upstream）
3. 移植 FocuBili 的 codemagic/split-per-abi/scripts/skill，改名为 piliplus-build
4. 在 Codemagic 关联新库后试触发 android-apk + GHA Windows
5. 汇总产物路径与未决问题

约束：不发 fat APK；不写 token；保留上游 LICENSE。
```

---

## 10. 文件索引

| 本 handoff | `docs/agent-reports/HANDOFF_FOCUSBILI_BUILD_TO_PILIPLUS.md` |
| Focus 实现 | `lib/utils/focus_mode.dart` 及 §3 列表 |
| Focu 构建技能 | `/home/cnic/work/FocuBili/.grok/skills/focubili-build/` |
| Focu 产物 | yqh2:`/home/cnic/work/FocuBili/artifacts/` |

**状态：** Ready for next agent — **先 `gh repo create` 公开库，再迁 CI。**
