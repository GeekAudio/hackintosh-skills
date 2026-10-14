# 参考机器事实（Z690 / Alder Lake / macOS 26）

> 这些是**参考机器**（本 skill 取材时用的那台）的实测结论，可直接引用作对照；
> **换机器时按 `SKILL.md` 的阶段 0 重新核实**，不要当成通用配置。
> 下文说的「本机」= 这台参考机器。

## 硬件 / 机型

- 主板 ASUS TUF GAMING Z690-PLUS WIFI D4；CPU i7-12700K（Alder Lake-S，`0x90672`）
- 独显 RTX 3080 10GB（`10de:2206`，PEG1 0:1:0）；核显 UHD 770（`8086:4680`，0:2:0）
- 网卡 I225-V（`AppleIGC.kext` 驱动）+ Broadcom BCM943602CDP（无线/BT）
- 机型 `MacPro7,1`；macOS 26.7.1（25G241）
- 磁盘（**按容量认，盘号会漂**）：
  | 卷 | 容量 | 物理盘 | 接口 |
  |---|---|---|---|
  | 软件 | 256 GB | SAMSUNG MZVLW256HEHP | NVMe |
  | 项目 | 205 GB | KINGSTON SA400S37480G（**与 macOS 同盘**） | SATA · AHCI Port 4 |
  | macOS（Macintosh HD，APFS 274.9 GB） | — | KINGSTON SA400S37480G | SATA · AHCI Port 4 |
  | Windows 卷（无名） | 512 GB | ZHITAI PC005 Active 512 GB | NVMe |
  | 备份 | 1 TB | WDC WD10SPZX-00Z10T0 | SATA · AHCI Port 5 |

## EFI / OpenCore

- **ESP 在 512 G 盘上**（ZHITAI）：`disk1s1`，卷名 `EFI`，卷 UUID **⟨你的 ESP 卷 UUID，用 `diskutil info diskXs1 | grep UUID` 取⟩**，FAT16，119.5 MB
- OpenCore = **`DBG-108-2026-09-27`**（= **1.0.8 DEBUG 构建**，`OpenCore.efi` 868,352 B，sha `11ba0b76…`；官方 RELEASE 是 626,688 B / `9ef21f9d…`）
- config 版本存档：`xh_adls3修复-20261013/config.plist.vNN-<说明>`；工作区镜像 `_oc-current.plist`
- **现行 = v45**，sha `6804f5701c0fcebe0e5db847d7fd8d594f7314ac09489a5ecd685d149189eb16`

## 关键开关现状（v45）

| 键 | 值 | 备注 |
|---|---|---|
| `Misc>Debug>Target` | `69 (0x45)` | 记录 + DataHub + 文件；**控制台位 0x02 已关**（屏幕不再刷） |
| `Misc>Debug>DisplayLevel` | `0x80000042` | ERROR + INFO（未开 VERBOSE） |
| `Misc>Security>ScanPolicy` | `0` | 保持 0（选择器要能看到 Windows） |
| `Misc>Security>SecureBootModel` | `Disabled` | 与 `FixupAppleEfiImages=true` 成对 |
| `Misc>Security>Vault` | `Optional` | 无 vault.plist |
| `Misc>Security>ExposeSensitiveData` | `7` | `0x01` 是 1401 App 找 OpenCore 用的 `boot-path`，**别降成 6** |
| `Misc>Boot>LauncherOption` / `RequestBootVarRouting` | `Full` / `true` | 成对 |
| `Misc>Boot>PickerMode/Variant/Attributes` | `External` / `Acidanthera\GoldenGate` / `144` | 主题，保留 |
| `Misc>Boot>HideAuxiliary` | `true` | 隐藏 recovery / 工具项（按空格展开） |
| `Booter>Quirks>EnableWriteUnprotector` | `false` | 依据 `OCABC: MAT support is 1` |
| `Booter>Quirks>ResizeAppleGpuBars` | `-1` | 驱动基线 |
| `UEFI>Quirks>ResizeGpuBars` | `13`（8 GB） | 驱动基线；代价 = 开机黑屏 ~21 s |
| `UEFI>APFS>MinDate/MinVersion` | `0` / `0` | 原来 `-1`（文档 strongly discouraged） |
| `Kernel>Quirks>PanicNoKextDump` | `false` | 要 panic 日志里的 kext 信息 |
| `Kernel>Quirks>ProvideCurrentCpuInfo` | `true` | Alder Lake 非对称 SMP |
| `Kernel>Emulate>Cpuid1Data/Mask` | `55 06 0A 00…` / `FF FF FF FF…` | 文档给出的 ADL→Comet Lake 推荐值 |
| `PlatformInfo>UpdateSMBIOSMode` + `CustomSMBIOSGuid` | `Custom` + `true` | 成对 |
| `PlatformInfo>CustomMemory` + `Memory>Devices[12]` | `true` | `Devices` 必须含全部槽位（含空槽） |

**boot-args**：
```
-v amfi_get_out_of_my_way=0x1 amfi=0x80 -wegnoigpu nvrmsettle=1500 nvfbsample=1
ipc_control_port_options=0 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
-no_compat_check revpatch=sbvmm,cpuname keepsyms=1 debug=0x144 revcpu=1 nmxintel=1
```

## ACPI / SSDT 现状

- 启用 6 张：`SSDT-EC.aml`、`SSDT-RTC-AWAC.aml`、`SSDT-USBX.aml`、`SSDT-SBUS-MCHC.aml`、`SSDT-PLUG-ADL.aml`、`SSDT-XHADLS3.aml`
- 禁用 2 张（在 `ACPI/disabled/`）：`SSDT-PLUG-MADT.aml`、`SSDT-PLUG-DRTNIA.aml`
- `ACPI>Delete` 删固件里的 `SSDT`（OEM ID `xh_adls3`，7586 B）并注入替换表（7393 B，保留同 OEM ID）
- 内核日志 ACPI **0 报错**；固件 26 张表；**没有 DMAR**；`FACP` 276 B rev6、`FACS` 在 `0x5871E000`
- ★ 本机 ACPI 命名：根设备 **`PC00`**（非 `PCI0`）、音频 **`HDAS`**（非 `HDEF`）、核显 **`GFX0`**（无 `IGPU`）
- 设备存在性：`SBUS`=1 / `BUS0`=0→（启用 SMBus SSDT 后应有 1）/ `PMCR`=0 / `AWAC`=0 / `RTC`=1 / `GPRET`=0 / `HPET`=1 / `GPRW`=0

## kext 现状（18 个，23 MB）

启用：Lilu、CPUFriend、CPUFriendDataProvider、VirtualSMC、SMCProcessor、SMCSuperIO、WhateverGreen、AppleIGC、
BlueToolFixup、NVMeFix、RestrictEvents、USBToolBox、XHCI-unsupported、UTBMap、AMFIPass、
IOSkywalkFamily、IO80211FamilyLegacy、AirPortBrcmNIC-Tahoe（+ 禁用的 `IO80211FamilyLegacy…/AirPortBrcmNIC.kext` 作 Sequoia 回退）

已删除（备份在工作区 `_kexts-removed-20261014/`）：`itlwm`、`IntelBluetoothFirmware`、`IntelBTPatcher`、
`AppleALC`、`CpuTopologyRebuild`

## macOS 侧屏蔽（`/etc/fstab`）

4 条 `noauto`（`项目` / `Windows 卷` / `软件` / `备份`，**按卷 UUID**），**不含 EFI**。
脚本：工作区 `_mask-other-disks.sh`。

## 工具

- GitHub API：用脚本包装 `curl` 调 `https://api.github.com`（`<GET|POST|PATCH> <path> [json文件]`），
  凭证从**本地文件**读取（自行准备，勿写进仓库）
  - 路径**必须以 `/` 开头**
- 提权：`osascript -e 'do shell script "…" with administrator privileges'`（可跑 `log show`、`diskutil mount`）
- 本机没有 `/opt/homebrew`；managed Python = `~/.workbuddy-ai/binaries/python/versions/3.13.12/bin/python3`
