#!/usr/bin/env bash
# 将本地产物目录上传到 GitHub Release（需 gh 已登录）。
#
# 期望目录内文件名（示例 v2.1.0 / version 2.1.0）:
#   PiliPlus_android_2.1.0_arm64-v8a.apk          # GHA 风格（优先）
#   PiliPlus_android_2.1.0_armeabi-v7a.apk
#   PiliPlus_android_2.1.0_x86_64.apk
#   PiliPlus-v2.1.0-android-arm64-v8a.apk         # 备选 Release 风格
#   PiliPlus_windows_2.1.0_x64_portable.zip       # 与 win_x64.yml 一致
#   PiliPlus_windows_2.1.0_x64_setup.exe
#   PiliPlus-macos-*.zip / PiliPlus-v2.1.0-macos.zip
#
# 用法:
#   ./scripts/publish_github_release.sh v2.1.0 /path/to/assets
#   ./scripts/publish_github_release.sh v2.1.0 /path/to/assets --notes-file docs/NOTES.md
#
# REPO 默认占位，必须用环境变量覆盖真实 owner/repo：
#   REPO=owner/PiliPlus ./scripts/publish_github_release.sh ...
#
# Android 构建请使用: flutter build apk --release --split-per-abi
# 不要把 fat app-release.apk 当作发布物。
set -euo pipefail

TAG="${1:?usage: $0 <tag> <assets-dir> [--notes-file path] [--title title]}"
ASSETS_DIR="${2:?usage: $0 <tag> <assets-dir> [--notes-file path]}"
shift 2

REPO="${REPO:-chocolatedesue/PiliPlus}"
NOTES_FILE=""
TITLE="PiliPlus ${TAG}"

if [[ "$REPO" == REPLACE_ME_OWNER/* ]]; then
  echo "warn: REPO is still placeholder ($REPO); set REPO=owner/PiliPlus before real publish" >&2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes-file) NOTES_FILE="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$ASSETS_DIR" ]]; then
  echo "assets dir not found: $ASSETS_DIR" >&2
  exit 1
fi

cd "$ASSETS_DIR"
mapfile -t FILES < <(find . -maxdepth 1 -type f ! -name '.*' | sed 's|^\./||' | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "no files in $ASSETS_DIR" >&2
  exit 1
fi

# Reject obvious fat android single-name if both fat and split present
if ls PiliPlus*-android.apk PiliPlus_android.apk 2>/dev/null | grep -q .; then
  if ls PiliPlus*android*arm64* 2>/dev/null | grep -q .; then
    echo "warn: both fat *-android.apk and split arm64 APKs present; prefer deleting fat before upload" >&2
  fi
fi

# Build checksums from product files only (exclude existing SHA256SUMS.txt to avoid double-upload)
mapfile -t SUM_SRC < <(printf '%s
' "${FILES[@]}" | grep -v '^SHA256SUMS\.txt$' || true)
if [[ ${#SUM_SRC[@]} -gt 0 ]]; then
  sha256sum "${SUM_SRC[@]}" > SHA256SUMS.txt
else
  sha256sum ./* > SHA256SUMS.txt 2>/dev/null || true
fi
echo "SHA256SUMS.txt:"
cat SHA256SUMS.txt

ARGS=(release upload "$TAG" -R "$REPO" --clobber)
for f in "${SUM_SRC[@]}" SHA256SUMS.txt; do
  [[ -f "$f" ]] || continue
  ARGS+=("$f")
done

TARGET_BRANCH="${TARGET_BRANCH:-main}"

if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  echo "Updating existing release $TAG"
  if [[ -n "$NOTES_FILE" && -f "$NOTES_FILE" ]]; then
    gh release edit "$TAG" -R "$REPO" --title "$TITLE" --notes-file "$NOTES_FILE"
  fi
  gh "${ARGS[@]}"
else
  echo "Creating release $TAG"
  CREATE=(release create "$TAG" -R "$REPO" --title "$TITLE" --target "$TARGET_BRANCH")
  if [[ -n "$NOTES_FILE" && -f "$NOTES_FILE" ]]; then
    CREATE+=(--notes-file "$NOTES_FILE")
  else
    CREATE+=(--generate-notes)
  fi
  for f in "${FILES[@]}" SHA256SUMS.txt; do
    [[ -f "$f" ]] || continue
    CREATE+=("$f")
  done
  gh "${CREATE[@]}"
fi

echo
gh release view "$TAG" -R "$REPO"
echo "Done: https://github.com/${REPO}/releases/tag/${TAG}"
