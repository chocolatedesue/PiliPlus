#!/usr/bin/env bash
# Codemagic-friendly Flutter SDK patcher (bash port of patch.ps1).
# Usage: lib/scripts/patch_cm.sh <android|ios|macos|windows|linux>
set -euo pipefail

platform="${1:-}"
if [[ -z "$platform" ]]; then
  echo "usage: $0 <platform>" >&2
  exit 2
fi
platform="$(echo "$platform" | tr '[:upper:]' '[:lower:]')"

REPO_ROOT="${CM_BUILD_DIR:-${GITHUB_WORKSPACE:-$(pwd)}}"
cd "$REPO_ROOT"

if [[ -z "${FLUTTER_ROOT:-}" ]]; then
  FLUTTER_ROOT="$(dirname "$(dirname "$(command -v flutter)")")"
fi
export FLUTTER_ROOT
echo "REPO_ROOT=$REPO_ROOT"
echo "FLUTTER_ROOT=$FLUTTER_ROOT"
echo "platform=$platform"

# iOS-only repo patches (applied in app tree, not Flutter SDK)
if [[ "$platform" == "ios" ]]; then
  for p in lib/scripts/bottom_sheet_ios_piliplus.patch lib/scripts/geetest_ios.patch; do
    if [[ -f "$p" ]]; then
      if git apply "$p"; then
        echo "applied $p (repo)"
      else
        echo "WARN: failed $p (repo)" >&2
      fi
    fi
  done
fi

# Flutter SDK commits to cherry-pick (temporary upstream fixes)
TextSelectionMenuFix="beb2ad17004a1b118ff2bd09f55cee23198f6652"

patches=(
  lib/scripts/modal_barrier.patch
  lib/scripts/text_selection.patch
  lib/scripts/mouse_cursor.patch
  lib/scripts/image_anim.patch
  lib/scripts/layout_builder.patch
  lib/scripts/navigation_drawer.patch
  lib/scripts/popup_menu.patch
  lib/scripts/fab.patch
  lib/scripts/null_safety_for_selectable_region.patch
  lib/scripts/selectable_region.patch
  lib/scripts/editable_text.patch
  lib/scripts/text_field.patch
  lib/scripts/scroll_position.patch
  lib/scripts/scrollable.patch
  lib/scripts/scrollable_gesture.patch
  lib/scripts/draggable_scrollable_sheet.patch
  lib/scripts/scaffold.patch
  lib/scripts/text.patch
  lib/scripts/text_painter.patch
)

case "$platform" in
  android)
    patches+=(lib/scripts/bottom_sheet_android.patch)
    patches+=(lib/scripts/scroll_view.patch)
    patches+=(lib/scripts/navigator.patch)
    ;;
  ios)
    patches+=(lib/scripts/scroll_view.patch)
    patches+=(lib/scripts/bottom_sheet_ios_flutter.patch)
    patches+=(lib/scripts/navigator.patch)
    ;;
  linux|macos|windows) ;;
  *) echo "unknown platform: $platform" >&2; exit 2 ;;
esac

cd "$FLUTTER_ROOT"
git config --global user.name "ci" || true
git config --global user.email "ci@codemagic.local" || true
git reset --hard HEAD

# cherry-pick temporary fix(es)
if git cat-file -e "${TextSelectionMenuFix}^{commit}" 2>/dev/null; then
  git stash push -u -m cm-patch || true
  if git cherry-pick "$TextSelectionMenuFix" --no-edit; then
    git reset --soft HEAD~1
    echo "picked $TextSelectionMenuFix"
  else
    git cherry-pick --abort 2>/dev/null || true
    echo "WARN: cherry-pick $TextSelectionMenuFix failed" >&2
  fi
  git stash pop || true
else
  echo "WARN: commit $TextSelectionMenuFix not in Flutter git; skip cherry-pick" >&2
fi

applied=0
failed=0
for patch in "${patches[@]}"; do
  abs="$REPO_ROOT/$patch"
  if [[ ! -f "$abs" ]]; then
    echo "WARN: missing $abs" >&2
    failed=$((failed+1))
    continue
  fi
  if git apply "$abs"; then
    echo "applied $patch"
    applied=$((applied+1))
  else
    echo "WARN: failed to apply $patch" >&2
    failed=$((failed+1))
  fi
done

echo "patch_cm.sh done: applied=$applied failed=$failed"
# Do not hard-fail the build solely on partial patch failures; analyze/build will surface issues.
exit 0
