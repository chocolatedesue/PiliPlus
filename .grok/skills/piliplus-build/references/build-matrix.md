# PiliPlus build matrix (quick reference)

## Channels

| Platform | Primary CI | Workflow ID / name | Free-tier note |
|----------|------------|--------------------|----------------|
| Android | Codemagic (or GHA `build.yml`) | `android-apk` / `Build`→android | CM OK on `mac_mini_m2` |
| macOS | Codemagic or GHA `mac.yml` | `macos-build` / `Build`→mac | CM often unsigned |
| Windows | **GitHub Actions (primary)** | `build.yml` `build_win_x64` → `win_x64.yml` | Preferred |
| Windows | Codemagic (optional paid) | `windows-build` | Needs `windows_x2` |

Do **not** add a competing FocuBili-style `windows-build.yml`; call existing PiliPlus Windows path.

## Android artifacts (release)

| ABI | Local output | GHA / preferred release name | CM intermediate |
|-----|--------------|------------------------------|-----------------|
| arm64-v8a | `app-arm64-v8a-release.apk` | `PiliPlus_android_{ver}_arm64-v8a.apk` | `PiliPlus-android-arm64-v8a-b{N}.apk` |
| armeabi-v7a | `app-armeabi-v7a-release.apk` | `PiliPlus_android_{ver}_armeabi-v7a.apk` | `PiliPlus-android-armeabi-v7a-b{N}.apk` |
| x86_64 | `app-x86_64-release.apk` | `PiliPlus_android_{ver}_x86_64.apk` | `PiliPlus-android-x86_64-b{N}.apk` |

**Do not ship** `app-release.apk` fat as the main asset.

Optional Release-style alias: `PiliPlus-vX.Y.Z-android-{abi}.apk` (fetch script writes both).

## Windows artifacts (existing GHA)

From `win_x64.yml`:

- `PiliPlus_windows_{ver}_x64_portable.zip`
- `PiliPlus_windows_{ver}_x64_setup.exe`

## Commands

```bash
# Local Android
flutter build apk --release --split-per-abi

# Codemagic trigger (placeholders)
export CM_APP_ID=6a7803420aef485a30432738
export REPO=chocolatedesue/PiliPlus
# token via CM_API_TOKEN or ~/.cmtoken — never commit
curl -sS -X POST https://api.codemagic.io/builds \
  -H "Content-Type: application/json" \
  -H "x-auth-token: $CM_API_TOKEN" \
  -d "{\"appId\":\"$CM_APP_ID\",\"workflowId\":\"android-apk\",\"branch\":\"main\"}"

# GHA Windows (primary)
gh workflow run Build -R "$REPO" --ref main -f build_win_x64=true -f build_android=false ...

# Scripts
./scripts/fetch_codemagic_android_split.sh <buildId> ./dist/android 2.1.0
./scripts/download_release.sh v2.1.0 ./dist arm64
REPO=owner/PiliPlus ./scripts/publish_github_release.sh v2.1.0 ./dist
```

## IDs (placeholders this wave)

- GitHub repo default in scripts: `chocolatedesue/PiliPlus`
- Codemagic appId default: `6a7803420aef485a30432738`
- applicationId: `com.example.piliplus` (unchanged)
- pubspec name: `PiliPlus`
- Flutter: 3.44.8 (pubspec / .fvmrc); CM `stable` ≈ 3.44.x
