# BIOS / UEFI 设置审查

> ★ **更早一步**：**配机 / 换件之前**先看 `laobamac/SimpleBuyersGuide`《黑苹果硬件避坑指南》
> —— 明确列出**不应购买**的 CPU / GPU / 主板芯片组 / SSD / 网卡 / 无线卡等。索引见 `laobamac-toolkit.md` §3。

> **三个来源，优先级从高到低：**
> 1. **OpenCore 官方文档**（`Docs/Configuration.pdf` 的 troubleshooting 检查清单）—— 权威，但只列「会拦住引导」的项
> 2. **Dortania OpenCore Install Guide**（社区事实标准）—— 官方没写的它也写了，分 Intel / AMD
> 3. **社区实战补充**（VMD、Speed Shift 等）—— 官方**完全没提**，但踩到就装不上
>
> ⚠️ 三份都不完整，**要合起来看**。本文第 3 节把它们合并成「必须关 / 必须开 / 看情况」三类。

---

## 0. 先说方法：BIOS 审查怎么做

**不要**一上来就把 BIOS 所有选项翻一遍（几百项，且各厂商命名不同）。按这个顺序：

1. **先跑 Windows 审查脚本**（`scripts/bios-audit.ps1`）—— 它能在 Windows 里**直接判定**一批项，
   把「肯定有问题」的先挑出来，剩下的才需要人工进 BIOS 核
2. **进 BIOS 核「必须关/必须开」两类**（§3）—— 用 §7 的检查表逐条打勾
3. **BIOS 里找不到某项**时，看 §8 的厂商命名对照表（同一设置各家叫法不同）
4. **找不到、又确实需要**时 → 走 §5 的隐藏选项路线（UEFITool + IFR-Extractor），
   或用 §3 表里「对应的 OpenCore 兜底」那一列绕过

> ★ **判据优先级**：**BIOS 层能解决的一律在 BIOS 层解决**，别用 OpenCore 的 quirk 兜底。
> 官方原话（关于 CFG Lock）：*"this option should be avoided whenever possible"*（指 `AppleXcpmCfgLock`）。

---

## 1. 官方清单（OpenCorePkg `Configuration.pdf` 原文）

官方把它放在 troubleshooting 的检查清单里，**9 条**：

| # | 官方原文要点 | 方向 |
|---|---|---|
| 1 | Most up-to-date UEFI firmware | **升级固件** |
| 2 | `Fast Boot` and `Hardware Fast Boot` disabled | **关** |
| 3 | `Above 4G Decoding` or similar enabled —— ★ 但 **ASUS WS-X299-PRO** 上该选项会**起反效果、必须关**；其它主板未见此问题，出现「莫名其妙引导失败」时**第一个查它** | **开**（例外：关） |
| 4 | `DisableIoMapper` quirk enabled, **or** `VT-d` disabled in firmware, **or** ACPI DMAR deleted（三选一） | **关**（或 quirk 兜底） |
| 5 | No `slide` boot argument present | **别加** |
| 6 | `CFG Lock`（MSR `0xE2` write protection）disabled —— 详见 `ControlMsrE2` | **关** |
| 7 | `CSM`（Compatibility Support Module）disabled —— NVIDIA 6xx / AMD 2xx 及更老需先刷 GOP ROM | **关** |
| 8 | `EHCI/XHCI Hand-off` enabled —— **仅当**不拔 USB 设备就卡住引导时才需要 | **开**（条件） |
| 9 | `VT-x`、`Hyper Threading`、`Execute Disable Bit` enabled | **开** |
| 附 | 有时 `Thunderbolt`、`Intel SGX`、`Intel Platform Trust` 可能需要禁用 | **关**（按需） |

> 官方还提到：调试**睡眠**问题时，可临时关掉 Power Nap 与自动断电（`pmset` 三连），
> 但那是 macOS 侧、不是 BIOS。

---

## 2. Dortania 清单（社区事实标准，分平台）

### 2.1 Intel（桌面 / 笔记本 / HEDT 通用）

> 原文前置说明：*"Most of these options may not be present in your firmware, we recommend matching up as closely as possible but don't be too concerned if many of these options are not available in your BIOS"*

**Disable**

| 设置 | 备注（Dortania 原文） |
|---|---|
| Fast Boot | |
| Secure Boot | |
| Serial/COM Port | |
| Parallel Port | |
| VT-d | *"can be enabled if you set `DisableIoMapper` to YES"* |
| Compatibility Support Module (CSM) | ★ **"Must be off in most cases, GPU errors/stalls like `gIO` are common when this option is enabled"** |
| Thunderbolt | 安装期（未正确配置时 TB 会出问题） |
| Intel SGX | |
| Intel Platform Trust | |
| **CFG Lock (MSR 0xE2 write protection)** | ★★ **"This must be off, if you can't find the option then enable `AppleXcpmCfgLock` under Kernel → Quirks. Your hack will not boot with CFG-Lock enabled"** |

**Enable**

| 设置 | 备注 |
|---|---|
| VT-x | |
| **Above 4G Decoding** | ★ *"2020+ BIOS Notes: When enabling Above4G, Resizable BAR Support may become available on some Z490 and newer motherboards. Please ensure that `Booter → Quirks → ResizeAppleGpuBars` is set to `0` if this is enabled."* |
| Hyper-Threading | |
| Execute Disable Bit | |
| EHCI/XHCI Hand-off | |
| OS type: **Windows 8.1/10 UEFI Mode**（部分主板要选 **Other OS**） | |
| DVMT Pre-Allocated (iGPU Memory): **64MB 或更高** | 有核显时 |
| SATA Mode: **AHCI** | |

### 2.2 AMD（Zen）

**Disable**：Fast Boot、Secure Boot、Serial/COM Port、Parallel Port、**CSM**、**IOMMU**
> ★ 特殊：**3990X** 有 128 线程，macOS 内核只支持 64 ⇒ 必须**关超线程**（Dortania 明确建议）。

**Enable**：
- **Above 4G Decoding** —— ★ **"This must be on, if you can't find the option then add `npci=0x3000` to boot-args. Do not have both this option and npci enabled at the same time."**
  - ★ **Gigabyte/Aorus 或 ASRock 主板**：开它可能**弄坏某些驱动（如网卡）**或让**其它系统启动失败** ⇒ 那就关掉它、改用 `npci`
  - 2020+ 备注同 Intel（ReBAR 出现后 `ResizeAppleGpuBars=0`）
- EHCI/XHCI Hand-off
- OS type: Windows 8.1/10 UEFI Mode（或 Other OS）
- SATA Mode: AHCI

---

## 3. ★★ 合并后的三类清单（**这张表是核心**）

### 3.1 必须关闭

| 设置 | 为什么必须关 | 不关的后果 | OpenCore 兜底 |
|---|---|---|---|
| **Fast Boot / Ultra Fast Boot / MSI Fast Boot** | 跳过设备初始化 | **进不去选择器**、USB 键鼠没反应 | ❌ 无 |
| **Secure Boot** | macOS 不认非 Apple 签名 | 第三方 kext 加载失败 | ⚠️ 部分靠 `SecureBootModel=Disabled`，但 BIOS 侧仍建议关 |
| **CSM（Compatibility Support Module）** | 引入 legacy option ROM，GOP 走不通 | **GPU 报错 / 卡在 `gIO` / 分辨率异常** | ❌ 无 |
| **CFG Lock（MSR 0xE2 write protection）** | macOS 原生电源管理要写 MSR `0xE2` | ★★ **"Your hack will not boot"**（Dortania 原文） | ⚠️ `Kernel → Quirks → AppleXcpmCfgLock = true`（**官方说尽量别用**） |
| **★ Intel VMD / Volume Management Device** | **macOS 没有 VMD 驱动** | ★★ **装系统时「找不到任何驱动器」**；已装好的系统看不到盘 | ❌ 无（**官方与 Dortania 都没写，纯社区经验**） |
| **Intel RST / SATA RAID Mode** | macOS 只认 AHCI / NVMe 原生，不认 RST 假 RAID | 看不到硬盘 | ❌ 无 |
| **Serial / COM Port** | 占 I/O、老平台可能冲突 | 少数情况卡引导 | ❌ 无 |
| **Parallel Port** | 同上 | | ❌ 无 |
| **Intel SGX** | macOS 无驱动 | 一般无害，官方仍建议关 | ❌ 无 |
| **Intel Platform Trust / PTT / fTPM** | macOS 不需要 TPM | 一般无害 | ❌ 无 |
| **VT-d / IOMMU**（**可以开，但要知道代价**） | 与 XNU 的 IOMapper 冲突 | 网卡/无线反复 `link up/link down`、发现不了网络 | ✅ ★ **官方首选是开 `DisableIoMapper=true`**（*"a preferred alternative to … disabling VT-d in firmware preferences, which does not obstruct VT-d support in other systems"*） |
| **Thunderbolt**（**仅安装期**） | 未配置时可能出问题 | 安装期异常 | — 装好后按需开 |
| **ErP / EuP Ready** | 关机后切断待机供电 | 关机不断电、USB 唤醒异常（**看情况**，不是必须） | ❌ 无 |
| **Wake on LAN / 网络唤醒** | 睡眠被网络事件唤醒 | 睡眠不稳 | ❌ 无 |
| **Network Stack / PXE Boot** | POST 阶段要初始化网络 | 开机变慢 | ❌ 无 |

### 3.2 必须开启

| 设置 | 为什么必须开 | 不开的后果 | 备注 |
|---|---|---|---|
| **VT-x**（Intel）/ **SVM Mode**（AMD） | 虚拟化 | Docker/VM 用不了 | |
| **Above 4G Decoding** | 让大 BAR 能被映射到 4G 以上 | 大 BAR 显卡驱动起不来 | ★ 官方点名例外：**ASUS WS-X299-PRO 必须关** |
| **Hyper-Threading** | 性能 | 线程数减半 | ★ 例外：**3990X 必须关**（macOS 内核 64 线程上限） |
| **Execute Disable Bit**（XD / NX） | macOS 要求 | 可能起不来 | |
| **EHCI/XHCI Hand-off** | USB 控制权交接给 OS | 安装期 USB 键鼠 / 安装介质没反应 | 官方：**仅当不拔 USB 就卡引导时**才需要 |
| **OS Type = Windows 8.1/10 UEFI Mode**（或 **Other OS**） | 让固件按 UEFI 方式初始化 | 可能退回 legacy 路径 | 部分主板必须选 "Other OS" |
| **SATA Mode = AHCI** | macOS 只认 AHCI | 看不到 SATA 盘 | |
| **DVMT Pre-Allocated ≥ 64MB** | 给核显足够显存 | 核显花屏 / 黑屏 | **有核显时**才需要 |
| **★ Intel Speed Shift Technology** | macOS 用 HWP 调度 | ★★ **`wrmsr(0x770,1)` #GP panic**（本机实测硬前提） | **官方与 Dortania 都没写**，社区经验 |
| **Resizable BAR / Re-Size BAR Support** | 大 BAR 驱动路线需要 | 大 BAR 驱动拿不到 BAR | **看情况**，见 §3.3 |

### 3.3 看情况（Conditional）——**这些不需要一律关/开**

| 设置 | 什么时候开 | 什么时候关 |
|---|---|---|
| **Re-Size BAR Support** | 你的驱动/卡需要大 BAR（本机 NVIDIA 驱动就是），且 `ResizeGpuBars` 已配好 | 驱动版本或卡不支持大 BAR 时；出现黑屏/起不来时先试关 |
| **XMP / DOCP / EXPO** | 内存超频档，**稳定就开着** | 出现内存相关不稳定、睡眠异常时关掉回 JEDEC |
| **Internal Graphics / iGPU** | 核显有驱动、要用（如 `WhateverGreen` + 核显硬解） | 核显无驱动 ⇒ **关掉更干净**（或留开但加 `-wegnoigpu` 藏起来） |
| **Thunderbolt** | 装好系统、TB 设备配置好之后 | 安装期（见 §3.1） |
| **Legacy USB Support** | **装系统期间**（U 盘 / USB 键鼠） | 装好后可关，能省一点 POST 时间 |
| **Above 4G Decoding** | 绝大多数主板 | **ASUS WS-X299-PRO**（官方点名）；AMD 的 Gigabyte/Aorus/ASRock 上若坏驱动 ⇒ 关它 + 改 `npci=0x3000` |
| **CSM** | 只有「NVIDIA 6xx / AMD 2xx 及更老、且 GOP ROM 未刷」时才临时需要 | **其它一切情况都关**（默认答案就是关） |
| **Global C-state Control**（AMD） | 一般开着 | 出现待机不稳定时试关 |
| **Power Supply Idle Control**（AMD） | 一般 `Auto` | 某些 Ryzen 待机重启 ⇒ 试 `Typical Current Idle` |
| **Multi-Monitor / Primary Display** | 取决于用哪块 GPU 输出 | — |
| **DMA Protection / Kernel DMA Protection** | Win11 需要 | 与 macOS 无关，但**可能干扰**第三方驱动，出问题先试关 |

---

## 4. 官方与 Dortania **都没写**、但实际很关键的项

| 项 | 为什么关键 | 怎么知道要不要动 |
|---|---|---|
| **★ VMD（Intel Volume Management Device）** | 11 代 Intel 起很多主板**默认开启**。它把 NVMe 挂在一个虚拟控制器后面，**macOS 没有对应驱动** ⇒ 装系统时「找不到驱动器」、系统内看不到盘 | BIOS 里搜 `VMD` / `Volume Management Device` / `VMD Setup Menu`；Windows 侧见 §6 脚本的存储控制器检查 |
| **★ Intel Speed Shift Technology** | macOS 走 HWP 需要它。**关掉会 `wrmsr(0x770,1)` #GP panic**（本机实测） | BIOS 里搜 `Speed Shift`；Windows 侧看 `CPUID.06H:EAX` bit6–11（需工具） |
| **Re-Size BAR + Above 4G 的组合** | ReBAR 依赖 Above 4G。只开 ReBAR 不开 Above 4G 会出怪问题 | 两个一起看；配 `ResizeGpuBars` / `ResizeAppleGpuBars` |
| **XMP 与内存稳定性** | XMP 档位在 macOS 下不一定稳（尤其 4 条满插） | Windows 里对比 `Speed` vs `ConfiguredClockSpeed`（§6 脚本） |
| **ErP / EuP** | 关机行为、USB 供电 | 只在你关心关机/唤醒行为时动 |
| **TPM / PTT / fTPM** | macOS 用不到；有些主板开 PTT 会多出设备 | Windows 里 `Get-Tpm` 看 `TpmPresent`（§6 脚本） |
| **固件版本** | 官方清单第 1 条就是「用最新 UEFI」 | 记下当前版本，去主板官网比对 |

---

## 5. CFG Lock 专题（官方展开最细的一项）

**CFG Lock = `PKG_CST_CONFIG_CONTROL (0xE2)` MSR 的写保护。** 开着 ⇒ macOS 原生电源管理写不进 MSR ⇒ **不开机**。

### 5.1 三种查法

| 环境 | 怎么做 | 判据 |
|---|---|---|
| **OpenCore 引导界面** | 官方自带 **`ControlMsrE2.efi`**（在 `EFI/OC/Tools/`，选择器里按空格显示工具）。也可用社区的 `VerifyMsrE2` / `CFGLOCK` | 输出 `MSR 0xE2 is LOCKED` / `This firmware has UNLOCKED MSR` |
| **macOS** | `sudo wrmsr 0xE2 0x0`（需 `msr-tools`） | 报 `cannot set MSR 0x000000e2` ⇒ **是锁着的** |
| **Windows** | ⚠️ 读 MSR 需要特权工具（RWEverything / HWiNFO 等），**PowerShell 读不了** | 见 §6「无法直接读取」一节 |

> ★ 官方提醒：**某些固件只在部分核心上锁这个寄存器** —— 所以只看一个核的结果可能不准。

### 5.2 BIOS 里找不到 CFG Lock？走隐藏选项（官方给的方法）

适用于 **APTIO 固件**（AMI）：

1. 下载 **UEFITool**（`LongSoft/UEFITool`）与 **IFR-Extractor**（`LongSoft/Universal-IFR-Extractor`）
2. 用 UEFITool 打开固件镜像，搜 **`CFG Lock`** unicode 字符串。
   **找不到 ⇒ 该固件可能没有这个选项，流程到此为止**
3. 用 UEFITool 的 **Extract Body** 导出它所在的 `Setup.bin`（PE32 Image Section）
4. 对导出的文件跑 IFR-Extractor：`./ifrextract Setup.bin Setup.txt`
5. 在 `Setup.txt` 里找 **`CFG Lock, VarStoreInfo (VarOffset/VarName)`** —— 拿到 **VarStore GUID** 与 **offset**
6. 用该 GUID + offset 直接改这个 UEFI 变量（或在 OpenCore 里用 `NVRAM > Add` 写），再重启验证

### 5.3 兜底（不推荐，但能用）

`Kernel → Quirks → AppleXcpmCfgLock = true`（新系统）/ `AppleCpuPmCfgLock = true`（老系统，`AppleIntelCPUPowerManagement` 在 macOS 13 起已移除）。

> 官方原话：*"As modern firmware provide a CFG Lock setting … this option should be avoided whenever possible."*
> 即 **BIOS 能关就关，别用 quirk**。

---

## 6. Windows 侧审查工具：`scripts/bios-audit.ps1`

**为什么要脚本**：BIOS 界面里选项几百个、各厂商命名还不一样，人工核对容易漏。
这个脚本在 Windows 里**只读**采集，把能判定的直接判定，把不能判定的标出来让你去 BIOS 核。

### 6.1 怎么跑

```powershell
# 以【管理员】身份打开 PowerShell（部分项需要提权），然后：
powershell -ExecutionPolicy Bypass -File .\bios-audit.ps1

# 想同时存报告：
powershell -ExecutionPolicy Bypass -File .\bios-audit.ps1 -OutFile C:\bios-audit.txt
```

> 脚本**纯 ASCII 输出**（避免 PowerShell 5.1 的编码坑），报告里是英文键名 + 判定，对照本文看即可。

### 6.2 它**能**判定什么（A 类）

| 检查项 | 方法 | 判据 |
|---|---|---|
| 固件类型（UEFI / Legacy） | `$env:firmware_type` | 必须是 **UEFI** |
| 启动模式 | `bcdedit` 的 `winload.efi` | 必须是 `.efi` |
| 系统盘分区样式 | `Get-Disk.PartitionStyle` | **GPT**（配合 UEFI） |
| **Secure Boot** | `Confirm-SecureBootUEFI` | 期望 **False**（= 已关） |
| **TPM / PTT / fTPM** | `Get-Tpm.TpmPresent` | 期望 **False**（= BIOS 里已关） |
| **VT-x / SVM** | `Win32_Processor.VirtualizationFirmwareEnabled` | 期望 **True**（若 Hyper-V 在跑会误报，脚本会一并报 `HypervisorPresent`） |
| **超线程** | `Cores` vs `LogicalProcessors` | 逻辑 = 2×物理 ⇒ HT 已开 |
| **XMP / DOCP** | `Speed` vs `ConfiguredClockSpeed` | Configured > JEDEC 默认 ⇒ 超频档生效 |
| **★ VMD / RST** | `Get-Disk.BusType` + 存储控制器设备名 | 出现 **`RAID`** 总线类型、或控制器名含 `VMD` / `Volume Management Device` / `RST` ⇒ **VMD 开着，必须关** |
| 存储控制器清单 | `Get-PnpDevice` + PCI 硬件 ID | 列出所有 SCSIAdapter/HDC，便于人工认 |
| Serial/COM 端口 | `Get-CimInstance Win32_SerialPort` | 有 COM 口 ⇒ BIOS 里串口可能没关 |
| BIOS 版本 / 日期 / 主板 | `Win32_BIOS` / `Win32_BaseBoard` | 拿去官网比对是否最新 |
| 内存条与插槽 | `Win32_PhysicalMemory` | 顺便核对内存注入的槽位（见 `memory-injection.md`） |

### 6.3 它只能**给线索**、要人工确认的（B 类）

| 项 | 脚本能给什么 | 还要看什么 |
|---|---|---|
| Above 4G Decoding | 显卡 PCI 硬件 ID + 已分配的大内存资源线索 | 用 **GPU-Z** 看 "Above 4G Decoding" / "Resizable BAR"；或 NVIDIA 控制面板 → 系统信息 |
| Re-Size BAR | 同上 | 同上；本机以 `nvrm-bars` / 驱动日志为准 |
| Execute Disable Bit | `DataExecutionPrevention_Available` | 为 True 一般说明 XD 开着（推断，非直接读） |
| CSM | 只能看「当前是否 UEFI 启动」 | CSM 状态**无法从 Windows 直读** ⇒ 进 BIOS 看 |
| Fast Boot | 无 | 进 BIOS 看（Fast Boot / Ultra Fast Boot） |
| iGPU / DVMT | `Get-PnpDevice -Class Display` 看核显在不在 | DVMT 值读不到 ⇒ 进 BIOS 看 |

### 6.4 它**读不了**、必须另找工具的（C 类）

| 项 | 为什么读不了 | 正确工具 |
|---|---|---|
| **CFG Lock / MSR 0xE2** | 读 MSR 需要内核态特权 | **OpenCore 的 `ControlMsrE2.efi`**（最准）· Windows 上用 RWEverything · macOS 上 `wrmsr` 测试 |
| ACPI 表（DSDT / DMAR …） | Windows 不暴露 ACPI 表给用户态 | RWEverything / `acpidump`；或 OpenCore 的 `SysReport`（DEBUG 构建） |
| SATA Mode 实际值 | 只看到结果看不到设置 | 进 BIOS |
| BIOS 隐藏选项 | 界面里就没有 | UEFITool + IFR-Extractor（§5.2） |

---

## 7. 检查表（进 BIOS 时逐条打勾）

```
【必须关】
[ ] Fast Boot / Ultra Fast Boot / MSI Fast Boot
[ ] Secure Boot
[ ] CSM (Compatibility Support Module)
[ ] CFG Lock (MSR 0xE2)
[ ] VMD / Intel Volume Management Device        ← ★ 官方没写，但必关
[ ] Intel RST / SATA RAID Mode  → 改成 AHCI
[ ] Serial / COM Port
[ ] Parallel Port
[ ] Intel SGX
[ ] Intel Platform Trust / PTT / fTPM
[ ] Network Stack / PXE（可选，为了快）
[ ] Wake on LAN（可选）
[ ] VT-d / IOMMU（★ 也可改开 + 用 DisableIoMapper=true 兜底）

【必须开】
[ ] VT-x（Intel）/ SVM Mode（AMD）
[ ] Above 4G Decoding
[ ] Hyper-Threading（3990X 例外：关）
[ ] Execute Disable Bit (XD / NX)
[ ] EHCI/XHCI Hand-off
[ ] OS Type = Windows 8.1/10 UEFI Mode（或 Other OS）
[ ] SATA Mode = AHCI
[ ] DVMT Pre-Allocated ≥ 64MB（有核显时）
[ ] Intel Speed Shift Technology                ← ★ 官方没写，但本机硬前提
[ ] Resizable BAR（按驱动需要，配 ResizeGpuBars）

【看情况，别一律动】
[ ] XMP / DOCP          → 稳定就开
[ ] Internal Graphics   → 核显有驱动才开
[ ] Legacy USB Support  → 装系统期开，之后可关
[ ] Thunderbolt         → 装好后按需
[ ] ErP / EuP           → 只在关心关机/唤醒时动
```

---

## 8. 各厂商命名对照（同一设置，各家叫法不同）

| 通用名 | ASUS | MSI | Gigabyte / AORUS | ASRock |
|---|---|---|---|---|
| CSM | `Boot → CSM (Compatibility Support Module)` | `Settings → Advanced → Windows OS Configuration → CSM` | `BIOS → CSM Support` | `Boot → CSM` |
| Secure Boot | `Boot → Secure Boot → OS Type = Other OS` | `Security → Secure Boot` | `BIOS → Secure Boot` | `Security → Secure Boot` |
| Fast Boot | `Boot → Fast Boot` | `Settings → Advanced → Boot → MSI Fast Boot` | `BIOS → Fast Boot` | `Boot → Fast Boot` |
| Above 4G | `Advanced → PCI Subsystem Settings → Above 4G Decoding` | `Settings → Advanced → PCI Subsystem Settings` | `Settings → IO Ports → Above 4G Decoding` | `Advanced → PCI Configuration → Above 4G Decoding` |
| Re-Size BAR | `Advanced → PCI Subsystem → Re-Size BAR Support` | `Settings → Advanced → PCI Subsystem → Re-Size BAR` | `Settings → IO Ports → Re-Size BAR Support` | `Advanced → PCI Configuration → Re-Size BAR` |
| CFG Lock | `Advanced → CPU Configuration → CPU Power Management → CFG Lock` | `OC → CPU Features → CFG Lock` | `Settings → Miscellaneous → CFG Lock` | `Advanced → CPU Configuration → CFG Lock` |
| VT-d / IOMMU | `Advanced → System Agent → VT-d` | `OC → CPU Features → VT-d` | `Settings → Miscellaneous → VT-d` | `Advanced → Chipset → VT-d` |
| VMD | `Advanced → VMD Setup Menu → Enable VMD controller = Disabled` | `Settings → Advanced → VMD Setup Menu` | `Settings → IO Ports → VMD Configuration` | `Advanced → VMD Configuration` |
| Speed Shift | `Advanced → CPU Configuration → Intel Speed Shift Technology` | `OC → CPU Features → Intel Speed Shift` | `Settings → Advanced CPU Settings` | `Advanced → CPU Configuration` |
| SATA Mode | `Advanced → SATA Configuration → SATA Mode = AHCI` | `Settings → Advanced → SATA Mode = AHCI` | `Settings → SATA Mode = AHCI` | `Advanced → Storage Configuration → SATA Mode = AHCI` |

> 各家菜单名会随版本变，**用「搜设置」功能最快**（现代 BIOS 基本都有搜索框）：
> 直接搜 `VMD` / `CFG` / `CSM` / `Above 4G` / `Speed Shift`。

---

## 9. BIOS 设置 ↔ OpenCore quirk 的对应关系

| BIOS 里做不到 / 不想动 | OpenCore 侧对应 | 说明 |
|---|---|---|
| 关不掉 VT-d | `Booter → Quirks → DisableIoMapper = true` | ★ **官方首选**（不影响其它系统用 VT-d） |
| 关不掉 CFG Lock | `Kernel → Quirks → AppleXcpmCfgLock = true` | ⚠️ 官方说尽量避免 |
| 关不掉 CSM（老卡） | 无 —— 需先刷 GOP ROM | |
| Above 4G 关掉（ASUS WS-X299-PRO / AMD 某些板） | boot-args 加 `npci=0x3000` | ★ **两者不能同时** |
| ReBAR 开着但驱动不认 | `Booter → ResizeAppleGpuBars` / `UEFI → ResizeGpuBars` | 见 `nvidia-driver.md` |
| iGPU 没驱动 | boot-args `-wegnoigpu`（或 BIOS 里直接关核显） | 本机实测能省 ~60 s 开机时间 |
| BIOS 有 Fast Boot 但不想关 | ❌ 无替代 | 必须关 |

---

## 10. 与其它 reference 的关系

- **引导失败 / 卡住** → `logs-and-debug.md`（先看 OC 日志）；**耗时** → `boot-timeline.md`
- **NVIDIA 大 BAR 与 ReBAR** → `nvidia-driver.md`
- **核显 / iGPU** → 见 §3.3 与 `boot-timeline.md` 的 `-wegnoigpu`
- **内存条与插槽核对** → `memory-injection.md`（脚本的 §6.2 顺带输出槽位）
- **改 ESP 的安全流程** → `SKILL.md` 铁律 1–16 + `scripts/oc-edit-safe.sh`
