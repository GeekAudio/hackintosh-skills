# 开小核 / 关小核（Intel 混合架构：P 核 / E 核）

> 依据：**`CpuTopologyRebuild` 官方 README**（`b00t0x/CpuTopologyRebuild`，逐条引用，见 §8）
> + **本机 10-15 实测**（`ProvideCurrentCpuInfo` 行为、BIOS 项名、Geekbench 7 官网同 CPU 榜对照）。
> ★ **先说结论**：**「关小核」和「开小核」是两种取舍，不是谁对谁错** ——
> 关掉会减少可用核心；开启后的收益取决于目标 CPU、拓扑与负载。需要时评估 `CpuTopologyRebuild`，
> 其官方记录了 **`-v` 随机启动失败问题**，见 §4.3。

## 0. 术语与机制

- **小核 = E-core（Efficient Core）**，大核 = **P-core（Performance Core）**。Intel 12 代（Alder Lake）起引入。
- 例：**i7-12700K = 8 P + 4 E**，P 核带超线程 ⇒ 满配 **12 核 20 线程**。
- **macOS 对混合架构支持不完整**，三步走：
  1. 靠 **`Kernel > Quirks > ProvideCurrentCpuInfo = true`** 才能把 E 核「喂」给内核
     （官方 README 原话：*"OpenCore's `ProvideCurrentCpuInfo` quirk enables Alder Lake's both P-Cores and E-Cores,
     but all cores and threads are recognized as equivalent"*）；
  2. 但喂进来后 **P 核和 E 核被当成等价的** ⇒ 可能拖累单线程 / 实际性能；
  3. 想区分 ⇒ 加 **`CpuTopologyRebuild.kext`** 重建拓扑（§4）。
- 不喂（`ProvideCurrentCpuInfo=false`）**或** BIOS 里关掉 E 核 ⇒ macOS 只见 **8 核 16 线程**。

> ★ **别误判成「CPU 缺核」**：`CPUID.1FH`（混合拓扑）在**开着小核**时会报 **20 个逻辑处理器**，
> 而 macOS 侧只报 8 核 16 线程是**正常现象**，不是硬件缺核、也不是驱动没加载。

## 1. 先判现状（先量再动）

```bash
sysctl -n hw.ncpu hw.physicalcpu hw.logicalcpu   # 当前逻辑 / 物理数量，结合目标型号与 BIOS 解释
sysctl -n machdep.cpu.core_count machdep.cpu.thread_count
sysctl -n hw.nperflevels                       # x86 为单一 SMP 类型，不能据此判断 E 核
```

**Intel 上不能用 ARM 式 perflevel 验收。** XNU 的
[`ml_get_cpu_types()`](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/i386/machine_routines.c)
在 x86 返回单一 SMP 类型；CTR 重建 SMT 拓扑，没有建立 Apple Silicon 式的 P/E perflevel。
因此 `hw.nperflevels=1`、不存在 `hw.perflevel1`，都不能推出 E 核已关闭。

先确认目标 CPU 的 P/E 数量、BIOS 的活动核心与 HT 设置，再对照暴露的逻辑线程数。
例如 i7-12700K 在全部核心和 HT 都启用时预期 20 个逻辑线程；只有 8P+HT 时为 16。
这组数字只适用于该示例，不能拿 20 当成所有 Intel CPU 的阈值。
CTR 默认 SMT 伪装及 `ctrsmt=full` 还会影响显示的物理核数，见 §4。

`scripts/e-cores-check.sh --topo` 显示读数但不猜 E 核开关；已确认预期时可运行
`scripts/e-cores-check.sh --topo --expected-threads 20`（20 换成目标值）。
数量匹配仍需结合 BIOS、实际拓扑及同机负载测试，不能单独证明调度正确。

## 2. 关小核（推荐给「求稳 / 不想折腾」）

**唯一可靠的做法是在 BIOS 层关**（macOS 侧没有「隐藏 E 核」的开关）：

| 厂商 | 位置 / 名字 |
|---|---|
| **ASUS** | `Advanced > CPU Configuration > **Active Efficient Cores**` → 设 **`0`** |
| MSI | `OC → Advanced CPU Configuration → **E-Core Count**`（或 `Active E-Cores`）→ `0` |
| Gigabyte | `Settings > Advanced CPU Settings → **E-Core Count**` → `0` |
| ASRock | `Advanced → CPU Configuration → **Active E Cores**` → `0` |

- **配置侧不用动**：`ProvideCurrentCpuInfo` 保持原样即可；`CpuTopologyRebuild` 留 `Enabled=false`（或删条目）。
- **取舍**：减少暴露的异构核心，可能简化特定故障的排查，但不保证性能或稳定性一定改善。
- **代价**：失去被关闭 E 核的计算容量；数量按目标型号确认。修改前后的影响需要同机、同负载比较。
- 本次仅改变 E 核时，保留既有可用的 P 核、HT 和 Speed Shift 设置，避免同时引入变量。若 panic 明确涉及 HWP，按 `intel-turbo.md` §6 核实。

## 3. 开小核（求性能 / 愿意收拾拓扑）

三件事，按顺序：

1. **BIOS**：`Active Efficient Cores` → **`All`**（厂商命名见 §2 表）。
2. **config**：`Kernel > Quirks > **ProvideCurrentCpuInfo = true**`（**必需** —— 官方 README 明写
   Alder Lake / Raptor Lake 要配合这个 quirk；Arrow Lake 才不需要）。
3. **可选但推荐**：`Kernel > Add` 加 **`CpuTopologyRebuild.kext`**，**紧跟 `Lilu` 之后**
   （它是 Lilu 插件，`OSBundleLibraries` 要求 `as.vit9696.Lilu ≥ 1.2.0`）⇒ 顺序 `Lilu → CpuTopologyRebuild → …`。

重启后按 §1 对照目标逻辑线程数与 CTR 拓扑。例如上述 i7-12700K 满配为 20 个逻辑线程；不要求 `hw.nperflevels` 变成 2。

★ **`ProvideCurrentCpuInfo` 与 `-ctrfixcnt` 的例外**：若用了 `-ctrfixcnt`，**必须**同时装
`AppleMCEReporterDisabler.kext`，否则**起不来**（§4.2）。

## 4. `CpuTopologyRebuild` —— 把「20 个等价核」重建成「8P + 4E」

### 4.1 它做什么

- 支持 **Alder Lake / Raptor Lake / Arrow Lake（实验性）**。
- 默认行为 = **把 E 核伪装成 P 核的「第 N 路 SMT 逻辑线程」**，得到更好的调度；
  **「系统信息」里显示真实核数（P+E）**。
- ★ 官方自述边界：*"The effect of this kext is not yet clear"* —— 有实测收益，但**官方不承诺**。

### 4.2 四个取值（boot-arg 或 NVRAM 二选一）

NVRAM 域 = **`4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`**（OpenCore 的 `NVRAM > Add`）。

| NVRAM 键 | boot-arg | 效果 |
|---|---|---|
| （都不写） | （都不写） | **默认**：拓扑伪装成 SMT，E 核识别为 P 核的 N 路逻辑线程；系统信息显示真实核数（P+E） |
| `ctrsmt` = `"off"` | **`ctrsmt=off`** | 不伪装，拓扑 = 真实结构，**性能会下降**；仅对**开了 HT** 的 Alder/Raptor 有效；等同 v1.x.x 默认行为 |
| `ctrsmt` = `"full"` | **`ctrsmt=full`** | 系统信息只显示 **P 核数**；性能影响不确定；等同 v1.x.x 加 **`-ctrsmt`** 的行为 |
| `ctrfixcnt` = `true` | **`-ctrfixcnt`** | 启用 `machdep.cpu.core_count` 修正；★ **必须同时装 `AppleMCEReporterDisabler.kext`，否则起不来** |

> ★★ **语法坑**：**v2.x 是 `ctrsmt=off` / `ctrsmt=full`（等号形式）**，
> 而 **v1.x 的 `-ctrsmt` 是另一回事**（等价于 v2.x 的 `ctrsmt=full`）。抄旧帖的 `-ctrsmt` 到 v2.x 上不会报错，但**不生效**。
> ⇒ **先看自己装的 kext 版本号**（`CFBundleVersion`；本文写作时为 **2.0.2**）。

### 4.3 ★★ 已知冲突：与 `-v` 冲突

官方 README 的 *Current problems* 明写：

> *"May cause random boot failure with verbose (`-v`) boot"*

⇒ **开小核 + `-v` 有概率随机启动失败**。而排查阶段通常**必须开 `-v`**（否则看不见卡在哪）
⇒ **要么先关小核，要么临时去掉 `-v`**，别把随机失败误判成配置坏了。
（另注：`ProvideCurrentCpuInfo` 本身在 High Sierra 及更早无效，那时用官方的 `patches_legacy.plist` 替代。）

### 4.4 拓扑对照（官方 README 原表，摘 12700K）

| CPU | 配置 | 原始 | `ctrsmt=off` | **默认（不写）** |
|---|---|---|---|---|
| **i7-12700K** | **8P+4E+HT** | 20c20t | 12c20t | **8c20t** |
| i7-12700K | 8P+4E（关 HT） | 12c12t | 8c12t | 8c12t |
| i9-12900K | 8P+8E+HT | 24c24t | 16c24t | 8c24t |
| i9-13900K | 8P+16E+HT | 32c32t | 24c32t | 8c32t |

★ **读法**：默认那一列把 20 线程**全挂在 8 个 P 核上**（「8c20t」），E 核不单独出现 ——
这就是「伪装成 SMT」的意思；`ctrsmt=off` 才是「12 核 20 线程」的真实结构。

## 5. 验证（改完重启后）

1. `scripts/e-cores-check.sh` —— 记录数量与 CTR 状态；已确认目标预期时加 `--expected-threads N`。不以 Intel 的 perflevel 数量判断 E 核。
2. **`kextstat` / `kmutil showloaded`** 里应有 `org.b00t0x.CpuTopologyRebuild`，且**在 Lilu 之后**。
3. **`ocvalidate` = No issues found**（改过 `Kernel>Add` 必跑）。
4. **跑分对照**：Geekbench 单核 / 多核，与「关小核」时的基线**同机对比**（别跨机器比，见 §7.3）。
5. 使用 `scripts/cpu-freq-probe.sh` 等目标系统支持的工具，在相同负载下与修改前基线比较。
   频率或耗时变差时同时检查温度、功耗与拓扑，必要时回退，不把单次变化直接认定为 XCPM 冲突。

## 6. 回滚（三条，任选一条即可）

1. **最快**：BIOS 把 `Active Efficient Cores` 设回 **`0`** —— **配置一行都不用改**。
2. **只想去掉 kext**：`CpuTopologyRebuild` 条目设 **`Enabled=false`**（或删条目 + 移走 kext，保持文件与配置引用一致）。
3. **起不来**：拷回备份的 config（`scripts/oc-edit-safe.sh` 的存档）+ U 盘 EFI 救援。

## 7. 实测与取舍

### 7.1 关小核时的现状（实测）

- 当时 macOS 报 **8 核 16 线程**：`hw.ncpu=16`、`hw.physicalcpu=8`；`hw.nperflevels=1` 只是 x86 的 SMP 读数，不是关小核证据。
  `CPUID.1FH` 曾报 20 个逻辑处理器；该记录与 OS 数量需要结合当时 BIOS 状态核实，不能仅凭它判断当前活动 E 核。
- `CpuTopologyRebuild` 当时在 `Kernel>Add` 里但 **`Enabled=false`** ⇒ 官方所说「配合 `ProvideCurrentCpuInfo`」的收益拿不到。

### 7.2 ★ 为什么「关掉」也可能是对的

- Alder Lake 在 macOS 上**调度 E 核本就是雷区**（内核没有完整的混合调度支持）；
- 「多 4 个核」不等于「快 4 核」—— 若内核把 E 核当 P 核派活，单线程 / 时延敏感任务反而变慢；
- 因此按用户目标与同机证据选择，不默认替用户关闭小核。若使用 CTR，另核实 §4.3 的已知冲突。

### 7.3 榜上对照（**有局限，别当铁证**）

Geekbench 7 官网同 CPU（i7-12700K，`Family 6 Model 151 Stepping 2`）榜：

| 平台 | 线程 | 单核 | 多核 |
|---|---|---|---|
| macOS（**关小核**）4 条 | 16 | 941–980 | 5132–5714 |
| macOS（**开小核**）1 条 | 20 | **1393** | **7672** |
| Windows 12 条 | — | 2007–2351 | 7761–17781 |
| Linux 4 条 | — | 2162–2540 | 10330–19535 |

- 开小核那条比关小核高 **+47% 单核 / +37% 多核**；逐项对比里 **`HTML5 Browser` 与 `PDF Viewer` 恰好 2.0x**
  —— 这两项框架密集、会派生辅助线程，**与「多 4 个 E 核可用」一致**。
- ★ **局限**：只有 **1 条**开小核样本、且**不是本机**；跨平台比「分数」会被内存 / OS / 版本污染
  （Windows 那条是 DDR5 四通道，本机 DDR4 双通道）⇒ **只作方向性参考，最终以本机 A/B 为准**。
- ★ 这条数据**推翻了早先「小核已关 ⇒ `CpuTopologyRebuild` 是 no-op」的推论**（当时无实测）。

### 7.4 「开小核」的落地状态（示例）

- 已做：从 `_kexts-removed-20261014/` 拷回 `CpuTopologyRebuild.kext`（v2.0.2）到 `EFI/OC/Kexts/`；
  `Kernel>Add` 插入条目 `Enabled=true`、**紧跟 Lilu**（index 1）；`ProvideCurrentCpuInfo` 保持 `true`。
  校验：`plutil` OK · **`ocvalidate` 1.0.8 = No issues found** · 语义 diff 仅 1 处（Add 19→20）· 卸载重挂 sha 一致。
- **待做（BIOS，只能人工）**：`Active Efficient Cores = All` → F10。
- **可选的下一步**：默认拓扑不理想时再加 **`ctrsmt=full`**（**一次只加一个变量**，便于归因）。

## 8. 官方出处

- `b00t0x/CpuTopologyRebuild` → `README.md`（Usage / Options 表 / Internal topology examples / Current problems）。
- OpenCore `Configuration.pdf` → `Kernel > Quirks > ProvideCurrentCpuInfo`。
- ★ 生态与工具索引另见 `ecosystem-sources.md`；CPU 限频 / 睿频另见 `intel-turbo.md`；
  BIOS 项命名对照另见 `bios-settings.md` §8。
