# Intel 无线网卡驱动安装方法（AirportItlwm / itlwm）

> 上游：`OpenIntelWireless/itlwm`（zxystd 等）。
> 本机参考的 fork：**`laobamac/itlwm`**（<https://github.com/laobamac/itlwm>）——
> 它为 **macOS Sequoia 15.2+** 与 **macOS 26 Tahoe** 分别提供 `AirportItlwm` 构建。
> 下文「官方口径」= 该 fork README 原文，「通用做法」= OpenCore 注入的常规步骤。

## 0. 先分清两种形态

| 形态 | 表现 | 版本要求 |
|---|---|---|
| **`AirportItlwm`** | **原生** Wi-Fi：出现在系统 Wi-Fi 菜单里，不需要额外客户端 | **必须与 macOS 版本匹配的构建**（不同 macOS 的 ABI 不同） |
| `itlwm` | 走 ioctl，需要一个用户态客户端（HeliPort）来扫描/连接 | 跨版本可用性较好 |

本 fork 提供的是 **`AirportItlwm`**（Sequoia 目标 + Tahoe 目标），README 里没有 `itlwm` 形态的说明。

## 1. 官方口径（laobamac/itlwm README 原文要点）

**版本线（★ 最关键）**

- `AirportItlwm-Sequoia` 目标：**macOS Sequoia 15.2 及以后**，x86_64；实测于 macOS 15.8 (24H23)
- `AirportItlwm-Tahoe` 目标：**macOS 26.x（Darwin 25.x）**
- ★ 原文：*"Sequoia and Tahoe use separate ABI headers and build products."*
  → *"Use this kext only on Darwin 24.2.0–24.99.99. Keep the Tahoe kext restricted to Darwin 25.x when both systems share an OpenCore configuration."*
  ⇒ **双系统共用一个 OpenCore 配置时，必须用 `MinKernel`/`MaxKernel` 把两个 kext 分别限定在各自的 Darwin 版本**，否则会加载错的那份

**macOS 26 上的能力与限制**

- Wi-Fi 6（802.11ax / HE）**默认关闭**；加 boot-arg **`itlwm_he=1`** 在支持的网卡上启用
- 支持：WPA2-Personal、WPA2/WPA3 过渡网络（含可选 PMF）、扫描 / 连接 / 切换网络 / 私有 Wi-Fi 地址
- **不支持**：WPA3-only、强制 PMF、**AWDL / AirDrop**、MLO
- 设备支持跟随上游硬件表；**Tahoe 兼容性仍需逐网卡验证**

**下载与构建**

- 从 **fork 自己的 Releases** 取 Sequoia / Tahoe 的 **Release** 与 **Debug** 构建
- 自行构建：装 Xcode + Python 3，`MacKernelSDK` 检出到 `MacKernelSDK/`（README 指定 commit `3f750085caa17ec3a7880f11c11bf4f48cd6a164`）

```bash
# Tahoe（macOS 26）
xcodebuild -project itlwm.xcodeproj -scheme AirportItlwm-Tahoe \
  -configuration Release ARCHS=x86_64 CODE_SIGNING_ALLOWED=NO build
# Sequoia（macOS 15.2+）
xcodebuild -project itlwm.xcodeproj -scheme AirportItlwm-Sequoia \
  -configuration Release ARCHS=x86_64 CODE_SIGNING_ALLOWED=NO build
```

- 上游文档（Intro / Compatibility / FAQ）：<https://OpenIntelWireless.github.io/itlwm>

## 2. 装进 OpenCore（通用做法）

1. 把 `AirportItlwm.kext` 放进 `EFI/OC/Kexts/`
2. 在 `Kernel → Add` 加条目，**必须排在 `Lilu.kext` 之后**（Lilu 是宿主）
3. **用 `MinKernel` / `MaxKernel` 限定 Darwin 版本**（见 §1）：Sequoia 那份填 `MinKernel=24.2.0` / `MaxKernel=24.99.99`；Tahoe 那份填 `MinKernel=25.0.0`。用 `uname -r` 查当前 Darwin 版本
4. 需要 Wi-Fi 6 时，boot-args 加 `itlwm_he=1`
5. `Misc → Security → SecureBootModel = Disabled`（第三方 kext 非 Apple 签名）；SIP 按需放宽
6. 重启后验证：

```bash
kmutil showloaded --list-only | grep -i itlwm          # kext 是否加载
system_profiler SPAirPortDataType | head -30           # 是否出现 Wi-Fi 接口
networksetup -listallhardwareports                    # 看有没有 Wi-Fi 端口（en0/en1）
```

## 3. Intel 蓝牙要另外装（别混）

Intel 无线网卡上的**蓝牙**不由 itlwm 负责，需要：

| kext | 作用 |
|---|---|
| `IntelBluetoothFirmware` | 给 Intel 蓝牙控制器加载固件 |
| `IntelBTPatcher` | 补丁（新版 macOS 上常见） |
| `BlueToolFixup` | 修 Bluetooth 栈（新版 macOS 上常与上面两个一起用） |

> 对照：Broadcom 卡走的是另一套（`BrcmPatchRAM*` / `BlueToolFixup` + 系统原生 `IO80211` 栈）。

## 4. 排错

| 现象 | 检查 |
|---|---|
| Wi-Fi 完全不出现在系统里 | `Lilu` 是否加载、`Kernel → Add` 顺序是否 Lilu 在前、kext 是否与当前 macOS **ABI 匹配**（Sequoia/Tahoe 别装错） |
| kext 加载了但没有接口 | `MinKernel`/`MaxKernel` 是否把当前 Darwin 排除掉了（`uname -r`）；`system_profiler SPAirPortDataType` 里有没有接口 |
| 能连 2.4G 连不上 5G / 连上很慢 | HE 是否开了（`itlwm_he=1`）、信道/加密方式是否在支持列表内（WPA3-only 与强制 PMF **不支持**） |
| AirDrop / 接力不可用 | **已知不支持**（AWDL 未实现），不要当故障查 |
| 装完蓝牙坏 | 蓝牙是另一组 kext（§3），先确认那三个的状态 |

## 5. 与「换网卡」的关系（重要）

换掉 Intel 网卡（例如换成 Broadcom BCM943602CDP）之后：

- **必须**把 Intel 无线/蓝牙那三个 kext 从 `Kernel → Add` 里**禁用或删除**，并把 `EFI/OC/Kexts/` 下的文件删掉 —— 否则它们仍会尝试匹配不存在的设备（白加载、日志噪音，某些版本还可能干扰 Bluetooth 栈）
- 删除前先把原件备份出来；判断「是否真的不用」见 `disks-and-kexts.md` 的删除判据
- ★★ **换卡后要确认 `en0` 归属** —— 内核按**驱动挂载先后**给 `en` 编号（与 PCI 顺序无关），
  换卡 / 增删驱动会让 `en0` 换人 ⇒ **详见 `network-en0-order.md`**（含「怎么把无线钉到 `en0`」与连带影响）

> **同一台机器不要同时注入多套网卡驱动**。除 Intel / Broadcom 之外，MediaTek（MT7921 / MT7922 / RZ608）见
> `mediatek-wifi.md` —— 那里的结论是「**蓝牙可用、Wi-Fi 仍实验性**，要稳定就换卡」。

## 6. 安全提示

- 第三方 kext（非 Apple 签名）⇒ 需要 `SecureBootModel=Disabled`，SIP 视情况放宽。**只在你确实要用这张网卡时这么做**
- 从 fork 的 Releases 下载时，注意核对来源仓库与文件哈希；上游是 `OpenIntelWireless/itlwm`，本 fork 是个人维护的分支，**Tahoe 支持仍属「需要逐网卡验证」的状态**
