# Intel 睿频（Turbo Boost）诊断与调优案例

> 依据：一次完整实战闭环（**诊断 → 排除 → CPUFriend 修复 → 全量机型 profile 对比 →
> iMac19,1 实验翻车回滚 → 最终定案**）+ CPUFriend 官方 `Instructions.md` / `Tools/ResourceConverter.sh`
> + `X86PlatformPlugin` 全部 76 份 `Mac-*.plist` 的实测解码。
> 案例使用 CPU-S、Intel Power Gadget 与自写探针交叉印证；工具选择按目标 CPU、系统支持和用户偏好决定。

## 0. 先诊断，再评估是否需要 CPUFriend

[CPUFriend 官方说明](https://github.com/acidanthera/CPUFriend/blob/master/Instructions.md) 提醒：不清楚是否需要时通常无需使用 CPUFriend，原生电源数据多能工作。先按 §1–2 确认限频现象、温度、功耗及当前注入，再评估是否修改。

下面是参考机器对自有 profile 删除 `hwp` 的一次实验结果，不是所有 CPU / SMBIOS 的推荐配置；不要直接套用数值或删除该项。

| 项 | 该案例的值 |
|---|---|
| 注入的数据 | **你自己机型那份 profile**（例：`iMac20,1` ⇒ `Mac-CFF7D910A743CAAF.plist`），**只把 `hwp` 一项删掉** |
| `FrequencyVectors` 段数 | **1 段**（每段恒 7668 B） |
| `Frequencies` 上限 | `4500`（**1 段族的天花板**） |
| `CPUFloor` | 按自己 CPU 的最低档设（例：i7-12700K 用 `1300`） |
| **`hwp`** | **已删除** ← ★★ **最关键的一项** |
| 实测频率 | 单线程 **4.28–4.35 GHz**；8 线程 **4.29–4.35 GHz**，八核一致、无振荡 |

这些参数只说明该案例如何验收。目标机器应以自身基线、稳定性、负载频率与功耗验证，不能用这组参数定义通用「最佳」。

### 0.1 跨机型 profile 的实验结果（示例）

参考机器测试了以下两份其他机型的 profile，均出现性能下降；不能据此推断所有跨机型 profile 都有相同结果：

| 试过的 | 结果 |
|---|---|
| `iMac19,1`（上限 5000，看着诱人） | **1.97 GHz**（暴跌 ~54%，比历史最低还低）⇒ 已回滚 |
| `MacPro7,1`（原生 `hwp='on'`） | **2.3 GHz**（约一半性能） |

⇒ **电源管理 profile 这类改动，默认不动** —— 除非你有明确的判据说明现在这份是错的。
（上表是一次实测的结果，你自己的机器要自己测一遍，别拿这些数字当结论。）

官方 `Instructions.md` 的警告是对的（**原话**）：

> *"most likely NOT required"*
> *"Do not use CPUFriend for data customization until one knows clearly what power management data really is"*
> *"If possible, changing SMBIOS … can be more reasonable"*

## 1. 先确认现象（三种工具互相印证）

| 工具 | 看什么 | 实测（修复前，示例） |
|---|---|---|
| **★ CPU-S**（社区工具，v4.3.2） | `设备型号` / `处理器型号` / **`当前睿频状态`** / 频档数量 / 测得频率列表 | `MacPro7,1` / `12thGen i7-12700K` / **`未睿频`** / 10 档 / 只测到 `100 / 700–1500 MHz` |
| Intel Power Gadget | CORE `MAX/AVG/MIN/REQ`、PKG 功耗、温度 | `MAX 3.9 / AVG 2.25 / MIN 0.7 / REQ 2.97 GHz`；PKG 58 W；50 ℃ |
| 自写探针（`scripts/cpu-freq-probe.sh`） | 单线程 / 8 线程实测频率 | 单线程 2.24–2.54、8 线程 2.2–2.3 GHz |

**CPU-S 的读法**：最关键是 **「当前睿频状态」** —— 显示 **未睿频**、且频率列表只到 1.5 GHz 就是被限频；
修好后应显示**已睿频**，且频率列表覆盖到高倍频档。

**参考基线（i7-12700K）**：单核睿频 **5.0 GHz** / 全核约 **4.7 GHz** / 基础频率 **3.6 GHz**
⇒ 测到 2.3 GHz 意味着**连基础频率都没跑到**，约一半性能。

> ★ **自写基准的坑**：clang `-O2` 会把展开的依赖加法律**折叠**（曾算出 8.34 / 11.03 GHz 的荒谬值）。
> 要测频率必须用**内联汇编钉住**（`cpu-freq-probe.sh` 用的就是 `mulsd` 固定 4 周期延迟的依赖链）。

## 2. 先排除，别急着动 profile

| 项 | 判据 |
|---|---|
| 热降频 | `sysctl machdep.xcpm.cpu_thermal_level` 应为 **0**（三项全 0、温度不高即为正常） |
| XCPM 上限被限 | `machdep.xcpm.hard_plimit_max_100mhz_ratio` / `soft_...` / `bootpst`（**按自己的 CPU 算**：值 ×100 MHz = 上限；例 i7-12700K 为 `49` ⇒ 4.9 GHz） |
| 日志风暴 / 后台负载 | `uptime`、`iostat`、`vm_stat`（★ 若 `ps` / `top` 被环境策略禁用，用这三个替代） |
| 只是刚开机 | 先看是否只发生在前 10–15 分钟 |
| ★★ **改了 profile 但没重启** | 见 §7 —— **最常见的「修了没好」** |

## 3. 定位根因：机型 profile 的 `FrequencyVectors` + `hwp`

profile 来自 **`X86PlatformPlugin.kext/Contents/Resources/Mac-<board-id>.plist`**（数量随 macOS 版本变，某个版本里是 **76 份**，
去重后 **62 份不同数据**）。

**★ 全部差异只有 5 个维度**：

| 维度 | 说明 |
|---|---|
| `pmspFile` | 1–16，插件内部的索引 |
| `CPUFloor` | 1300 / 1200 / 1000 / 800 / 无 |
| `Frequencies` | 档位表，**值 = 段索引**（不是 MHz 表本身） |
| `FrequencyVectors` | **每段恒 7668 B**；**段数 = 复杂度** |
| **`hwp`** | ★★ **打包在向量二进制内部**，**不是 plist 键** ⇒ `plutil` / `PlistBuddy` 搜不到（见 §4） |

格式：`FrequencyVectors` 是 `xcpmio_vectors_t` 的**紧凑（packed）序列化**
⇒ 可用「解回应为 **7668 B/段**」来**校验注入数据有没有被截断**。

> ⚠️ **两个解析坑**（都踩过）：
> ① `FrequencyVectors` 的值是 **bytes 对象的 list**（`[b'\x02\x00…']`），**不是单个 bytes**
> ⇒ 判「没有 FrequencyVectors」多半是脚本写错了；
> ② `hwp` **不是 plist 键**，在 76 份 plist 里 `grep hwp` **命中 0 处** —— 别因此以为它不存在。

## 4. ★★★ `hwp` 的真实位置与删除方法（最关键的一步）

`hwp` **不在 plist 里**，而在 **7668 B 向量二进制内偏移 ~7128 的「变量名表」里**，形如

```
… io_core_cst_lim … hwp "on" …
```

- **禁用方法 = 删除这一项**（不是改名！改名会留字符串、长度也变）；删掉后**其后所有项前移**。
- 改好那份：比原生段少 **7128–7544 共 165 字节**，段内 `hwp` 出现次数 **1 → 0**，
  原生段从 `hwp` 开始、现装那份直接从 `io_core_cst_lim` 开始。
- **这就是标准 CPUFriend 用法**：注入「删掉 `hwp` 的同机型 profile」覆盖系统自带的那份，
  **强制 macOS 走传统 XCPM P-state 而不是 HWP** ⇒ 实测单线程 4.33 GHz 就是它带来的。

> ★★ **判「这份 DataProvider 有没有作用」必须逐字节比向量二进制** ——
> 只比 `pmspFile` / `Frequencies` / 段数 / plist 键就下结论会**判错**
> （曾因此误判成「no-op」，后来逐字节比对才订正）。

## 5. ★ 选型决策：76 份 profile 的五族（换机器时照此挑）

**第一分水岭 = 段数**：

| 族 | 特征 | 份数 | 实测结果 |
|---|---|---|---|
| **A** | 无档位 + **1 段** + 无 `hwp` | 25（`iMacPro1,1`） | **4.28–4.35 GHz ✓** |
| **B** | 无档位 + **1 段** + **有 `hwp`** | 2（`MacPro7,1`） | **2.3 GHz ✗** |
| **C** | 有档位 + **1 段** | 5（`iMac20,1` / `20,2`，上限 4500） | **4.33 GHz ✓（i7-12700K 实测）** |
| **D** | 有档位 + **多段（2–5）** | 32（`iMac19,1` 4 段、MBP 全系） | **1.97 GHz ✗ 实测翻车** |
| **E** | **0 段** | 12 | 无向量，不可用 |

**★ 两条由天然对照得出的因果**（不是推测）：

- **`iMacPro1,1` vs `MacPro7,1` 只差 `hwp` 一项**（其余键 / 段数 / `pmspFile` / `CPUFloor` 全同）
  ⇒ 无 `hwp` = 4.3 GHz，有 `hwp` = 2.3 GHz —— **`hwp` 的作用被单独孤立出来**。
- **`iMac19,1` vs `iMac20,1` 只差「4 段 vs 1 段」**（键集 / `CPUFloor` / `hwp` 全同）
  ⇒ **崩溃真因 = 多段 CFL 向量表，不是 `hwp`**（订正：此前把锅往 `hwp` 上引是错的）。

**★★ 结构性死路**：**所有上限 5000 的 profile 都是 3–5 段，没有 1 段的**
⇒ **「抬上限到 5000」与「结构兼容」在这类机器上不可兼得**。
⇒ **1 段族的天花板就是 4500**，1 段族机型已到顶；**想再榨，没有 profile 可用**。

## 6. 修法：CPUFriend + CPUFriendDataProvider（官方机制）

1. **取 profile plist**：默认应取**你自己机型那份**（`Mac-<你的 board-id>.plist`），
   再用官方 `Tools/ResourceConverter.sh` 生成 `CPUFriendDataProvider.kext`：
   - 把**整个机型 plist 做 base64** 塞进 `IOKitPersonalities/CPUFriendDataProvider/cf-frequency-data`
   - 另需：`IOClass=AppleACPICPU`、`IONameMatch=processor`、`IOProbeScore=1100`、`OSBundleRequired=Root`
   - ★ **`ExecutablePath` 必须为空**
   - ★ 官方 `Instructions.md`：`cf-frequency-data` 里放的是 **complete plist**（不是裸 `FrequencyVectors`）
2. **★ 删掉 `hwp`**（§4）—— 这是一台机器有别于「什么都不做」的关键一步
3. `Kernel → Add` 加两条，**顺序：Lilu → CPUFriend → CPUFriendDataProvider → VirtualSMC**
   - ★ **`CPUFriend.kext` 必须排在 `Lilu.kext` 之后**（它是 Lilu 插件）
4. ★ **`ocvalidate` 对 `Kernel>Add>Comment` 有字符限制**：
   `iMacPro1,1 ... (no HWP) ~2.3GHz` 会被判 `illegal character`（逗号 / 括号 / 波浪号至少其一）
   ⇒ 注释只留 **字母数字、空格、连字符、点号**
5. 校验：`FrequencyVectors` 解回应为 **7668 B/段**；`ocvalidate` = No issues found；卸载重挂后 sha 一致

> **最小改动技巧**：想试另一份 profile 时，**复制现用的 `Info.plist`，只替换 `cf-frequency-data`**
> ⇒ diff 只有一处，回滚直接拷回文件即可。

## 7. ★★ 改完必须重启（「修了没好」的头号原因）

- profile 是**开机时读进内存**的 ⇒ **不重启，内存里跑的仍是旧的那份**。
- 踩过：回滚到正确值之后一直没重启，实测单线程仍是 **2.22 GHz**（应 4.28–4.33）
  ⇒ **ESP 上早就是正确值，修法只是「重启」**。
- **判据**：`sysctl -n kern.boottime` —— **比你的改动时间还早 ⇒ 没重启**。
- ★ 顺带一条实证：**即使「卸载重挂复验 sha」失败，ESP 写入仍会落盘**
  （有害 profile 那次 sha 确为候选值，证明写进去了）⇒ **别拿「没复验成功」当「没写进去」**。

## 8. 验证（重启后）

- **★ CPU-S**：`当前睿频状态` 应从「未睿频」变成**已睿频**，频率列表覆盖到高倍频
- **探针**：`scripts/cpu-freq-probe.sh` —— 参考基线（i7-12700K）**单线程 4.28 / 8 线程 4.29–4.35 GHz**，
  且**八核高度一致、无振荡**
- **比数值更重要的改善**：修复前 8 个核频率**忽高忽低（低频档 ↔ 满频振荡）**；
  修复后 **8 核一致**，振荡消失 —— **这才是「卡顿 / 掉帧」的直接来源**
- 同时复查：机型没变、`Processor Name` 正确、`CPUFriend (1.3.0)` 已加载且在 Lilu 之后、**无新 panic**、
  `machdep.xcpm.mode=1`、`hard_plimit_max=49`
- **换了机型且已使用 DataProvider ⇒ 重新核对其来源与适用性**；需要时重建，未使用 CPUFriend 的机器不因此新增它

## 9. 还想追满频（4.3 → 5.0 GHz）？

**此路不通，别再花时间**（§0.1 + §5）：

- 剩余差距不是 profile 上限能解释的 —— `hard_plimit_max = 49`（4.9 GHz）本就没锁，
  说明 **`Frequencies` 未必是真正的频率天花板**；换 profile 的收益**未被证实**且**风险已实测**。
- 真正的原因更可能是 **功耗墙 PL1/PL2** 或 **OS 侧差异**：
  同 CPU 在 macOS 上普遍比 Windows / Linux 低约 **2.4×**（Geekbench 7 官网榜同 `Family 6 Model 151` 对照）
  ⇒ **差距在 OS 侧，不在硅片，也不在 CPUFriend**。
- ★ 官方立场明确：**「不确定就别用 CPUFriend」**，若已无卡顿 ⇒ **不建议继续叠加风险**。

## 10. ★ 硬前提：BIOS 的 Speed Shift 必须开

`Intel(R) Speed Shift Technology` **必须 `Enabled`**（**`Auto` 也可能等效关闭**）：

```
HWP 不可用 ⇒ wrmsr(0x770,1) 触发 #GP ⇒ xcpm_hwp_enable 崩（panic type 13）
```

有过两次「SpeedShift 又被关过」导致的 panic
⇒ **遇到 `X86PlatformShim` / `xcpm_hwp_enable` 相关 panic，第一件事查 BIOS 这一项**。

> ★ **别混淆**：BIOS 里的 HWP（Speed Shift）**要开着**（否则 panic），
> 而 macOS 侧则**刻意不走 HWP**（走传统 XCPM P-state）
> ⇒ 组合 = **固件开 HWP + macOS 走传统 XCPM**，这是验证过的正确解，**不要去「修」**。

## 11. 现状与回退

- **该案例最终保留的配置**：`CPUFriend 1.3.0` + `CPUFriendDataProvider`
  （数据 = **`iMac20,1` 自己的 profile 且已删 `hwp`**），**sha `5952ea56…`**；
  现用备份 `_CPUFriendDataProvider-最佳-iMac20,1-已去hwp-20261015-172126/`
- **备用（免手工编辑）**：`iMacPro1,1` **原生无 `hwp`**（A 族），实测同样 4.28–4.35 GHz，
  可直接替换（`_CPUFriendDataProvider-iMacPro11-备用/`）
- **回退** = 把备份的 `Info.plist` 拷回 `EFI/OC/Kexts/CPUFriendDataProvider.kext/Contents/`（或 U 盘 EFI 救援）
- **探针脚本**：`scripts/cpu-freq-probe.sh`（i7-12700K 上 4.28–4.35 GHz 属正常）
- 小核（E 核）那一档是**另一件事** ⇒ `e-cores.md`
- ★ 排除 `CpuTopologyRebuild` 与 `-v` 的已知冲突后再判断「是不是 profile 改坏了」（`e-cores.md` §4.3）
