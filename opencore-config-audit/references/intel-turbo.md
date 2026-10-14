# Intel 睿频（Turbo Boost）—— 修「CPU 被压在低频」

> 依据：本机 10-13 的实战闭环（**CPU-S + Intel Power Gadget 观测 → 排除 → 定位 → CPUFriend 修复 → 重启验证**）
> + CPUFriend 官方 `Instructions.md` / `Tools/ResourceConverter.sh`。
> ★ **验证工具用 CPU-S**（用户指定），配合 Power Gadget 与自写探针交叉印证。

## 0. 一句话

macOS 的 CPU 频率由**机型 profile 里的 `FrequencyVectors`** 加上 HWP/XCPM 机制决定。
**机型选错**（profile 表不适合这颗 CPU）会把 CPU 压在低频 —— 本机曾被压在 **~2.3 GHz（低于基础频率 3.6，只有约一半性能）**，
表现为「反应慢 / 掉帧」；用 **CPUFriend + CPUFriendDataProvider** 注入一份合适的 profile 数据后恢复到 **~4.2 GHz**。

## 1. 先确认现象（三种工具互相印证）

| 工具 | 看什么 | 本机实测（修复前） |
|---|---|---|
| **★ CPU-S**（社区工具，本机用 v4.3.2） | `设备型号` / `处理器型号` / **`当前睿频状态`** / 频档数量 / 测得频率列表 | `MacPro7,1` / `12thGen i7-12700K` / **`未睿频`** / 10 档 / 只测到 `100 / 700–1500 MHz` |
| Intel Power Gadget | CORE `MAX/AVG/MIN/REQ`、PKG 功耗、温度 | `MAX 3.9 / AVG 2.25 / MIN 0.7 / REQ 2.97 GHz`；PKG 58 W；50 ℃ |
| 自写探针（本机 `cpu-freq-probe.sh`） | 单线程 / 8 线程实测频率 | 单线程 2.24–2.54、8 线程 2.2–2.3 GHz |

**CPU-S 的读法**：最关键是 **「当前睿频状态」** —— 显示 **未睿频**、且频率列表只到 1.5 GHz 就是被限频；
修好后应显示**已睿频**，且频率列表覆盖到高倍频档。

**参考基线（i7-12700K）**：单核睿频 **5.0 GHz** / 全核约 **4.7 GHz** / 基础频率 **3.6 GHz**
⇒ 测到 2.3 GHz 意味着**连基础频率都没跑到**，约一半性能。

> ★ **自写基准的坑**：clang `-O2` 会把展开的依赖加法律**折叠**（曾算出 8.34 / 11.03 GHz 的荒谬值）。
> 要测频率必须用**内联汇编钉住**（`cpu-freq-probe.sh` 用的就是 `mulsd` 固定 4 周期延迟的依赖链）。

## 2. 先排除，别急着上 CPUFriend

| 项 | 判据 |
|---|---|
| 热降频 | `sysctl machdep.xcpm.cpu_thermal_level` 应为 **0**（本机 cpu/gpu/io 全 0，温度 39–55 ℃ 很凉） |
| XCPM 上限被限 | `machdep.xcpm.hard_plimit_max_100mhz_ratio` / `soft_...` / `bootpst`（本机 = **49** ⇒ 4.9 GHz，正常） |
| 日志风暴 / 后台负载 | `uptime`、`iostat`、`vm_stat`（★ 本机 `ps` / `top` 被策略禁用，只能换这些） |
| 只是刚开机 | 先看是否只发生在前 10–15 分钟 |

## 3. 定位根因：机型 profile 的 `FrequencyVectors` + `hwp`

profile 来自 **`X86PlatformPlugin.kext/Contents/Resources/Mac-<board-id>.plist`**。

本机的对比法（同一台机器换机型 A/B，是决定性判据）：

| | `MacPro7,1` | `iMacPro1,1` |
|---|---|---|
| `hwp` 变量 | **on（强制 HWP）** | off（走传统 XCPM P-state 路径） |
| `FrequencyVectors` 首部 u32 | `[2,20,1,0,1000,0,200,0]` | `[2,0,2,0,100,0,25,0]` |
| 实测结果 | CPU 卡在 **2.3–2.5 GHz** | 流畅 |

- ⇒ **唯一与「流畅 ↔ 卡顿」完全对应的差异是 `hwp` 变量**
- 而 HWP 正是先前 panic（`xcpm_hwp_enable` 里的 `wrmsr(0x770,1)`）的同一机制 ⇒ **推断：`MacPro7,1` 的 `hwp=on` + 该表在 Alder Lake 上工作不良 ⇒ 卡在低频**
- **★ 格式已解出**：`FrequencyVectors` 是 `xcpmio_vectors_t` 的**紧凑（packed）序列化，总长恒为 7668 字节**
  ⇒ 可用它**校验注入数据有没有被截断**

## 4. 修法：CPUFriend + CPUFriendDataProvider（官方机制）

1. **取一个合适机型的 profile plist**（本机用 **iMacPro1,1** 的完整 plist）
2. 用 CPUFriend 官方的 **`Tools/ResourceConverter.sh`** 生成 `CPUFriendDataProvider.kext`：
   - 把**整个机型 plist 做 base64** 塞进 `IOKitPersonalities/CPUFriendDataProvider/cf-frequency-data`
   - 另需：`IOClass=AppleACPICPU`、`IONameMatch=processor`、`IOProbeScore=1100`、`OSBundleRequired=Root`
   - ★ **`ExecutablePath` 必须为空**
3. `Kernel → Add` 加两条，**顺序：Lilu → CPUFriend → CPUFriendDataProvider → VirtualSMC**
   - ★ **`CPUFriend.kext` 必须排在 `Lilu.kext` 之后**（它是 Lilu 插件）
4. ★ **`ocvalidate` 对 `Kernel>Add>Comment` 有字符限制**：
   `iMacPro1,1 ... (no HWP) ~2.3GHz` 会被判 `illegal character`（逗号 / 括号 / 波浪号至少其一）
   ⇒ 注释只留 **字母数字、空格、连字符、点号**
5. 校验：`FrequencyVectors` 解回应为 **7668 B**；`ocvalidate` = No issues found；卸载重挂后 sha 一致

## 5. 验证（重启后）

- **★ CPU-S**：`当前睿频状态` 应从「未睿频」变成**已睿频**，频率列表覆盖到高倍频
- 本机实测对比：

| | 修复前 | 修复后 |
|---|---|---|
| 单线程 | 2.24–2.54 GHz | **3.90 → 4.15 GHz（+65%）** |
| 8 线程全核 | 2.2–2.3 GHz | **4.18–4.20 GHz（+85%）** |
| 相对 12700K 单核睿频 5.0 | ~46% | **88%** |

- ★★ **比数值更重要的改善**：修复前 8 个核频率**忽高忽低（低频档 ↔ 满频振荡）**；
  修复后 **8 核高度一致（4.18–4.20）**，振荡消失 —— **这才是「卡顿 / 掉帧」的直接来源**
- 同时复查：机型没变、`Processor Name` 正确、`CPUFriend (1.3.0)` 已加载且在 Lilu 之后、**无新 panic**、
  `machdep.xcpm.mode=1`、`hard_plimit_max=49`

## 6. 还想追满频（4.2 → 4.7 GHz）？

- 剩余差距可能是 **功耗墙 PL1/PL2** 或**注入 profile 的上限**
- 可试把数据换成 **iMac20,1（Comet Lake 桌面；percent 13-22-31-40-100、vars 最全）** 再测
- ★ **官方立场**：CPUFriend `Instructions.md` 明确警告「**不确定就别用 CPUFriend**」、
  「**能通过改 SMBIOS 解决通常更合理**」⇒ 本机已无卡顿，**不建议继续叠加风险**

## 7. ★ 硬前提：BIOS 的 Speed Shift 必须开

`Intel(R) Speed Shift Technology` **必须 `Enabled`**（**`Auto` 也可能等效关闭**）：

```
HWP 不可用 ⇒ wrmsr(0x770,1) 触发 #GP ⇒ xcpm_hwp_enable 崩（panic type 13）
```

本机 10-13 有过两次「SpeedShift 又被关过」导致的 panic
⇒ **遇到 `X86PlatformShim` / `xcpm_hwp_enable` 相关 panic，第一件事查 BIOS 这一项**。

## 8. 本机现状与回退

- **生效配置** = `config.plist.v16-MacPro71-CPUFriend`（sha `dd4515ef…`）：机型 `MacPro7,1` +
  `CPUFriend 1.3.0` + `CPUFriendDataProvider`（数据 = **iMacPro1,1 完整 plist**，15283 B，逐字节一致）
- **kext 与源 plist 备份**：`xh_adls3修复-20261013/CPUFriend-kexts/`
  （`CPUFriend.kext` / `CPUFriendDataProvider.kext` / `src-iMacPro11.plist`）
- **探针脚本**：`cpu-freq-probe.sh`（本机 3.5–4.3 GHz 属正常）
- **回退** = 回到 `config.plist.v14-MacPro71-pci-slots-cpuname`，并把两条 CPUFriend 条目设 `Enabled=false`
- 另注：系统只认 **8 核 / 16 线程**（12700K 满配 12C/20T）⇒ **E-core 未暴露**（BIOS 里关着）。
  ★ **这属于「开小核 / 关小核」的取舍，不是限频问题** ⇒ 详见 **`e-cores.md`**（含 `CpuTopologyRebuild` 用法与 `-v` 冲突）。
  历史上 `CpuTopologyRebuild.kext` 在 `Kernel>Add` 里但 `Enabled=false`（10-15 已改为启用，待 BIOS 配合）。
