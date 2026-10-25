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
# archive-dir 默认为 <workdir>/oc-config-archive，可用 OC_ARCHIVE_DIR 指定已有存档目录。
# OC_DOCS_DIR 可指定唯一版本的官方包目录；默认在 <workdir>/_oc-docs-audit 中查找。
set -euo pipefail

MODE="${1:?用法: oc-edit-safe.sh begin|finish <esp_config> <workdir> [标签]}"
CFG="${2:?缺少 esp_config}"
WORK="${3:?缺少 workdir}"
LABEL="${4:-edit}"
TS=$(date +%Y%m%d-%H%M%S)

[ -f "$CFG" ] || { echo "找不到 ${CFG}（ESP 挂载了吗？ls -d /Volumes/EFI）"; exit 2; }
mkdir -p "$WORK"
CFG="$(cd "$(dirname "$CFG")" && pwd -P)/$(basename "$CFG")"
WORK="$(cd "$WORK" && pwd -P)"

# ESP 设备标识（用于卸载/重挂复验）
# ★ 安全护栏：只有当 config 确实位于 /Volumes/ 下的 **EFI 分区** 时才做卸载/重挂。
#   否则（例如把工作区里的副本传进来）df 会给出 /System/Volumes/Data 之类的系统卷，
#   误卸载系统卷是危险操作 ⇒ 宁可跳过。
ESP_DEV=""
MP=$(df -P "$CFG" | awk 'NR==2{print $NF}' || true)
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
  # mktemp 防止相同标签在同一秒再次 begin 时覆盖可回滚的备份。
  BASE_F=$(mktemp "$WORK/_oc-backup-before-$LABEL-$TS.plist.XXXXXX")
  cp -p "$CFG" "$BASE_F"
  BASE=$(shasum -a 256 "$BASE_F" | awk '{print $1}')
  echo "== 基线 =="
  echo "   config : $CFG"
  echo "   sha256 : $BASE"
  echo "   挂载点 : ${MP:-未知}   设备: ${ESP_DEV:-未知}"
  echo "   备份   : $BASE_F"
  printf '%s\n%s\n%s\n' "$BASE" "$BASE_F" "$CFG" > "$WORK/.oc-edit-baseline"
  echo
  echo "现在可以用 plutil 改 config 了；改完执行:"
  echo "  oc-edit-safe.sh finish \"$CFG\" \"$WORK\" $LABEL"
  ;;

finish)
  # 以最近一次 begin 的会话为准；finish 标签只用于新存档的说明。
  # 不从历史标签猜测基线，否则可能对比到另一轮编辑的备份。
  STATE="$WORK/.oc-edit-baseline"
  [ -s "$STATE" ] || { echo "★ 缺少 begin 基线；先执行 begin，再修改配置并 finish"; exit 1; }
  BASE=$(sed -n '1p' "$STATE")
  BASE_F=$(sed -n '2p' "$STATE")
  BASE_CFG=$(sed -n '3p' "$STATE")
  if ! printf '%s\n' "$BASE" | grep -Eq '^[[:xdigit:]]{64}$' || \
     [ "$BASE_CFG" != "$CFG" ] || [ ! -f "$BASE_F" ]; then
    echo "★ begin 基线不完整、备份缺失或配置路径不符；保留现有文件并检查对应的 begin 会话"
    exit 1
  fi
  SAVED=$(shasum -a 256 "$BASE_F" | awk '{print $1}')
  [ "$SAVED" = "$BASE" ] || { echo "★ begin 备份 SHA 与基线不符，停止 finish"; exit 1; }

  echo "== 1) 语法与官方校验 =="
  plutil -lint "$CFG" || { echo "plutil 校验失败 —— 建议回滚备份"; exit 1; }

  DOCS="${OC_DOCS_DIR:-$WORK/_oc-docs-audit}"
  OVS=()
  for CANDIDATE in "$DOCS"/Utilities/ocvalidate/ocvalidate "$DOCS"/oc*/Utilities/ocvalidate/ocvalidate; do
    [ ! -f "$CANDIDATE" ] || OVS[${#OVS[@]}]="$CANDIDATE"
  done
  if [ "${#OVS[@]}" -gt 1 ]; then
    echo "   ★ 找到多个 ocvalidate，停止 finish："
    printf '     %s\n' "${OVS[@]}"
    echo "   用 OC_DOCS_DIR 指定与目标 OpenCore 同版的唯一官方包目录，或清理目录歧义。"
    exit 1
  fi
  if [ "${#OVS[@]}" -eq 0 ]; then
    echo "   ★ 未找到 ocvalidate；先把同版本官方包放到 $WORK/_oc-docs-audit，再执行 finish"
    exit 1
  fi
  OV="${OVS[0]}"
  "$OV" "$CFG" || { echo "   ★ ocvalidate 校验失败，停止同步、存档与重挂；先修复配置"; exit 1; }

  echo
  echo "== 2) 语义差异（相对基线备份）=="
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

  echo
  echo "== 3) 同步工作区镜像 =="
  cp -p "$CFG" "$WORK/_oc-current.plist" && echo "   → $WORK/_oc-current.plist"

  echo
  echo "== 4) 版本存档 =="
  ARCH="${OC_ARCHIVE_DIR:-$WORK/oc-config-archive}"
  mkdir -p "$ARCH"
  N=$(ls -1 "$ARCH"/config.plist.v[0-9]* 2>/dev/null | sed -En 's|.*/config\.plist\.v([0-9]+)-.*|\1|p' | sort -n | tail -1 || true)
  N=$(( ${N:-0} + 1 ))
  DST="$ARCH/config.plist.v$N-$LABEL"
  cp -p "$CFG" "$DST" && echo "   → $DST"

  echo
  echo "== 5) 落盘复验（sync → 卸载 → 重挂 → 复验 sha）=="
  NEW=$(shasum -a 256 "$CFG" | awk '{print $1}')
  sync
  if [ -n "$ESP_DEV" ]; then
    diskutil unmount "$ESP_DEV" >/dev/null 2>&1 || { echo "   ★ 无法卸载 ${ESP_DEV}，未完成落盘复验"; exit 1; }
    diskutil mount   "$ESP_DEV" >/dev/null 2>&1 || \
      osascript -e "do shell script \"diskutil mount $ESP_DEV\" with administrator privileges" >/dev/null 2>&1 || \
      { echo "   ★ 无法重挂 ${ESP_DEV}，未完成落盘复验"; exit 1; }
    AFTER=$(shasum -a 256 "$CFG" 2>/dev/null | awk '{print $1}' || true)
    if [ "$AFTER" = "$NEW" ]; then echo "   ✓ 重挂后 sha 一致：$NEW"
    else echo "   ★ 重挂后 sha 不一致（期望 ${NEW}，得到 ${AFTER:-读不到}）—— 检查 ESP 是否挂上"; exit 1; fi
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
