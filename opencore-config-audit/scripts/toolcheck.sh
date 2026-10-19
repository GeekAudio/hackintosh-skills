#!/bin/bash
# 工具链自检：这套流程要用的工具，本机有哪些、缺哪些、缺了怎么办
#
# 用法:
#   toolcheck.sh                    表格输出（工具 / 状态 / 路径 / 版本）
#   toolcheck.sh --oc-dir <目录>     顺带核对官方包里的 ocvalidate / macserial
#   toolcheck.sh --strict           缺「必需」项时退出码非 0
#   toolcheck.sh --json             机器可读
#
# 判据见 references/toolchain.md：① 系统自带 ② OpenCore 官方包自带 ③ 需自备
# 只读脚本，不改任何东西。
set -euo pipefail

# ★ 沙箱里 PATH 会被搞坏；同时保留用户自己的 ~/bin 与既有 PATH
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/opt/local/bin:$HOME/bin:${PATH:-}"

OC_DIR=""
STRICT=0
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --oc-dir) OC_DIR="${2:-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    --json)   JSON=1; shift ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1（-h 看用法）" >&2; exit 2 ;;
  esac
done

TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
MISS_REQ=0
MISS_OPT=0

# 版本探测：只对能自报版本的工具做，其余记 "-"
probe_ver() {
  local n="$1" p="$2" out=""
  case "$n" in
    python3)    out="$("$p" -V 2>&1 | head -1)" ;;
    git)        out="$("$p" --version 2>&1 | head -1)" ;;
    iasl)       out="$("$p" -v 2>&1 | grep -o 'version [0-9]\{8\}' | head -1)" ;;
    dot)        out="$("$p" -V 2>&1 | head -1)" ;;
    shellcheck) out="$("$p" --version 2>&1 | grep -i '^version' | head -1)" ;;
    jq)         out="$("$p" --version 2>&1 | head -1)" ;;
    macserial)  out="$("$p" --version 2>&1 | head -1)" ;;
    ocvalidate) out="$("$p" 2>&1 | grep -o 'OpenCore version [0-9.]*' | head -1)" ;;
    gfxutil)    out="(无版本开关)" ;;
    *)          out="-" ;;
  esac
  out="$(printf '%s' "$out" | tr -d '\r' | sed 's/[[:space:]]\{1,\}/ /g; s/^ //; s/ $//')"
  [ -n "$out" ] || out="-"
  printf '%s' "$out"
}

# record <名字> <required|optional> <说明> [候选路径...]
record() {
  local name="$1" kind="$2" note="$3"; shift 3
  local p=""
  if [ $# -gt 0 ]; then
    for c in "$@"; do
      if [ -x "$c" ]; then p="$c"; break; fi
    done
  else
    p="$(command -v "$name" 2>/dev/null || true)"
    # ★ 排除 IDE / 沙箱注入的 shim（例如宿主自带的 7z），那不是用户装的真工具
    case "$p" in
      *app.asar.unpacked*|*brokered-bin*|*/.workbuddy-ai/*) p="" ;;
    esac
  fi
  local status ver
  if [ -n "$p" ]; then
    status="OK"; ver="$(probe_ver "$name" "$p")"
  else
    status="缺"; ver="-"
    if [ "$kind" = "required" ]; then MISS_REQ=$((MISS_REQ+1)); else MISS_OPT=$((MISS_OPT+1)); fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$kind" "$status" "${p:--}" "$ver" "$note" >> "$TMP"
}

# ---------- ① 系统自带 ----------
record plutil          required "校验/改 plist（-lint 只查语法，schema 归 ocvalidate）"
record PlistBuddy      required "改单键；★ 不在 PATH，必须写全路径" /usr/libexec/PlistBuddy
record nvram           required "OC 版本 / boot-args / 启动项"
record ioreg           required "设备树取证（输出大，配 -n/-r 收窄）"
record diskutil        required "列盘 / 挂 ESP（报 failed 但可能已挂载，用 mount 判断）"
record shasum          required "sha256 对照"
record python3         required "本 skill 全部脚本的解析层（本机 bash 3.2 无 mapfile）"
record sysctl          required "hw.nperflevels / machdep.cpu / kern.boottime"
record kmutil          optional "showloaded；★ 无代码 kext 永不出现"
record kextutil        optional "kext 依赖/签名诊断（只对磁盘上的 kext 有意义）"
record log             optional "内核日志；★ 本机 --start/--end 失效，只能流式过滤"
record pmset           optional "睡眠/唤醒取证（pmset -g log 才是时间线）"
record spindump        optional "用户态卡顿取证（要 root）"
record codesign        optional "签名验证（本机 spctl -a 误判，改用它）"
record stapler         optional "公证票据验证"
record spctl           optional "Gatekeeper 状态"
record csrutil         optional "SIP 状态"
record tccutil         optional "TCC 重置"
record nm              optional "Mach-O 符号（需 Xcode CLT + license）"
record otool           optional "Mach-O 依赖（同上）"
record size            optional "Mach-O 段大小（同上）"
record lipo            optional "通用二进制拆分"
record xxd             optional "二进制取证（configdata / MuteGPIO）"
record ditto           optional "复制保留元数据"
record rsync           optional "镜像同步；★ -a --delete 会完全一致"
record hdiutil         optional "挂 dmg（KDK / 工具包）"
record curl            optional "下官方包 / 图标集（大文件用 -C -）"
record git             optional "仓库与 skill 同步"
record unzip           optional "解官方包"

# ---------- ② OpenCore 官方包自带 ----------
if [ -z "$OC_DIR" ]; then
  # 覆盖常见运行位置：工作区根 / skill 根 / scripts 内 / 仓库根
  # 并兼容 fetch-opencore-docs.sh 的产物结构（_oc-docs-audit/oc<版本>/Utilities）
  for c in ./_oc-docs-audit ../_oc-docs-audit ../../_oc-docs-audit ../../../_oc-docs-audit; do
    if [ -d "$c/Utilities" ]; then OC_DIR="$c"; break; fi
    for u in "$c"/oc*/Utilities; do
      if [ -d "$u" ]; then OC_DIR="${u%/Utilities}"; break 2; fi
    done
  done
fi
if [ -n "$OC_DIR" ] && [ -d "$OC_DIR/Utilities" ]; then
  U="$OC_DIR/Utilities"
  record ocvalidate required "config.plist 的 schema 校验；★★ 版本必须与机器上的 OC 同版" \
    "$U/ocvalidate/ocvalidate"
  record macserial  optional "三码生成/解码（-i 给出 SystemModel）；★ 是目录，二进制在 macserial/macserial" \
    "$U/macserial/macserial"
  record ACPIe      optional "在 ACPI 表里搜路径；★★ 命中/未命中退出码都是 0，只能看 stdout" \
    "$U/ACPIe/ACPIe"
  record acdtinfo   optional "显示器 DisplayProductID/VendorID" "$U/acdtinfo/acdtinfo"
else
  record ocvalidate required "官方包里的 Utilities/ocvalidate/ocvalidate（用 --oc-dir 指定，或先跑 fetch-opencore-docs.sh）"
  record macserial  optional "官方包里的 Utilities/macserial/macserial"
  record ACPIe      optional "官方包里的 Utilities/ACPIe/ACPIe"
  record acdtinfo   optional "官方包里的 Utilities/acdtinfo/acdtinfo"
fi

# ---------- ③ 需自备 ----------
record iasl        optional "★★ 改/编译 SSDT 必需（只加官方已编译 .aml 则不需要）；ACPICA 源码编译或 acpica 包"
record gfxutil     optional "设备路径 ↔ PciRoot(...)/Pci(...)；acidanthera/gfxutil release 有 macOS 二进制"
record zlib-flate  optional "解 AppleALC configdata 的 zlib（随 qpdf 提供）"
record dot         optional "Codec 拓扑图（graphviz）"
record jq          optional "解析键库/JSON（可用 python3 -m json.tool 替代）"
record shellcheck  optional "脚本静态检查"
record 7z          optional "解 .7z 工具包"

# ---------- GUI（可选） ----------
for app in "Hackintool:/Applications/Hackintool.app" "MaciASL:/Applications/MaciASL.app" \
           "OCAT:/Applications/OCAuxiliaryTools.app" "IORegistryExplorer:/Applications/IORegistryExplorer.app"; do
  nm_app="${app%%:*}"; p_app="${app#*:}"
  if [ -d "$p_app" ]; then
    printf '%s\toptional\tOK\t%s\t-\tGUI（可选）\n' "$nm_app" "$p_app" >> "$TMP"
  else
    MISS_OPT=$((MISS_OPT+1))
    printf '%s\toptional\t缺\t-\t-\tGUI（可选）\n' "$nm_app" >> "$TMP"
  fi
done

# ---------- 输出 ----------
if [ "$JSON" -eq 1 ]; then
  printf '{"tools":[\n'
  first=1
  while IFS=$'\t' read -r n k s p v note; do
    [ "$first" -eq 1 ] || printf ',\n'
    first=0
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
    printf '  {"name":"%s","kind":"%s","status":"%s","path":"%s","version":"%s","note":"%s"}' \
      "$(esc "$n")" "$k" "$s" "$(esc "$p")" "$(esc "$v")" "$(esc "$note")"
  done < "$TMP"
  printf '\n],"missing_required":%d,"missing_optional":%d}\n' "$MISS_REQ" "$MISS_OPT"
else
  echo "== OpenCore 工具链自检 =="
  echo "   ① 系统自带 · ② OpenCore 官方包 · ③ 需自备    判据见 references/toolchain.md"
  echo
  # 表头手工对齐：中文占 2 显示列，用 printf 宽度会错位，直接写死空格
  echo "工具           类别       状态    路径                                          版本"
  echo "-------------- --------- ------ -------------------------------------------- ----"
  while IFS=$'\t' read -r n k s p v note; do
    if [ "$k" = "required" ]; then kk="必需"; else kk="按需"; fi
    printf '%-14s %-9s %-6s %-44s %s\n' "$n" "$kk" "$s" "$p" "$v"
  done < "$TMP"
  echo
  echo "== 缺失项的说明 =="
  found=0
  while IFS=$'\t' read -r n k s p v note; do
    if [ "$s" = "缺" ]; then
      found=1
      if [ "$k" = "required" ]; then printf '  [必需] %-14s %s\n' "$n" "$note"
      else printf '  [按需] %-14s %s\n' "$n" "$note"; fi
    fi
  done < "$TMP"
  [ "$found" -eq 1 ] || echo "  （无）"
  echo
  echo "== 结论 =="
  echo "  必需缺失: $MISS_REQ    按需缺失: $MISS_OPT"
  if [ "$MISS_REQ" -gt 0 ]; then
    echo "  ★ 必需项缺失 ⇒ 核心流程（校验 / 取证 / 改 ESP）跑不完整，先补这几个："
    echo "    - ocvalidate: scripts/fetch-opencore-docs.sh <与机器同版本>"
    echo "    - PlistBuddy 属系统自带，缺了说明系统异常（/usr/libexec/PlistBuddy）"
  fi
  echo "  ★ 按需项缺失不必全补 —— 按 references/toolchain.md §6 的降级矩阵处理"
  echo "  ★★ 最容易出错的不是「没装」，而是「装错版本」：ocvalidate 必须与机器上的 OpenCore 同版"
fi

if [ "$STRICT" -eq 1 ] && [ "$MISS_REQ" -gt 0 ]; then exit 1; fi
exit 0
