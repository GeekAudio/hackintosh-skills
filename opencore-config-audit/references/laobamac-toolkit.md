# laobamac 工具与补丁索引（Hackintosh）

> `laobamac` 维护了 **48 个仓库**，其中一大批是黑苹果相关的「**用原版 kext / 官方机制，不打补丁**」工具与驱动。
> 本文件是**完整索引** —— 具体用法看各仓库自己的 README。
>
> **分工**：有线网卡见 `ethernet-drivers.md` · 无线网卡见 `mediatek-wifi.md` / `intel-wifi.md` ·
> 声卡见 `applealc-custom.md` · NVIDIA 见 `nvidia-driver.md` · ACPI 见 `acpi-ssdt.md`。

## ★★ 先看这条：哪些项目已存档（2026-06）

**2026 年 6 月，一批项目集中进入存档状态** —— 作者原话：
*"非极特殊情况（比如世界毁灭）不再发布任何更新"*。

| 仓库 | 存档日 | 影响 |
|---|---|---|
| **`OCLP-Mod`** | **2026-06-13** | 已存在的版本**仍可用**，但 **API 节点会逐步关闭** ⇒ ★ **在 OCLP-Mod 设置里关掉 `SimpleHacAPI`** |
| **`SimpleKaruzi`** | **2026-06-18** | 不再更新（★ 但它提到的 **OCLP(-Mod) 3.0.0 初步支持 macOS Tahoe 26** 仍有效） |
| `SimpleGBE` | 2026-06-18 | 不再更新 |
| `SimpleLaunchPadRestore` | 2026-06-18 | 不再更新 |

> ★★ **但 2026-10 作者又回归了** —— `SimpleHDA`（10-13 创建）、`SimpleMtkWlan` / `SimpleMtkBtFw`、
> `itlwm` fork 都是新东西。
> ⇒ **纪律：用某个仓库前，先看它最后一次 push 时间**，别把「已存档」当成「还在维护」。

---

## 1. 硬件驱动

| 仓库 | 管什么 | 详见 |
|---|---|---|
| **`SimpleHDA`** | **macOS 26 恢复原版 `AppleHDA`**（OpenCore 注入，不打补丁 / 不关 SIP / 不用 KDK）；★ **现已降为备选**（作者不允许二次开发 + 只有 alpha + 有已知问题）⇒ 首选见 `applealc-custom.md` §0.5 | `applealc-custom.md` §0.5.6 |
| `SimpleMtkWlan` / `SimpleMtkBtFw` / `SimpleMTKClient` | MediaTek Wi-Fi / 蓝牙 | `mediatek-wifi.md` |
| `itlwm`（fork） | Intel Wi-Fi | `intel-wifi.md` |
| **`SimpleVGBE`** | Intel **I225 / I226** 2.5G | `ethernet-drivers.md` |
| **`SimpleGBE`** | Intel I210/I211/82575·76·80/I350 千兆 | `ethernet-drivers.md` |
| **`SimpleHacPlugins`**（原 `SakuraPlugins`） | **`SimpleEthernet`**（Lilu 插件，i225/226/210/211）· `SakuraLegacyFix`（I350/X540，测试中）· `SimpleLexa`（AMD RX5300/RX550，开发中） | `ethernet-drivers.md` |
| **`SimpleRTK5`** | Realtek **RTL8125 / 8126** 2.5/5GbE | `ethernet-drivers.md` |
| ~~`SimpleRTLHV`~~ | ★ **已并入 `SimpleRTK5`，不要再单独用** | — |
| `nvidia-macos-driver`（fork） | NVIDIA Metal 驱动（上游是 `nullmoth`） | `nvidia-driver.md` |

## 2. 装机 / EFI 生成

| 仓库 | 用途 | 备注 |
|---|---|---|
| **`SimpleKaruzi`** | **简化 OpenCore EFI 创建** —— 自动化基本设置流程 + 提供标准化配置，减少手动操作 | **AGPL-3.0**；★ **2026-06-18 已存档**；README 提到 **OCLP(-Mod) 3.0.0 已初步支持 macOS Tahoe 26** |
| `PVE-OpenCore` | **在 PVE 上装 macOS**（基于 OpenCore 的引导器） | **GPL-3.0**；作者称比 `KVM-OpenCore` **更小、bug 更少**（内含 macOS basesystem）；V20240224 起不再附带 recovery |

> 与 `rapidefi-first-efi.md`（Windows 上用 RapidEFI 生成基础 EFI）互为替代。

## 3. ★★ 装机前必读：硬件避坑

| 仓库 | 内容 |
|---|---|
| ★★ **`SimpleBuyersGuide`** | **《黑苹果硬件避坑指南》** —— 明确列出**不应购买**的硬件：<br>**CPU** · **GPU**（完全不支持 / 应避免）· **主板**（应避免的芯片组与品牌）· **存储**（完全不支持 / 应避免的 SSD）· **内存**（XMP 与睡眠问题）· 散热器 · **网络设备**（应避免的网卡）· **无线设备**（完全不支持 / 应避免的无线网卡）· 电源 · 机箱 · 散热硅脂 |

> ★ **配机 / 换件之前先翻这份**，比事后排查省事得多。与 `bios-settings.md`（BIOS 审查）配套。

## 4. 系统维护 / kext 安装工具

| 仓库 | 用途 | 备注 |
|---|---|---|
| ★★ **`SimpleLoader`** | **KDK 合并 + Kext 安装 + 重建内核缓存 + APFS 快照保护**（SwiftUI 图形界面） | macOS 11+；**GPLv3**；★ **比手工 `kmutil` / 快照操作安全**（自带快照回滚） |
| `SimpleBoxi` | *"macOS all-in-one toolbox"* | **GPL-2.0** |
| `KdkSupportPkg`（fork） | **Kernel Debug Kit 镜像**（Ventura 及更新） | — |
| `MetallibSupportPkg`（fork） | **Metal Library 补丁工具** | — |
| `PatcherSupportPkg`（fork） | OCLP 的**补丁资源包** | — |

## 5. macOS 26 缺失功能补回

| 仓库 | 用途 | 备注 |
|---|---|---|
| **`SimpleLaunchPadRestore`** | **一键恢复旧版启动台**（macOS 26 把 LaunchPad 换成了 Spotlight 式） | 要求 **Tahoe 26.0 B4+** + **已关 SIP**（`03080000` 或更高）；替换 `Apps.app` / `Dock.app` / `Spotlight.app`；★ **已存档** |
| **`SimpleLaunchpad`** | 启动台的**独立替代 App**（网格视图 / 搜索 / 自动分类 / `⌘⇧L` 呼出 / 毛玻璃） | **AGPL-3.0**；★ 作者标注**仍在开发中、不稳定** |

> ★ 与黑苹果无关，但 macOS 26 用户普遍会遇到（LaunchPad 被移除）。

## 6. 参考 / 补丁仓库

| 仓库 | 内容 |
|---|---|
| ★ **`OC-little-zh`** | **ACPI 热补丁中文指南** —— ACPI 基础 · 通过 SSDT 启用/添加设备 · 禁用设备 · 修显卡（核显/独显）· 修 USB · 修重启/睡眠/唤醒 · 外设问题 · 笔记本特殊补丁 · CMOS · EFI 文件夹 · **内核扩展加载顺序** · **MMIO 白名单** · 内存速度 ⇒ **写 SSDT / 修 ACPI 时的权威中文参考**（配合 `acpi-ssdt.md`） |
| `non-metal-frameworks` | **非 Metal 框架补丁仓库**（基于 Moraea 已删除的仓库）⇒ 老显卡在 Metal 化系统上的补丁（配合 `nvidia-driver.md`） |
| `misc-patches` | **杂项补丁** —— *"Patches not covered in non-metal-frameworks or elsewhere"* |
| `SimpleBuyersGuide` | 见 §3 |

## 7. 虚拟化

| 仓库 | 用途 |
|---|---|
| `PVE-OpenCore` | 见 §2 |

## 8. AMD 平台

| 仓库 | 内容 |
|---|---|
| `AMD_Vanilla`（fork） | **AMD 平台跑原生 macOS** 的 OpenCore 补丁 |
| `NootedRed`（fork） | **AMD Vega 核显支持补丁**（★ 作者标注 **No commercial use**） |
| `SMCAMDProcessor`（fork） | **AMD 处理器电源管理 / 监控**（VirtualSMC 插件） |

> 本机是 Intel，这几项**仅供参考**；AMD 机器才需要。

## 9. 上游仓库的 fork（作者改过的版本）

| 仓库 | 上游 |
|---|---|
| `Lilu` · `OpenCorePkg` · `AppleALC` · `WhateverGreenPR` · `Hackintool` · `OpenCore-Legacy-Patcher` · `USBToolBox` · `UTBKext` · `SMCAMDProcessor` | 各自的上游 |

> ★ **这些是 fork**，通常用于「改一版试 PR / 打自己的补丁」。
> **日常使用优先取上游官方版本**；只有在 fork 的 README/commit 里**明确写了改动**时才考虑用它。
> `WhateverGreenPR` 从命名看是**给上游提 PR 用的试验版**，不要当稳定版用。

## 10. 个人 EFI 参考

| 仓库 | 配置 |
|---|---|
| `Hackintosh-i7-8700K-ASUS-PRIME-Z370-A-Z370-F` | i7-8700K + ASUS PRIME Z370-A |
| `Hackintosh-I3-9100F-B365M-RX580` | i3-9100F + B365M + RX580 |

> ★ **别人的 EFI 只能当参考，不能直接套** —— 尤其 **USB 端口图**编码的是「那块板子怎么接线」，
> **跨品牌/跨型号套用必然出问题**（见 `intel-wifi.md` §5 与 `usb` 相关纪律）。

---

## 怎么用这份索引

| 你要做的事 | 用哪个 |
|---|---|
| **配机 / 换硬件前** | ★ `SimpleBuyersGuide`（避坑指南） |
| **从零生成 EFI** | `SimpleKaruzi`（已存档）或 `rapidefi-first-efi.md` 的 RapidEFI |
| **修 ACPI / 写 SSDT** | ★ `OC-little-zh` + `acpi-ssdt.md` |
| **装 kext 到系统目录 / 合并 KDK / 重建缓存** | ★ `SimpleLoader`（有快照保护） |
| **声卡** | 先 USB 声卡 / `MyKextInstaller`+KDK（`applealc-custom.md` §0.5）· 兜底 `SimpleVoodooHDA`（音质有损）；`SimpleHDA` 已降为备选 |
| **有线网卡** | `ethernet-drivers.md` |
| **老显卡** | `non-metal-frameworks` + `misc-patches` |
| **macOS 26 想要回启动台** | `SimpleLaunchPadRestore` / `SimpleLaunchpad` |
| **PVE 上装 macOS** | `PVE-OpenCore` |

> ★ **所有这些第三方 kext 都非 Apple 签名** ⇒ 需要 `SecureBootModel=Disabled`，SIP 视情况放宽。
> ★ 下载时**核对来源仓库与文件哈希**；**已存档的项目不会再修 bug**。
