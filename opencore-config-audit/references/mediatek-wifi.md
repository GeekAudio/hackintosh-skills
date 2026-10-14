# MediaTek 无线网卡（MT7921 / MT7922 / RZ608）在 macOS 上的支持与流程

> ★★★ **2026-10 重大更新：macOS 26（Tahoe）已原生内置 Apple 自己的 MediaTek 驱动**
> （`com.apple.AppleSunriseWLAN.dext` + `com.apple.AppleSunriseBluetooth.dext`，**自带固件**）——
> **优先走原生路线**，见 §0.3 / §1.5；下面的第三方仓库是**退路**。
>
> 上游（第三方路线）：`laobamac` 的三个仓库（同一作者，也是本 skill 里 Intel 无线用的那个 fork 作者）
> - **Wi-Fi（PCIe）**：`laobamac/SimpleMtkWlan` —— *"an experimental macOS kernel extension for MediaTek MT792x PCIe wireless adapters"*
> - **蓝牙（USB）**：`laobamac/SimpleMtkBtFw` —— *"a MediaTek USB Bluetooth driver for macOS"*
> - **Wi-Fi 客户端**：`laobamac/SimpleMTKClient` —— 菜单栏 App（`SimpleMTK`）

## 0. ★★★ 结论先行（先看这段，能省很多时间）

### 0.1 macOS 26 原生内置 MediaTek 驱动 —— 这是首选路线

**macOS 26（Tahoe）自带 Apple 自己的 MediaTek 驱动**，不需要任何第三方 kext：

```
/System/Library/DriverExtensions/
├── com.apple.AppleSunriseWLAN.dext        ← Wi-Fi（代号 Sunrise）
└── com.apple.AppleSunriseBluetooth.dext   ← 蓝牙（★ 自带固件）
```

两者的 `Info.plist` 匹配条件（**本机 macOS 26.7.1 实测读出**）：

| dext | `IOProviderClass` | `IOPCIMatch` | 对应芯片 |
|---|---|---|---|
| `AppleSunriseWLAN` | `IOPCIDevice` | `0x792214c3` `0x792314c3` `0x793214c3` | **MT7922** / MT7923 / MT7932（Wi-Fi） |
| `AppleSunriseBluetooth` | `IOPCIDevice` | `0x792a14c3` `0x792b14c3` `0x793b14c3` | **MT7922** 的蓝牙 / MT7923 / MT793b |

★★ **关键认识：`AppleSunriseBluetooth` 匹配的是 `IOPCIDevice`（PCIe），不是 USB！**
即**较新的 MediaTek 模块，蓝牙是挂在 PCIe 上的**（`14c3:792a`）——
这和下面第三方路线假设的「蓝牙 = USB 设备」是**两代不同的硬件形态**，别混。

**dext 自带固件**（就在 dext 目录里，`/usr/share/firmware/` 下**没有** MediaTek 目录）：

```
com.apple.AppleSunriseBluetooth.dext/
├── BT_RAM_CODE_MT7922_1_1_hdr.bin        576 KB  ← MT7922 蓝牙固件
└── BT_RAM_CODE_MT7923_1_1_hdr_ipc.bin    437 KB

com.apple.AppleSunriseWLAN.dext/IZUBA/            ← MT7932 整套 Wi-Fi 固件
├── IZUBA_WIFI_MT7932_patch_mcu_1_2_hdr.bin
├── IZUBA_WIFI_RAM_CODE_MT7932_1_2_idxlog.bin
├── IZUBA_EEPROM_MT7932_1.bin · IZUBA_WIFI_MFG_MT7932_2.bin
└── IZUBA_TxPwrLimit_*.dat · IZUBA_wifi.cfg · IZUBA_db.dat …
```

**`bluetoothd` 里也有 MediaTek 字符串**（说明蓝牙栈本身就认这些芯片）：

```
BT_RAM_CODE_MT7922 · MT7923 · MT7923A0 · SRS_7922
```

> **`SRS` = SunRise** —— `SRS_7922` 就是 MT7922 在 Sunrise 里的代号。

### 0.2 三条路线怎么选

| 路线 | 蓝牙 | Wi-Fi | 前提 |
|---|---|---|---|
| **① 原生（Sunrise）** | ✅ **Apple 自带** | ✅ **Apple 自带** | **macOS 26+**（Sequoia 没有这两个 dext） |
| ② 第三方 `SimpleMtkBtFw` | ✅ 有 release | — | 蓝牙走 **USB** 的老款模块 |
| ③ 第三方 `SimpleMtkWlan` | — | ⚠️ 实验性（无 release，需自编译） | 愿意折腾 |

> ★★ **先试路线 ①** —— 系统自带，**不用装任何 kext**。
> 只有当「你的模块蓝牙走 USB（老款）」或「系统是 Sequoia」时，才退到 ②/③。
>
> 第三方路线的成熟度（作为对比）：

| 部件 | 第三方路线状态 | 依据 |
|---|---|---|
| 蓝牙（USB） | 可用 | `SimpleMtkBtFw` 有 **`1.0.0`** release；issue #1 标题即 *"MT7922 bluetooth is working"* |
| Wi-Fi（PCIe） | 实验性、未稳定 | `SimpleMtkWlan` README *"The driver is not release-stable yet."*；**无 release**；实机「扫描 OK，一连接就 panic」 |

> **要「能日常用的 Wi-Fi」的兜底做法仍是换卡**（Broadcom 原生 / Intel `AirportItlwm` 成熟）。

### 0.3 先用三行命令判断你该走哪条

```bash
# ① 系统有没有原生 Sunrise 驱动？（有 ⇒ 优先走原生路线）
ls /System/Library/DriverExtensions/ | grep -i sunrise

# ② 你的模块蓝牙是 PCIe 还是 USB？
system_profiler SPUSBDataType    | grep -i -E "MediaTek|0x0e8d"   # USB 侧（老款）
ioreg -l -p IODeviceTree | grep -i "14c3"                          # PCIe 侧（含 792a 蓝牙功能）

# ③ 系统是哪个大版本？（Sequoia 没有 Sunrise ⇒ 只能走第三方）
sw_vers -productVersion && uname -r
```

## 1. 先认芯片（别把型号认错）

| 芯片 | 常见别名 | PCI ID（Wi-Fi） | 蓝牙：**PCIe**（新，Sunrise） | 蓝牙：**USB**（老，第三方） |
|---|---|---|---|---|
| MT7921 | — | `14c3:7961` | — | `0x7961` |
| MT7921K | **AMD RZ608** | `14c3:0608` | — | `0x0608` / `0x7961` |
| **MT7922** | **AMD RZ616**、MT7922A | **`14c3:7922`** | ★ **`14c3:792a`** | **`0x7922`** |
| MT7923 | — | `14c3:7923` | `14c3:792b` | — |
| MT7932 / MT7925 | AMD RZ717 | `14c3:7932` / `14c3:7925` | `14c3:793b` | — （Wi-Fi 6E/7，见 §5 支线） |

★ **同一块 MT7922 模块可能有两种形态**：新的是**蓝牙走 PCIe**（`14c3:792a`，Apple 原生驱动管），
老的是**蓝牙走 USB**（`0x0e8d` + class `0xE0/1/1`，要靠第三方 `SimpleMtkBtFw`）。
**先按 §0.3 的第 ② 条命令判清自己属于哪种。**

- `SimpleMtkWlan` 只声明支持 **MT7921 / MT7921K(RZ608) / MT7922**；README 明说 *"Other MediaTek devices are not currently supported."*
- 蓝牙侧 `SimpleMtkBtFw` 的 `Info.plist` 覆盖 **MT7921 / MT7922 / MT7922A + 一条 MediaTek 通用 USB class 匹配**
  （`idVendor = 3725 (0x0E8D)` + `bDeviceClass 0xE0 / SubClass 1 / Protocol 1`）；
  **但运行时固件流程只接受内部设备 ID `0x7961` / `0x7922`** —— 认错型号 = 固件不加载。

**先查本机到底有没有这张卡：**

```bash
# PCIe 侧（Wi-Fi）
ioreg -l -p IODeviceTree | grep -i "14c3"          # 应看到 14c3:7922 之类
system_profiler SPNetworkDataType | grep -i -B2 -A4 media
# USB 侧（蓝牙）
system_profiler SPUSBDataType | grep -i -B3 -A8 -E "MediaTek|0x0e8d"
```

## 1.5 ★ 原生路线（Sunrise）怎么用 —— macOS 26+

### 前提

- 系统是 **macOS 26（Tahoe）或更新**（`ls /System/Library/DriverExtensions/ | grep -i sunrise` 有输出）
- 你的模块蓝牙**走 PCIe**（`ioreg` 里能看到 `14c3:792a`）

### 步骤（先别装任何 kext）

1. **确认 dext 在位**：`ls /System/Library/DriverExtensions/ | grep -i sunrise` → 应有 `AppleSunriseWLAN.dext` + `AppleSunriseBluetooth.dext`
2. **插上模块 → 重启**
3. **看有没有自动认**：

```bash
# dext 是否加载
kmutil showloaded --list-only | grep -i sunrise
# 蓝牙控制器是否起来（Chipset 会显示 MediaTek 相关）
system_profiler SPBluetoothDataType | head -20
# Wi-Fi 接口是否出现
networksetup -listallhardwareports | grep -A2 -i wi-fi
ioreg -l -p IODeviceTree | grep -i "14c3"
```

4. **能认 ⇒ 到此结束**，不用装第三方 kext、不用改 config。

### 社区做法（**仅记录，未在本机复现**）

tonymacx86 那个帖子（标题 *"Wifi 6(E) & Bluetooth 5.x MEDIATEK chipset on **native** Sequoia & Tahoe"*）里有人报告：

- **注入 `AppleSunrise.kext` via OpenCore** ⇒ *"Tahoe boots properly"*
- 加 boot-arg **`wlan.debug.enable=0x1`**

> ⚠️ **两点保留**：
> 1. 该帖正文被 Cloudflare 验证码挡住，**我只拿到搜索快照**，没读到完整步骤；
> 2. **本机（Z690）用的是 Broadcom `BCM943602CDP`，没有 MediaTek 卡**，所以上面两条**我没有复现**。
>
> ⇒ **建议顺序**：先按上面 1–4 步「**不装任何东西**」试一遍；
> 只有系统确实不认时，再去试社区那两条（`wlan.debug.enable=0x1` 本身是**调试开关**，不是「启用开关」）。
> 要完整步骤 ⇒ 把帖子正文贴给我，我再补进这里。

### Sequoia（macOS 15）怎么办

Sequoia **没有**这两个 dext ⇒ 原生路线走不通，只能走下面的第三方路线（§3 / §4）。

## 2. 三个项目分工

| 项目 | 管什么 | 形态 | 有 Release？ | 现状 |
|---|---|---|---|---|
| `laobamac/SimpleMtkWlan` | **Wi-Fi（PCIe）** | kext（+ `mtk80211` 兼容层） | ❌ **无**（必须自编译） | 实验性，bring-up 中 |
| `laobamac/SimpleMtkBtFw` | **蓝牙（USB）固件加载** | **两个** kext | ✅ **`1.0.0`** | 可用 |
| `laobamac/SimpleMTKClient` | Wi-Fi 菜单栏客户端 | App（`SimpleMTK`） | ❌ 无 | 配套 Wi-Fi 用 |

> 注意分工：**`SimpleMtkBtFw` 不是 Wi-Fi 驱动、也不是独立蓝牙协议栈** ——
> 它只负责「把固件塞进 MediaTek 蓝牙控制器」，**塞完就交给 macOS 自己的蓝牙栈**（和 `IntelBluetoothFirmware` 同一套路，其致谢里也点名了 `zxystd` 与 IntelBluetoothFirmware）。

## 3. 路线 A：蓝牙（推荐先做，成功率高）

### 3.1 安装

1. 从 `SimpleMtkBtFw` 的 **Releases 取 `1.0.0`**（`-RELEASE.zip`；排错期可用 `-DEBUG.zip`）
2. 两个 kext 放进 `EFI/OC/Kexts/`，在 `Kernel → Add` **按此顺序**：

```
[1] Lilu.kext                  ← 宿主，必须在最前
[2] SimpleMtkBtFw.kext         ← 固件加载
[3] SimpleMtkBtPatcher.kext    ← 基于 Lilu 的兼容性补丁
```

3. ★ **只走 OpenCore 注入**（作者明确推荐）；**不要**同时注入另一个会绑定**同一 USB 蓝牙设备**的固件加载器
   （例如同时留 `IntelBluetoothFirmware` / `BrcmPatchRAM*` 会互相抢设备）

### 3.2 ★★ 两个致命坑（来自 `SimpleMtkBtFw` issue #3 的实机验证）

**坑 1：不要把 USB 产品名改成 `Bluetooth USB Host Controller`。**
改了会让 `bluetoothd` 走「**内置**控制器」那条路径 —— 而那条路径**假定芯片是 Broadcom**，
于是在 `_BCM_ReadVerboseConfigVersionInfoParser`（`bcm_vsc.c:1125`）上 abort ——
因为 MediaTek 对 VSC `0xFC79` 的回复格式和 Broadcom 不一样。**保持产品名原样。**

**坑 2：要让 macOS 走「第三方 dongle」路径，必须注入 NVRAM 两条 data。**
判据是这两个键**存在**：

```
7C436110-AB2A-4BBB-A880-FE41995C9F82   （data 类型）
  bluetoothExternalDongleFailed    = 00
  bluetoothInternalControllerInfo  = <14 字节>
```

- 在 OC 里写在 `NVRAM > Add`，**同时 `NVRAM > Delete` 里也必须出现**（官方规则：Add 的键要在 Delete 里才生效）
- ★ **不做对的症状**：`bluetoothd` 每 ~30 s 被看门狗杀掉、蓝牙菜单一直转圈、
  关机卡在 BlueTool、日志里反复 `Can't obtain vendorID and productID`
- 这两条键与 Broadcom 路线用的是**同一对键**（见 `broadcom-wifi.md` §2.3），只是 Broadcom 那边填的是具体控制器信息

**附加坑：AirPods 连上但没声音** = A2DP 的「Read Clock」问题（issue #3 有修法）。

### 3.3 验证

```bash
# 1. kext 是否加载
kmutil showloaded --list-only | grep -i -E "SimpleMtk"
# 2. 内核日志（找固件加载痕迹）
log show --last 5m --style compact --predicate 'process == "kernel"' 2>/dev/null | grep -i -E "SimpleMtk|fw_name"
# 3. IORegistry 看固件是否真的加载了
ioreg -l -p IOService | grep -i -E "FirmwareLoaded|fw_name"
```

- 作者给的判据：日志里的**内部设备 ID 必须是 `0x7961` 或 `0x7922`**；IORegistry 里看 `FirmwareLoaded` 与 `fw_name`
- 系统层面确认：`system_profiler SPBluetoothDataType` 里控制器能起来

## 4. 路线 B：Wi-Fi（实验性，接受风险再上）

### 4.1 现状（别抱错期望）

`SimpleMtkWlan` README 的 Status 段原文 —— 当前开发焦点就是**还没做完的那些**：

> - MT7921/MT7922 PCIe probe and attach
> - Firmware loading
> - DMA queue setup
> - Hardware scan support
> - **Association/authentication TX path debugging**
>
> *"The driver is not release-stable yet."*

对应到实机：

| 能力 | 状态 |
|---|---|
| kext 匹配设备 / probe / attach | ✅ |
| 加载固件 | ✅ |
| 硬件扫描（能看到 SSID） | ✅ |
| **关联 / 连接（输密码上网）** | ⚠️ **仍在修**；实机报告「一连接就卡死或 panic」（issue #3，MT7921） |
| MT7922 专项修复 | issue **#5**（association context、TX 同步、packet ownership），**2026-09-19 过硬件验证，但未合进主线发布** |

### 4.2 怎么装（没有 release，只能自编译）

```bash
git clone https://github.com/laobamac/SimpleMtkWlan
cd SimpleMtkWlan
# 需要：Xcode + 与本地环境匹配的 Kernel SDK 头 + 项目自带的固件生成脚本
xcodebuild -project SimpleMtkWlan.xcodeproj -scheme SimpleMtkWlan -configuration Debug build
# 产物：SimpleMtkWlan.kext
```

- 仓库布局：`SimpleMtkWlan/hal_mwx/` 是 MT7921/MT7922 实现，`mtk80211/` 是 OpenBSD net80211 兼容层
- 许可 **GPLv2**；固件数据由 `scripts/` 里的脚本生成
- 连接网络需要**菜单栏客户端 `SimpleMTK`**（`SimpleMTKClient`，走 ClientKit ioctl API，macOS 10.13+）——
  **它没有 release，同样要 Xcode 编译**；它由 `HeliPort`（Intel 那边那个客户端）改编而来

### 4.3 风险与前置

- **连接即 panic 的可能** ⇒ 上之前：备份 EFI、备好可引导 U 盘、记下回退路径（禁用 kext 即回到「无驱动」状态）
- 不要把「实验性」当「能日常用」；**先只做蓝牙（路线 A），Wi-Fi 等上游 release 再上**

## 5. 支线：USB 网卡 ≠ 主板上的 PCIe 卡

`Network-Weather/mt76-usb-macos` —— 用户态 mt76 USB 驱动，覆盖 **MT7921U（AWUS036AXML）/ MT7925U（Nighthawk A9000）** 这类**USB 网卡**。
**这和主板/笔记本上的 MT7922（PCIe）是两回事**，别混：PCIe 卡走 `SimpleMtkWlan`，USB 网卡走这个。
（另有实机参考：`thanhnndev/ga403wm-hackintosh`，ASUS ROG Zephyrus G14 + MT7925。）

## 6. 决策树

```
芯片是 MediaTek MT792x（14c3:7922 / 7923 / 7932 / 7961 / 0608）？
│
├─ 系统是 macOS 26+，且蓝牙走 PCIe（14c3:792a）
│   └─► ★★★ 路线 ①：原生 Sunrise —— 什么都不用装，插上重启看认不认（§1.5）
│           不认再考虑社区那两条（AppleSunrise.kext 注入 / wlan.debug.enable=0x1）
│
├─ 系统是 Sequoia，或蓝牙走 USB（0x0e8d）
│   └─► 路线 ②：SimpleMtkBtFw（有 release，成功率高）
│           记得 §3.2 的两个坑：不改产品名 + 注入两条 NVRAM data
│
└─ 要 Wi-Fi
   ├─ macOS 26+ 且芯片在 7922/7923/7932 里 ─► 先试原生（路线 ①）
   ├─ 要稳定能用 ─► 换卡：Broadcom（原生，broadcom-wifi.md）
   │                 或 Intel + AirportItlwm（intel-wifi.md）
   └─ 愿意折腾 ───► 路线 ③：自编译 SimpleMtkWlan + SimpleMTK 客户端
                    接受「能扫描、但连接可能 panic」；先备份 EFI
```

## 7. 排错

| 现象 | 检查 |
|---|---|
| **原生路线**：Sunrise dext 在但不加载 | ① 芯片是否在 `IOPCIMatch` 列表里（`0x792214c3`/`792a14c3` 等，见 §0.1）；② 蓝牙是不是 PCIe 形态（USB 形态不吃这个驱动）；③ `kmutil showloaded \| grep -i sunrise` 看有没有加载 |
| **原生路线**：Wi-Fi 认了但连不上 | 先看是不是被 **`en0` 归属** / 网络服务顺序影响（⇒ **`network-en0-order.md`**）；再看系统日志里 Sunrise 相关行 |
| 蓝牙 kext 加载了但控制器起不来 | NVRAM 两条 data 是否**同时在 `Add` 和 `Delete`**（§3.2 坑 2） |
| `bluetoothd` 反复重启 / 蓝牙菜单转圈 / 关机卡 BlueTool | 同上；并确认**没有**把产品名改成 `Bluetooth USB Host Controller` |
| 日志里固件没加载 | 内部设备 ID 是不是 `0x7961` / `0x7922`；USB 是否被 `Info.plist` 匹配（`idVendor 0x0E8D` + class `0xE0/1/1`） |
| AirPods 连上无声 | A2DP Read Clock 问题（issue #3） |
| Wi-Fi kext 加载但无接口 | `SimpleMtkWlan` 是 Debug 构建？设备 ID 是否在支持列表？ |
| Wi-Fi 能扫描但一连接就卡死/panic | **已知**：关联/TX 路径未完成（issue #3/#5），不是配置错 |
| 装了蓝牙但另一套 BT 固件加载器也在 | 移除冲突项（同一条纪律见 `intel-wifi.md` §5「换网卡后要清理」） |

## 8. 安全提示与边界

- 三个 kext 都**非 Apple 签名** ⇒ 需要 `SecureBootModel=Disabled`，SIP 视情况放宽；**只在确实要用这张卡时这么做**
- `SimpleMtkWlan` 明确是 **GPLv2 的实验性 bring-up 项目**，**没有 release**；从源码构建前先看清 `CREDITS.md` 与固件再分发条款
- 与 `broadcom-wifi.md` / `intel-wifi.md` 的关系：**同一台机器不要同时注入三套网卡驱动**；
  换卡后按 `intel-wifi.md` §5 的纪律把旧的一套**禁用或删除**，并注意 **`en0` 归属**会随驱动挂载顺序变化（⇒ **`network-en0-order.md`**）
- **本 reference 是通用流程**；本机（Z690）用的是 Broadcom `BCM943602CDP`，**没有 MT7922**。
  - **§0.1 的原生路线事实（两个 dext、`IOPCIMatch`、自带固件、`bluetoothd` 字符串）是在本机 macOS 26.7.1 上实测读出的** —— 这部分是硬证据
  - **§1.5 的「社区做法」与 §3/§4 的第三方路线**未在本机复现（没有对应硬件）—— 按 §0.3 / §1 先确认芯片与形态，再逐步验证
