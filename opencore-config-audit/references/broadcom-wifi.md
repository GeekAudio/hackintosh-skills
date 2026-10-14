# 博通网卡（BCM943602CDP / BCM43602）配置流程

> 依据：本机（ASUS Z690 / macOS 15.8.1 → 26.7.1）的实战记录 +
> OCLP 的 `efi_builder/networking/wireless.py`（Modern Wireless 分支）逐字对齐的写法。
> **★ 本流程必须按 macOS 版本分开走** —— 苹果从 Sequoia 起把 Broadcom Wi-Fi 驱动删了，
> 而 Sequoia 与 Tahoe 的补法**不是同一套**。

## 0. 先认清卡

| 部件 | 芯片 | 位置 | 说明 |
|---|---|---|---|
| Wi-Fi | **BCM43602** | **PCIe**，`14e4:43ba` | FullMAC，3×3 802.11ac；subsystem `0x14E4,0x16D`（= Apple） |
| 蓝牙 | **BCM20703** | **USB**（主板 9-pin 内部排针） | Apple 原厂芯片，macOS 原生支持 |

- ★ **蓝牙不走 PCIe**：卡上那条 9-pin 内部 USB 线不接就只有 Wi-Fi、没有蓝牙
- ★ **BCM20703 固件在卡上** ⇒ 一般**不需要** `BrcmPatchRAM3` / `BrcmFirmwareData`（那是给非原厂博通卡的）
- ★ 拔掉/屏蔽**原来的 Intel 网卡**（本机是 AX201，蓝牙 `8087:0026`）：两个蓝牙控制器会让 macOS 犯迷糊

## 1. ★★ 按系统分路线（核心）

| | **macOS 15 Sequoia（Darwin 24）** | **macOS 26 Tahoe（Darwin 25）** |
|---|---|---|
| Wi-Fi 内核驱动 | `IO80211FamilyLegacy.kext` + 它内部的 **`AirPortBrcmNIC.kext` 插件** | **独立的 `AirPortBrcmNIC-Tahoe.kext`** |
| 内核条目版本限制 | plugin：`MinKernel 23.0.0` / **`MaxKernel 24.99.99`** | 独立 kext：**`MinKernel 25.0.0`** / `MaxKernel` 空 |
| 驱动来源 | OCLP 2.5.1 的 kext 集 | **OCLP 3.0.0-rc.3+** 新增的 Tahoe 版（`payloads/Kexts/Wifi/AirPortBrcmNIC-Tahoe-v1.0.0.zip`） |
| 为什么不一样 | — | OCLP 2.5.1 的 `AirPortBrcmNIC.kext` 带 `MaxKernel=24.99.99` ⇒ **升到 Tahoe 后条目被跳过 ⇒ Wi-Fi 直接消失** |
| 用户态（root patch） | **必须**打 OCLP root patch | **同样需要**（用 OCLP 3.0.0+ 打） |
| 双系统共用一个配置 | 两条都留着，**靠 `MinKernel`/`MaxKernel` 各管一段**：Sequoia 条目 `MaxKernel 24.99.99`，Tahoe 条目 `MinKernel 25.0.0` | 同左 |

> 本机现状就是「两条并存」：plugin 版 `AirPortBrcmNIC.kext` = **禁用**（注释 Sequoia only），
> `AirPortBrcmNIC-Tahoe.kext` = **启用**（注释 Tahoe / Darwin 25+）。

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
[5] BlueToolFixup.kext            （蓝牙必需，macOS 12+）
```

- **顺序依据（来自 kext 自己的 `OSBundleLibraries`）**：`IO80211FamilyLegacy` 依赖
  `com.apple.iokit.IOSkywalkFamily 1.0`；`AirPortBrcmNIC` 依赖 `com.apple.iokit.IO80211FamilyLegacy 600.0`
  ⇒ **IOSkywalkFamily 必须在最前**，顺序错了会「有图标但连不上/打不开」
- `AirPortBrcmNIC.kext` 的 `IONameMatch` 里就有 **`pci14e4,43ba`** —— 正是这张卡
- Tahoe 那条的字段（照 OCLP 3.0.0 的写法）：
  `BundlePath=AirPortBrcmNIC-Tahoe.kext` / `ExecutablePath=Contents/MacOS/AirPortBrcmNIC` /
  `PlistPath=Contents/Info.plist` / `MinKernel=25.0.0` / `Arch=x86_64`
- ★ **`itlwm.kext` 必须禁用**（Intel 网卡驱动，会和博通冲突）

### 2.3 NVRAM（`7C436110-…-FE41995C9F82`，**data 类型**）

```
bluetoothExternalDongleFailed   = 00
bluetoothInternalControllerInfo = 000000000000000089653a552efd
```

（Sonoma/Sequoia 起蓝牙必需的「控制器信息」注入；缺了蓝牙打不开）

### 2.4 USB 端口映射（最容易翻车的一步）

用 `USBToolBox.kext` + `UTBMap.kext` 时，**没写进映射表的端口会被直接禁用**：

- 蓝牙所在端口（本机 **HS11**）的 `UsbConnector` 设为 **`255` (Internal)**
- **移除原 Intel 蓝牙端口**（本机 HS14）；`port-count` 相应减 1
- 验证（读的是**端口对象上的实际值**，不是只看配置文件）：
  ```bash
  ioreg -p IOUSB -w0 -l | grep -i -A3 "bluetooth"     # 应见 Bluetooth USB Host Controller / BCM20703
  ```

### 2.5 `built-in` 注入（Dortania 的 en0 / Continuity 要求）

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

**为什么必须打**：实测系统里 `/System/Library/Extensions/IO80211Family.kext` **是个空壳**
（`IOKitPersonalities` 空字典、连 `Contents/MacOS` 都没有），全盘 `find -iname "*AirPortBrcm*"` 为空
⇒ 苹果在 Sequoia 把博通 Wi-Fi 驱动整个删了。**内核层**靠上面注入的 kext 补回来，
**用户态框架**（`IO80211.framework` / `wifip2pd` / `WiFiPeerToPeer.framework`）必须靠 **root patch**。

```
1) ★ 先跑保护脚本（见 §3.1）
2) 装 OCLP（Sequoia 用 2.5.1+；Tahoe 用 3.0.0-rc.3+）—— 必须走 .pkg 装
   （它的 privileged-helper 靠 SUID 提权，root patch 依赖这个）
3) 打开 OpenCore-Patcher.app → Post-Install Root Patch → Start Root Patching
   应看到 "Networking: Modern Wireless"（OCLP 按 PCI 的 0x43BA 识别，在官方支持列表里）
4) 重建 dyld shared cache 可能要 10–30 分钟，别中断 → 重启
```

### 3.1 ★★ 打补丁前必须先跑保护脚本（否则 NVIDIA 驱动会失效）

OCLP 打补丁前会执行 `clean_auxiliary_kc()`（`sys_patch/kernelcache/kernel_collection/support.py`）：

```python
for file in Path("/Library/Extensions").glob("*.kext"):
    if datetime.fromtimestamp(file.stat().st_mtime) < datetime(2021, 10, 1):
        # → 移动到 /Library/Relocated Extensions
```

而 NullMoth NVIDIA 那 4 个 kext（`NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC`）的 **mtime 是 epoch 0**
⇒ **会被搬走 ⇒ NVIDIA 驱动失效**。

**处置**：先跑保护脚本，它做两件事 ——
① 把整个 `/Library/Extensions` 备份出来；② 把 mtime 早于 2021-10-01 的 kext 目录 **`touch` 成当前时间**
（**只改时间戳、不改内容**，不影响加载）。跑完打印复查结果，全 ✅ 才继续。

打完补丁后**务必复查**：

```bash
ls -1 /Library/Extensions/*.kext                  # NVIDIA 4 件套还在
ls -1 "/Library/Relocated Extensions" 2>/dev/null # 应该为空/不存在
```

## 4. 验证判据

| 检查 | 期望 |
|---|---|
| `kmutil showloaded --list-only \| grep 80211` | 4 行：`IOSkywalkFamily`、`corecapture`、`IO80211FamilyLegacy`、`AirPort.BrcmNIC` |
| `ioreg` 里驱动是否绑上卡 | `"IONameMatched" = "pci14e4,43ba"`、`"IOClass" = "AirPort_BrcmNIC"` |
| ★ Wi-Fi 是否真的活 | **看 `ifconfig en1`（要有 `inet` + `status: active`）**，或 `ioreg -n en1 -r -l -w0 \| grep -E "IO80211SSID\|IO80211BSSID\|IOControllerEnabled"` |
| AWDL（AirDrop/接力） | `ifconfig` 里有 **`awdl0`**（AirLink）与 **`llw0`**（LowLatency）且 UP/RUNNING |
| 蓝牙 | `system_profiler SPBluetoothDataType` **秒回**；`Chipset: BCM_20703A2`、`Transport: USB` |
| 蓝牙死锁是否根除 | `log show --last 3m --predicate 'process == "bluetoothd"' \| grep -c "Couldn't find IOBluetoothHCIController"` = **0** |

> ★★ **别只看 `system_profiler SPAirPortDataType` 判 Wi-Fi 死活**：重启后驱动要读卡、关联、DHCP，
> 十几秒才起来。本机就出现过「验证时返回空 ⇒ 以为失败，其实只是还没初始化」的假警报。
> **`ifconfig en1` 才是硬判据。**

## 5. 国家码 / 速率：什么时候才需要 `AirportBrcmFixup`

| 场景 | 做法 |
|---|---|
| 系统已自动协商出正确的 `IO80211CountryCode`（本机 = `CN`，信道表 1–13 / 36–64 / 149–165 与中国划分完全吻合） | **不要动**（人工干预只会帮倒忙） |
| AP 用了 **100–140（DFS）** 信道，或要突破发射功率 | 才需要 `AirportBrcmFixup.kext` + `brcmfx-country=US`（或 HK/KR） |
| 速率不到理论值 | 先查 AP 的空间流数：BCM43602 是 **3×3**，若 AP 只有 2×2 就只能 2 流（本机 867 Mbps 属正常） |

## 6. 代价与回滚

| 项 | 代价 |
|---|---|
| OCLP 换掉 `IOSkywalkFamily` | **所有 DriverKit 网卡驱动失效** ⇒ Intel i225/i226 必须改用 `AppleIGC.kext`（IOKit 驱动） |
| OCLP root patch | **不能用增量 OTA**；**每次系统更新后都要重打**（且每次都要先跑 §3.1 的保护脚本） |
| 加回蓝牙/Wi-Fi kext | 启动会变慢一些（当初屏蔽蓝牙/Wi-Fi 换来 137 s→91 s，现在要还一部分） |
| 回滚 | 改 config + 换 kext 之前先备份；本机的做法是「脚本 + `--revert`」+ ESP/工作区双备份 |

## 7. 本机实测事实（可直接引用）

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

1. **本机 zsh 没有 `timeout`**（没装 coreutils）⇒ 脚本里 `timeout N cmd` 会**静默失败**，
   会让「蓝牙探针 0 秒返回」变成**假结果**。写验证脚本时要自带 bash 版 timeout 兼容层。
2. **`log show` 在沙箱里永远跑不了**（`log: Cannot run while sandboxed`）⇒ 日志类诊断得走提权 AppleScript 或让用户手动跑。
3. **Wi-Fi 的设备节点名不是 `ARPT`**，是 `AirPort_BrcmNIC` / `en1`；`ioreg -l -w0` 不加过滤会输出几百 KB。
4. **改配置时注意别踩到别的任务**：本机曾出现「另一个会话同时改同一份 config」（iGPU 注入 + 删 `-wegnoigpu`）
   ⇒ 改动前**必读 live 并对 diff**；`NVRAM>Delete` 含 `boot-args` 时，配置文件里的值**下次重启就会覆盖实际生效值**。
5. **EFI 盘号会漂**：同一次会话里 `diskutil list` 先后给过两个不同的 EFI 分区号 ⇒ 一律按卷 UUID / 现查。
