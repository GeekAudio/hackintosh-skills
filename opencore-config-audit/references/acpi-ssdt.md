# ACPI / SSDT 巡检

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

## 6. 排查顺序（建议）

1. 内核日志 0 报错？→ 没有"坏 ACPI"
2. 官方样例逐条对照本机设备存在性 → 得到"该加/不该加"清单
3. 检查 `ACPI>Add` 每条 `Path` 是否**真的存在**、目录里有没有**孤儿文件**
4. 检查 `ACPI>Delete` 是否命中（看 OC 日志 `OCA: Deleting table …`）
5. 最后才考虑"要不要补"；补的时候一次只加一张，重启后看内核日志是否仍 0 报错
