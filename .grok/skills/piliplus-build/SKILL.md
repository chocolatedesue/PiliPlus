---
name: piliplus-build
description: >
  PiliPlus project cloud/local build, ABI-split Android APKs, Codemagic + existing
  GitHub Actions (build.yml / win_x64.yml), and GitHub Release upload/download.
  Use when the user asks to build PiliPlus, run Codemagic/GHA, split-per-abi,
  publish/download Release, or runs /piliplus-build. Prefer this over generic
  Flutter build advice inside this repo.
---

# PiliPlus Build Skill（项目级）

在 **本仓库** 内执行构建、云编译与 Release 分发。先 `cd` 到仓库根（含 `pubspec.yaml` / `codemagic.yaml`）。

## 何时使用

- 本地 / 云端编译 Android、Windows、macOS
- Android **split-per-abi**（禁止 fat APK 作为发布物）
- 触发 Codemagic / GitHub Actions
- 上传或下载 GitHub Release 资产
- 用户说：云构建、打 APK、发版、Release、Codemagic、GHA Windows

## 涉及什么

| 类别 | 路径 | 作用 |
|------|------|------|
| 云配置 | `codemagic.yaml` | CM：`android-apk` / `macos-build`；`windows-build` **仅付费回退** |
| GHA（主 Windows） | `.github/workflows/build.yml` + `win_x64.yml` | `build_win_x64` / `Build for Windows x64` → portable zip + setup |
| GHA Android 等 | `build.yml` 编排 ios/mac/linux 可调用工作流 | **不要删除**上游 workflows |
| 签名（可选） | `android/key.properties` + keystore（gitignore） | Release 签名；无则 debug 签；**勿提交** |
| Gradle | `android/app/build.gradle.kts` | `splits.abi` + `universalApk = false` |
| 文档 | `docs/CODEMAGIC.md` | 构建说明（无 secrets） |
| 脚本 | `scripts/download_release.sh` | 下 Release |
| | `scripts/fetch_codemagic_android_split.sh` | 从 CM build 拉 split APK |
| | `scripts/publish_github_release.sh` | 上传本地产物到 Release |
| 技能 | `.grok/skills/piliplus-build/scripts/trigger_cloud_builds.sh` | 一键触发（占位 ID） |
| 矩阵 | `references/build-matrix.md` | 速查 |

**不要**把 `build/app/outputs/flutter-apk/app-release.apk`（fat）当正式发布物。

**不要**新增与 `win_x64.yml` 竞争的第二套 Windows GHA yaml（FocuBili `windows-build.yml` 风格）。

---

## 环境

```bash
export PATH="${HOME}/flutter/bin:${PATH}"
# 国内镜像（需要时）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

flutter --version   # 建议 3.44.x stable（pubspec / .fvmrc: 3.44.8）
```

凭证（按需，**勿提交**；脚本只引用 **环境变量名**）：

| 用途 | 位置 |
|------|------|
| Codemagic API | `~/.cmtoken`（`CM_API_TOKEN=...` 或纯 token）或 env `CM_API_TOKEN` |
| GitHub CLI | `gh auth status`（scopes: repo, workflow） |

Codemagic **App ID** 默认占位：`REPLACE_ME_CM_APP_ID`（**禁止**复制其他项目真实 App ID）  
仓库默认占位：`REPLACE_ME_OWNER/PiliPlus`（`REPO` 环境变量覆盖）  
`applicationId`：**保持** `com.example.piliplus`

---

## 工作流矩阵

| 目标 | 推荐通道 | Workflow / 命令 | 产物 |
|------|----------|-----------------|------|
| Android release | Codemagic（免费 mac 可跑）或 GHA | `android-apk` / `Build` android | CM: `PiliPlus-android-{abi}-bN.apk`；GHA: `PiliPlus_android_{ver}_{abi}.apk` |
| macOS | Codemagic 或 GHA `mac.yml` | `macos-build` | `PiliPlus-macos-bN.zip` / `PiliPlus.app` |
| Windows | **GitHub Actions（主路径）** | `build.yml` + `build_win_x64` → `win_x64.yml` | `PiliPlus_windows_{ver}_x64_portable.zip` 等 |
| Windows | Codemagic | `windows-build` | 常需付费 `windows_x2`，仅回退 |
| 本地 Android | 本机 | 见下 | split APK |
| 发版 | GitHub Release | `scripts/publish_github_release.sh` | 多资产 + SHA256SUMS |

Android ABI：`armeabi-v7a` / `arm64-v8a`（**多数真机**）/ `x86_64`。

### 命名对照

| 场景 | 模式 |
|------|------|
| GHA Android（`build.yml` Rename） | `PiliPlus_android_${ver}_${abi}.apk` |
| CM 中间产物 | `PiliPlus-android-{abi}-bN.apk` |
| Release 备选 | `PiliPlus-vX.Y.Z-android-{abi}.apk` |
| GHA Windows portable | `PiliPlus_windows_${ver}_x64_portable.zip` |

`fetch_codemagic_android_split.sh` 会同时写出 GHA 风格与 Release 备选名。

---

## 本地构建

### 通用检查

```bash
flutter pub get
flutter analyze
flutter test   # 若无测试文件，记录 exit / empty
```

### Android（必须 split，不发 fat）

```bash
flutter build apk --release --split-per-abi
# 输出：
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#   build/app/outputs/flutter-apk/app-x86_64-release.apk
```

重命名发版示例（对齐 GHA）：

```bash
VER=2.1.0
OUT=dist/v${VER}
mkdir -p "$OUT"
for abi in armeabi-v7a arm64-v8a x86_64; do
  cp "build/app/outputs/flutter-apk/app-${abi}-release.apk" \
    "$OUT/PiliPlus_android_${VER}_${abi}.apk"
done
```

GHA 还会对 release 使用 `lib/scripts/patch.ps1` 与 `--dart-define-from-file=pili_release.json`。Codemagic 在无 PowerShell 时会 **跳过 patch 并明文记录**，仍执行 plain `flutter build apk --split-per-abi`。

### 桌面

```bash
flutter config --enable-windows-desktop   # 或 macos / linux
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

Windows 正式便携包优先走 GHA `win_x64.yml`（fastforge + Inno），不要另起 FocuBili 专用 workflow 名。

---

## 云构建：Codemagic

```bash
CM_TOKEN=$(grep -oE '[^=]+$' "$HOME/.cmtoken" | head -1 | tr -d ' \n\r')
APP_ID="${CM_APP_ID:-REPLACE_ME_CM_APP_ID}"

# 触发（勿使用其他项目真实 App ID）
curl -sS -X POST "https://api.codemagic.io/builds" \
  -H "Content-Type: application/json" \
  -H "x-auth-token: $CM_TOKEN" \
  -d "{\"appId\":\"$APP_ID\",\"workflowId\":\"android-apk\",\"branch\":\"main\"}"

# workflowId: android-apk | macos-build | windows-build（后者付费回退）

# 查状态
curl -sS -H "x-auth-token: $CM_TOKEN" \
  "https://api.codemagic.io/builds/<buildId>"
```

从已成功 build 拉 Android split 并改名为 GHA/Release 文件名：

```bash
./scripts/fetch_codemagic_android_split.sh <buildId> ./dist/android 2.1.0
```

可选 Android 签名：Codemagic 环境变量 / 构建时写入 `key.properties`（见 `docs/CODEMAGIC.md`）。无 keystore 时 CM 用 debug 签。

一键触发（占位会 skip）：

```bash
export REPO=REPLACE_ME_OWNER/PiliPlus
export CM_APP_ID=REPLACE_ME_CM_APP_ID
.grok/skills/piliplus-build/scripts/trigger_cloud_builds.sh android macos windows
```

---

## 云构建：GitHub Actions（Windows 主路径）

```bash
export REPO="${REPO:-REPLACE_ME_OWNER/PiliPlus}"

# 推荐：编排器 Build，只开 Windows
gh workflow run Build -R "$REPO" --ref main \
  -f build_android=false -f build_ios=false -f build_mac=false \
  -f build_win_x64=true -f build_linux_x64=false

# 或直接 callable 工作流名
gh workflow run "Build for Windows x64" -R "$REPO" --ref main

gh run list -R "$REPO" -L 5
gh run download <runId> -R "$REPO" -n Windows-file-x64-release -D ./dist/win
```

PR CI：`build.yml` 已放宽仓库硬编码，使 fork/mirror 在 `pull_request` 或 `workflow_dispatch` 时也能跑（见 `github.repository` 条件）。

---

## GitHub Release

### 下载

```bash
REPO=owner/PiliPlus ./scripts/download_release.sh v2.1.0 ./dist
REPO=owner/PiliPlus ./scripts/download_release.sh v2.1.0 ./dist arm64
```

### 上传 / 更新

```bash
REPO=owner/PiliPlus ./scripts/publish_github_release.sh v2.1.0 ./dist \
  --title "PiliPlus v2.1.0"
```

脚本会生成并上传 `SHA256SUMS.txt`。若目录里同时有 fat 与 split，应删掉 fat 再传。

---

## Agent 操作清单（发一版）

1. `git status`；需要则 commit/push（本 skill 不代替发布权限策略）。
2. 跑本地 `analyze` + `test`（或依赖 CI）。
3. 触发云构建：
   - Android：CM `android-apk` 或 GHA android
   - macOS：CM `macos-build` 或 GHA mac
   - Windows：**GHA** `build_win_x64` / `win_x64.yml`
4. 等待成功；失败则拉 log。
5. 收集产物：
   - `./scripts/fetch_codemagic_android_split.sh <androidBuildId> ./dist/vX.Y.Z X.Y.Z`
   - `gh run download ...` Windows zip 保持 `PiliPlus_windows_*` 名
6. `REPO=... ./scripts/publish_github_release.sh vX.Y.Z ./dist/vX.Y.Z`
7. 用 `download_release.sh` 抽检 + `sha256sum -c SHA256SUMS.txt`。

---

## 常见失败

| 现象 | 处理 |
|------|------|
| CM Windows `instance type not available` | 改 GHA `win_x64.yml`，勿死磕免费 CM |
| 只产出 / 误传 fat APK | 确认 `--split-per-abi` 与 `universalApk false`；发布只用 split 名 |
| CM 下载 APK 得到 JSON | 用 build API 的 artefact `url` + `x-auth-token` |
| `REPLACE_ME_*` 触发被 skip | 设置真实 `CM_APP_ID` / `REPO`（勿提交） |
| PowerShell missing on CM | 预期：跳过 `patch.ps1`，plain flutter build |

---

## 相关阅读

- `docs/CODEMAGIC.md`
- `references/build-matrix.md`（本 skill 目录）
- 现有 GHA：`.github/workflows/build.yml`, `win_x64.yml`, `mac.yml`, …

## 约束

- 不把 token / keystore 写进仓库。
- 不 force-push 主分支。
- 不复制其他产品的真实 Codemagic App ID。
- Focus Mode 产品文件与构建迁移正交：构建 skill 不删除 `lib/utils/focus_mode.dart` 等。
