# 有线网卡（Intel / Realtek）第三方驱动

> 依据：`laobamac` 的 **`SimpleVGBE`** / **`SimpleGBE`** / **`SimpleHacPlugins`** / **`SimpleRTK5`** 官方 README。
> **相关**：`network-en0-order.md`（★ 换驱动会改变 `en0` 归属）、`intel-wifi.md` §5（换网卡后要清理旧驱动）、
> `laobamac-toolkit.md`（工具索引）。

## 0. 什么时候需要

macOS **原生不认**的板载 / 扩展有线网卡。

> ★★ **本机（ASUS Z690）板载是 Intel `I225-V`** —— 原生不认，必须第三方驱动。
> 本机目前用的是 **`AppleIGC.kext`**，本文里的方案是它的**替代品**。

## 1. Intel 2.5G —— **I225 / I226**

| 方案 | 说明 |
|---|---|
| **`laobamac/SimpleVGBE`** | *"Intel **2.5G** Ethernet driver for macOS. Based on **I225** firmware in LinuxKernel V6.5"* —— 支持 **I225 / I226**（具体硬件 ID 见仓库 `igc_hw.h`）；移植自 Linux 的 IGC 驱动 |
| **`laobamac/SimpleHacPlugins` → `SimpleEthernet`** | **Lilu 插件**，注入 i225/226/210/211 驱动。原文：*"Put it into `EFI/OC/Kexts` and enable it, then reboot. **Only Ventura and newer system need it!**"*；Sonoma 14.5 实测 **2.5G 速率与虚拟机网络正常** |

**支持情况（`SimpleVGBE`）**：IPv4/IPv6 DHCP · TCP 校验和 · **TSO / TSO6** · 网线热插拔与重分配 · 支持 Sequoia
**已知限制**：强制速率受 `igc_ethtool_set_link_ksettings()` 影响**无法生效**

> ★ **本机注意**：换驱动会改变**驱动挂载顺序** ⇒ **可能让 `en0` 换人**（见 `network-en0-order.md`）。
> **换之前先记下当前 `en0` 是谁**（`networksetup -listallhardwareports`）。

## 2. Intel 千兆 —— I210 / I211 / 82575·76·80 / I350

| 方案 | 说明 |
|---|---|
| `laobamac/SimpleGBE` | 移植自 Ubuntu 的 `EthernetIgb-5.17.4`；支持 **I210 · I211 · 82575/82576/82580 · I350/I350T4**；**支持 Sequoia**；自 v1.0.1 起支持**自定义速率与 MTU 9000** |
| `SimpleHacPlugins → SakuraLegacyFix` | Intel **I350 / X540** —— **测试中，暂无下载**（作者说将并入 `SakuraEthernet`） |

> ⚠️ **`SimpleGBE` 自 2026-06-18 起进入存档状态**，不再更新（作者原话）。

## 3. Realtek —— RTL8125 / RTL8126

| 方案 | 说明 |
|---|---|
| **`laobamac/SimpleRTK5`** | **RTL8125 / 8126 的 2.5 / 5GbE 驱动**；原生兼容 macOS 网络栈（**支持 AppleVTD**）；支持 **ASPM** 与 **TSO**；可用 boot-arg / 设备属性调**轮询间隔** |
| ~~`laobamac/SimpleRTLHV`~~ | ★ **已并入 `SimpleRTK5`，不要再单独用**（原定位：RTL8125 2.5G 的 Lilu 插件） |

## 4. 装法与判据

**装**：

1. `.kext` 放进 `EFI/OC/Kexts/`，`Kernel → Add` 加条目
   ★ **`SimpleEthernet` 是 Lilu 插件** ⇒ 必须排在 **`Lilu` 之后**
2. 改 ESP 走**安全流程**：备份 → 改 → `plutil -lint` → `ocvalidate` → `sync` → 卸载重挂 → 复验 sha

**★ 纪律：一次只换一套** ——
**同一台机器不要同时注入多套有线驱动**（`AppleIGC` + `SimpleVGBE` 会**互相抢设备**）。
换驱动时先把旧的那套 `Enabled=false` 或删掉（判据见 `disks-and-kexts.md`）。

**验证**：

```bash
ifconfig en0 | head -3                  # 有没有 inet + status: active
networksetup -listallhardwareports      # ★ 确认 en0 归属（见 network-en0-order.md）
system_profiler SPEthernetDataType | head -30
```

> ★★ **换完必须复查 `en0`** —— 换驱动会改变挂载顺序，`en0` 可能换人 ⇒
> `ROM` / iMessage / Continuity 会**静默失效**（详见 `network-en0-order.md`）。

## 5. 安全提示

- 这些 kext 都**非 Apple 签名** ⇒ 需要 `SecureBootModel=Disabled`，SIP 视情况放宽
- 从 Releases 取包时**核对来源仓库与文件哈希**；`SimpleGBE` 这类**已存档**的项目不会再修 bug
- 有线网卡**不影响 Wi-Fi**，但会影响 `en0` 归属与网络服务顺序 ⇒ 改完顺带看一眼「系统设置 → 网络」里的服务顺序
