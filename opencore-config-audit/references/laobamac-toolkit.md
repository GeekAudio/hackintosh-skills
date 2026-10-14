# laobamac 工具与补丁索引（Hackintosh）

> `laobamac` 维护了一批「**用原版 kext / 官方机制，不打补丁**」的黑苹果工具与驱动。
> 本文件是**索引** —— 具体用法看各仓库自己的 README。
>
> **分工**：网卡驱动见 `ethernet-drivers.md`（有线）· `mediatek-wifi.md` / `intel-wifi.md`（无线）·
> 声卡见 `applealc-custom.md` · NVIDIA 见 `nvidia-driver.md`。

## ★★ 先看这条：哪些项目已存档（2026-06）

**2026 年 6 月，一批项目进入存档状态** —— 作者原话：
*"非极特殊情况（比如世界毁灭）不再发布任何更新"*。

| 仓库 | 存档日 | 影响 |
|---|---|---|
| **`OCLP-Mod`** | **2026-06-13** | 已存在的版本**仍可用**，但**API 节点会逐步关闭** ⇒ ★ **在 OCLP-Mod 设置里关掉 `SimpleHacAPI`** |
| `SimpleGBE` | 2026-06-18 | 不再更新 |
| `SimpleLaunchPadRestore` | 2026-06-18 | 不再更新 |

> ★★ **但 2026-10 作者又回归了** —— `SimpleHDA`（10-13 创建）、`SimpleMtkWlan` / `SimpleMtkBtFw`、
> `itlwm` fork 都是新东西。
> ⇒ **纪律：用某个仓库前，先看它最后一次 push 时间**，别把「已存档」当成「还在维护」。

## 1. 硬件驱动（本技能已分别收录）

| 仓库 | 管什么 | 详见 |
|---|---|---|
| **`SimpleHDA`** | **macOS 26 恢复原版 `AppleHDA`**（不打补丁 / 不关 SIP / 不用 KDK） | `applealc-custom.md` §0.5 |
| `SimpleMtkWlan` / `SimpleMtkBtFw` / `SimpleMTKClient` | MediaTek Wi-Fi / 蓝牙 | `mediatek-wifi.md` |
| `itlwm`（fork） | Intel Wi-Fi | `intel-wifi.md` |
| **`SimpleVGBE`** / **`SimpleGBE`** / **`SimpleHacPlugins`** / **`SimpleRTK5`** | **有线网卡**（Intel / Realtek） | `ethernet-drivers.md` |
| `SimpleHacPlugins → SimpleLexa` | AMD RX5300 / RX550 —— **开发中，无下载** | — |

## 2. 工具（★ 实用的几个）

| 仓库 | 用途 | 备注 |
|---|---|---|
| ★★ **`SimpleLoader`** | **KDK 合并 + Kext 安装 + 重建内核缓存 + APFS 快照保护**（SwiftUI 图形界面） | macOS 11+；**GPLv3**；★ **比手工 `kmutil` / 快照操作安全**（自带快照回滚） |
| **`SimpleVoodooHDA`** | **一键在 Monterey–Tahoe 部署 VoodooHDA** | 需关 SIP（`csr-active-config` = `03080000` 或 `850A0000`）；★ **强烈建议禁用/移除 `AppleALC.kext`**；核心脚本来自 @chris1111 |
| `SimpleLaunchPadRestore` | 一键恢复**旧版启动台**（macOS 26 把 LaunchPad 换成了 Spotlight 式） | 要求 **Tahoe 26.0 B4+** + **已关 SIP**（`03080000` 或更高）；会替换 `Apps.app` / `Dock.app` / `Spotlight.app`；★ **已存档** |
| `SimpleLaunchpad` | 同类（把 LaunchPad 要回来） | — |
| `SimpleKaruzi` | *"Easier to start Hackintosh"*（上手辅助） | Python |
| `SimpleBoxi` | *"macOS all-in-one toolbox"* | — |
| `PVE-OpenCore` | **在 PVE 上装 macOS** 更省事 | 虚拟化场景 |
| `OCLP-Mod` | **OCLP 的 mod 版**：中文界面、Sequoia 的 Intel 无线、**KDK / MetalLib 加速下载** | ★ **已存档**；API 会关 ⇒ 关掉 `SimpleHacAPI` |

## 3. 参考 / 补丁仓库

| 仓库 | 内容 |
|---|---|
| ★ **`OC-little-zh`** | **ACPI 热补丁中文指南** —— ACPI 基础 · 通过 SSDT 启用/添加设备 · 禁用设备 · 修显卡（核显/独显）· 修 USB · 修重启/睡眠/唤醒 · 外设问题 · 笔记本特殊补丁 · CMOS · EFI 文件夹 · **内核扩展加载顺序** · **MMIO 白名单** · 内存速度 ⇒ **写 SSDT / 修 ACPI 时的权威中文参考**（配合 `acpi-ssdt.md`） |
| `non-metal-frameworks` | **非 Metal 框架补丁仓库**（基于 Moraea 已删除的仓库）⇒ 老显卡在 Metal 化系统上的补丁（配合 `nvidia-driver.md`） |
| `SimpleBuyersGuide` | 黑苹果**选购指南**（翻译文档） |
| `misc-patches` | 杂项补丁（其它仓库装不下的） |
| `MetallibSupportPkg` / `KdkSupportPkg` | 官方仓库的镜像 fork |

## 4. 怎么用这份索引

- **修 ACPI / 写 SSDT** ⇒ 先翻 **`OC-little-zh`**，再对照 `acpi-ssdt.md` 的官方样例
- **装 kext 到系统目录 / 合并 KDK / 重建缓存** ⇒ 用 **`SimpleLoader`**（有快照保护，比手工安全）
- **声卡** ⇒ 先试 **`SimpleHDA`**（无损、不打补丁）；走不通再考虑 `SimpleVoodooHDA`（有损但兼容面广）
- **老显卡** ⇒ 看 **`non-metal-frameworks`**
- **有线网卡** ⇒ `ethernet-drivers.md`

> ★ **所有这些第三方 kext 都非 Apple 签名** ⇒ 需要 `SecureBootModel=Disabled`，SIP 视情况放宽。
> ★ 下载时**核对来源仓库与文件哈希**；已存档的项目不会再修 bug。
