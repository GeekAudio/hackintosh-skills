# 开小核 / 关小核（Intel 混合架构：P 核 / E 核）

> 依据：**`CpuTopologyRebuild` 官方 README**（`b00t0x/CpuTopologyRebuild`，逐条引用，见 §8）
> + **本机 10-15 实测**（`ProvideCurrentCpuInfo` 行为、BIOS 项名、Geekbench 7 官网同 CPU 榜对照）。
> ★ **先说结论**：**「关小核」和「开小核」是两种取舍，不是谁对谁错** ——
> **关掉最稳**（macOS 本来也调度不好 E 核，关掉几乎不损失）；**开着多 4 核 4 线程**（但要靠 `CpuTopologyRebuild`
> 收拾拓扑，且官方明写**与 `-v` 有冲突**，见 §4.3）。

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
sysctl -n hw.ncpu hw.physicalcpu hw.logicalcpu        # 16 = 只有 P 核；20 = P+E 都暴露
sysctl -n hw.nperflevels                              # 1 = 只有一种核；2 = P/E 两级都识别
sysctl -n hw.perflevel0.physicalcpu                   # P 核数（示例：8）
sysctl -n hw.perflevel1.physicalcpu                   # E 核数（示例：4；关小核时该键不存在）
sysctl -n machdep.cpu.core_count                      # 见 §4.2 的 -ctrfixcnt
```

`scripts/e-cores-check.sh` 一次跑完上面全部，并给判读。

| `hw.nperflevels` | `hw.ncpu` | 含义 |
|---|---|---|
| **1** | 16 | macOS 只看到一种核 ⇒ **E 核没暴露**（BIOS 关着，或 `ProvideCurrentCpuInfo=false`） |
| 2 | 20 | P / E 两级都识别 ⇒ **小核已开**（再往下看拓扑重建成什么样） |

★ **`hw.nperflevels=1` 时不要急着「修」** —— 见 §7，那可能是**刻意选的稳定态**（本机就选了这一档）。

## 2. 关小核（推荐给「求稳 / 不想折腾」）

**唯一可靠的做法是在 BIOS 层关**（macOS 侧没有「隐藏 E 核」的开关）：

| 厂商 | 位置 / 名字 |
|---|---|
| **ASUS** | `Advanced > CPU Configuration > **Active Efficient Cores**` → 设 **`0`** |
| MSI | `OC → Advanced CPU Configuration → **E-Core Count**`（或 `Active E-Cores`）→ `0` |
| Gigabyte | `Settings > Advanced CPU Settings → **E-Core Count**` → `0` |
| ASRock | `Advanced → CPU Configuration → **Active E Cores**` → `0` |

- **配置侧不用动**：`ProvideCurrentCpuInfo` 保持原样即可；`CpuTopologyRebuild` 留 `Enabled=false`（或删条目）。
- **收益**：Alder Lake 在 macOS 上调度 E 核本就是雷区（§7.2），关掉**几乎不损失性能**（macOS 本来也用不满）。
- **代价**：少 4 核 / 少 4 线程 —— 但**如果原本就没被用上，关掉等于零代价**。
- ★ **硬前提不动**：`Active Performance Cores` = `All`、`Hyper-Threading` = `Enabled`、
  **`Intel Speed Shift Technology` 保持 `Enabled`**（关它会 `wrmsr(0x770,1)` #GP panic，见 `intel-turbo.md` §7）。

## 3. 开小核（求性能 / 愿意收拾拓扑）

三件事，按顺序：

1. **BIOS**：`Active Efficient Cores` → **`All`**（厂商命名见 §2 表）。
2. **config**：`Kernel > Quirks > **ProvideCurrentCpuInfo = true**`（**必需** —— 官方 README 明写
   Alder Lake / Raptor Lake 要配合这个 quirk；Arrow Lake 才不需要）。
3. **可选但推荐**：`Kernel > Add` 加 **`CpuTopologyRebuild.kext`**，**紧跟 `Lilu` 之后**
   （它是 Lilu 插件，`OSBundleLibraries` 要求 `as.vit9696.Lilu ≥ 1.2.0`）⇒ 顺序 `Lilu → CpuTopologyRebuild → …`。

重启后应看到 `hw.nperflevels=2`、`hw.ncpu=20`、`perflevel1.physicalcpu=4`（§1）。

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

1. `scripts/e-cores-check.sh` —— 拓扑 + 频率 + 判读（**重点看 `hw.nperflevels` 是否变 2**）。
2. **`kextstat` / `kmutil showloaded`** 里应有 `org.b00t0x.CpuTopologyRebuild`，且**在 Lilu 之后**。
3. **`ocvalidate` = No issues found**（改过 `Kernel>Add` 必跑）。
4. **跑分对照**：Geekbench 单核 / 多核，与「关小核」时的基线**同机对比**（别跨机器比，见 §7.3）。
5. ★ **频率别掉**：`scripts/cpu-freq-probe.sh` —— 基线单线程 ≈ 4.28、8 线程 ≈ 4.29–4.35 GHz；
   若开小核后频率掉了，说明拓扑重建与 XCPM 打架，回滚。

## 6. 回滚（三条，任选一条即可）

1. **最快**：BIOS 把 `Active Efficient Cores` 设回 **`0`** —— **配置一行都不用改**。
2. **只想去掉 kext**：`CpuTopologyRebuild` 条目设 **`Enabled=false`**（或删条目 + 移走 kext，见铁律 6）。
3. **起不来**：拷回备份的 config（`scripts/oc-edit-safe.sh` 的存档）+ U 盘 EFI 救援。

## 7. 实测与取舍

### 7.1 关小核时的现状（实测）

- macOS 只见 **8 核 16 线程**：`hw.ncpu=16`、`hw.nperflevels=1`、`hw.perflevel0.physicalcpu=8`；
  而 `CPUID.1FH` 报**逻辑处理器 20**（sub0 SMT=2 / sub1 Core 级=20，无 Module/Tile 级）⇒ **E 核在硅片上存在，只是没喂给 macOS**。
- `CpuTopologyRebuild` 当时在 `Kernel>Add` 里但 **`Enabled=false`** ⇒ 官方所说「配合 `ProvideCurrentCpuInfo`」的收益拿不到。

### 7.2 ★ 为什么「关掉」也可能是对的

- Alder Lake 在 macOS 上**调度 E 核本就是雷区**（内核没有完整的混合调度支持）；
- 「多 4 个核」不等于「快 4 核」—— 若内核把 E 核当 P 核派活，单线程 / 时延敏感任务反而变慢；
- ⇒ **关掉是「低风险默认」**；要开就必须连 `CpuTopologyRebuild` 一起上，并且接受 §4.3 的 `-v` 冲突。

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
- **可选的下一步**：默认拓扑不理想时再加 **`ctrsmt=full`**（**一次只加一个变量**，见铁律 5）。

## 8. 官方出处

- `b00t0x/CpuTopologyRebuild` → `README.md`（Usage / Options 表 / Internal topology examples / Current problems）。
- OpenCore `Configuration.pdf` → `Kernel > Quirks > ProvideCurrentCpuInfo`。
- ★ 生态与工具索引另见 `ecosystem-sources.md`；CPU 限频 / 睿频另见 `intel-turbo.md`；
  BIOS 项命名对照另见 `bios-settings.md` §8。
