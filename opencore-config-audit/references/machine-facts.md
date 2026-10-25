# 参考机器事实（Z690 / Alder Lake / macOS 26）

> 这些是**参考机器**（本 skill 取材时用的那台）的实测结论，可直接引用作对照；
> **换机器时按 [技能入口的基线与判断](../SKILL.md#基线与判断) 重新核实**，不要当成通用配置。
> 下文说的「本机」= 这台参考机器。

## 硬件 / 机型

- 主板 ASUS TUF GAMING Z690-PLUS WIFI D4；CPU i7-12700K（Alder Lake-S，`0x90672`）
- 独显 RTX 3080 10GB（`10de:2206`，PEG1 0:1:0）；核显 UHD 770（`8086:4680`，0:2:0）
- 网卡 I225-V（**Apple 原版 I210 kext 仿冒**：`device-id=0x1533` + boot-arg `e1000=0`，跑在 1000baseT；
  `AppleIGC.kext` 已禁用 —— 曾触发网络 panic）+ Broadcom BCM943602CDP（无线/BT）
- 机型 **`iMac20,1`**（10-15 01:54 起；此前 10-13–10-15 是 `MacPro7,1`，更早 `iMacPro1,1`）；board-id `Mac-CFF7D910A743CAAF`
  - ★★ **10-15 03:33 已连同三码一起换**（`serial` / `MLB` / `UUID` 三处；`ROM` 未动）
    ⇒ 依据：**「关于本机」的机型名 = 序列号产品码的函数**，只换机型不换码会一直显示旧机型
    （`smbios-and-serials.md` §1.3）
  - ★ **三码真值不进仓库**：本机台账在工作区 `SMBIOS-iMac201-三码-20261015.md`（含身份凭证，勿外发）；
    本文只记结构：`serial` 产品码须对应 `iMac20,1`、`MLB` 校验位通过、`UUID` 为随机 v4
  - 电脑名 `Geek’s iMac` / `LocalHostName` `Geeks-iMac`（10-15 03:37 改；**SMB 的 `NetBIOSName`/`ServerDescription` 同步改过**）
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
- **现行（10-15 03:33 起）**：内置 ESP 的 config sha **`d1f6990295f5b49b0e62509bdbfba7b44e4f1d6bd56772a2153717208b309d44`**，
  `SystemProductName=iMac20,1` + 新三码 + `LauncherOption=Full`；存档 **`config.plist.v52-imac201-serials`**。
  备份：`_oc-backup-before-imac201-serials-20261015-033352.plist`（工作区）+ ESP 上 `config.plist.BASELINE-20261015-033349`。
  U 盘 ESP 的 config sha **`d01b859a…`**，`LauncherOption=Disabled`。
  （更早：`a08dfed3…` = iMac20,1 但**旧三码**那一版；`b06951b2…` = 两边都 Disabled 那一版；v45–v51 在 `xh_adls3修复-20261013/`）
- **两个 ESP（★ 盘号会漂，按容量/角色认）**：
  | ESP | 盘 | 容量 | config | 角色 |
  |---|---|---|---|---|
  | 内置 ESP（**见过 `disk1s1` / `disk2s1`，盘号会漂**） | ZHITAI PC005 NVMe 512 GB | 119.5 MB | `DBG-108`（DEBUG，868,352 B） | **目标引导盘** |
  | U 盘 ESP `disk9s1` | 32 GB 外接盘 | 1.1 GB | `REL-108`（RELEASE，626,688 B），机型 `iMacPro1,1` 的 FALLBACK 配置 | 救援盘 |
- **★ 当前从哪引导**（`nvram 4D1FDA02-…:boot-path`）：
  - 10-15 02:55 实测 = `…/USB(0x18,0x0)/…/HD(1,GPT,…)/EFI\OC\OpenCore.efi` ⇒ 当时**从 U 盘**引导（`REL-108`）
  - **10-15 03:40 实测 = `PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)/NVMe(0x1,…)/HD(1,GPT,⟨内置 ESP⟩)/\EFI\OC\OPENCORE.EFI`**
    ⇒ ★★ **已改成从内置硬盘引导**（OC = `DBG-108`，即硬盘那份）⇒ `boot-entries.md` §8 的迁移**已完成**
- ★★ **新三码尚未生效**（10-15 03:40 实测）：config 里已是新码，但**运行时的 `IOPlatformSerialNumber` 仍是旧码**
  ⇒ **说明自 03:33 写入后还没重启过**。重启后才会切到新码，并触发 iCloud / 信息 / FaceTime 重新认证。
  「关于本机」显示名缓存（`~/Library/Preferences/com.apple.SystemProfiler.plist`）**此刻也还是旧值**
  （`cachedSerial` = 旧码、`P7QM-…` = `Mac Pro (2019)`）—— 重启后才会按新码重新推导。

## 关键开关现状（v52）

| 键 | 值 | 备注 |
|---|---|---|
| `Misc>Debug>Target` | `69 (0x45)` | 记录 + DataHub + 文件；**控制台位 0x02 已关**（屏幕不再刷） |
| `Misc>Debug>DisplayLevel` | `0x80000042` | ERROR + INFO（未开 VERBOSE） |
| `Misc>Security>ScanPolicy` | `0` | 保持 0（选择器要能看到 Windows） |
| `Misc>Security>SecureBootModel` | `Disabled` | 与 `FixupAppleEfiImages=true` 成对 |
| `Misc>Security>Vault` | `Optional` | 无 vault.plist |
| `Misc>Security>ExposeSensitiveData` | `7` | `0x01` 是 1401 App 找 OpenCore 用的 `boot-path`，**别降成 6** |
| `Misc>Boot>LauncherOption` / `RequestBootVarRouting` | **`Full`** / `true` | ★ **10-15 02:41 定案：硬盘那份 `Full`（自建+自愈）/ U 盘那份 `Disabled`（不改写 NVRAM）** —— 中间一度两边都改过 `Disabled`，但那样**没人建启动项**，已回退。见 `boot-entries.md` §3 |
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
| `PlatformInfo>CustomMemory` + `Memory>Devices` | `true` / **4 项** | ★ **槽位数随机型变**：`MacPro7,1`=12 槽、**`iMac20,1`=4 槽**；`Devices` 必须含全部槽位（含空槽）。`MaxCapacity` = 68719476736（64 GB） |

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

## kext 现状（`Kernel>Add` 22 条）

启用：Lilu、**AppleALC**、**CpuTopologyRebuild**、CPUFriend、CPUFriendDataProvider、VirtualSMC、SMCProcessor、
SMCSuperIO、WhateverGreen、AppleIGC、BlueToolFixup、NVMeFix、RestrictEvents、USBToolBox、XHCI-unsupported、UTBMap、
AMFIPass、IOSkywalkFamily、IO80211FamilyLegacy、AirPortBrcmNIC-Tahoe、**NvidiaSensor**
（其中 `IO80211FamilyLegacy…/AirPortBrcmNIC.kext` 一条 `Enabled=False`，作 Sequoia 回退：
博通走 **MinKernel 23 / MaxKernel 24.99.99 用 `AirPortBrcmNIC`，≥25 用 `AirPortBrcmNIC-Tahoe`** 分流）

`Kernel>Block` 2 条：`IONDRVFramebuffer`（抢 NVRMFB 的 index 0）、`Allow IOSkywalk Downgrade`（OCLP Modern Wireless）

## USB 端口现状（★ 2026-10-25 起）

- 控制器 **`AppleUSBXHCISPT`**；`Kernel>Quirks>XhciPortLimit` **= true**（OC 1.0.8 含 1.0.7 的 Tahoe 修复）
- **注册根端口 13 HS + 9 SS = 22 个**，唯一 `locationID` 22 个；`port-count = 25`（端口号 1–13 + 17–25，**有缺口**）
- SS09 挂板载 ASM107x hub（`174c:3074`），**5 Gbps** 链路已建立；蓝牙在 HS11、Fireface 在 HS04、键鼠在 HS06 的 USB2 hub 树
- 固件 RHUB 列了 SS01–SS10，但 Windows RootHub 描述符 `bNumberOfPorts=25`、USB3 只有 17–25 共 9 个
  ⇒ **SS10 是模板多列，不是硬件缺失**
- ★ **尚未逐口验证**：物理位置、Type-C 正反插（`9` vs `10` 未定）、USB 存储吞吐、睡眠唤醒、长期稳定性
- 方法与判据 ⇒ `usb-port-mapping.md`；回滚脚本在 `EFI/OC/Rollback-USB22-Evidence02.nsh`

已删除（备份在工作区 `_kexts-removed-20261014/`）：`itlwm`、`IntelBluetoothFirmware`、`IntelBTPatcher`

**板载音频现状**：`AppleHDA.kext` 600.2 装在 **`/System/Library/Extensions`**（来自 KDK 15.8.1 build 24H32，macOS 26 必装回）；
`AppleALC` 1.9.9 自编译，DeviceProperties 注入到 `PciRoot(0x0)/Pci(0x1F,0x3)`：`layout-id=<0e000000>`（本机自建 layout 14）
+ `alc-verbs=<01000000>`。完整方法与坑见 `applealc-custom.md`。

## macOS 侧屏蔽（`/etc/fstab`）

4 条 `noauto`（`项目` / `Windows 卷` / `软件` / `备份`，**按卷 UUID**），**不含 EFI**。
脚本：工作区 `_mask-other-disks.sh`。

## 工具

- GitHub API：用脚本包装 `curl` 调 `https://api.github.com`（`<GET|POST|PATCH> <path> [json文件]`），
  凭证从**本地文件**读取（自行准备，勿写进仓库）
  - 路径**必须以 `/` 开头**
- 提权：`osascript -e 'do shell script "…" with administrator privileges'`（可跑 `log show`、`diskutil mount`）
- 本机没有 `/opt/homebrew`；managed Python = `~/.workbuddy-ai/binaries/python/versions/3.13.12/bin/python3`
