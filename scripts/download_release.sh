#!/usr/bin/env bash
# 从 GitHub Release 下载 PiliPlus 多端产物。
# 用法:
#   ./scripts/download_release.sh
#   ./scripts/download_release.sh v2.1.0 ./dist
#   ./scripts/download_release.sh v2.1.0 ./dist arm64   # 仅 Android arm64-v8a
#
# REPO 默认占位，覆盖示例: REPO=owner/PiliPlus ./scripts/download_release.sh ...
set -euo pipefail

TAG="${1:-v2.1.0}"
OUT_DIR="${2:-./dist/${TAG}}"
FILTER="${3:-all}" # all | arm64 | android | windows | macos
REPO="${REPO:-chocolatedesue/PiliPlus}"

if [[ "$REPO" == REPLACE_ME_OWNER/* ]]; then
  echo "warn: REPO is still placeholder ($REPO); set REPO=owner/PiliPlus" >&2
fi

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

download() {
  local name="$1"
  echo ">> $name"
  gh release download "$TAG" -R "$REPO" -p "$name" --clobber
}

VER="${TAG#v}"

case "$FILTER" in
  arm64)
    download "PiliPlus_android_${VER}_arm64-v8a.apk" 2>/dev/null \
      || download "PiliPlus-v${VER}-android-arm64-v8a.apk" 2>/dev/null \
      || download "PiliPlus-*-android-arm64-v8a.apk"
    ;;
  android)
    gh release download "$TAG" -R "$REPO" -p "PiliPlus*android*.apk" --clobber
    ;;
  windows)
    gh release download "$TAG" -R "$REPO" -p "PiliPlus*windows*" --clobber
    ;;
  macos)
    gh release download "$TAG" -R "$REPO" -p "PiliPlus*macos*" --clobber
    ;;
  all|*)
    gh release download "$TAG" -R "$REPO" --clobber
    ;;
esac

echo
echo "Saved under: $(pwd)"
ls -lh
if [[ -f SHA256SUMS.txt ]]; then
  echo
  echo "Verifying SHA256SUMS.txt (files present only)..."
  sha256sum -c SHA256SUMS.txt --ignore-missing 2>/dev/null || sha256sum -c SHA256SUMS.txt || true
fi
