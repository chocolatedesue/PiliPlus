#!/usr/bin/env bash
# Trigger PiliPlus cloud builds: Codemagic Android/macOS and GHA Windows (primary).
# Can run from repo root or from this skill directory.
#
# Defaults are placeholders — override before real use:
#   REPO=owner/PiliPlus
#   CM_APP_ID=<codemagic app id>
#   BRANCH=main
#   CM_API_TOKEN or ~/.cmtoken  (env/file names only; never commit tokens)
#
# Usage:
#   .grok/skills/piliplus-build/scripts/trigger_cloud_builds.sh
#   .grok/skills/piliplus-build/scripts/trigger_cloud_builds.sh android
#   .grok/skills/piliplus-build/scripts/trigger_cloud_builds.sh android macos windows
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
  # .../repo/.grok/skills/piliplus-build/scripts → four levels up
  ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

REPO="${REPO:-chocolatedesue/PiliPlus}"
APP_ID="${CM_APP_ID:-6a7803420aef485a30432738}"
BRANCH="${BRANCH:-main}"

if [[ $# -eq 0 ]]; then
  set -- android windows macos
fi

if [[ -f "${HOME}/.cmtoken" ]]; then
  CM_TOKEN=$(grep -oE '[^=]+$' "${HOME}/.cmtoken" | head -1 | tr -d ' \n\r')
else
  CM_TOKEN="${CM_API_TOKEN:-}"
fi

trigger_cm() {
  local wf="$1"
  if [[ "$APP_ID" == "REPLACE_ME_CM_APP_ID" ]]; then
    echo "skip CM $wf (CM_APP_ID still placeholder REPLACE_ME_CM_APP_ID)" >&2
    return 0
  fi
  if [[ -z "${CM_TOKEN:-}" ]]; then
    echo "skip CM $wf (no ~/.cmtoken or CM_API_TOKEN)" >&2
    return 0
  fi
  echo "Codemagic → $wf @ $BRANCH (app $APP_ID)"
  curl -sS -X POST "https://api.codemagic.io/builds" \
    -H "Content-Type: application/json" \
    -H "x-auth-token: $CM_TOKEN" \
    -d "{\"appId\":\"$APP_ID\",\"workflowId\":\"$wf\",\"branch\":\"$BRANCH\"}"
  echo
}

echo "repo root: $ROOT"
echo "REPO=$REPO CM_APP_ID=$APP_ID BRANCH=$BRANCH"

for t in "$@"; do
  case "$t" in
    android|apk)
      trigger_cm android-apk
      ;;
    macos|mac)
      trigger_cm macos-build
      ;;
    windows|win)
      # Primary Windows path: existing PiliPlus GHA (not FocuBili windows-build.yml)
      if [[ "$REPO" == REPLACE_ME_OWNER/* ]]; then
        echo "skip GHA Windows (REPO still placeholder $REPO)" >&2
        continue
      fi
      if command -v gh >/dev/null 2>&1; then
        echo "GHA → Build workflow (build_win_x64) / win_x64.yml @ $BRANCH"
        # Prefer monorepo Build orchestrator when present
        if gh workflow view Build -R "$REPO" >/dev/null 2>&1; then
          gh workflow run Build -R "$REPO" --ref "$BRANCH" \
            -f build_android=false \
            -f build_ios=false \
            -f build_mac=false \
            -f build_win_x64=true \
            -f build_linux_x64=false \
            || gh workflow run "Build for Windows x64" -R "$REPO" --ref "$BRANCH" \
            || echo "Could not dispatch Windows workflow; check workflow names." >&2
        else
          gh workflow run "Build for Windows x64" -R "$REPO" --ref "$BRANCH" \
            || echo "Could not dispatch win_x64 workflow" >&2
        fi
        sleep 2
        gh run list -R "$REPO" -L 3 || true
      else
        echo "gh not installed; skip Windows" >&2
      fi
      ;;
    cm-windows)
      echo "NOTE: CM windows-build is paid fallback; primary is GHA win_x64.yml"
      trigger_cm windows-build
      ;;
    *)
      echo "unknown target: $t (android|macos|windows|cm-windows)" >&2
      ;;
  esac
done
