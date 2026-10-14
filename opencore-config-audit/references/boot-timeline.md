# 启动耗时 / 时间线分析

## 0. 用途与前置

「开机很慢」「卡在某处」「黑屏多久」这类问题**不能靠感觉**。启动耗时是一条**三段独立**的时间线，
每段的证据在**不同的地方**，混在一起看永远定位不到：

| 段 | 时间范围 | 证据在哪 | 谁负责 |
|---|---|---|---|
| **A. OC 段** | 固件 POST → 交给 macOS | ESP 根 `opencore-*.txt`（`Misc>Debug>Target` 含 `0x40`） | OpenCore 配置（kext 数量、ACPI、quirk、超时） |
| **B. 内核 / 驱动段** | 内核起来 → 显示 arm / 桌面 | `dmesg` + `log show`（`process == "kernel"`） | 驱动（NVIDIA NVRM/NVRMFB、网卡、iGPU 等） |
| **C. 用户态段** | launchd → Finder / 桌面可用 | `/var/log/com.apple.xpc.launchd/launchd.log`（**不需 sudo**） | 服务依赖、`IOKitWaitQuiet` 阻塞、Spotlight |

**★ 铁律**：报「开机慢」时**先问清楚是哪一段**。
「从选择器到苹果 logo 之间滚字很慢」是 **A 段**（见 `logs-and-debug.md` 的 `Target` 位）；
「苹果 logo 转圈很久才进桌面」是 **B/C 段**（多半是驱动在等）。

## 1. 采集：两个脚本，一个原则

原则：**先拿快且关键的数据（`dmesg` / `launchd.log`），把最慢的 `log show` 放最后并设超时**。
否则一次采集能卡十几分钟（本机日志库 ~3 GB / 2000 万行）。

```bash
# ① 总览（推荐先跑）—— 基本信息 + NVRM 属性 + dmesg + launchd 时间线 + 内核日志
sudo bash scripts/boot-timeline.sh          # 输出 ~/boot-timeline-<时间>.txt

# ② 精查某个「停顿窗口」—— 先自动找最大空档，再流式抓该窗口的日志
sudo bash scripts/find-boot-gap.sh          # 全量，2–5 分钟；可 Ctrl-C
sudo bash scripts/find-boot-gap.sh --kernel # 只抓内核，快很多
```

两个脚本都**只读**，不改任何东西。输出写到 `$SUDO_USER` 的家目录（用 `dscl` 查，不写死路径）。

### 1.1 ★★ 本机（及很多机器）`log show` 的时间过滤整体失效

这是本机踩得最深的一个坑，**换机器也要先验证**：

| 你以为能用的写法 | 实际行为（本机实测） |
|---|---|
| `log show --start "<t>" --end "<t>"` | 报 `Wall Clock adjustment detected`（开机时系统时钟被校正），返回**整个日志库**（≈3 GB / 2000 万行） |
| `log show --last 30m` | **同样返回整个日志库**（不按时间裁） |
| `log show --boot` | **该选项不存在** |

**正确做法 = 流式过滤**：`log show` 的输出是**按时间顺序的流**，所以不落中间文件，用 `awk` 只打印窗口内的行：

```bash
log show --style compact --predicate "$PRED" 2>/dev/null \
  | awk -v s="$S" -v e="$E" '{ t=substr($0,1,19); if (t >= s && t <= e) print }' \
  > "$FILTERED"
```

无论日志库多大，**落盘的只有窗口内那几十 KB**。

**谓词要省**：`process == "kernel"` 是索引字段，很快；**不要**用 `eventMessage CONTAINS` 做过滤
（要全量扫描，极慢）—— 关键词过滤放到本地 `grep`。需要排除刷屏消息时用 `NOT (eventMessage CONTAINS "...")`。

### 1.2 从 `launchd.log` 找「停顿窗口」（最快、不需要 sudo）

用户态空档就藏在 `launchd.log` 的**时间戳跳变**里。脚本里用 python 算相邻时间戳的差：

```python
# 限定 0..180 秒，找最大空档，输出 "时长 起点偏移 终点偏移"
for a, b in zip(ts, ts[1:]):
    if b - a > best[0]: best = (b - a, a, b)
```

得到「最大空档 D 秒（+A s → +B s）」后，把窗口两端各外扩几秒（`A-4` → `B+8`）去 `log show` 里精查。

## 2. 判据：日志行 → 含义 → 秒数

### 2.1 OC 段（`opencore-*.txt`）

行格式 `mm:sss 间隔 OC模块: 消息`，**第一列是相对启动的秒数**，直接拿来做阶段耗时。
关键判据行见 `logs-and-debug.md` §5（`OCABC:` 各 quirk、`OCA:` ACPI 表、`OCJS:` APFS 门槛、`OCB:` 启动项）。
**看 OC 段耗时就找两个相邻 `OCB:`/`OCA:` 行之间秒数跳变最大的那一段。**

### 2.2 内核 / 驱动段（`dmesg` + `log show`）

| 日志行 | 含义 |
|---|---|
| `auto-go: go(2) in <N> ms (BAR1 placed outside the console \| not placed)` | **★ 最有价值的一行** —— `N` 就是驱动在 arm 显示前**主动睡的毫秒数**；括号里是 BAR1 放置结果 |
| `nv_get_firmware ... gsp_ga10x.bin` | GSP 固件开始加载（在 `go(2)` 之后） |
| `boot hold RELEASED (display armed) — WindowServer's IOKitWaitQuiet may return` | 驱动放开 registry；**这一行之前的等待会直接推迟桌面** |
| `boot raster: head 0 … 60.000 Hz MEASURED` / `armed raster <WxH> pclk <f>` | 光栅测量完成（`pclk 148500000` = 60 Hz） |
| `head N not running` | 其余头没在扫描（`nvfbheads=4` 不代表 4 个头都跑） |
| `setDetailedTimings: … that is the current mode now (NO MODESET)` | 接管**没有改模式** ⇒ 黑屏不是模式切换造成的 |
| `Previous shutdown cause:` | 上次关机是否正常（panic / 断电） |

### 2.3 用户态段（`launchd.log`）

看**关键服务的首次出现时刻**（相对开机秒数）与**每秒事件数**（低条数 = 空转）：

```bash
for s in WindowServer loginwindow Dock Finder coreservicesd; do
  t=$(grep -m1 "$s" /var/log/com.apple.xpc.launchd/launchd.log | cut -c1-23)
  echo "  $s: ${t:-?}"
done
```

## 3. ★ 本机实测案例（可直接当模板）

### 3.1 「每次开机固定多等 ~102 秒」（驱动 bug，B 段）

**症状**：开机到 Finder 可用 ≈ **3 分 17 秒**；用户态时间线 `launchd +5s`、`WindowServer +8s`、
**`+34s→+71s 卡住 37 秒（日志全空）`**、用户会话 `+72s`、**Finder `+197s`**。

**取证**：把「驱动 start」与「释放 hold」配对，**五轮开机全部 101–103 秒，一秒不差 ⇒ 固定开销，非偶发**：

| 驱动 start（持 hold） | 加载 GSP 固件 | 释放 hold | start→固件 | 固件→释放 |
|---|---|---|---|---|
| 21:24:38.360 | 21:26:20.104 | 21:26:24.023 | **+102.0 s** | +4.0 s |
| 22:06:37.182 | 22:08:19.083 | 22:08:22.992 | **+102.0 s** | +3.0 s |
| 23:05:30.485 | 23:07:13.889 | 23:07:17.785 | **+103.0 s** | +4.0 s |

**根因行**（`NVRM.cpp:328`，1.0.9 时代是 324）：
```c
fAutoGoSettleMs = bar1Placed ? 500 : 100000;   // BAR1 未放置 ⇒ 盲睡 100 秒
// 下一行就是覆盖口：PE_parse_boot_argn("nvrmsettle", ...)
```
因果链：BAR1 未放置 → `fAutoGoSettleMs=100000` → `autoGo` 先 `IOSleep(100s)` **才**加载 GSP 固件并 arm 显示
→ boot hold 期间 registry busy → WindowServer 的 `IOKitWaitQuiet` 被挡 ~106 s → 桌面推迟到 `+197s`。

**解法**：boot-args 加 **`nvrmsettle=<ms>`**。同机前后实测 **`+197 s → +94 s`，省 103 秒**；
`5000` 就够（本机用 `1500`）。上游 issue **#23**（closed/DONE）。

> ★ **1.14 起安装器会自动加 `nvrmsettle=10000`，但只对 Turing 卡**（`case "$NVDEV" in 1[eEfF]??|21[89a-fA-F]?)`）——
> **Ampere（如本机 `10de:2206`）不在范围 ⇒ 必须手工保留**。且 `100000` 这个默认值在 1.15.0 里**原封不动**。

### 3.2 「剩下的 ~60 秒」（无驱动 iGPU 拖累 `IOGraphicsFamily`，B 段）

**症状**：加了 `nvrmsettle` 后仍慢。

**根因**：主板枚举到的**无驱动 Intel UHD 770** 让 `IOGraphicsFamily` bring-up 等它。
**解法**：boot-args 加 **`-wegnoigpu`**（藏掉核显）⇒ **91 s → 27 s**。最终 **137 s → 28 s**。
上游 issue **#35**（closed/DONE）。

> 注意区分：本机 10-09 曾观察到「**带核显开机 15 s 到 WindowServer，无 91 s 回归**」——
> 即 `GPUCDetect` 这个状态**不是**「空档」的充分条件。**要看具体秒数，不要看单个状态标志。**

### 3.3 「进入选择器到启动之间滚字很久」（A 段）

见 `logs-and-debug.md` §1：OC 段刷屏由 `Misc>Debug>Target` 的 **`0x02`（控制台）** 位控制。
本机实测 OC 日志 **712 行 / 262 KB、OC 阶段 33 s**；`Target` 从 `71 (0x47)` → `69 (0x45)` 后屏幕上不再滚字。
**这与 boot-args 的 `-v` 完全独立**（`-v` 管的是 macOS 段）。

## 4. 常见耗时来源与处置

| 症状 | 最可能的段 | 取证行 | 处置 |
|---|---|---|---|
| 每次开机固定多等 ~100 s | B | `auto-go: go(2) in 100000 ms (BAR1 not placed)` | `nvrmsettle=<ms>`（#23） |
| 加了 settle 仍慢 ~60 s | B | `IOGraphicsFamily` 等待 / 无驱动 iGPU | `-wegnoigpu`（#35） |
| 选择器阶段屏幕滚字、耗时 | A | OC 日志行数 / `Target` | `Target` 去掉 `0x02` |
| 苹果 logo 后转圈很久、日志有空档 | B/C | launchd 空档 + `log show` 窗口 | 见 §1.2 精查 |
| 某个 kext 拖慢 | A | OC 日志 `OCB: Registering entry` | kext 精简（`disks-and-kexts.md`） |
| `Misc>Boot>Timeout` 等待 | A | 选择器停留 | 改 `Timeout`（**用户可见偏好，先问**） |

## 5. 方法论要点

1. **三段分开量**，别用「开机总共多久」一个数字下结论。
2. **固定 vs 偶发**：多轮开机对齐同一对日志行，秒数一致 ⇒ 固定开销（改配置/驱动）；波动大 ⇒ 依赖/竞态。
3. **空档 = 证据**：「某段时间日志全空」本身就是结论（说明在**没有日志输出**的地方卡住，通常是硬件 bring-up 或同步等待）。
4. **先问「卡在哪一段」，再决定查哪个日志**；`log show` 时间过滤不可信时，一律改用**流式过滤**。
5. **驱动侧耗时要对照上游 issue**（`nullmoth/nvidia-macos-driver` 的 #23 / #35）——本机的「神秘延迟」很可能是**已知的上游默认值**，不是你的配置错了。
