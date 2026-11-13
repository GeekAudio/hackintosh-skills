# ForbiddenItlwm（Intel 无线与 AirDrop）

需要在 Intel 网卡上验证原生 Wi-Fi 和双向 AirDrop 时，可评估 ForbiddenItlwm 的公开测试版。普通联网、HeliPort 和原版蓝牙驱动见 [Intel 无线](intel-wifi.md)。本专题以 2026-11-14 核对的 `v0.5.3-test1` 与配套 `BTLEAdvFixup 0.9.0` 为基线，适用于 x86_64。发布包分 Tahoe、Sequoia、Sonoma 三组，各有独立的 Wi-Fi ZIP 与 BT ZIP。[上游发布](https://github.com/retropineaple/ForbiddenItlwm/releases/tag/v0.5.3-test1)

## 判断是否适用

| 目标系统 | 两个 kext 的 Darwin 分流 | 已有证据 |
|---|---|---|
| Tahoe | `25.0.0`–`25.99.99` | 26.7.1 `25G241` 有作者在 AX211 和 iPhone 11 上的双向传输结果。26.7.2 `25G332`、26.7.3 `25G342` 有离线 ABI 核对和用户报告。 |
| Sequoia | `24.2.0`–`24.99.99` | 15.8 `24H23` 和 15.8.3 `24H241` 有离线 ABI 核对。15.8.1 `24H32`、15.8.2 `24H232`、15.8.3 有 `0.5.1-test1` 起的双向报告。AX200 在 15.6 的个案使用带本地修复的构建，按个案记录。 |
| Sonoma | `23.4.0`–`23.99.99` | 14.8.9 `23J631` 只有离线核对，发布页列为测试构建。该组的普通 Wi-Fi 目标从 14.4 起。 |

Darwin 范围用于隔离要加载的构建。Sequoia 采用源码实际设定的最低 Darwin `24.2.0`。AirDrop 还要求内核与 Apple AWDL 虚表校验通过，以及 BTLEAdvFixup 匹配实际 `bluetoothd` 字节。Sequoia 某些同内核系列的系统可显示 `expected`，私有数据结构相关路径仍要求 `verified`。遇到 `blocked` 就按该系统与内核重新选包或回到普通联网方案，保留驱动的校验机制。[启动版本门槛](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/ForbiddenItlwm/AirportItlwmV2.cpp#L1587-L1602) · [系统与实测记录](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/docs/TESTED-HARDWARE.md) · [内核校验](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/include/AWDLBuildGuard.hpp) · [虚表校验](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/ForbiddenItlwm/AWDLBuildGuard.cpp)

读 `sw_vers -buildVersion`、`uname -v` 与实际 Wi-Fi PCI、蓝牙 USB ID，再用固定版本仓库中的 `bash tools/compat/check_compat.sh` 预检。此脚本在本机读取设备、系统状态及 `bluetoothd` 匹配，输出用于选型。AX211 是作者测试机，AX201、AX210、AX200、AX1690i 有用户报告，按报告中的系统、网卡与版本判断。即时热点与连续互通相机列为未实现，睡眠唤醒留待实测。[预检工具](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/tools/compat/README.md) · [蓝牙匹配说明](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/BTLEAdvFixup/README.md) · [发布限制](https://github.com/retropineaple/ForbiddenItlwm/releases/tag/v0.5.3-test1)

## 准备 OpenCore 测试 EFI

在可启动 EFI 的副本上改配置，并保留经过验证的回退入口。下载同一系统组的两个 ZIP，核对发布页的 SHA256。解包后使用 `EFI/OC/Kexts/`，按以下顺序合并 `Kernel > Add`，`PlistPath` 均为 `Contents/Info.plist`。[上游安装说明](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/docs/INSTALL.md)

| BundlePath | ExecutablePath |
|---|---|
| `Lilu.kext` | `Contents/MacOS/Lilu` |
| `IntelBluetoothFirmware.kext` | `Contents/MacOS/IntelBluetoothFirmware` |
| `BlueToolFixup.kext` | `Contents/MacOS/BlueToolFixup` |
| `BTLEAdvFixup.kext` | `Contents/MacOS/BTLEAdvFixup` |
| `ForbiddenItlwm.kext` | `Contents/MacOS/ForbiddenItlwm` |

上游测试组合为 Lilu 1.7.2、IntelBluetoothFirmware 2.5.1、BlueToolFixup 2.7.3。BTLEAdvFixup 依赖 Lilu，并接管 IntelBTPatcher 的挂钩。启用该组合时禁用 `IntelBTPatcher.kext`，以免重复挂钩触发 panic。测试系统按上游要求在同一次启动中只启用 `ForbiddenItlwm`、`AirportItlwm`、`itlwm` 中的一个。`ForbiddenItlwm.kext` 通过 macOS Wi-Fi 菜单连接，HeliPort 用于 `itlwm` 路线。[依赖和互斥](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/docs/INSTALL.md)

给 `ForbiddenItlwm` 和 `BTLEAdvFixup` 两条分别填表中的版本范围。共用 EFI 的不同系统可给外层目录加系统后缀并各设 `BundlePath` 与互不重叠的范围，内部可执行文件路径保持如表。原系统需要的 Wi-Fi 驱动与 `IntelBTPatcher` 也按各自范围隔离。BlueToolFixup 的上游示例为 `MinKernel=21.0.0`。这条路线使用系统自带 `IO80211Family` 和 `IOSkywalkFamily`。若目标系统用过 OCLP Modern Wireless，先确认可恢复的原系统状态，撤销该无线 root patch，并清除这个系统对应的 `IOSkywalkFamily` block 与旧 `IOSkywalkFamily.kext` / `IO80211FamilyLegacy.kext` 注入。撤销 root patch 改的是目标 macOS 卷，从测试 USB 启动仍会使用该卷的系统状态。其它系统还在使用这些条目时按版本隔离。[无线栈前提](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/docs/INSTALL.md#before-you-start)

从同版 boot flags 文档取 `The tested set`，合并进 Apple GUID `7C436110-AB2A-4BBB-A880-FE41995C9F82` 下的 `boot-args`，保留其它用途的参数。需要覆盖已持久化的 `boot-args` 时，再检查同一 GUID 下的 `NVRAM > Delete` 是否包含 `boot-args`，并保留原有的其它项。固件 NVRAM 可跨系统、跨 EFI 保留，测试前记录 `sysctl -n kern.bootargs`，切回原环境时复核当前参数。保留默认构建校验和正常联网模式。`0.5.3-test1` 的 `-itlawdlbaaskshared` / `-itlawdlhideinfra` 各自用于排查同信道时的单向慢速。应用前完成 plist、引用和同版 `ocvalidate` 校验。[同版启动参数](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/docs/BOOT-FLAGS.md)

## 验收、升级和回退

先记录实际 kext 版本并验证 Wi-Fi 关联、DHCP、持续流量和蓝牙。用 `check_compat.sh` 查看监听器与主要启动参数，用 `ioreg` 核对 `ItlwmAWDLBuildCheck`、`ITLAWDLCoexAdded`、`BTLEAdvHookRouted`，用 `ifconfig awdl0` 查看接口。然后用 iPhone 和 Mac 各发送一个文件，确认接收端落盘并核对文件内容，期间记录基础 Wi-Fi 是否持续可用。`airdrop_measure.sh` 可从本地日志记录双向连接时间及速率。[验收和测量](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/tools/compat/README.md)

信道 149、80 MHz 依赖固件学到地区及信道许可。信道 6 可作低速路径，`itlwm_cc` 只影响显示，不开放额外信道。遇到 Mac 发往 iPhone 慢，先记录基础网络与 AWDL 是否同信道、`ITLAWDLCoexBaTxStateName` 和实际速率。遇到基础 Wi-Fi 反复掉线，先保存重启前的 I/O Registry，查看 `ITLAWDLCoexAddsAfterRestart`，再用回退 EFI 复核。[上游排障](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/docs/TROUBLESHOOTING.md)

macOS 更新前，先以移除 `-btleadv` 或禁用 BTLEAdvFixup 的配置实际启动一次。该插件会修改内存中的 `bluetoothd` 页面，启用时增量更新的校验可能失败。更新完成后重新核对目标 build、Wi-Fi ABI 与 `bluetoothd` 匹配，再启用对应组。回退时恢复原测试 EFI、蓝牙组合与原 `boot-args`。若测试参数仍保存在固件 NVRAM，按记录覆盖 `boot-args`，并复核实际启动配置。若曾撤销 OCLP 无线补丁，也要复核旧方案所需的目标卷状态。[升级与卸载](https://github.com/retropineaple/ForbiddenItlwm/blob/v0.5.3-test1/docs/INSTALL.md#before-a-macos-update)
