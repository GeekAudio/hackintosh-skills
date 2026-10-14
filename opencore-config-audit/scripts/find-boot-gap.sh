#!/bin/bash
# 抓「启动停顿窗口」的日志（流式过滤版 —— 不落盘）
#
# 这台机器的 log show **时间过滤整体失效**：
#   --start/--end  → 报 "Wall Clock adjustment detected"，返回整个日志库（实测 3 GB / 2000 万行）
#   --last Nm      → 同样返回整个日志库
#   --boot         → 这个选项不存在
#
# 但 `log show` 的输出是**按时间顺序**的流，所以正确做法是：
#   **流式过滤** —— 不写中间文件，用 awk 只打印目标时间窗内的行。
#   无论日志库多大，落盘的只有窗口内那几十 KB。
#
# 用法： sudo bash find-boot-gap.sh [--kernel]
#        --kernel  只抓内核消息（快很多，但会漏掉用户态）
# 只读，不修改任何东西。

set -u
[ "$(id -u)" = "0" ] || { echo "请用 sudo 运行： sudo bash \"$0\""; exit 1; }

KERNEL_ONLY=0
[ "${1:-}" = "--kernel" ] && KERNEL_ONLY=1

U="${SUDO_USER:-$USER}"
H="$(dscl . -read /Users/"$U" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
[ -n "${H:-}" ] && [ -d "$H" ] || H="/tmp"
OUT="$H/boot-gap-$(date +%Y%m%d-%H%M%S).txt"
FILTERED=$(mktemp /tmp/gapfiltered-XXXXXX.txt)
trap 'rm -f "$FILTERED"' EXIT

BOOT=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/^[^{]*{ sec = \([0-9][0-9]*\),.*$/\1/p')
[ -n "${BOOT:-}" ] || { echo "!! 拿不到 kern.boottime"; exit 1; }

echo "=============================================="
echo " 启动停顿窗口精查（流式过滤版）"
echo "=============================================="
echo " 开机: $(date -r "$BOOT" '+%Y-%m-%d %H:%M:%S')"
echo " 开机 UUID: $(sysctl -n kern.bootsessionuuid 2>/dev/null || echo '?')"
echo

echo "→ 第 1 步：从 launchd.log 找最大空档"
GAP=$(python3 - "$BOOT" <<'PY'
import re, sys, datetime
boot = int(sys.argv[1]); t0 = datetime.datetime.fromtimestamp(boot)
L = "/var/log/com.apple.xpc.launchd/launchd.log"
pat = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})")
ts = []
with open(L, encoding="utf-8", errors="replace") as f:
    for line in f:
        m = pat.match(line)
        if not m: continue
        t = datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
        off = int((t - t0).total_seconds())
        if 0 <= off <= 180: ts.append(off)
if len(ts) < 2: print("ERR 0 0 0"); raise SystemExit
ts = sorted(set(ts)); best = (0, 0, 0)
for a, b in zip(ts, ts[1:]):
    if b - a > best[0]: best = (b - a, a, b)
print("%d %d %d" % best)
PY
)
set -- $GAP
[ "${1:-ERR}" = "ERR" ] && { echo "  解析失败"; exit 1; }
D=$1; A=$2; B=$3
echo "   最大空档：${D}s   （+${A}s → +${B}s）"

S=$(date -r $(( BOOT + A - 4 )) '+%Y-%m-%d %H:%M:%S')
E=$(date -r $(( BOOT + B + 8 )) '+%Y-%m-%d %H:%M:%S')
echo "   目标窗口：${S} ~ ${E}"
echo
if [ "$KERNEL_ONLY" = "1" ]; then
  echo "→ 第 2 步：流式抓取【仅内核】（快，约 30-90 秒）"
  PRED='process == "kernel" AND NOT (eventMessage CONTAINS "nvAllocVram" OR eventMessage CONTAINS "nvScanoutInfo" OR eventMessage CONTAINS "allocPhysical")'
else
  echo "→ 第 2 步：流式抓取【全部】（约 2-5 分钟，要扫过整个日志库；可 Ctrl-C）"
  echo "   嫌慢可改用： sudo bash \"$0\" --kernel"
  PRED='NOT (eventMessage CONTAINS "nvAllocVram" OR eventMessage CONTAINS "nvScanoutInfo" OR eventMessage CONTAINS "allocPhysical")'
fi

ST=$(date +%s)
log show --style compact --predicate "$PRED" 2>/dev/null \
  | awk -v s="$S" -v e="$E" '{ t=substr($0,1,19); if (t >= s && t <= e) print }' \
  > "$FILTERED"
DUR=$(( $(date +%s) - ST ))
echo "   完成，耗时 ${DUR}s，窗口内 $(wc -l < "$FILTERED" | tr -d ' ') 行"

{
  echo "启动停顿窗口精查  $(date)"
  echo "开机: $(date -r "$BOOT" '+%Y-%m-%d %H:%M:%S')   UUID: $(sysctl -n kern.bootsessionuuid 2>/dev/null)"
  echo "最大空档: ${D}s  (+${A}s → +${B}s)"
  echo "目标窗口: ${S} ~ ${E}"
  echo "模式: $([ "$KERNEL_ONLY" = 1 ] && echo 仅内核 || echo 全部)   耗时 ${DUR}s"
  echo
  echo "===== B. 窗口内 进程 统计（前 25）====="
  awk '{for(i=1;i<=NF;i++) if ($i ~ /\[[0-9]+:/ || $i ~ /\[[0-9]+\]$/) {sub(/\[.*/,"",$i); print $i; break}}' "$FILTERED" | sort | uniq -c | sort -rn | head -25
  echo
  echo "===== B2. 去重后的消息（把时间戳和数字抹掉后统计，前 25）====="
  sed -E 's/^[0-9-]+ [0-9:.]+ +//; s/\[[0-9]+:[0-9a-f]+\]/[pid]/g; s/0x[0-9a-f]+/0xX/g; s/[0-9]{3,}/N/g' "$FILTERED" \
    | sort | uniq -c | sort -rn | head -25 | cut -c1-190
  echo
  echo "===== C. 窗口内每秒的日志条数（低条数 = 空转）====="
  awk '{print substr($0,1,19)}' "$FILTERED" | uniq -c | head -120
  echo
  echo "===== D. 自检 ====="
  echo "  窗口内总行数: $(wc -l < "$FILTERED" | tr -d ' ')"
  echo -n "  窗口内最早: "; grep -a -m1 -oE "^[0-9-]+ [0-9:]+" "$FILTERED" || echo "(无)"
  echo -n "  窗口内最晚: "; grep -a -oE "^[0-9-]+ [0-9:]+" "$FILTERED" | tail -1 || echo "(无)"
  echo
  # 自动找出窗口内最吵的进程，排除它，免得把 head 配额吃光
  TOP=$(awk '{for(i=1;i<=NF;i++) if ($i ~ /\[[0-9]+:/ || $i ~ /\[[0-9]+\]$/) {sub(/\[.*/,"",$i); print $i; break}}' "$FILTERED" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  echo "===== A1. 窗口内日志【已排除最吵的进程: ${TOP:-无}】（前 300 行）====="
  if [ -n "${TOP:-}" ]; then
    grep -av "^[0-9-]* [0-9:.]* [A-Za-z]* *${TOP}\[" "$FILTERED" | head -300
  else
    head -300 "$FILTERED"
  fi
  echo
  echo "===== A2. 窗口末尾 250 行（解锁瞬间在这里）====="
  if [ -n "${TOP:-}" ]; then
    grep -av "^[0-9-]* [0-9:.]* [A-Za-z]* *${TOP}\[" "$FILTERED" | tail -250
  else
    tail -250 "$FILTERED"
  fi
} > "$OUT"

echo
echo "=========================================="
echo " 输出：$OUT"
echo " 大小：$(wc -c < "$OUT") 字节"
echo " 行数：$(wc -l < "$OUT")"
echo " 把文件发我即可。"
echo "=========================================="
