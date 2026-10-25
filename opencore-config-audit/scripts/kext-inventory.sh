#!/bin/sh
# kext-inventory.sh —— kext 清单体检（版本 / 构建元数据 / 大小 / sha256 / config 引用核对）
#
# 用途：更新 kext 或 OpenCore 前后，留一份「改动前的证据」；
#       并回答「这个 kext 是不是官方件」需要的那几列（见 references/kext-and-oc-update.md §1）。
#
# 用法：
#   ./kext-inventory.sh /Volumes/EFI                     # EFI 挂载点（自动找 EFI/OC/Kexts）
#   ./kext-inventory.sh /Volumes/EFI/EFI/OC/Kexts        # 直接给 Kexts 目录
#   ./kext-inventory.sh /Volumes/EFI --config /Volumes/EFI/EFI/OC/config.plist
#   ./kext-inventory.sh /Volumes/EFI --tsv               # 制表符分隔（便于 diff / 存档）
#   ./kext-inventory.sh /Volumes/EFI --save VERSIONS-before.txt
#   ./kext-inventory.sh /Volumes/EFI --host-nvram        # 另读当前宿主 NVRAM（不代表目标 EFI）
#
# 退出码：0 正常；1 引用缺失或 config 解析失败；2 参数或保存失败。

set -u
# ★ 沙箱里 PATH 可能被搞坏（stat/strings/grep 会 command not found）
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

TSV=0; SAVE=""; CONFIG=""; TARGET=""; HOST_NVRAM=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tsv) TSV=1 ;;
    --config|--save)
      option="$1"
      case "${2:-}" in
        ""|-*) echo "$option 缺少路径参数" >&2; exit 2 ;;
      esac
      shift
      if [ "$option" = "--config" ]; then CONFIG="$1"; else SAVE="$1"; fi
      ;;
    --host-nvram) HOST_NVRAM=1 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "未知参数：$1（-h 看用法）" >&2; exit 2 ;;
    *) [ -z "$TARGET" ] || { echo "只能指定一个目标目录" >&2; exit 2; }; TARGET="$1" ;;
  esac
  shift
done
[ -n "$TARGET" ] || { echo "用法：$0 <EFI 挂载点 | Kexts 目录> [--config <config.plist>] [--tsv] [--save <file>] [--host-nvram]" >&2; exit 2; }
[ -z "$CONFIG" ] || [ -f "$CONFIG" ] || { echo "找不到 config：$CONFIG" >&2; exit 2; }

# 定位 Kexts 目录
if [ -d "$TARGET/EFI/OC/Kexts" ]; then
  KEXTS="$TARGET/EFI/OC/Kexts"
  [ -z "$CONFIG" ] && [ -f "$TARGET/EFI/OC/config.plist" ] && CONFIG="$TARGET/EFI/OC/config.plist"
elif [ -d "$TARGET" ] && ls "$TARGET"/*.kext >/dev/null 2>&1; then
  # 直接把「一堆 .kext 的目录」当 Kexts（含工作区里的备份目录）
  KEXTS="$TARGET"
else
  echo "找不到 Kexts 目录（试过 $TARGET/EFI/OC/Kexts 与 $TARGET 本身）" >&2; exit 2
fi
[ -z "$CONFIG" ] && [ -f "$(dirname "$KEXTS")/config.plist" ] && CONFIG="$(dirname "$KEXTS")/config.plist"

report() {
pl() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

emit() {
  if [ "$TSV" -eq 1 ]; then printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "${6:-}"
  else printf '  %-38s %-9s %-7s %-11s %-9s %s\n' "$1" "$2" "$3" "$4" "$5" "${6:-}"; fi
}

[ "$TSV" -eq 1 ] || {
  echo "══════════════════════════════════════════════════════════════"
  echo "  kext 清单 —— $KEXTS"
  echo "  （生成时间 $(date '+%Y-%m-%d %H:%M:%S')）"
  echo "══════════════════════════════════════════════════════════════"
  printf '  %-38s %-9s %-7s %-11s %-9s %s\n' "kext（含包内插件）" "版本" "DTXcode" "DTSDKName" "大小" "sha256(前12)"
}

# 顶层 kext + 包内 PlugIns 里的 kext
find "$KEXTS" -name '*.kext' -maxdepth 4 2>/dev/null | sort | while IFS= read -r k; do
  # 跳过 macOS 的 AppleDouble 影子文件（._Foo.kext），它不是真 kext
  case "$(basename "$k")" in ._*) continue ;; esac
  info="$k/Contents/Info.plist"
  if [ ! -f "$info" ]; then
    emit "$(basename "$k")" "?" "?" "?" "?" "缺 Info.plist" "" 
    continue
  fi
  name=$(basename "$k")
  # 包内插件加个缩进提示
  case "$k" in "$KEXTS"/*/Contents/PlugIns/*) name="    └ $name" ;; esac
  ver=$(pl "$info" CFBundleVersion)
  xcode=$(pl "$info" DTXcode)
  sdk=$(pl "$info" DTSDKName)
  exe=$(pl "$info" CFBundleExecutable)
  bin="$k/Contents/MacOS/${exe:-}"
  if [ -n "${exe:-}" ] && [ -f "$bin" ]; then
    sz=$(stat -f %z "$bin" 2>/dev/null || echo 0)
    sha=$(shasum -a 256 "$bin" 2>/dev/null | cut -c1-12)
  else
    sz=$(du -sk "$k" 2>/dev/null | awk '{print $1*1024}')
    sha="（无二进制）"
  fi
  emit "$name" "${ver:-?}" "${xcode:-?}" "${sdk:-?}" "$sz" "$sha"
done

# --- config 引用核对 ---
rc=0
if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]; then
  echo
  echo "── config 引用核对（${CONFIG}）──"
  python3 - "$CONFIG" "$KEXTS" <<'PY'
import sys, plistlib, os
cfg, kdir = sys.argv[1], sys.argv[2]
try:
    d = plistlib.load(open(cfg, "rb"))
except Exception as e:
    print(f"  读不了 config：{e}"); sys.exit(1)
adds = (d.get("Kernel", {}) or {}).get("Add", []) or []
missing, disabled_missing, enabled = [], [], 0
for a in adds:
    bp = a.get("BundlePath", "")
    en = a.get("Enabled", False)
    if en: enabled += 1
    if not os.path.exists(os.path.join(kdir, bp)):
        (missing if en else disabled_missing).append((bp, en))
print(f"  Kernel>Add 共 {len(adds)} 条，启用 {enabled} 条")
if disabled_missing:
    print(f"  禁用项文件缺失 {len(disabled_missing)} 条（不影响启用引用完整性）")
    for bp, _ in disabled_missing:
        print(f"     - {bp}（已禁用）")
if missing:
    print(f"  ❌ 引用缺失 {len(missing)} 条：")
    for bp, en in missing:
        print(f"     - {bp}{'' if en else '（已禁用，影响小）'}")
    sys.exit(1)
else:
    print("  ✅ 所有启用的 BundlePath 都能在 Kexts/ 找到（启用引用 0 缺失）")
PY
  [ $? -ne 0 ] && rc=1
else
  echo
  echo "  （未提供 config.plist，跳过引用核对；用 --config <路径> 指定）"
fi

# 宿主 NVRAM 不能用于判定离线 EFI 的 OpenCore 版本，必须显式选择。
if [ "$HOST_NVRAM" -eq 1 ]; then
  echo
  echo "── 当前宿主 OpenCore NVRAM（不代表目标 EFI 的版本）──"
  ocv=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null | sed 's/^.*opencore-version[[:space:]]*//')
  if [ -n "$ocv" ]; then
    echo "  $ocv   （DBG- = DEBUG 构建 / REL- = RELEASE；仅宿主证据）"
  else
    echo "  （宿主变量读不到或宿主未运行 OpenCore）"
  fi
fi

echo
echo "── 提醒（见 references/kext-and-oc-update.md）──"
echo "  ★★ 判「该不该更新」前，核对上游发布、构建元数据，以及当前发行版的安装脚本 / mirror.json；记录来源与版本约束"
echo "  ★  上游 tag 查不到 ≠ 来路不明（可能是 Dortania build-repo 按 commit 构建、补丁号 +1）"
echo "  ★  换 OpenCore 构建必须连官方同名 Drivers 一起换"

[ "$rc" -eq 0 ] || return 1
return 0
}

if [ -n "$SAVE" ]; then
  REPORT=$(mktemp) || exit 2
  trap 'rm -f "$REPORT"' EXIT HUP INT TERM
  report > "$REPORT"
  rc=$?
  cat "$REPORT"
  cat "$REPORT" > "$SAVE" || { echo "无法保存报告：$SAVE" >&2; exit 2; }
  exit "$rc"
fi
report
