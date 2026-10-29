#!/bin/sh
# e-cores-check.sh —— Intel 混合架构现状检查（只读）
#
# 用法：
#   ./e-cores-check.sh                          # 拓扑、可选频率采样、CTR 加载状态
#   ./e-cores-check.sh --topo                    # 只看拓扑与判读
#   ./e-cores-check.sh --freq                    # 只运行同目录频率探针
#   ./e-cores-check.sh --topo --expected-threads 20
#
# --expected-threads 是调用者按目标 CPU、BIOS 核数和 HT 状态确认的预期逻辑线程数。
# 默认不猜 CPU 的满配线程数，也不以 hw.nperflevels 判断 Intel E 核是否启用。
# 退出码：0 检查完成；1 必需读数缺失、预期数量不符或探针失败；2 参数错误。
# 不挂载磁盘、不写 NVRAM、不提权；频率探针会产生短时 CPU 负载。

set -u

positive_int() {
  case "$1" in ''|*[!0-9]*|0) return 1 ;; esac
  [ "$1" -gt 0 ] 2>/dev/null
}

ONLY=""
EXPECTED=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --topo|--freq)
      mode=${1#--}
      if [ -n "$ONLY" ] && [ "$ONLY" != "$mode" ]; then
        echo "--topo 与 --freq 不能同时使用" >&2; exit 2
      fi
      ONLY=$mode; shift ;;
    --expected-threads)
      if [ "$#" -lt 2 ] || ! positive_int "${2:-}"; then
        echo "--expected-threads 需要正整数" >&2; exit 2
      fi
      EXPECTED=$2; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1（-h 看用法）" >&2; exit 2 ;;
  esac
done

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WARN=0
say() { printf '%s\n' "$*"; }
kv() { printf '  %-38s = %s\n' "$1" "${2:-<不可用>}"; }
read_sysctl() { sysctl -n "$1" 2>/dev/null || true; }

topo() {
  say "=========== 1) CPU 拓扑 ==========="
  ncpu=$(read_sysctl hw.ncpu)
  physical=$(read_sysctl hw.physicalcpu)
  logical=$(read_sysctl hw.logicalcpu)
  kv hw.ncpu "$ncpu"
  kv hw.physicalcpu "$physical"
  kv hw.logicalcpu "$logical"
  kv machdep.cpu.brand_string "$(read_sysctl machdep.cpu.brand_string)"
  kv machdep.cpu.core_count "$(read_sysctl machdep.cpu.core_count)"
  kv machdep.cpu.thread_count "$(read_sysctl machdep.cpu.thread_count)"
  kv hw.cputhreadtype "$(read_sysctl hw.cputhreadtype)"

  say ""
  say "  -- perflevel（仅作系统读数，不映射为 Intel P/E 核）--"
  kv hw.nperflevels "$(read_sysctl hw.nperflevels)"
  kv hw.perflevel0.physicalcpu "$(read_sysctl hw.perflevel0.physicalcpu)"
  kv hw.perflevel0.logicalcpu "$(read_sysctl hw.perflevel0.logicalcpu)"
  kv hw.perflevel1.physicalcpu "$(read_sysctl hw.perflevel1.physicalcpu)"
  kv hw.perflevel1.logicalcpu "$(read_sysctl hw.perflevel1.logicalcpu)"

  say ""
  kv hw.model "$(read_sysctl hw.model)"
  system_profiler SPHardwareDataType 2>/dev/null \
    | grep -E "Model Identifier|Total Number of Cores|Chip|Processor Name" \
    | sed 's/^[[:space:]]*/     /'
}

freq() {
  say "=========== 2) 频率探针 ==========="
  if [ -x "$DIR/cpu-freq-probe.sh" ]; then
    say "  与当前机器的同负载基线比较；不把单次频率变化直接归因于拓扑。"
    if ! "$DIR/cpu-freq-probe.sh"; then
      say "  ⚠ 频率探针执行失败，未完成采样"
      WARN=1
    fi
  else
    say "  未找到可执行的 cpu-freq-probe.sh，跳过可选采样"
  fi
}

kext() {
  say ""
  say "=========== 3) CpuTopologyRebuild 是否加载 ==========="
  if command -v kmutil >/dev/null 2>&1; then
    if loaded=$(kmutil showloaded --list-only 2>/dev/null); then
      out=$(printf '%s\n' "$loaded" | grep -i CpuTopologyRebuild)
      if [ -n "$out" ]; then
        say "  已加载：$out"
      else
        say "  列表中没有 CpuTopologyRebuild；是否需要它取决于目标配置，不能据此判断 E 核关闭。"
      fi
    else
      say "  无法读取已加载 kext，CTR 加载状态未知。"
    fi
  else
    say "  kmutil 不可用，CTR 加载状态未知。"
  fi
  say "  若计划使用 CTR，另需核实 Kernel > Add 已启用且位于 Lilu 之后。"
}

verdict() {
  say ""
  say "=========== 4) 判读 ==========="
  say "  XNU x86 只提供单一 SMP perflevel；nperflevels=1 或没有 perflevel1 不表示 E 核关闭。"
  if ! positive_int "$ncpu" || ! positive_int "$physical" || ! positive_int "$logical"; then
    say "  ⚠ CPU 数量读数缺失或无效，无法完成拓扑数量检查。"
    WARN=1
    return
  fi
  if [ "$ncpu" -ne "$logical" ] || [ "$physical" -gt "$logical" ]; then
    say "  ⚠ CPU 数量读数不一致，先核实当前活动 CPU 与拓扑，再判断配置。"
    WARN=1
  fi
  if [ -n "$EXPECTED" ]; then
    if [ "$logical" -eq "$EXPECTED" ]; then
      say "  逻辑线程数匹配调用者预期：$logical。数量匹配不单独证明 P/E 调度正确。"
    else
      say "  ⚠ 逻辑线程数 $logical 与调用者预期 $EXPECTED 不符。"
      say "     核对目标型号、BIOS 活动核心、HT、ProvideCurrentCpuInfo 与 CTR 配置；不自动归因为缺 E 核。"
      WARN=1
    fi
  else
    say "  已读到 $physical 个物理核心、$logical 个逻辑线程；未提供目标预期，不判定 E 核开关。"
    say "  先按目标 CPU 与 BIOS/HT 设置确认预期，再用 --expected-threads 对照。"
  fi
  say "  CTR 可能伪装 SMT / 修改显示核数；结合 BIOS、实际拓扑与同机负载测试验收。"
  say "  若命中 CTR 官方记录的 verbose (-v) 随机启动失败问题，按 e-cores.md 排查。"
}

case "$ONLY" in
  topo) topo; verdict ;;
  freq) freq ;;
  *) topo; freq; kext; verdict ;;
esac

[ "$WARN" -eq 0 ] || exit 1
exit 0
