# 博通网卡（BCM943602CDP / BCM43602）配置流程

> 依据：一次 15.8.1 → 26.7.1 的实战记录（本机 ASUS Z690，见 `machine-facts.md`）+
> OCLP 的 `efi_builder/networking/wireless.py`（Modern Wireless 分支）逐字对齐的写法。
> **按卡型、macOS 与补丁版本选择路线**。OCLP 的 Modern Wireless 检测将这些旧 Broadcom 卡的
> 原生支持截止于 Sonoma 之前；不能推广为所有 Broadcom 卡都在 Sequoia 才失去支持。
> 依据：[OCLP Modern Wireless](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/opencore_legacy_patcher/sys_patch/patchsets/hardware/networking/modern_wireless.py)。

## 0. 先认清卡

| 部件 | 芯片 | 位置 | 说明 |
|---|---|---|---|
| Wi-Fi | **BCM43602** | **PCIe**，`14e4:43ba` | FullMAC，3×3 802.11ac；subsystem `0x14E4,0x16D`（= Apple） |
| 蓝牙 | **BCM20703** | **USB**（主板 9-pin 内部排针） | Apple 原厂芯片，macOS 原生支持 |

> ★ **从 15 升到 26 时这张卡的驱动要换**（`AirPortBrcmNIC-Tahoe.kext`，`MinKernel 25.0.0`）
> ⇒ 完整升级流程见 `os-upgrade-15-to-26.md`。

- ★ **蓝牙不走 PCIe**：卡上那条 9-pin 内部 USB 线不接就只有 Wi-Fi、没有蓝牙
- ★ **BCM20703 固件在卡上** ⇒ 一般**不需要** `BrcmPatchRAM3` / `BrcmFirmwareData`（那是给非原厂博通卡的）
- 多个无线 / 蓝牙控制器并存时，先确认实际绑定与用户需要；仅在证据指向控制器竞争或原设备确实不再使用时禁用对应设备 / 专用驱动。

## 1. ★★ 按系统分路线（核心）

| | **macOS 15 Sequoia（Darwin 24）** | **macOS 26 Tahoe（Darwin 25）** |
|---|---|---|
| Wi-Fi 内核驱动 | `IO80211FamilyLegacy.kext` + 它内部的 **`AirPortBrcmNIC.kext` 插件** | **独立的 `AirPortBrcmNIC-Tahoe.kext`** |
| 内核条目版本限制 | plugin：`MinKernel 23.0.0` / **`MaxKernel 24.99.99`** | 独立 kext：**`MinKernel 25.0.0`** / `MaxKernel` 空 |
| 驱动来源 | OCLP 2.5.1 的 kext 集 | **OCLP 3.0.0-rc.3+** 新增的 Tahoe 版（`payloads/Kexts/Wifi/AirPortBrcmNIC-Tahoe-v1.0.0.zip`） |
| 为什么不一样 | — | OCLP 2.5.1 的 `AirPortBrcmNIC.kext` 带 `MaxKernel=24.99.99` ⇒ **升到 Tahoe 后条目被跳过 ⇒ Wi-Fi 直接消失** |
| 用户态（root patch） | **必须**打 OCLP root patch | **同样需要**（用 OCLP 3.0.0+ 打） |
| 双系统共用一个配置 | 两条都留着，**靠 `MinKernel`/`MaxKernel` 各管一段**：Sequoia 条目 `MaxKernel 24.99.99`，Tahoe 条目 `MinKernel 25.0.0` | 同左 |

> **双系统共用一份配置时的典型做法是「两条并存」**：plugin 版 `AirPortBrcmNIC.kext` 给 Sequoia 段用，
> `AirPortBrcmNIC-Tahoe.kext` 给 Tahoe 段用。**只装 Tahoe 一台机器就只留后者**，plugin 版可以直接删掉
> （不必为了「保留」而留一个被 `MaxKernel` 挡掉的死条目）。

## 2. 两版都要做的部分

### 2.1 `Kernel → Block`（OCLP 路线的前提）

- **移除**（如果之前为省电/排障屏蔽过）：`IOBluetoothFamily`、`IOBluetoothHIDDriver`、`AppleBluetoothModule`、
  `AppleBluetoothMultitouch`、`IO80211Family`
- **新增**：
  ```
  Identifier : com.apple.iokit.IOSkywalkFamily
  Strategy   : Exclude
  MinKernel  : 23.0.0
  Enabled    : true
  ```
  （OCLP 路线要**替换** IOSkywalkFamily，所以先屏蔽系统的）

### 2.2 `Kernel → Add`（顺序不能反）

```
[1] IOSkywalkFamily.kext          MinKernel 23.0.0
[2] IO80211FamilyLegacy.kext      MinKernel 23.0.0
[3] AirPortBrcmNIC.kext（plugin） MinKernel 23.0.0 / MaxKernel 24.99.99   ← Sequoia
[4] AirPortBrcmNIC-Tahoe.kext     MinKernel 25.0.0                        ← Tahoe
[5] BlueToolFixup.kext            （是否需要，按具体蓝牙控制器与当前作者说明核对）
```

- **顺序依据（来自 kext 自己的 `OSBundleLibraries`）**：`IO80211FamilyLegacy` 依赖
  `com.apple.iokit.IOSkywalkFamily 1.0`；`AirPortBrcmNIC` 依赖 `com.apple.iokit.IO80211FamilyLegacy 600.0`
  ⇒ **IOSkywalkFamily 必须在最前**，顺序错了会「有图标但连不上/打不开」
- `AirPortBrcmNIC.kext` 的 `IONameMatch` 里就有 **`pci14e4,43ba`** —— 正是这张卡
- Tahoe 那条的字段（照 OCLP 3.0.0 的写法）：
  `BundlePath=AirPortBrcmNIC-Tahoe.kext` / `ExecutablePath=Contents/MacOS/AirPortBrcmNIC` /
  `PlistPath=Contents/Info.plist` / `MinKernel=25.0.0` / `Arch=x86_64`
- 不将 Intel 驱动与 Broadcom 驱动的并存本身判为冲突；确认原 Intel 设备不再使用后再清理其专用驱动。
  互斥要求针对同一设备的不同实现，见 [Intel 换卡说明](intel-wifi.md)。

### 2.3 NVRAM：按控制器与驱动要求核对

先读取现值和实际蓝牙控制器，已正常工作时保留。不能把某台机器的非零
`bluetoothInternalControllerInfo` 当作所有 BCM20703 / Sonoma / Sequoia 的必填值。

[BrcmPatchRAM 的 BlueToolFixup 说明](https://github.com/acidanthera/BrcmPatchRAM#bluetoolfixupkext)
对至少 Intel 蓝牙给出的示例是以下 data（十六进制表示），**这不自动构成当前 Broadcom 控制器的注入要求**：

```
bluetoothExternalDongleFailed   = 00
bluetoothInternalControllerInfo = 0000000000000000000000000000   # 14 字节全零
```

确有作者要求或故障证据时，按目标控制器确定值；不要复制参考机器的控制器身份。
新变量可通过 `NVRAM > Add` 提供默认值，只有明确要覆盖已有值时才先列入 `NVRAM > Delete`。
依据：[OpenCore NVRAM Add 定义](https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.tex)。

### 2.4 USB 端口映射（最容易翻车的一步）

用 `USBToolBox.kext` + `UTBMap.kext` 时，**没写进映射表的端口会被直接禁用**：

- 蓝牙所在端口按实际 `ioreg` 与插拔验证确定，连接器类型 `UsbConnector` / `usb-port-type` 使用 **Integer `255`** (Internal)。
- 原 Intel 蓝牙端口只有在设备不再使用且该口无需保留时才移除。**`port-count` 重新取保留端口中的最大端口号，不能按删除条目数减一**；
  例如删 HS14 但 SS25 仍保留，值仍为 25。依据：[USBMap 计算](https://github.com/corpnewt/USBMap/blob/master/USBMap.py)。
- 验证（读的是**端口对象上的实际值**，不是只看配置文件）：
  ```bash
  ioreg -p IOUSB -w0 -l | grep -i -A3 "bluetooth"     # 应见 Bluetooth USB Host Controller / BCM20703
  ```

### 2.5 `built-in` 注入（Dortania 的 `en0` / iServices 要求）

先查现有 built-in 与实际设备路径；下面路径仅为参考机器示例，不能直接复制到另一主板。

```
DeviceProperties → Add →
  PciRoot(0x0)/Pci(0x1C,0x1)/Pci(0x0,0x0)
    built-in = <01>          ← Data 类型，值 1 字节 01
```

- 路径怎么来的：从 IODeviceTree 回溯祖先链 `Root / PC00@0 / RP02@1C,1 / PXSX@0` ⇒
  `PciRoot(0x0)/Pci(0x1C,0x1)/Pci(0x0,0x0)`（与 iGPU 的 `PciRoot(0x0)/Pci(0x2,0x0)` 同规则）
- **为什么是 `01`**：Dortania《OpenCore Post-Install · iServices》原文 —— `built-in` 用 `Data` 类型、值 `01`；
  实测 PCIe 设备默认都是 `<00>`（= 非内建）
- 验证：`ioreg -p IOService -l -w0 | grep -B30 '"IOName" = "pci14e4,43ba"' | grep built-in`

## 3. 用户态：OCLP root patch（两版都要）

对所述 OCLP Modern Wireless 路线，除内核组件外还需恢复对应用户态组件
（`IO80211.framework` / `wifip2pd` / `WiFiPeerToPeer.framework`）。
先核对具体卡型、目标系统构建与 OCLP 发行版是否支持；单机目录内容不是所有 Broadcom 卡的统一判据。
依据：[OCLP 补丁清单](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/opencore_legacy_patcher/sys_patch/patchsets/hardware/networking/modern_wireless.py)。

```
1) 备份并核对现有第三方驱动是否受本次 OCLP 清理影响（见 §3.1）
2) 装 OCLP（Sequoia 用 2.5.1+；Tahoe 用 3.0.0-rc.3+）—— 必须走 .pkg 装
   （它的 privileged-helper 靠 SUID 提权，root patch 依赖这个）
3) 打开 OpenCore-Patcher.app → Post-Install Root Patch → Start Root Patching
   应看到 "Networking: Modern Wireless"（OCLP 按 PCI 的 0x43BA 识别，在官方支持列表里）
4) 重建 dyld shared cache 可能要 10–30 分钟，别中断 → 重启
5) 重启后记录 Wi-Fi 的实际 `enX` 并检查联网；核对 `en0` 是否存在且 built-in，不要求 Wi-Fi 必须为 `en0`
   ⇒ 见 `network-en0-order.md`
```

> 网卡与补丁变化后分别验证联网、iServices 与所需连续互通功能。接口编号变化不等于故障，正常有线 `en0` 与无线 `en1` 可以并存；不要为 AirDrop 重排接口或改 ROM。见 [接口顺序](network-en0-order.md) 与 [连续互通](airdrop-handoff.md)。

### 3.1 root patch 前检查现有系统侧驱动

先备份完整 EFI、相关系统侧驱动和版本 / 哈希清单，核对**所用 OCLP 版本**的
[AuxKC 清理逻辑](https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/opencore_legacy_patcher/sys_patch/kernelcache/kernel_collection/support.py)。
当前代码既可能删除先前补丁记录中的 kext，也会在特定系统上迁移 mtime 早于 2021-10-01 的 `/Library/Extensions/*.kext`。
仅改时间戳不能阻止前一种清理。

参考机器的 NullMoth 四个 kext 曾因 epoch 时间戳被迁移。目标机器若确有同类情况，
优先按相关驱动作者 / OCLP 版本的兼容流程处理；确需调整时间戳时，只针对已核实、备份且仍需使用的目标 kext。
**不要为绕过清理而 touch 整个 `/Library/Extensions` 中的旧驱动**，也不假定存在一份本技能未附带的保护脚本。

打补丁后对照清单检查原有驱动是否仍在、内容与哈希是否符合预期，检查 `/Library/Relocated Extensions` 的实际迁移项，
再核对 AuxKC 构建结果。失败时按备份恢复或停止于可恢复状态，不反复叠加补丁。
root patch 的安全设置按具体补丁要求调整并记录；不能仅因使用 Broadcom 卡就无条件关闭 SIP / SecureBootModel。

## 4. 验证判据

| 检查 | 期望 |
|---|---|
| `kmutil showloaded --list-only \| grep 80211` | 4 行：`IOSkywalkFamily`、`corecapture`、`IO80211FamilyLegacy`、`AirPort.BrcmNIC` |
| `ioreg` 里驱动是否绑上卡 | `"IONameMatched" = "pci14e4,43ba"`、`"IOClass" = "AirPort_BrcmNIC"` |
| Wi-Fi 联网 | 先用 `networksetup -listallhardwareports` 确定实际 `enX`，再结合关联、IP / DHCP、路由与实际连接测试；不固定要求 `en1` |
| AWDL（AirDrop/接力） | `ifconfig` 里有 **`awdl0`**（AirLink）与 **`llw0`**（LowLatency）且 UP/RUNNING |
| 蓝牙 | `system_profiler SPBluetoothDataType` **秒回**；`Chipset: BCM_20703A2`、`Transport: USB` |
| 蓝牙死锁是否根除 | `log show --last 3m --predicate 'process == "bluetoothd"' \| grep -c "Couldn't find IOBluetoothHCIController"` = **0** |

> ★★ **别只看 `system_profiler SPAirPortDataType` 判 Wi-Fi 死活**：重启后驱动要读卡、关联、DHCP，
> 十几秒才起来。本机就出现过「验证时返回空 ⇒ 以为失败，其实只是还没初始化」的假警报。
> 使用实际接口名综合验证，不能只用某条命令或固定的 `en1` 作为成功 / 失败判据。

## 5. 国家码 / 速率：什么时候才需要 `AirportBrcmFixup`

| 场景 | 做法 |
|---|---|
| 系统已自动协商出正确的 `IO80211CountryCode`（本机 = `CN`，信道表 1–13 / 36–64 / 149–165 与中国划分完全吻合） | **不要动**（人工干预只会帮倒忙） |
| 预期信道不可用 | 核对实际地区、AP 国家码、网卡支持及驱动协商结果；只有确认错误识别时才评估 AirportBrcmFixup，参数须符合实际使用地区，不以伪装地区突破功率限制 |
| 速率不到理论值 | 先查 AP 的空间流数：BCM43602 是 **3×3**，若 AP 只有 2×2 就只能 2 流（3×3 卡配 2×2 AP，867 Mbps 属正常） |

## 6. 代价与回滚

| 项 | 代价 |
|---|---|
| OCLP 换掉 `IOSkywalkFamily` | 可能影响依赖该栈的 DriverKit 网卡驱动；核对当前系统、依赖和加载日志。I225/I226 按[有线网卡专题](ethernet-drivers.md)选择已验证组合，不因此强制切换 AppleIGC |
| OCLP root patch | 更新可能需要完整系统下载并重新打补丁；按所用 OCLP 版本的更新说明执行，更新前按 §3.1 核对前置条件与驱动备份 |
| 加回蓝牙/Wi-Fi kext | 启动会变慢一些（当初屏蔽蓝牙/Wi-Fi 换来 137 s→91 s，现在要还一部分） |
| 回滚 | 修改前备份完整 EFI 与工作区；EFI 从已验证备份恢复，系统 root patch 用所用版本的 Revert Root Patches。仅在实际工具明确提供撤销命令时使用它 |

## 7. 实测事实（可作参考值）

| 项 | 值 |
|---|---|
| Wi-Fi 卡 | `(0x14E4, 0x16D)`，固件 `Broadcom BCM43xx 1.0 (7.77.111.1 AirPortDriverBrcmNIC-1772.1)` |
| 接口 | `en1`（Infrastructure）+ **`awdl0`**（AirLink）+ **`llw0`**（LowLatency） |
| 速率/信号 | 802.11ac / Ch36 (5 GHz, 80 MHz) / WPA2 / **867 Mbps** / MCS 9 / -36 dBm |
| 蓝牙 | `BCM_20703A2`，Vendor `0x004C (Apple)`，FW `v76 c4290`，USB 端口 **HS11**（`UsbConnector=255`） |
| 支持的蓝牙服务 | HFP AVRCP A2DP HID Braille **LEA AACP GATT** SerialPort（后三个是 Continuity 需要的） |
| `built-in` | `PciRoot(0x0)/Pci(0x1C,0x1)/Pci(0x0,0x0)` = `<01>` |
| 国家码 | `IO80211CountryCode = CN`（自动协商正确，**不需要** `AirportBrcmFixup`） |

### 踩过的环境坑

1. **macOS 自带 zsh 没有 `timeout`**（没装 coreutils）⇒ 脚本里 `timeout N cmd` 会**静默失败**，
   会让「蓝牙探针 0 秒返回」变成**假结果**。写验证脚本时要自带 bash 版 timeout 兼容层。
2. **`log show` 在沙箱里永远跑不了**（`log: Cannot run while sandboxed`）⇒ 日志类诊断得走提权 AppleScript 或让用户手动跑。
3. **Wi-Fi 的设备节点名不是 `ARPT`**，是 `AirPort_BrcmNIC` / `en1`；`ioreg -l -w0` 不加过滤会输出几百 KB。
4. **改配置时注意别踩到别的任务**：本机曾出现「另一个会话同时改同一份 config」（iGPU 注入 + 删 `-wegnoigpu`）
   ⇒ 改动前**必读 live 并对 diff**；`NVRAM>Delete` 含 `boot-args` 时，配置文件里的值**下次重启就会覆盖实际生效值**。
5. **EFI 盘号会漂**：同一次会话里 `diskutil list` 先后给过两个不同的 EFI 分区号 ⇒ 一律按卷 UUID / 现查。
