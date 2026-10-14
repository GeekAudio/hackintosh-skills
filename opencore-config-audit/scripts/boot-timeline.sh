#!/bin/bash
# 启动时间线采集（快速版）
# 用法：  sudo bash boot-timeline.sh
#         （输出写到调用者家目录 ~/boot-timeline-<时间>.txt）
#
# 顺序经过调整：先把「快且关键」的数据写出来（dmesg 里就有驱动的内核消息），
# 最慢的 `log show` 放在最后，并且最多跑 60 秒就会自动中断，不会一直卡着。
# 只读，不修改任何东西。

set -u
U="${SUDO_USER:-$USER}"
H="$(dscl . -read /Users/"$U" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
[ -n "${H:-}" ] && [ -d "$H" ] || H="/tmp"
OUT="$H/boot-timeline-$(date +%Y%m%d-%H%M%S).txt"
: > "$OUT"

step() { printf '\n>>> %s\n' "$*"; printf '\n>>> %s\n' "$*" >&2; }
H2()   { { echo; echo "===================== $* ====================="; } >> "$OUT"; }

# 带超时地跑一条命令，输出追加到 $OUT
timed() {   # timed <秒> <命令...>
  local t=$1; shift
  ( "$@" >> "$OUT" 2>&1 ) & local pid=$!
  ( sleep "$t"; kill -TERM "$pid" 2>/dev/null ) & local killer=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill -TERM "$killer" 2>/dev/null; wait "$killer" 2>/dev/null
  echo "# (exit $rc, timeout ${t}s)" >> "$OUT"
}

# 开机时刻
BOOT=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/^[^{]*{ sec = \([0-9][0-9]*\),.*$/\1/p')
if [ -n "${BOOT:-}" ] && [ "$BOOT" -gt 1000000000 ] 2>/dev/null; then
  START=$(date -r "$BOOT" "+%Y-%m-%d %H:%M:%S")
  END=$(date -v+5M -r "$BOOT" "+%Y-%m-%d %H:%M:%S")
else
  START=$(date -v-1H "+%Y-%m-%d %H:%M:%S"); END=$(date "+%Y-%m-%d %H:%M:%S")
fi

# ---------- 1. 快 ----------
step "1/5 基本信息"
H2 "基本信息"; { echo "boottime: $START"; echo "现在: $(date)"; uptime; sw_vers; } >> "$OUT" 2>&1

step "2/5 NVRM 启动属性"
H2 "NVRM 启动属性"
ioreg -r -n NVRM -d 1 -l 2>/dev/null | grep -E '"nvrm-|"model"' >> "$OUT" 2>&1

# ---------- 3. 快，且最关键：dmesg 里就有驱动的内核消息 ----------
step "3/5 dmesg（驱动内核消息环 —— 关键数据在这）"
H2 "dmesg：驱动消息"
dmesg 2>&1 | grep -iE 'nvrm|nvaccel|nvidia|nullmoth|gsp|bar1|flip|vblank|settle|armed|hold' | tail -400 >> "$OUT" 2>&1
{ echo; echo "-- dmesg 行数 --"; dmesg 2>&1 | wc -l; dmesg 2>&1 | tail -1; } >> "$OUT" 2>&1
echo "    （已写入 ${OUT}  ，可以先看这一段）"

# ---------- 4. 快：launchd 时间线 ----------
step "4/5 launchd 启动时间线"
H2 "launchd 时间线"
{
  echo "-- 关键服务首次出现 --"
  for s in WindowServer loginwindow Dock Finder coreservicesd; do
    t=$(grep -m1 "$s" /var/log/com.apple.xpc.launchd/launchd.log 2>/dev/null | cut -c1-23)
    echo "  $s: ${t:-?}"
  done
  echo
  echo "-- 每个时间点的事件数（前 240 秒；空档就是卡住的地方）--"
} >> "$OUT" 2>&1
python3 - >> "$OUT" 2>&1 <<'PY'
import re, collections, datetime
L = "/var/log/com.apple.xpc.launchd/launchd.log"
c = collections.Counter()
try:
    with open(L, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", line)
            if m: c[m.group(1)] += 1
except Exception as e:
    print("  读取失败:", e); raise SystemExit
if not c: print("  无数据"); raise SystemExit
ts = sorted(c); t0 = datetime.datetime.strptime(ts[0], "%Y-%m-%d %H:%M:%S")
prev = None
for t in ts:
    d = datetime.datetime.strptime(t, "%Y-%m-%d %H:%M:%S")
    off = (d - t0).total_seconds()
    if off > 240: break
    gap = "" if prev is None else ("   <<< 停顿 %ds >>>" % (d - prev).total_seconds() if (d - prev).total_seconds() >= 5 else "")
    print("   +%4ds  %5d 事件  %s%s" % (off, c[t], t, gap))
    prev = d
PY

# ---------- 5. 慢：unified log，放最后，60 秒超时 ----------
# ⚠️ 两个坑：
#   1) 不能用 --start/--end：开机时系统时钟会被校正，log show 会报
#      "Wall Clock adjustment detected" 并返回**上一次开机**的时间段（实测抓到 17:47–21:28，而本次开机是 23:10）。改用 --last。
#   2) 谓词不要用 eventMessage CONTAINS（要全量扫描，很慢）。只用索引字段 process == "kernel"，
#      关键词过滤放到本地 grep。
#   ★ 若这台机器的 --last 也失效（返回整个日志库），别在这硬等：改用 find-boot-gap.sh（流式过滤）。
UP=$(( $(date +%s) - ${BOOT:-0} )); MIN=$(( UP / 60 + 2 )); [ "$MIN" -gt 30 ] && MIN=30; [ "$MIN" -lt 3 ] && MIN=3
step "5/5 内核日志（较慢，最多 90 秒，超时自动中断）"
H2 "内核日志：驱动消息（--last ${MIN}m，避开时钟校正问题）"
KD=$(mktemp /tmp/bt-kdump-XXXXXX.txt)
( /usr/bin/log show --last "${MIN}m" --style compact --predicate 'process == "kernel"' > "$KD" 2>/dev/null ) & _p=$!
( sleep 90; kill -TERM "$_p" 2>/dev/null ) & _k=$!
wait "$_p" 2>/dev/null; _rc=$?
kill -TERM "$_k" 2>/dev/null; wait "$_k" 2>/dev/null
echo "# (log show exit $_rc, 抓到 $(wc -c < "$KD" | tr -d ' ') 字节)" >> "$OUT"
grep -a -iE "nvrm|nvaccel|gsp|bar1|nvidia|nullmoth" "$KD" >> "$OUT" 2>&1
rm -f "$KD"

echo
echo "=========================================="
echo " 完成，已写入："
echo "   $OUT"
echo " 大小：$(wc -c < "$OUT") 字节"
echo " 把文件发我即可（第 3 段的 dmesg 最关键）。"
echo "=========================================="
