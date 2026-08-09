# PiliPlus Codemagic 云编译指南

为 PiliPlus 提供 Android / macOS 云构建（以及可选的付费 Windows 回退）。  
配置文件：仓库根目录 [`codemagic.yaml`](../codemagic.yaml)。

**本页不含任何密钥、token 或 keystore 内容。** 凭证仅通过 Codemagic UI / CI 环境变量注入。

## 工作流一览

| Workflow ID | 名称 | 机器 | 产物 | 说明 |
|-------------|------|------|------|------|
| `android-apk` | PiliPlus Android APK | `mac_mini_m2` | **按 ABI 拆分的 APK** ×3 + sha256 | 免费计划通常可用 |
| `macos-build` | PiliPlus macOS Build | `mac_mini_m2` | `PiliPlus-macos-bN.zip`（内含 `PiliPlus.app`） | 常为未签名 |
| `windows-build` | PiliPlus Windows（CM 回退） | `windows_x2` | `PiliPlus_windows_bN_x64_portable.zip` | **常需付费**；日常请用 GHA |

### Windows 主路径（不要用第二套 GHA yaml）

| 路径 | 说明 |
|------|------|
| `.github/workflows/build.yml` | `workflow_dispatch` 输入 `build_win_x64` |
| `.github/workflows/win_x64.yml` | `Build for Windows x64`；产物 `PiliPlus_windows_*_x64_portable.zip` 与 setup exe |

不要引入与上述路径竞争的 FocuBili 式 `windows-build.yml`。

## Flutter 版本

- 仓库 `pubspec.yaml` / `.fvmrc`：`3.44.8`
- Codemagic `environment.flutter: stable` 跟踪 3.44.x（例如 3.44.9）

## Android：ABI split（无 fat 发布物）

```bash
flutter build apk --release --split-per-abi
```

中间产物：

```text
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

**不要**把 `app-release.apk` 当作发布物。

Gradle（`android/app/build.gradle.kts`）启用 `splits.abi` 且 `universalApk = false`，与 Flutter split 对齐。

### 命名对照

| 场景 | 模式 |
|------|------|
| Codemagic 中间名 | `PiliPlus-android-{abi}-b{N}.apk` |
| GHA `build.yml` Rename | `PiliPlus_android_{ver}_{abi}.apk` |
| Release 备选 | `PiliPlus-vX.Y.Z-android-{abi}.apk` |

拉取并改名：[`scripts/fetch_codemagic_android_split.sh`](../scripts/fetch_codemagic_android_split.sh)。

### 用户应装哪个 ABI？

| ABI | 建议 |
|-----|------|
| **arm64-v8a** | 默认真机 |
| armeabi-v7a | 老 32 位 ARM |
| x86_64 | 模拟器 / 罕见 x86 平板 |

## PowerShell patch 差距（CM）

GHA Android 使用 `lib/scripts/patch.ps1`。Codemagic mac 实例上若无 `pwsh`/`powershell`，`android-apk` 工作流会 **跳过 patch 并打印 NOTE**，然后执行 plain `flutter build apk --split-per-abi`。需要完整 patch 行为时优先 GHA 或自备带 PowerShell 的 runner。

## 接入 Codemagic

1. [codemagic.io](https://codemagic.io) 用 GitHub 登录。
2. **Add application** → 选择你的 PiliPlus fork/mirror（不要假设固定 App ID）。
3. 选择 Flutter App，扫描根目录 `codemagic.yaml`。
4. 将真实 **App ID** 仅保存在本地环境 / `CM_APP_ID`（脚本默认为 `6a7803420aef485a30432738`）。
5. 手动 Start：优先 `android-apk` / `macos-build`。

触发示例（占位）：

```bash
export CM_APP_ID=6a7803420aef485a30432738   # 换成你的 App ID
# CM_API_TOKEN 或 ~/.cmtoken — 勿提交
.grok/skills/piliplus-build/scripts/trigger_cloud_builds.sh android macos
```

## Android 签名（可选）

未配置密钥时 Release APK 使用 **debug 签名**，适合试装。

通过 Codemagic 环境变量组注入（名称示例，值勿写入仓库）：

- `CM_KEYSTORE` / `CM_KEYSTORE_PASSWORD` / `CM_KEY_PASSWORD` / `CM_KEY_ALIAS`
- 或 `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_PASSWORD` / `KEY_ALIAS`

构建脚本会在 runner 上生成临时 `android/key.properties`；该文件与 `*.jks` 已在 `.gitignore`。

## applicationId

本波次保持 `com.example.piliplus`（namespace 相同），不做包名迁移。

## 相关

- 技能：`.grok/skills/piliplus-build/SKILL.md`（`/piliplus-build`）
- 矩阵：`.grok/skills/piliplus-build/references/build-matrix.md`
- 脚本：`scripts/*.sh`
