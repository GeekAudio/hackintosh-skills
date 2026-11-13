# Intel 无线网卡驱动选择与安装

> 上游：`OpenIntelWireless/itlwm`（zxystd 等）。
> 实践中用得较多的 fork：**`laobamac/itlwm`**（<https://github.com/laobamac/itlwm>）——
> 它为 **macOS Sequoia 15.2+** 与 **macOS 26 Tahoe** 分别提供 `AirportItlwm` 构建。
> 下文的版本区间、依赖和配置示例针对该 fork。需要 Intel AirDrop 时，单独评估 [ForbiddenItlwm](forbidden-itlwm.md) 的发布包、目标系统构建和实测范围。

## 0. 先按目标选路线

| 目标 | 路线 | 选择条件 |
|---|---|---|
| 常规联网，使用系统 Wi-Fi 菜单 | **`AirportItlwm`**，下文列出 laobamac 构建 | 核对目标 macOS ABI 和实际网卡 |
| 常规联网，可使用额外客户端 | 上游 `itlwm.kext` + HeliPort，客户端通过 ioctl 扫描和连接 | 按该发行版检查网卡和系统范围 |
| 明确需要在 Intel 网卡上测试 AirDrop | [ForbiddenItlwm 实验路线](forbidden-itlwm.md) | 先核对精确 macOS 构建号、网卡及配套蓝牙；用备用 EFI 验证并保留常规联网回退 |

laobamac 的 Sequoia / Tahoe 发布说明针对 **`AirportItlwm`** 两个目标。`itlwm.kext` + HeliPort 按 OpenIntelWireless 的发布与说明选择。

## 1. laobamac/itlwm 的发布说明

**版本线（★ 最关键）**

- `AirportItlwm-Sequoia` 目标：**macOS Sequoia 15.2 及以后**，x86_64；实测于 macOS 15.8 (24H23)
- `AirportItlwm-Tahoe` 目标：**macOS 26.x（Darwin 25.x）**
- [fork 的 main 分支说明](https://github.com/laobamac/itlwm/blob/main/README.md) 要求 Sequoia 构建仅用于 Darwin `24.2.0`–`24.99.99`，双系统共用配置时 Tahoe 构建限于 Darwin 25.x。
  ⇒ **双系统共用一个 OpenCore 配置时，用 `MinKernel` / `MaxKernel` 把两份构建分别限定在各自支持的区间**，见 §2 的独立条目示例。

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

## 2. 将 laobamac 的 AirportItlwm 装进 OpenCore

1. 将所需构建放进 `EFI/OC/Kexts/`。双系统并存时，分别命名外层 bundle 为 `AirportItlwm-Sequoia.kext` 与 `AirportItlwm-Tahoe.kext`（示例名称），不要将两份同名 `AirportItlwm.kext` 互相覆盖，也不要让两个条目指向同一份文件。
2. 在 `Kernel → Add` 加条目，按实际 `OSBundleLibraries` 核对依赖与加载顺序。所述 fork 的
   [Tahoe](https://github.com/laobamac/itlwm/blob/main/AirportItlwm/WCL/Info.plist) /
   [Sequoia](https://github.com/laobamac/itlwm/blob/main/AirportItlwm/WCL/Sequoia-Info.plist)
   构建依赖 Apple 网络栈，**不是 Lilu 插件**；不要仅为 AirportItlwm 新增 Lilu。蓝牙补丁自己的依赖另见 §3。
3. **按下表分别填写 `BundlePath` 和版本范围**。`ExecutablePath` / `PlistPath` 相对于各自 bundle，按包内实际内容填写；更改外层目录名不代表要重命名内部可执行文件。用 `uname -r` 查当前 Darwin 版本。

   | 构建 | `BundlePath`（示例） | `MinKernel` | `MaxKernel` |
   |---|---|---|---|
   | macOS 15.2+ Sequoia | `AirportItlwm-Sequoia.kext` | `24.2.0` | `24.99.99` |
   | macOS 26 Tahoe | `AirportItlwm-Tahoe.kext` | `25.0.0` | `25.99.99` |

   两个条目均设 `Enabled=true`，OpenCore 按当前内核版本选择。`MaxKernel` 留空会允许未来的 Darwin 26 及以后，不符合此 fork 限于 Darwin 25.x 的要求；上下限同时设置时须满足 `MinKernel ≤ MaxKernel`。

4. 需要 Wi-Fi 6 时，boot-args 加 `itlwm_he=1`
5. 按该构建作者对目标系统的要求核对 `SecureBootModel` 与 SIP；第三方 kext 的签名本身不足以推出应关闭这些保护，已有设置可用时保留
6. 重启后验证：

```bash
kmutil showloaded --list-only | grep -i itlwm          # kext 是否加载
system_profiler SPAirPortDataType | head -30           # 是否出现 Wi-Fi 接口
networksetup -listallhardwareports                    # 看有没有 Wi-Fi 端口（en0/en1）
```

## 3. 常规 Intel 蓝牙路线

常规 Wi-Fi 驱动和蓝牙组件分别核对。下表列出 Intel 蓝牙的常用组件：

| kext | 作用 |
|---|---|
| `IntelBluetoothFirmware` | 给 Intel 蓝牙控制器加载固件 |
| `IntelBTPatcher` | 补丁（新版 macOS 上常见） |
| `BlueToolFixup` | 修 Bluetooth 栈（新版 macOS 上常与上面两个一起用） |

> 对照：Broadcom 卡走的是另一套（`BrcmPatchRAM*` / `BlueToolFixup` + 系统原生 `IO80211` 栈）。

使用 ForbiddenItlwm 的 AirDrop 实验路线时，按[配套蓝牙与互斥说明](forbidden-itlwm.md)部署。`BTLEAdvFixup` 与 `IntelBTPatcher` 钩住同一函数，启用配套 `BTLEAdvFixup` 的系统须禁用 `IntelBTPatcher`。

## 4. 排错

| 现象 | 检查 |
|---|---|
| Wi-Fi 完全不出现在系统里 | 查目标设备匹配、启用状态、实际 Apple 网络栈依赖与当前 macOS **ABI**（Sequoia/Tahoe 别装错）；不要以 Lilu 是否加载判断 AirportItlwm 状态 |
| kext 加载了但没有接口 | `MinKernel`/`MaxKernel` 是否把当前 Darwin 排除掉了（`uname -r`）；`system_profiler SPAirPortDataType` 里有没有接口 |
| 能连 2.4G 连不上 5G / 连上很慢 | 在 laobamac 的构建上核对 HE 开关（`itlwm_he=1`）与信道、加密方式；其发布说明列 WPA3-only 与强制 PMF 为未支持 |
| AirDrop 不可用 | 先辨认具体构建。OpenIntelWireless 原版 AirportItlwm 和本专题所列 laobamac 构建均不支持 AirDrop；ForbiddenItlwm 按[实验路线](forbidden-itlwm.md)及[连续互通排查](airdrop-handoff.md)核对 |
| Handoff / 通用剪贴板不可用 | [OpenIntelWireless FAQ](https://openintelwireless.github.io/itlwm/FAQ.html) 将这两项列为原版 AirportItlwm 的能力。核对所用构建、蓝牙、账号与功能开关，见[连续互通排查](airdrop-handoff.md) |
| 装完蓝牙坏 | 检查实际安装路线的蓝牙依赖与互斥条件，见 §3 |

## 5. 与「换网卡」的关系（重要）

换掉 Intel 网卡（例如换成 Broadcom BCM943602CDP）之后：

- 先确认换下的设备确实不再使用，再禁用其专用驱动；若机器仍有其他 Intel 无线或蓝牙设备，保留需要的驱动。
  `BlueToolFixup` 可被其他蓝牙方案使用，不能连同 Intel 专用固件加载器一并机械删除。
  需要清理文件时同步处理对应 config 引用，不因换一张卡就删除全部无线/蓝牙驱动。
- 删除前先把原件备份出来；判断「是否真的不用」见 `disks-and-kexts.md` 的删除判据
- ★★ **换卡后要确认 `en0` 归属** —— 内核按**驱动挂载先后**给 `en` 编号（与 PCI 顺序无关），
  换卡 / 增删驱动会让 `en0` 换人 ⇒ **详见 `network-en0-order.md`**（有线可以是 `en0`，不要求无线必须排第一）

> 同一无线设备只选一套驱动。`itlwm`、`AirportItlwm` 和 `ForbiddenItlwm` 的迁移还须核对目标系统的配套互斥约束。
> 先核对 vendor/device ID 与实际绑定对象。MediaTek（MT7921 / MT7922 / RZ608）的具体路线与限制见
> [MediaTek 专题](mediatek-wifi.md)，是否换卡取决于所需功能和目标系统验证。

## 6. 安全提示

- 放宽 `SecureBootModel` / SIP 前，核实具体构建、目标系统与当前故障确实需要，说明恢复路径；不能把所有第三方 kext 都归为同一安全设置需求
- 从 Releases 下载时核对来源仓库与发布包。laobamac 构建的 Tahoe 兼容性须逐网卡验证，ForbiddenItlwm 的实验范围按[该路线](forbidden-itlwm.md)逐系统构建核对。
