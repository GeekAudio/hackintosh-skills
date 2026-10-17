# AirDrop / 接力（Handoff / 连续互通）—— 为什么不能用，怎么查

> ★ **本文的定位**：AirDrop / 接力是**独立于 `en0` / `ROM` / 三码**的一条问题线。
> 过去 skill 里把它混进 `network-en0-order.md` 的「依赖 `en0`」清单，**是错的**，
> 会把排查方向带到 `ROM` 上去。本文是那条线的**唯一权威出口**。
>
> 来源分级（本文只用前两类做依据，本机实测单列）：
>
> | 级别 | 来源 |
> |---|---|
> | **Apple 官方** | 连续互通 / AirDrop 系统要求 |
> | **驱动官方** | itlwm（OpenIntelWireless）FAQ、Dortania |
> | 本机实测 | 命令输出、两份 EFI 的 `config.plist` 对比 |

## 0. 一句话

**AirDrop / 接力能不能用，只取决于一件事：无线网卡是否跑在 Broadcom 原生 `IO80211Family` 栈上、从而产生 `awdl0`。**

- **`itlwm.kext`（Intel 网卡的以太网式驱动）⇒ 永远没有 `awdl0` ⇒ AirDrop 必然不可用**
  —— 这是驱动设计层面的限制，不是配置问题，**改任何 config 都救不回来**。
- **`ROM` / `en0` 归属 / 机型 / 序列号 / `SystemUUID` 与 AirDrop 无关**，别往那儿查。

## 1. 权威依据

### 1.1 Apple 官方：连续互通只要三件事

Apple 支持《使用"连续互通"在 Apple 设备间工作》：

> 若要使用"连续互通"功能，请在所有设备上**通过相同 Apple ID 登录**。
> 此外，你的设备还必须**打开 Wi-Fi 和蓝牙**且**满足系统要求**。

—— **没有** `en0`，**没有** `ROM`，**没有** 序列号 / UUID。

AirDrop 的设备发现与点对点传输走 **Wi-Fi + 蓝牙**，macOS 上的点对点通道就是：

| 接口 | 全称 | 作用 |
|---|---|---|
| **`awdl0`** | Apple Wireless Direct Interface | AirDrop / 接力 / 随航的主通道 |
| **`llw0`** | Low-Latency WLAN | 低延迟链路，缺它接力会不灵 |

**AWDL 是 Apple 私有协议，跑在 `IO80211Family` 栈里** ⇒ 驱动不在这个栈里就**不可能**有 `awdl0`。

### 1.2 itlwm 官方 FAQ：明确不支持 AirDrop

`https://openintelwireless.github.io/itlwm/FAQ.html`

> **Limitation of `AirportItlwm.kext`**
> - **Handoff and Universal Clipboard are the only supported Continuity features.**

> **Does it support Apple's Continuity Framework (Airdrop, HandOff)**
> **Only *Handoff* and *Universal Clipboard* works with AirportItlwm, other features are not supported.**

> **Is it a replacement of natively supported Broadcom Cards**
> **No.**

而更基础的 `itlwm.kext`（不是 `AirportItlwm`）：

> `itlwm.kext` uses Apple's public **IOEthernetController instead of the private IO80211Family**.
> `AirportItlwm` enables the native Wi-Fi selection menu with limited continuity features.

⇒ `itlwm.kext` **把无线网卡伪装成以太网卡**，根本不进 `IO80211Family`，**不会产生 `awdl0`**。
⇒ 即使 `AirportItlwm` 也只是「Handoff + 通用剪贴板」，**AirDrop 仍不支持**。

### 1.3 Dortania：`en0` / `ROM` 只管 iServices，且**与接口类型无关**

`https://dortania.github.io/OpenCore-Post-Install/universal/iservices.html`

整篇标题是 **"Fixing iMessage and other services"**，通篇讲 iMessage / FaceTime / iCloud / App Store，
**没有一处提到 AirDrop 或 Handoff**。关于 `en0` 类型，原文：

> **Note**: `en0` can be either Wifi, ethernet or even Thunderbolt. **The type doesn't matter**,
> just that it's present and marked as built-in.

⇒ **`en0` 是以太网完全合规**（本机 `en0` = Intel I225-V，Wi-Fi 是 `en1`）⇒ **不影响 AirDrop**。

## 2. 排查顺序（按权威依赖链，从便宜到贵）

| 顺序 | 检查 | 命令 | 期望 / 说明 |
|---|---|---|---|
| 1 | **`awdl0` 存在且 RUNNING** | `ifconfig awdl0` | `flags=8843<UP,BROADCAST,RUNNING,…>`；**没有 ⇒ 直接看第 2 步**（最常见根因） |
| 2 | **Wi-Fi 走的是哪个驱动** | `kmutil showloaded --list-only \| grep -i 80211`<br>`ioreg -l \| grep -i IO80211`<br>看 `Kernel > Add` | 必须是 **Broadcom 原生栈**（`IOSkywalkFamily` + `IO80211FamilyLegacy` + `AirPortBrcmNIC`）；**`itlwm.kext` 一定不行** |
| 3 | `llw0` 是否存在 | `ifconfig llw0` | `flags=8863<…SMART,RUNNING…>`；缺它接力会不灵 |
| 4 | AirDrop 是否 Supported | `system_profiler SPAirPortDataType \| grep AirDrop` | `AirDrop: Supported`；否则查国家码 / 卡是否被识别 |
| 5 | 蓝牙 BLE 服务 | `system_profiler SPBluetoothDataType \| grep "Supported services"` | 要有 **`LEA` / `AACP` / `GATT`**（连续互通需要）；缺 ⇒ 蓝牙驱动问题 |
| 6 | 是否两台蓝牙控制器 | `ioreg -p IOUSB -w0 -l \| grep -i bluetooth` | 原 Intel 网卡没拔 / 没屏蔽 ⇒ macOS 会犯迷糊 |
| 7 | 系统开关 | 系统设置 → 通用 → 隔空投送与接力 | 接力开关、AirDrop 可见性 |
| 8 | Apple ID | 两台设备是否同一账号 | Apple 官方第一条要求 |

> ★★ **判据纪律**：`system_profiler SPAirPortDataType` 在重启后**十几秒才准**，
> **别拿它判 Wi-Fi 死活**；`ifconfig awdl0` / `ifconfig enX` 才是硬判据
> （见 `broadcom-wifi.md` §4）。

## 3. 四个常见误判（都验证过是错的）

| 误判 | 为什么错 |
|---|---|
| **「`ROM` 必须是真实 Wi-Fi MAC，否则 AirDrop 坏」** | `ROM` 是 Dortania **iServices**（iMessage / FaceTime / App Store）的要求，**Apple 官方对连续互通只要求 Apple ID + Wi-Fi + 蓝牙**。实测：`ROM` 与 `en0` 不一致时 AirDrop **照样可用** |
| **「Continuity / AirDrop 挂在 `en0` 上」** | 同上。Dortania 原文 *"The type doesn't matter"*，且通篇不提 AirDrop |
| **「`SystemUUID` / `IOPlatformUUID` 不一致导致 AirDrop 坏」** | 反证很直接：本机 `config SystemUUID` 与 `IOPlatformUUID` **至今仍不一致**（且两次启动之间还会变），而 AirDrop **实测可用** ⇒ 不是因素，**不要为 AirDrop 去动 UUID** |
| **「机型 / 序列号不对导致 AirDrop 坏」** | 无依据。序列号影响的是 iServices 与「关于本机」 |

> ★ **别为了「符合规范」去改 `ROM`** —— 那要付一次「重建 `ByHost` + 重新认证」的代价，
> 还可能把本来正常的 iServices 弄坏。详见 `smbios-and-serials.md` §6.1。

## 4. 选卡原则（一句话）

> **要 AirDrop / 接力 ⇒ 必须用 Broadcom 原生支持的卡**（BCM43602 / BCM94360CDP 这类）。
> **Intel 卡无论 `itlwm` 还是 `AirportItlwm`，都拿不到 AirDrop**；
> **MediaTek 第三方路线（`SimpleMtkWlan`）设计上就不可能**（见 `mediatek-wifi.md` §4.1）。

| 卡 | AirDrop | 依据 |
|---|---|---|
| Broadcom（原生栈 + OCLP root patch） | ✅ | 有 `awdl0` / `llw0` |
| Intel + `AirportItlwm` | ❌（仅 Handoff / 通用剪贴板） | itlwm 官方 FAQ |
| Intel + `itlwm.kext` | ❌（连 `IO80211Family` 都不进） | 同上 |
| MediaTek 第三方 kext | ❌（"not possible with this design"） | `mediatek-wifi.md` §4.1 |

## 5. 本机实测（Z690 / i7-12700K / macOS 26.7.1 / BCM43602 + BCM20703）

| 项 | 值 |
|---|---|
| `awdl0` | `flags=8843<UP,BROADCAST,RUNNING,…>` ✅ |
| `llw0` | `flags=8863<UP,BROADCAST,SMART,RUNNING,…>` ✅ |
| AirDrop | `Supported` ✅ |
| 蓝牙服务 | `HFP AVRCP A2DP HID Braille LEA AACP GATT SerialPort` ✅ |
| `en0` | **Ethernet** `Intel I225-V`（built-in ✅）—— 无线是 `en1` |
| 无线驱动 | `AirPortBrcmNIC-Tahoe.kext`（`MinKernel 25.0.0`） |
| 加载的驱动 | `com.apple.driver.AirPort.BrcmNIC (1400.1.1)` —— **只来自 EFI**，系统卷里一份都没有 |

### 5.1 一个反例：U 盘 EFI 为什么 AirDrop 坏

| | U 盘 EFI | 内部盘 EFI |
|---|---|---|
| 无线驱动 | **`itlwm.kext`**（Intel，走 `IOEthernetController`） | **`AirPortBrcmNIC-Tahoe.kext`**（Broadcom，走 `IO80211Family`） |
| `DeviceProperties:Add` | **0 条**（连 `built-in` 都没有） | 3 条（含 Wi-Fi 节点 `built-in=<01>`） |
| 蓝牙 | `IntelBluetoothFirmware` + `BlueToolFixup` | `BlueToolFixup` |
| 结果 | 无 `awdl0` ⇒ **AirDrop / 接力不可用** | `awdl0` + `llw0` RUNNING ⇒ **可用** |

★ 关键细节：U 盘启动时**靠有线（`AppleIGC.kext` + I225-V）上网**，所以用户感受是
「能上网，但 AirDrop / 接力不能用」——**与「Wi-Fi 根本不存在」完全吻合**，容易被误读成「Wi-Fi 正常但 AirDrop 坏了」。

★ 另一个易混项：`brcmfx-country=#a` **只影响可用信道**，不影响 `awdl0` 是否存在。

## 6. 相关文档

- `broadcom-wifi.md` —— 博通卡的完整配置（`awdl0` 的前提是这套栈起来）
- `intel-wifi.md` —— Intel 卡的能力边界（FAQ 原文）
- `mediatek-wifi.md` —— MediaTek 第三方路线的硬限制
- `network-en0-order.md` —— **只管 `en0` 归属与 iServices**，与 AirDrop 无关
