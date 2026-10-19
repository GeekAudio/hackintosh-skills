# ACPI / SSDT 巡检

> ★★★ **热补丁样例库主参考：`5T33Z0/OC-Little-Translated`**（<https://github.com/5T33Z0/OC-Little-Translated>，
> **★745** · BSD-3-Clause · **仍在更新**）—— 起于 Daliansky `OC-little` 的**英译**，但**已远超原作**：
> 新增第 7–20 章 + **完整附录 A–Z**，重写了 ACPI / USB 端口映射等章节。
> ★★ **作者明确定位**：**不是安装指南**，是**装好之后的调优与硬件启用**；
> **只用 ACPI 热补丁、不做 DSDT patch**（干净黑苹果路线）⇒ **与本文的判据完全同源，可以放心当样例库用**。
> ★ **诚实提醒**：英译是 AI 工具 + 人工校对，**译者不懂中文** ⇒ 译文可能有小偏差；**关键结论仍要回到官方文档核**。
>
> ★ **中文参考**：`laobamac/OC-little-zh`（原作的中文版，索引见 `laobamac-toolkit.md`）。
>
> ★ **写 SSDT 之前先翻样例库**，再对照本文的官方 `AcpiSamples` 判「该不该加」。

## 0. ★★ 按需求找哪一章（含**本机 Z690 / Alder Lake / iMac20,1** 的落点）

| 你要做的事 | 去哪一章 |
|---|---|
| ACPI 基础 · **删除固件表** · **重命名设备** · OC 的 ACPI Patch | `Content/00_ACPI/`（`ACPI_Basics` · **`ACPI_Dropping_Tables`** · **`ACPI_Rename_Devices`** · `ACPI_Patches_OpenCore` · `ACPI_Debugging`） |
| ★ **把多张 SSDT 合并成一张表** | `Content/00_ACPI/SSDT-ALL` |
| 添加缺失设备 / 启用功能 | `Content/01_Adding_missing_Devices_and_enabling_Features/` |
| **禁用设备**（ACPI 法 + `Block_Kexts` 法） | `Content/02_Disabling_Devices/Disabling_PCI_Devices/` |
| ★ **用 ACPI 做 USB 端口映射**（`XHUB` / `XUPC` 两种方法） | `Content/03_USB_Fixes/ACPI_Mapping_USB_Ports/` |
| **修睡眠 / 唤醒**（`060D` 秒醒 · `PTSWAK` · AOAC · ASPM） | `Content/04_Fixing_Sleep_and_Wake_Issues/` |
| 笔记本（电池 / FN 键 / 触摸板 I2C / 品牌专用） | `Content/05_Laptop-specific_Patches/` |
| CMOS 相关 | `Content/06_CMOS-related_Fixes/` |
| **Quirks 逐项解释** · Config 技巧 | `Content/08_Quirks/` · `Content/A_Config_Tips_and_Tricks/` |
| **kext 加载顺序实例** | `Content/10_Kexts_Loading_Sequence_Examples/` |
| 显卡（iGPU/dGPU/APU）· **GPU-BAR 尺寸** · 禁用不支持的 GPU · Metal 3 | `Content/11_Graphics/` |
| **MMIO 白名单** · AppleVTD | `Content/12_MMIO_Whitelist/` · `Content/20_AppleVTD/` |
| 雷雳 / 外设 / 网络 / RAM 速度 | `Content/19_Thunderbolt/` · `13_Peripherals/` · `N_Networking/` · `15_RAM/` |
| **boot-args 逐项解释** | `Content/H_Boot-args/` |
| OCLP on Wintel · OTA 更新 · Board-ID VMM spoof | `Content/14_OCLP_Wintel/` · `S_System_Updates/OTA_Updates.md` · `09_Board-ID_VMM-Spoof/` |
| ★ **自己做一个 ALC Layout-ID** | `Content/L_ALC_Layout-ID/`（另有更细的 `5T33Z0/AppleALC-Guides` ⇒ `applealc-custom.md`） |
| **排错**：SysReport · Preboot 卡住 · spindump 转文本 · 让 AI 分析 bootlog | `Content/K_Debugging/` · `18_Troubleshooting/`（`Fixing_Preboot` · `Converting_Spindumps.md` · `Config_Tweaks_AI.md`） |
| 一堆常用终端命令 | `Terminal_Commands.md` |
| **上传 EFI 前的自检清单** | `Content/M_EFI_Upload_Chklst/` |

### 0.1 ★ 这个仓库里「官方 / Dortania 没有」的东西（最值得翻的部分）

- ★ **`SSDT-ALL`：把多张 SSDT 合并成一张表** —— 减少 `ACPI>Add` 条目、便于管理；
- ★★ **`ACPI_Mapping_USB_Ports`：用 ACPI 而不是 kext 做 USB 端口映射**（`XHUB` / `XUPC` 两种方法）——
  对「USB 15 口上限」这类问题是一条**不同于 `UTBMap` 的路线**；
- ★ **`Intel_I225-V_Fix_(SSDT-I225V)`** —— **本机板载就是 Intel I225-V**，值得对照（现用 `AppleIGC.kext`，见 `ethernet-drivers.md`）；
- ★ **`PMCR_Support_(SSDT-PMCR)`** —— 本机 `PMCR` 计数 **0**，属于「可能该补」的一类；
- ★ **`ACPI_Dropping_Tables` + `ACPI_Rename_Devices`** —— 本机删 `xh_adls3` 用的就是前者那套机制；
- ★ **`GPU-BAR_Size` / `Disabling_unsupported_GPUs`** —— 与 ReBAR / 不支持显卡相关；
- ★ **`ACPI_Debugging`（含 `ACPIDebug.kext`）** —— ACPI 层面的取证手段；
- ★ **`18_Troubleshooting/Fixing_Preboot`** —— 卡在 Preboot 的专项排查（补 `boot-failure-debug.md`）。

## 1. 官方依据只有这些

官方发布包里 `Docs/AcpiSamples/`（Source/*.dsl + Binaries/）**就是判定"该不该加 SSDT"的权威清单**。
官方文档对 `OC/ACPI` 的规定：

- 文件放 `EFI/OC/ACPI`，扩展名 `.aml`；示例名 `DSDT.aml`、`SSDT-1.aml`、`MYTABLE.aml`
- **允许子目录**：`ACPI>Add>Path` 的示例值里明确写了 `SubDir/SSDT-8.aml`
- 路径上限 `OC_STORAGE_SAFE_PATH_MAX` = **192 字符**（含结尾 `\0`）
- ★ **表的身份由内容解析决定，不由文件名决定**（`Path` 条目原文：*"determined by parsing data, not by filename"*）
  ⇒ **改名安全**，只要同步改 `ACPI>Add>Path`；`ACPI>Delete` 匹配的也是内容（`TableSignature`/`OemTableId`）
- 处理顺序（ACPI Introduction）：**`Patch` → `Delete` → `Add`**；`RebaseRegions`/`SyncTableIds` 在所有改动**之后**才处理

## 2. 先做「零报错」确认

```bash
# 内核日志里 0 命中 ⇒ 没有坏掉的 ACPI（第一判据）
grep -aiE "acpi error|ae_not_found|ae_already|namespace lookup|Error evaluating" <内核日志>
```

## 3. 设备存在性检查（决定某张 SSDT 是否适用）

```bash
for n in SBUS BUS0 MCHC PMCR AWAC RTC RTC0 HPET GPRW XHCI GFX0 PEG0 PEG1 SAT0 HDAS; do
  printf "  %-6s %s\n" "$n" "$(ioreg -p IOACPIPlane -w0 | grep -c "$n")"
done
# 驱动是否真的挂上（例：SMBus）
kmutil showloaded --list-only | grep -iE "smbus|AppleSMBus"
ioreg -r -c AppleSMBusController -w0 | wc -l     # 0 = 已加载但无实例 ⇒ SSDT-SBUS-MCHC 未启用
```

★ 注意 ACPI 设备名因厂商而异：ASUS 常见根设备叫 **`PC00`**（不是 `PCI0`）、音频设备叫 **`HDAS`**（不是 `HDEF`）、
核显 ACPI 名可能是 **`GFX0`**（没有 `IGPU`）。**写 SSDT 必须按本机实际名字来**，否则表加载不了。

## 4. 官方 AcpiSamples 逐条适用条件

| 样例 | 官方注释里的适用条件 | 判定要点 |
|---|---|---|
| `SSDT-EC` / `SSDT-EC-USBX` | 桌面需假 EC（`_HID = ACID0001`）；官方明确 **不要把 EC0/H_EC 改名成 EC，AppleACPIEC 在桌面不该加载** | `ioreg -r -c AppleACPIEC` 应为空 |
| `SSDT-USBX` | USB 电源属性（`kUSBSleepPowerSupply` 等四个） | 表里四个属性齐即可 |
| `SSDT-PLUG` / `SSDT-PLUG-ALT` | Alder Lake 及 CPU 以 **Device 而非 Processor** 声明的平台；官方注明「Alder Lake 还需 CPUFriend 定制 CPU profile」 | 与 `Kernel>Quirks>ProvideCurrentCpuInfo` 配合 |
| `SSDT-AWAC-DISABLE` | **For 300-series only**，且需要 `STAS` 变量存在 | `ioreg` 里 `AWAC` 计数为 0 ⇒ 不适用 |
| `SSDT-RTC0` / `SSDT-RTC0-RANGE` | **For 300-series only**，`SSDT-AWAC` 不适用时（需 `STAS` 存在） | 同上 |
| `SSDT-PMC` | Intel 300-series PMC（`APP9876`）；**APTIO V 上 PMC 未初始化会卡 SMM ⇒ NVRAM 不可写** | 若 NVRAM 读写正常 ⇒ 无证据需要 |
| `SSDT-BRG0` | GPU 在多一层 PCI 桥后（`PCI0.PEG0.PEGP.BRG0.GFX0`），macOS 11+ 需要 | 独显直连且驱动正常 ⇒ 不需要 |
| `SSDT-UNC` | X99/X299 uncore 假桥（macOS 11 起 IOPCIFamily 会崩） | 平台不符 ⇒ 不适用 |
| `SSDT-IMEI` | Sandy/Ivy Bridge 核显 | 平台不符 |
| `SSDT-EHCx-DISABLE` | 老平台 EHCI | 平台不符 |
| `SSDT-ALS0` / `SSDT-PNLF` | 笔记本（环境光 / 背光） | 台式机不适用 |
| `SSDT-HV-DEV` / `HV-PLUG` / `HV-VMBUS` | Hyper-V 虚拟机 | 物理机不适用 |
| `SSDT-SBUS-MCHC` | SMBus 兼容表：给 `SBUS` 加 `BUS0`(`_CID="smbus"`) 与 `MCHC`，让 `AppleSMBusController` 挂上 | `BUS0`=0 且 `AppleSMBusController` 无实例 ⇒ **该启用** |

**Dortania 常见但 OpenCore 官方样例里没有的**：`SSDT-RHUB`（USB 控制器不枚举时复位 hub）、
`SSDT-DMAR`（屏蔽 DMAR）、`SSDT-GPRW`（秒醒）。判定同样靠"本机有没有对应的症状/方法"：
`GPRW` 方法不存在 ⇒ 该补丁不适用；USB 全端口枚举正常 ⇒ RHUB 不需要；固件表里没有 DMAR ⇒ DMAR 补丁不需要。

## 5. 命名规范化

**规范**：`SSDT-<功能>[-<平台>].aml`，全 ASCII 大写，只含字母/数字/`-`，不用 `_`、空格、非 ASCII；长度远低于 192 上限。

- 保留 Dortania 原生名（`SSDT-EC` / `SSDT-USBX` / `SSDT-RTCAWAC` / `SSDT-PLUG-ALT`）便于与指南对照
- 替换 BIOS 表用的表，**保留与被替换表相同的 OEM Table ID**（例：替换 `xh_adls3` 就用 `xh_adls3`），便于在日志里对上
- 未启用的表**移进子目录**（如 `ACPI/disabled/`），`Path` 写成 `disabled/SSDT-X.aml`；这样生效目录一眼可读
  —— 一旦启用，**移回 `ACPI/` 并同步改 `Path`**（别让启用项躺在 `disabled/` 里）

## 6. 编译与验证（`iasl`）

> 工具从哪来（ACPICA 源码编译 / 包管理器 / 借用第三方包内二进制）⇒ `toolchain.md` §3.1。
> ★★ **只加官方已编译的 `.aml`（`Docs/AcpiSamples/Binaries/`）根本不需要 `iasl`** —— 只有「要改」才需要。

### 6.1 三个动作，别混

| 要做什么 | 命令 | 产物 |
|---|---|---|
| `.dsl` → `.aml`（自己写的 SSDT） | `iasl -p SSDT-XXX.aml SSDT-XXX.dsl` | 与 dsl 同目录的 `.aml` |
| `.aml` → `.dsl`（读厂商 / 别人的表） | `iasl -d SSDT-XXX.aml` | 同目录的 `.dsl` |
| 输出到别处 | 上面任一动作加 `-p <输出前缀>` | 按前缀命名（扩展名由 `iasl` 补） |

★ `-p` 是**输出前缀**，不是「输出文件路径 + 任意扩展名」；★ `-f` 是**强制出结果**（有错也写文件），
排错时能拿到半成品，**但绝不能把带错误的产物放进 EFI**。

### 6.2 反编译厂商表会报一堆错 —— 这是正常的

整张 DSDT / 厂商 SSDT 引用了大量外部符号，单表反编译必然出现
`Object does not exist (AE_NOT_FOUND)` 之类。

- **只想看结构** ⇒ 报错不管，`.dsl` 照样能读
- **要编译回去** ⇒ 补外部表：`iasl -e <外部表.aml> -d <目标.aml>`（可给多个 `-e`）
- ★★ **更稳的做法：不改厂商表** —— 用 `ACPI>Delete` 删掉它 + 自己的 SSDT 顶替（热补丁路线，
  本 skill 与 `OC-Little` 的一致主张）。改厂商表等于把 BIOS 的私有实现复制进 EFI，后续无法追溯。

### 6.3 编译完必须做的四项验证

1. **回读**：`iasl -d` 把自己编出来的 `.aml` 反编译回来，与 `.dsl` 语义对一遍
   —— 防「编译通过但内容不对」（例如 `-f` 留下的半成品）
2. **搜路径**：`ACPIe -f <表.aml> <路径>` 确认关键设备 / 方法真的在里面
   （★★ **命中与未命中退出码都是 0**，只能看 stdout：`Returned offset: N` vs `EXIT: No entry found`）
3. **落盘**：放 `EFI/OC/ACPI` + 同步 `ACPI>Add>Path` ⇒ `plutil -lint` + `ocvalidate` ⇒ 重启
4. **生效**：引导日志看这张表有没有被加载（`OCA:` 段），再 `ioreg` / `kmutil showloaded` 看结果

★ **「表加载了」≠「表生效了」**。判据永远是**系统里的可观测结果**：设备出现在 `ioreg`、
驱动出现在 `kmutil showloaded`、内核日志 0 报错。

### 6.4 常见编译错误对照

| 报错 | 真相 | 处置 |
|---|---|---|
| `syntax error, unexpected …`，而样例是新版 | **编译器太老**（`iasl -v` 的日期串旧） | 换新 ACPICA，别去改样例 |
| `Object does not exist (AE_NOT_FOUND)` | 引用了外部表里的符号 | 补 `-e`，或改写为自包含的 SSDT |
| `_OFF` / `_ON` / `_STA` 重复定义 | 与厂商表里的同名对象冲突 | 先 `ACPI>Delete` 原表，再放自己的 |
| 编译通过，但 `ocvalidate` 报 `Path` 不存在 | 文件名 / 大小写 / 子目录没对上 | 对 `ACPI>Add>Path` 逐字核 |
| 编出来的 `.aml` 只有几十字节 | 编的是空文件 / 文件没被覆盖 | 看 `iasl` 的 `AML size` 行 |

## 7. 排查顺序（建议）

1. 内核日志 0 报错？→ 没有"坏 ACPI"
2. 官方样例逐条对照本机设备存在性 → 得到"该加/不该加"清单
3. 检查 `ACPI>Add` 每条 `Path` 是否**真的存在**、目录里有没有**孤儿文件**
4. 检查 `ACPI>Delete` 是否命中（看 OC 日志 `OCA: Deleting table …`）
5. 最后才考虑"要不要补"；补的时候一次只加一张，重启后看内核日志是否仍 0 报错
6. ★ 卡在 **Preboot** 之类的位置 ⇒ `5T33Z0/OC-Little-Translated` 的 `Content/18_Troubleshooting/Fixing_Preboot`（另有 `boot-failure-debug.md`）
