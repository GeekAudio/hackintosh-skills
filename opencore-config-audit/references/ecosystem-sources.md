# 黑苹果生态：权威来源与工具索引

> 本文件回答一个问题：**「做某件事，该信谁、该用哪个工具」**。
> 只收「有明确上游 / 长期维护 / 社区公认」的来源。
> 某个作者个人的 fork 与已存档项目见 `laobamac-toolkit.md`。

## 0. ★★ 权威性排序（先记这条）

1. **Acidanthera 官方仓库 + 官方文档** —— **最高权威**。配置的**唯一权威**是 `OpenCorePkg` 包里的 `Docs/Configuration.pdf`
2. **Dortania 指南** —— 社区事实标准（安装指南 / Post-Install / ACPI）
3. **驱动作者自己的 README** —— 驱动行为的唯一权威
4. **论坛帖子 / 博客** —— 只作**线索**，结论必须回到 1–3 验证

> ★★ **纪律：官方文档 > 驱动作者 README > 论坛帖子。**
> 任何「论坛说的」结论，都要回到 `Configuration.pdf` 或驱动源码验证。

## 1. 权威来源 —— Acidanthera（48 仓库）

| 仓库 | ★ | 是什么 |
|---|---|---|
| **`OpenCorePkg`** | 15.5k | **OpenCore 引导器本体**。★ `Docs/Configuration.pdf` 是配置的**唯一权威**；`Docs/AcpiSamples/` 是 SSDT 官方样例（18 个） |
| **`Lilu`** | 3.9k | **所有插件的宿主**（AppleALC / WhateverGreen / CPUFriend / RestrictEvents… 都靠它） |
| `AppleALC` | 3.6k | 板载声卡 → `applealc-custom.md` |
| `WhateverGreen` | 3.4k | 显卡补丁（ATI/AMD/Intel/NVIDIA） |
| `VirtualSMC` | 1.8k | SMC 模拟层（含 `SMCProcessor` / `SMCSuperIO` 等插件） |
| `BrcmPatchRAM` | 1.2k | 博通蓝牙固件上传 → `broadcom-wifi.md` |
| **`OcBinaryData`** | 814 | **官方图标集 / 字体 / 标签 / 音频** → `theme-opencanopy.md` |

> ★ 还有 `RestrictEvents`（`revpatch=` / `revcpu=`）、`CPUFriend`、`NVMeFix`、`AirportBrcmFixup`、`IntelMausi`、
> `AppleMCEReporterDisabler`、`CryptexFixup` 等 —— **按需在组织页里找**。

## 2. 权威来源 —— Dortania（33 仓库）

| 仓库 | ★ | 是什么 |
|---|---|---|
| **`OpenCore-Legacy-Patcher`** | 18.6k | **OCLP** —— 给老 Mac / 黑苹果打根补丁 → `broadcom-wifi.md` / `os-upgrade-15-to-26.md` |
| **`OpenCore-Install-Guide`** | 4.3k | **OpenCore 安装指南**（社区事实标准：`dortania.github.io/OpenCore-Install-Guide`） |
| **`Getting-Started-With-ACPI`** | 672 | **ACPI 入门** —— 写 SSDT 的第一份读物 |
| `OpenCore-Post-Install` | 630 | 装完之后的收尾（`dortania.github.io/OpenCore-Post-Install`） |
| `KdkSupportPkg` | 248 | **KDK 镜像**（Ventura+） |

## 3. 工具 —— corpnewt 全家桶（99 仓库）

| 工具 | ★ | 用途 |
|---|---|---|
| **`gibMacOS`** | 7.3k | 直接下载 macOS 组件（做装机盘） |
| **`ProperTree`** | 3.2k | **跨平台 plist 编辑器** —— 改 `config.plist` 的主力（带 OC 快照 / 清理） |
| **`GenSMBIOS`** | 2.0k | 用官方 `macserial` 生成 SMBIOS 三码 → `smbios-and-serials.md` |
| **`SSDTTime`** | 1.3k | **自动生成常用 SSDT**（DSDT 热补丁） |
| **`USBMap`** | 1.3k | 在 macOS 里**映射 USB 端口**并生成 kext |
| **`MountEFI`** | 1.2k | 挂载 EFI 分区（★ macOS 26 上需提权，见 `pitfalls.md`） |

### 其它工具

| 工具 | 作者 | 用途 |
|---|---|---|
| **`USBToolBox/tool`** ★1.5k | USBToolBox | **USB 端口映射**（Windows / macOS 双模式）；`USBToolBox/kext` ★455 是注入器 |
| **`blacktop/ipsw`** ★3.8k · **`ipsw-diffs`** ★899 | blacktop | **iOS / macOS 研究工具**；`ipsw-diffs` 能看**内核与 kext 的版本差异** —— ★ **我们就是靠它在 macOS 26 里发现 `AppleSunriseWLAN.dext` 的** |
| `NullMoth/1401` ★469 · `1401-probe` ★30 | NullMoth | **从 Windows 装 macOS**；`1401-probe` 是**离线硬件扫描 U 盘** |

## 4. 驱动作者（按硬件分类）

| 硬件 | 作者 / 仓库 | 详见 |
|---|---|---|
| **Intel 无线** | **`OpenIntelWireless`** —— `itlwm` ★7.1k · `IntelBluetoothFirmware` ★2.5k · `HeliPort` ★1.3k（原作者 **`zxystd`**） | `intel-wifi.md` |
| **MediaTek 无线 / 蓝牙** | **`GeekAudio/mediatek-sunrise-hackintosh`（MT7922 Sunrise Pack）** —— macOS 26 原生 Sunrise 的一站式包（固件 + `AppleSunrise.kext` + SSDT + 伪装片段 + macOS 15 第三方 kext 全套）· ★ **`flxxxxddd/SimpleMtkWlan`（fork，v1.5.0：`AirportMtkWlan` 原生菜单 / `SimpleMtkWlan` 以太网式，二选一）** + `laobamac/SimpleMtkBtFw`（第三方路线） | `mediatek-wifi.md` |
| **博通无线 / 蓝牙** | **Acidanthera** —— `AirportBrcmFixup` / `BrcmPatchRAM` | `broadcom-wifi.md` |
| **MediaTek** | **`laobamac`** —— `SimpleMtkWlan` / `SimpleMtkBtFw` | `mediatek-wifi.md` |
| **有线网卡** | **`Mieze`** —— `LucyRTL8125Ethernet` ★296 · `IntelMausiEthernet` ★413 · `RTL8111_driver_for_OS_X` ★717 · `IntelLucy` ★76 · `RTL812xLucy` ★22<br>**`Shaneee`** —— `AppleIGB` ★30<br>**`laobamac`** —— `SimpleVGBE` 等 | `ethernet-drivers.md` |
| **声卡** | **Acidanthera**（`AppleALC`）· ★★ **`5T33Z0`**（`AppleALC-Guides` —— **定制 layout 的实操主参考**、17 个现成 dump、`alc-verb`；另有 `OCLP4Hackintosh` 的 `Audio_Tahoe.md`）· **`perez987`**（`AppleHDA-gone-on-macOS-26-Tahoe` 指南）· **`Mirone`**（`MyKextInstaller`）· **`laobamac`**（`SimpleLoader` / `SimpleHDA`(备选) / `SimpleVoodooHDA`）· **`chris1111`**（VoodooHDA 脚本上游） | `applealc-custom.md` |
| **NVIDIA** | **`NullMoth`** —— `nvidia-macos-driver` ★3.0k | `nvidia-driver.md` |
| **AMD 核显 / CPU** | `NootedRed`（Vega）· `AMD_Vanilla` · `SMCAMDProcessor` | `laobamac-toolkit.md` §8 |
| **USB Wi-Fi（外置）** | **`chris1111`** —— `Wireless-USB-*` 系列 ★1k+ | — |
| **老显卡补丁** | **`chris1111`** —— `Geforce-Kepler-patcher` ★378 · `Legacy-Video-patch` ★197；`non-metal-frameworks` | `nvidia-driver.md` |

## 5. 中文资源

| 来源 | 内容 |
|---|---|
| ★ **`daliansky/OC-little`** ★1.6k | **ACPI 热补丁样例 —— 中文原作**（黑果小兵 Daliansky）⇒ 中文整理版 = **`laobamac/OC-little-zh`**（见 `laobamac-toolkit.md` §6）· **英文扩充版 = `5T33Z0/OC-Little-Translated`**（见下） |
| ★ **`daliansky/Hackintosh`** ★10.0k | **长期维护的 EFI 合集 + 安装教程**（黑果小兵） |
| `daliansky/daliansky.github.io` | 黑果小兵的部落阁（博客） |
| ★★★ **`5T33Z0/OC-Little-Translated`** ★745 | **ACPI 热补丁样例库主参考** —— 起于 OC-Little 英译，但**已远超原作**（新增第 7–20 章 + 完整附录 A–Z）；**只用 ACPI 热补丁、不做 DSDT patch**；覆盖 ACPI 基础/删表/改名 · 加/禁设备 · CPU 电源 · 显卡（含 **GPU-BAR**）· USB（含**用 ACPI 做端口映射**）· 睡眠唤醒 · 笔记本 · CMOS · **MMIO 白名单 / AppleVTD** · 雷雳 · boot-args / Quirks 解释 · kext 顺序 · **OCLP on Wintel** · 多系统 · 虚拟机 · **自己做 ALC Layout-ID** · 排错（SysReport / Preboot / spindump）⇒ 索引见 `acpi-ssdt.md` §0 |
| `5T33Z0/OCLP4Hackintosh` ★79 | OCLP 用在黑苹果上的简明指南（★ `Enable_Features/Audio_Tahoe.md` = **macOS 26 用 root patch 恢复 AppleALC**） |
| **远景论坛 `bbs.pcbeta.com`** | 中文社区 —— ★ **可直连**（我们就是从这拿到 `SimpleHDA` 一手信息的） |
| `tonymacx86.com` | 英文老牌论坛 —— ⚠️ **有 Cloudflare 验证码，程序抓不到** |
| `InsanelyMac` / `AppleLife` | **官方 AppleALC 指定的讨论渠道**（见 `applealc-custom.md` §6） |

## 6. 专项参考（显卡 / 选购 / 取证）

| 仓库 | 作者 | 内容 |
|---|---|---|
| `khronokernel/Anti-Hackintosh-Buyers-Guide` ★165 | khronokernel | **反黑苹果选购指南**（= `laobamac/SimpleBuyersGuide` 的英文源头） |
| `khronokernel/IO80211-Patches` ★68 | khronokernel | 打过补丁的 `IO80211Family` kext |
| `khronokernel/SmallTree-I211-AT-patch` ★83 | khronokernel | Intel I211-AT 支持 |
| ★ `khronokernel/IORegistryClone` ★80 | khronokernel | **克隆 Apple 机器的 IOReg**（★ 对照真机很有价值） |
| `khronokernel/Getting-Started-With-OpenCore` ★142 | khronokernel | OpenCore 简明上手 |
| `5T33Z0/AppleALC-Guides` ★66 | 5T33Z0 | ★★★ **AppleALC 定制 layout 的实操主参考**（14 章：dump → 拓扑图 → PathMap → PinConfig → 编译 → 测试 → PR）· **17 个现成 codec dump** · **`alc-verb` 运行时调音** · `MuteGPIO` 表 · **精简到 90 KB** · 文件管理/回滚 |
| `5T33Z0/OCLP4Hackintosh` | 5T33Z0 | OCLP 在黑苹果上的实操（★ `Enable_Features/Audio_Tahoe.md` = **macOS 26 用 root patch 恢复 AppleALC 全功能**） |
| `perez987/AppleHDA-gone-on-macOS-26-Tahoe` | perez987 | ★★ **macOS 26 板载声卡：把 `AppleHDA.kext` 装回来**（KDK + `MyKextInstaller` / `SimpleLoader`）—— 声卡恢复的主参考 |
| `perez987/Fenvi-wifi-back-on-Sonoma-Sequoia-Tahoe` ★132 | perez987 | Fenvi T919 等**博通卡**在新系统上恢复 Wi-Fi |
| `perez987/Intel-AX210-on-Sonoma-Sequoia-Tahoe` ★120 | perez987 | **Intel AX210S** 在新系统上跑通 |
| `perez987/OpenCore-and-UEFI-Secure-Boot` ★116 | perez987 | **UEFI 安全启动 + OpenCore** |
| `perez987/RX6600XT-on-macOS-with-softPowerPlayTable` ★110 | perez987 | AMD RX 6600 XT 的 `softPowerPlayTable`（关 Zero RPM） |

**`GeekAudio`（本项目作者的产出）**：

| 仓库 | 内容 |
|---|---|
| `GeekAudio/mediatek-sunrise-hackintosh` | ★★ **MT7922 Sunrise Pack**：把 tonymacx86 帖子 332855 的附件收齐成包（固件 + 两个版本 KDK 提取的 `AppleSunrise.kext` + SSDT + 免编译 `DeviceProperties` 伪装 + boot-args + macOS 15 第三方 kext 全套含预编译 SimpleMTK）—— 原生 Sunrise 路线的**主参考** |
| `GeekAudio/tcc-helper` | ★★ **macOS 权限工具（TCC）**：直接往 TCC 数据库写「已授权」条目，绕过弹窗；**自动从 `Info.plist` + launchd 后台组件反推谁需要什么权限**；GUI + CLI |
| `GeekAudio/hackintosh-skills` | 本 skill 的公开仓库（opencore-config-audit） |
| `GeekAudio/i7-12700K-RTX3080-OpenCore-Hackintosh` | 一份可参考的脱敏 EFI 发布仓库（i7-12700K + RTX 3080） |

## 7. 怎么用这份索引

| 你要做的事 | 信谁 / 用哪个 |
|---|---|
| **改 config 的任何一个键** | ★★ **`OpenCorePkg` 的 `Docs/Configuration.pdf`** + 官方 `ocvalidate` |
| **装 / 升级系统** | ★★ **Dortania `OpenCore-Install-Guide`** + 本技能 `lifecycle.md` / `os-upgrade-15-to-26.md` |
| **写 SSDT** | `Getting-Started-With-ACPI` + `daliansky/OC-little` + `5T33Z0/OC-Little-Translated` + `acpi-ssdt.md` |
| **改 plist** | `corpnewt/ProperTree` |
| **生成三码** | `corpnewt/GenSMBIOS`（底层是官方 `macserial`） |
| **USB 端口映射** | `corpnewt/USBMap`（macOS 侧）· `USBToolBox/tool`（Windows/macOS 双模式） |
| **自动生成 SSDT** | `corpnewt/SSDTTime` |
| **下载 macOS / 做装机盘** | `corpnewt/gibMacOS` · `NullMoth/1401`（Windows 侧） |
| **看内核 / kext 的版本差异** | `blacktop/ipsw-diffs`（★ 发现 `AppleSunriseWLAN` 就靠它） |
| **配机前避坑** | `khronokernel/Anti-Hackintosh-Buyers-Guide`（英文源头）· `laobamac/SimpleBuyersGuide`（中文） |
| **对照真机 IOReg** | `khronokernel/IORegistryClone` |
| **论坛求助** | 远景（中文，可直连）· InsanelyMac / AppleLife（AppleALC 官方指定）· tonymacx86（需人工过验证码） |

> ★★ **最后一条**：本文件里的 ★ 数是**当时快照**，仅供参考；**看项目是否还活着，以最后一次 push 时间为准**。
