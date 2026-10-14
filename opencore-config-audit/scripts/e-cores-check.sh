#!/bin/sh
# e-cores-check.sh —— Intel 混合架构（P 核 / E 核）现状体检
#
# 用途：判「小核有没有开」「开成什么样」，并给出判读。
#       配合 references/e-cores.md 使用。
#
# 用法：
#   ./e-cores-check.sh              # 完整体检
#   ./e-cores-check.sh --topo       # 只看拓扑
#   ./e-cores-check.sh --freq       # 只看频率（需同目录有 cpu-freq-probe.sh）
#
# 依赖：sysctl / system_profiler（macOS 自带）。可选：同目录 cpu-freq-probe.sh。
# 退出码：0 正常；1 有异常项（仅提示，不代表失败）。

set -u

ONLY=""
for a in "$@"; do
  case "$a" in
    --topo) ONLY=topo ;;
    --freq) ONLY=freq ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$a（-h 看用法）" >&2; exit 2 ;;
  esac
done

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WARN=0
say() { printf '%s\n' "$*"; }
kv()  { printf '  %-38s = %s\n' "$1" "${2:-<空>}"; }

topo() {
  say "=========== 1) CPU 拓扑 ==========="
  printf '  %-38s = ' "hw.ncpu / physicalcpu / logicalcpu"
  sysctl -n hw.ncpu hw.physicalcpu hw.logicalcpu 2>/dev/null | tr '\n' ' '; echo

  np=$(sysctl -n hw.nperflevels 2>/dev/null)
  kv "hw.nperflevels" "${np:-<不存在>}"

  p0p=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null)
  p0l=$(sysctl -n hw.perflevel0.logicalcpu  2>/dev/null)
  printf '  %-38s = %s\n' "perflevel0 (P 核) physical/logical" "${p0p:-<无>} / ${p0l:-<无>}"

  p1p=$(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null)
  p1l=$(sysctl -n hw.perflevel1.logicalcpu  2>/dev/null)
  printf '  %-38s = %s\n' "perflevel1 (E 核) physical/logical" "${p1p:-<无>} / ${p1l:-<无>}"

  kv "machdep.cpu.core_count" "$(sysctl -n machdep.cpu.core_count 2>/dev/null)"
  kv "machdep.cpu.thread_count" "$(sysctl -n machdep.cpu.thread_count 2>/dev/null)"
  kv "hw.cputhreadtype" "$(sysctl -n hw.cputhreadtype 2>/dev/null)"

  say ""
  say "  -- 机型 --"
  kv "hw.model" "$(sysctl -n hw.model 2>/dev/null)"
  system_profiler SPHardwareDataType 2>/dev/null \
    | grep -E "Model Identifier|Total Number of Cores|Chip|Processor Name" \
    | sed 's/^[[:space:]]*/     /'
}

freq() {
  say "=========== 2) 频率探针 ==========="
  if [ -x "$DIR/cpu-freq-probe.sh" ]; then
    say "  基线（i7-12700K）：单线程 ≈ 4.28 GHz / 8 线程 ≈ 4.29–4.35 GHz"
    "$DIR/cpu-freq-probe.sh" 2>/dev/null || say "  (探针执行失败)"
  else
    say "  未找到 cpu-freq-probe.sh，跳过（可在 scripts/ 目录下一起放）"
  fi
}

kext() {
  say ""
  say "=========== 3) CpuTopologyRebuild 是否加载 ==========="
  if command -v kmutil >/dev/null 2>&1; then
    out=$(kmutil showloaded --list-only 2>/dev/null | grep -i CpuTopologyRebuild)
    if [ -n "$out" ]; then
      say "  已加载：$out"
    else
      say "  未加载（或需提权）⇒ 若 config 里 Enabled=true 却看不到，查 kext 路径与依赖 Lilu"
    fi
  else
    say "  kmutil 不可用，跳过"
  fi
  say "  ★ 另需确认 config：Kernel > Add 里该条 Enabled=true，且排在 Lilu 之后"
}

verdict() {
  say ""
  say "=========== 4) 判读 ==========="
  np=$(sysctl -n hw.nperflevels 2>/dev/null)
  ncpu=$(sysctl -n hw.ncpu 2>/dev/null)
  case "$np" in
    1) say "  hw.nperflevels=1 ⇒ macOS 只看到一种核（E 核未暴露）"
       say "     · 若 BIOS 已把 Active Efficient Cores 设 All ⇒ 检查 ProvideCurrentCpuInfo 是否 true"
       say "     · 若刻意关小核 ⇒ 这是预期状态，见 e-cores.md §2（不要当故障修）" ;;
    2) say "  hw.nperflevels=2 ⇒ P / E 两级都已识别（小核已开）"
       if [ "${ncpu:-0}" -ge 20 ]; then
         say "     hw.ncpu=$ncpu ⇒ 20 线程，E 核已喂给内核"
       else
         say "     ⚠ hw.ncpu=$ncpu（本机满配应为 20）⇒ 检查 Hyper-Threading 是否 Enabled"
         WARN=1
       fi
       say "     下一步：确认 CpuTopologyRebuild 已加载（上面第 3 节），跑分与本机关小核基线对比" ;;
    *) say "  读不到 hw.nperflevels（非 Intel 混合架构 / 旧系统）" ;;
  esac
  say "  ★ 开小核 + boot-arg -v 可能随机启动失败（官方 README 明写）⇒ 排查时注意"
  say "  ★ 频率若比基线低 ⇒ 拓扑重建与 XCPM 打架，考虑回滚（e-cores.md §6）"
}

case "$ONLY" in
  topo) topo ;;
  freq) freq ;;
  *)    topo; freq; kext; verdict ;;
esac

[ "$WARN" -eq 0 ] || exit 1
exit 0
