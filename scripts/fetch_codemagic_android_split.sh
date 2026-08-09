#!/usr/bin/env bash
# 从 Codemagic 某次 android-apk 构建下载 split APK，并重命名为 Release / GHA 风格文件名。
#
# 依赖: curl, python3；凭证仅通过 env 名读取：
#   ~/.cmtoken 内容为 CM_API_TOKEN=... 或纯 token，或 env CM_API_TOKEN
# 本脚本不创建/写入 keystore 或 token 文件。
#
# 用法:
#   ./scripts/fetch_codemagic_android_split.sh <buildId> [out-dir] [version]
# 示例:
#   ./scripts/fetch_codemagic_android_split.sh <buildId> ./dist/android 2.1.0
#
# CM 中间名: PiliPlus-android-{abi}-bN.apk
# 输出名:    PiliPlus_android_{version}_{abi}.apk  (与 GHA build.yml Rename 一致)
# 另写一份:  PiliPlus-v{version}-android-{abi}.apk (Release 风格备选)
set -euo pipefail

BUILD_ID="${1:?usage: $0 <codemagic-build-id> [out-dir] [version]}"
OUT_DIR="${2:-./dist/android-split}"
VERSION="${3:-2.1.0}"

if [[ -f "${HOME}/.cmtoken" ]]; then
  CM_TOKEN=$(grep -oE '[^=]+$' "${HOME}/.cmtoken" | head -1 | tr -d ' \n\r')
elif [[ -n "${CM_API_TOKEN:-}" ]]; then
  CM_TOKEN="$CM_API_TOKEN"
else
  echo "need ~/.cmtoken or CM_API_TOKEN (env name only; do not commit tokens)" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
export BUILD_ID OUT_DIR VERSION CM_TOKEN

python3 - <<'PY'
import json, os, urllib.request, hashlib

token = os.environ["CM_TOKEN"]
build_id = os.environ["BUILD_ID"]
out_dir = os.environ["OUT_DIR"]
version = os.environ["VERSION"]

req = urllib.request.Request(
    f"https://api.codemagic.io/builds/{build_id}",
    headers={"x-auth-token": token},
)
with urllib.request.urlopen(req, timeout=120) as r:
    build = json.load(r).get("build", {})

seen = set()
for art in build.get("artefacts") or []:
    name = art.get("name") or ""
    if not name.endswith(".apk") or "latest" in name:
        continue
    if name in seen:
        continue
    if "arm64-v8a" in name:
        abi = "arm64-v8a"
    elif "armeabi-v7a" in name:
        abi = "armeabi-v7a"
    elif "x86_64" in name:
        abi = "x86_64"
    else:
        # skip fat / unknown
        if "android" in name.lower() and "arm" not in name and "x86" not in name:
            print(f"warn: skip possible fat APK artefact: {name}")
        continue
    seen.add(name)
    gha_name = f"PiliPlus_android_{version}_{abi}.apk"
    rel_name = f"PiliPlus-v{version}-android-{abi}.apk"
    url = art["url"]
    print(f"fetch {name} -> {gha_name} (+ {rel_name})")
    req = urllib.request.Request(url, headers={"x-auth-token": token})
    with urllib.request.urlopen(req, timeout=600) as r:
        data = r.read()
    for out_name in (gha_name, rel_name):
        path = os.path.join(out_dir, out_name)
        with open(path, "wb") as f:
            f.write(data)
        print(f"  wrote {out_name} sha256={hashlib.sha256(data).hexdigest()} size={len(data)}")

print("out:", out_dir)
for fn in sorted(os.listdir(out_dir)):
    print(" ", fn)
PY
