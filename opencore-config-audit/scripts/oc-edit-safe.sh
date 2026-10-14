#!/bin/bash
# 安全改 ESP 上 config.plist 的包装：备份 → (你自己改) → 校验/存档/落盘复验
#
# 用法:
#   oc-edit-safe.sh begin  <esp_config> <workdir>            备份 + 记录基线 sha
#   ... 用 plutil 改 config ...
#   oc-edit-safe.sh finish <esp_config> <workdir> [标签]      校验 + 同步镜像 + 版本存档 + 卸载重挂复验
#
# 例:
#   S=/Volumes/EFI/EFI/OC/config.plist; W="$PWD"
#   oc-edit-safe.sh begin  "$S" "$W"
#   plutil -replace 'Misc.Debug.Target' -integer 69 "$S"
#   oc-edit-safe.sh finish "$S" "$W" docaudit-console-off
#
# 约定：工作区里放 _oc-current.plist（镜像）与 <archive-dir>/config.plist.vNN-<说明>（版本存档）
set -u

MODE="${1:?用法: oc-edit-safe.sh begin|finish <esp_config> <workdir> [标签]}"
CFG="${2:?缺少 esp_config}"
WORK="${3:?缺少 workdir}"
LABEL="${4:-edit}"
TS=$(date +%Y%m%d-%H%M%S)

[ -f "$CFG" ] || { echo "找不到 $CFG（ESP 挂载了吗？ls -d /Volumes/EFI）"; exit 2; }
mkdir -p "$WORK"

# ESP 设备标识（用于卸载/重挂复验）
# ★ 安全护栏：只有当 config 确实位于 /Volumes/ 下的 **EFI 分区** 时才做卸载/重挂。
#   否则（例如把工作区里的副本传进来）df 会给出 /System/Volumes/Data 之类的系统卷，
#   误卸载系统卷是危险操作 ⇒ 宁可跳过。
ESP_DEV=""
MP=$(df -P "$CFG" | awk 'NR==2{print $NF}')
case "$MP" in
  /Volumes/*)
    INFO=$(diskutil info "$MP" 2>/dev/null || true)
    if printf '%s\n' "$INFO" | grep -q 'Partition Type:.*EFI'; then
      ESP_DEV=$(printf '%s\n' "$INFO" | awk -F': *' '/Device Identifier/{print $2}')
    fi
    ;;
esac

case "$MODE" in
begin)
  BASE=$(shasum -a 256 "$CFG" | awk '{print $1}')
  echo "== 基线 =="
  echo "   config : $CFG"
  echo "   sha256 : $BASE"
  echo "   挂载点 : ${MP:-未知}   设备: ${ESP_DEV:-未知}"
  cp -p "$CFG" "$WORK/_oc-backup-before-$LABEL-$TS.plist"
  echo "   备份   : $WORK/_oc-backup-before-$LABEL-$TS.plist"
  printf '%s' "$BASE" > "$WORK/.oc-edit-baseline"
  echo
  echo "现在可以用 plutil 改 config 了；改完执行:"
  echo "  oc-edit-safe.sh finish \"$CFG\" \"$WORK\" $LABEL"
  ;;

finish)
  echo "== 1) 语法与官方校验 =="
  plutil -lint "$CFG" || { echo "plutil 校验失败 —— 建议回滚备份"; exit 1; }

  OV=$(ls -1 "$WORK"/_oc-docs-audit/oc*/Utilities/ocvalidate/ocvalidate 2>/dev/null | head -1)
  if [ -n "$OV" ]; then "$OV" "$CFG" || echo "   ★ ocvalidate 有报错，先修"; else echo "   (未找到 ocvalidate，跳过)"; fi

  echo
  echo "== 2) 语义差异（相对基线备份）=="
  BASE_F=$(ls -t "$WORK"/_oc-backup-before-$LABEL-*.plist 2>/dev/null | head -1)
  # 标签不一致时回退到最近一次备份（begin/finish 的 LABEL 不必完全相同）
  [ -n "$BASE_F" ] || BASE_F=$(ls -t "$WORK"/_oc-backup-before-*.plist 2>/dev/null | head -1)
  if [ -n "$BASE_F" ]; then
    echo "   基线: $BASE_F"
    "${PYTHON:-python3}" - "$BASE_F" "$CFG" <<'PY'
import plistlib, sys
a = plistlib.load(open(sys.argv[1], "rb")); b = plistlib.load(open(sys.argv[2], "rb"))
def walk(x, y, p=""):
    if isinstance(x, dict) and isinstance(y, dict):
        for k in sorted(set(x) | set(y)):
            if k not in x: yield ("+", f"{p}/{k}", repr(y[k])[:60]); continue
            if k not in y: yield ("-", f"{p}/{k}", repr(x[k])[:60]); continue
            yield from walk(x[k], y[k], f"{p}/{k}")
    elif isinstance(x, list) and isinstance(y, list):
        if x != y: yield ("~", p, f"list 变化：{len(x)} 项 → {len(y)} 项")
    elif x != y:
        yield ("~", p, f"{x!r} -> {y!r}")
n = 0
for t, p, v in walk(a, b):
    n += 1; print(f"   {t} {p} | {v}")
print(f"   共 {n} 处差异")
PY
  fi

  echo
  echo "== 3) 同步工作区镜像 =="
  cp -p "$CFG" "$WORK/_oc-current.plist" && echo "   → $WORK/_oc-current.plist"

  echo
  echo "== 4) 版本存档 =="
  ARCH="$WORK/xh_adls3修复-20261013"
  mkdir -p "$ARCH"
  N=$(ls -1 "$ARCH"/config.plist.v[0-9]* 2>/dev/null | sed -n 's/.*\.v\([0-9]\+\).*/\1/p' | sort -n | tail -1)
  N=$(( ${N:-0} + 1 ))
  DST="$ARCH/config.plist.v$N-$LABEL"
  cp -p "$CFG" "$DST" && echo "   → $DST"

  echo
  echo "== 5) 落盘复验（sync → 卸载 → 重挂 → 复验 sha）=="
  NEW=$(shasum -a 256 "$CFG" | awk '{print $1}')
  sync
  if [ -n "$ESP_DEV" ]; then
    diskutil unmount "$ESP_DEV" >/dev/null 2>&1 || true
    diskutil mount   "$ESP_DEV" >/dev/null 2>&1 || \
      osascript -e "do shell script \"diskutil mount $ESP_DEV\" with administrator privileges" >/dev/null 2>&1 || true
    AFTER=$(shasum -a 256 "$CFG" 2>/dev/null | awk '{print $1}')
    if [ "$AFTER" = "$NEW" ]; then echo "   ✓ 重挂后 sha 一致：$NEW"
    else echo "   ★ 重挂后 sha 不一致（期望 $NEW，得到 ${AFTER:-读不到}）—— 检查 ESP 是否挂上"; fi
  else
    echo "   (无法确定 ESP 设备，跳过卸载/重挂；sha = $NEW)"
  fi
  echo
  echo "== 结论 =="
  echo "   sha256 : $NEW"
  echo "   存档   : $DST"
  echo "   回滚   : cp -p \"$BASE_F\" \"$CFG\"  (然后 sync/卸载重挂)"
  ;;
*)
  echo "未知模式 $MODE"; exit 2;;
esac
