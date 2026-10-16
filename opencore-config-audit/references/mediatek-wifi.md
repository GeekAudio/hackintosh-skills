# MediaTek 无线网卡（MT7921 / MT7922 / RZ608）在 macOS 上的支持与流程

> ★★★ **2026-10 重大更新：macOS 26（Tahoe）已原生内置 Apple 自己的 MediaTek 驱动**
> （`com.apple.AppleSunriseWLAN.dext` + `com.apple.AppleSunriseBluetooth.dext`，**自带固件**）——
> **优先走原生路线**，见 §0.3 / §1.5；下面的第三方仓库是**退路**。
>
> 上游（第三方路线）`laobamac` 的三个仓库（同一作者，也是本 skill 里 Intel 无线用的那个 fork 作者）
> - **Wi-Fi（PCIe）**：`laobamac/SimpleMtkWlan` —— *"An experimental macOS kernel extension for MediaTek MT792x PCIe wireless adapters."*
> - **蓝牙（USB）**：`laobamac/SimpleMtkBtFw` —— *"a MediaTek USB Bluetooth driver for macOS"*
> - **Wi-Fi 客户端**：`laobamac/SimpleMTKClient` —— 菜单栏 App（`SimpleMTK`）
>
> ★★ **2026-10-13 起的实用进展：第三方 Wi-Fi 请用 `flxxxxddd/SimpleMtkWlan` 这个 fork**（上游 laobamac 仓库的 fork，
> 分支 **`mt7921-fixes`**，**有 CI 构建的 release**）—— 它修好了「MT7921 / RZ608 能 attach 但过不了流量」的问题，
> 并补上 **802.11n（HT20/40）+ 802.11ac（VHT80）**。详见 §4。
>
> ★★★ **2026-10-16：原生路线有人打包好了 —— `GeekAudio/mediatek-sunrise-hackintosh`（MT7922 Sunrise Pack）**
> 把原来散在 tonymacx86 帖子附件里的东西收齐了：**MT7922 Wi-Fi 固件**（linux-firmware 官方 + SHA256SUMS）·
> **两个版本从 KDK 原样提取的 `AppleSunrise.kext`**（26.7.1/25G241 与 26.3/25D5087f）· **`SSDT-ARPT_RP04_Mediatek.aml`** ·
> **免编译的 `DeviceProperties` 伪装片段** · `Kernel>Add` 片段 · boot-args 清单 · macOS 15 第三方 kext 全套（含**预编译 SimpleMTK.app**）。
> ⇒ **要用原生 Sunrise 路线，先拿这个包**，不用去翻 69 页帖子找附件。详见 §1.5。

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

★★ **2026-10-16 补充实测（本机 26.7.1/25G241）**：「26.7.1+ 什么都不用装」只对一半成立：
- **蓝牙 dext 已内置** `BT_RAM_CODE_MT7922_1_1_hdr.bin`（+MT7923）→ 26.7.1 蓝牙免操作 ✅
- **WLAN dext 的 `IZUBA/` 只有 MT7932 一套 Wi-Fi 固件**，`find … -iname '*7922*'` 为空 ⇒
  **MT7922 的 Wi-Fi 固件在 26.7.1 仍缺失**，「升级免写固件」对 MT7922 Wi-Fi 不成立、对 MT7932 成立
- `AppleSunrise.kext` 26.7.1 仍**不在** `/System/Library/Extensions`，仅 KDK 有；
  KDK 可用 Dortania GitHub 镜像（`dortania/KdkSupportPkg/releases`，按 build 号选），
  提取法：`hdiutil attach` KDK.dmg → `pkgutil --expand-full KernelDebugKit.pkg` →
  `KDK.pkg/Payload/System/Library/Extensions/AppleSunrise.kext`（x86_64+arm64e，LSMinimumSystemVersion 26.7）

### 0.2 三条路线怎么选

| 路线 | 蓝牙 | Wi-Fi | 前提 |
|---|---|---|---|
| **① 原生（Sunrise）** | ✅ **Apple 自带** | ✅ **Apple 自带** | **macOS 26+**（Sequoia 没有这两个 dext） |
| ② 第三方 `SimpleMtkBtFw` | ✅ 有 release | — | 蓝牙走 **USB** 的老款模块 |
| ③ 第三方 `flxxxxddd/SimpleMtkWlan` | — | ⚠️ **能用但非原生**（**有 release v1.2.0**） | 接受「以太网式接口 + 菜单栏客户端」 |

> ★★ **先试路线 ①** —— 系统自带，**不用装任何 kext**。
> 只有当「你的模块蓝牙走 USB（老款）」或「系统是 Sequoia」时，才退到 ②/③。
>
> 第三方路线的成熟度（作为对比）：

| 部件 | 第三方路线状态 | 依据 |
|---|---|---|
| 蓝牙（USB） | 可用 | `SimpleMtkBtFw` 有 **`1.0.0`** release；issue #1 标题即 *"MT7922 bluetooth is working"*（fork：`flxxxxddd/SimpleMtkBtFw`，AirPods 音频可用） |
| Wi-Fi（PCIe） | ★ **能用，但有硬限制**（2026-10 起） | `flxxxxddd` fork 有 **release v1.1.0 / v1.2.0**；**MT7921 / RZ608 实测能连上网**；但 **802.11ax 不支持**、**没有原生 Wi-Fi 菜单**、**AirDrop / Handoff / Continuity 不可能** ⇒ §4 |

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

# ④ 上面都不缺 ⇒ 原生路线缺的只是「打包好的固件/kext/片段」⇒ 用
#    GeekAudio/mediatek-sunrise-hackintosh（MT7922 Sunrise Pack，见 §1.5）
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

### 社区做法（2026-01 调试全程，已从帖子全文还原；未在本机复现）

tonymacx86 帖子 *"Wifi 6(E) & Bluetooth 5.x MEDIATEK chipset on **native** Sequoia & Tahoe"*
（楼主 **Elias64Fr**，CaseySJ / Sn0wMan / f10 等参与实测；**全帖 69+ 页**，帖子 ID 332855）
——**开发者没有 GitHub**：Elias64Fr / CaseySJ 均无公开仓库，BlueToolFixup 修改版、
固件包、`SSDT-ARPT_RP04_Mediatek.aml`、日志全部以**论坛附件**形式分发（§9）。

**调试时间线**：

| 时间 | 事件 |
|---|---|
| 2025-12-07 | Elias64Fr 逆向 `bluetoothd`，发现 MediaTek BT 支持（Sequoia 1 个 / Tahoe 7 个 USB 设备），固件放 `/etc/bluetool` |
| 2026-01-07 | 发现 `AppleSunriseWLAN.dext`；Ghidra 逆出 `_wlanDebugInit`（默认 log level `0x2F`）；注入 **KDK 里的 `AppleSunrise.kext`** 后 `start ok`，但报 `Failed to open wifi.cfg` / `WIFI_MT7922_patch_mcu_1_1_hdr.bin` |
| 2026-01-19~20 | CaseySJ / Elias64Fr / Sn0wMan 实测（见下方步骤）；确认固件缺失是根因 |
| 2026-01-23 | 等 Apple 1 月发布会补固件 |
| 2026-10（今） | 帖子第 69 页：**macOS 26.7.1 上已有人报告 "It works!"**；本机 26.7.1 实测 dext 已自带 BT 固件 + IZUBA(MT7932) Wi-Fi 固件 |

> ★★★ **别手工翻帖子附件了 —— 用 `GeekAudio/mediatek-sunrise-hackintosh`（MT7922 Sunrise Pack，MIT）**：
>
> | 目录 | 内容 |
> |---|---|
> | `firmware/` | `WIFI_MT7922_patch_mcu_1_1_hdr.bin`(134 KB) · `WIFI_RAM_CODE_MT7922_1.bin`(1.1 MB，写入时改名 **`W7922_1.bin`**) · `BT_RAM_CODE_MT7922_1_1_hdr.bin`(505 KB，USB 蓝牙用) + `SHA256SUMS`（取自 **linux-firmware** 官方 `mediatek/`） |
> | `kexts/macos26/` | **`AppleSunrise.kext`（26.7.1/25G241）** 与 **`AppleSunrise-26.3.kext`（26.3/25D5087f，原帖同款）** —— 官方 KDK 原样提取，x86_64+arm64e |
> | `patches/` | `Kernel-Add-AppleSunrise.xml` · **`DeviceProperties-Add.xml`（免编译 device-id 伪装）** · `boot-args.txt` |
> | `ssdt/` | `SSDT-ARPT_RP04_Mediatek.aml`（原帖修正版，按 root port 改 4 行） |
> | `kexts/macos15/` | Sequoia 第三方路线全套：Lilu 1.7.3 + `SimpleMtkBtFw` + `SimpleMtkBtPatcher` + `SimpleMtkWlan` + **预编译好的 `SimpleMTK-1.0.0.zip`** |
> | `research/notes/docs/` | 全套调试笔记（含日志判读表） |
>
> ★ **`wifi.cfg` 不在包里**（Apple 私有配置；缺失时刷屏 `wlanCfgSet` 报错但**不致命**，仅补固件仍可能以 `wlanRemove` 收场）。

**完整调试/实测步骤（CaseySJ & Elias64Fr，2026-01-19）**：

1. 装 M.2 MT7922 模块（M.2→PCIe 转接卡）
2. **OpenCore 注入 `AppleSunrise.kext`**（取自 KDK，如 `KDK_26.3_25D5087f`）⇒ Tahoe 能启动
   ★★ **它是什么**：**内核态的 HAL（硬件抽象层）**，**只存在于 KDK 里、系统卷上没有**。
   DEXT 是**用户态**的，**不注入这个 HAL 它根本操作不了寄存器** ⇒ 这是**原生路线的必需项**，不是可选优化。
3. 加 boot-arg **`wlan.debug.enable=0x1`**（NVRAM）⇒ 解锁 DEXT 详细日志
4. **设备树/device-id**：DEXT 的 Info.plist 只匹配 `0x7922` ⇒ 原生 `0x616`（RZ616）要用
   **SSDT 把 device-id 伪造成 `0x7922`**（`SSDT-ARPT_RP04_Mediatek.aml`，按实际 root port 改 4 行；
   MT7925 造假成 `22790000`）。同时要给 PXSX 补 DEXT 相关属性，否则 info.plist 阶段就不匹配
5. 收集日志：`log show --style compact --debug --last boot --predicate 'drv.'`
   （`--info` 才出 info 级；纯 `drv.` 谓词可能为空）
6. **驱动请求的固件文件**：`wifi.cfg`、`WIFI_MT7922_patch_mcu_1_1_hdr.bin`
   （另需 `WIFI_RAM_CODE_MT7922_1.bin`，按驱动请求改名为 `W7922_1.bin`）
7. **开机崩溃缓解 boot-args**（0x7922 会让 DEXT 反复重启拖垮系统）：
   `mtk.wlan.startdelay=30`（Fenvi AX5400）/ `=45`（ASUS PCE-AXE59BT）；终极手段 `mtk.wlan.hangonstart=1`
8. **往系统卷塞固件**（Elias64Fr，实测可行）：Recovery 里 `csrutil disable` +
   `csrutil authenticated-root disable` → 挂载主 Tahoe 卷（非 data）→ 固件拷进去
   （`root:wheel`、`644`）→ `sudo bless --folder .../CoreServices --bootefi --create-snapshot`

**调试结论**：
- 根因 = **Wi-Fi 固件 + `wifi.cfg` 不在 DEXT 里**；只塞固件不够（缺 wifi.cfg ⇒ 满屏
  `wlanCfgSet` 报错，Elias64Fr 说配置表只有 256 项、这些不致命，但随后驱动以
  `wlanRemove` + `Disabling PCI device` 收场）
- 原生 `0x616` 即使伪装成 `0x7922` 也展不开设备树（反汇编显示 0x616 被同等配置）
- f10 在 macOS 26.3 beta + KDK_26.3 kext 上见到**完整 AWDL 支持**（唯一接近成功的报告）
- BT 侧独立可用：改装 `BlueToolFixup`（3 组 VID/PID）即插即用；AirPods 无声需
  「忘记设备 → iPhone/iPad 重新配对 → Mac 端重连」（CaseySJ 给 Sn0wMan 的修复）

### device-id 伪装：SSDT 与「免编译 DeviceProperties」二选一

DEXT 的 `Info.plist` **只匹配 `0x7922`**（另 7923 / 7932），而 **RZ616 原生是 `0x616`** ⇒ 必须伪造。

| 方式 | 做法 | 备注 |
|---|---|---|
| **A. SSDT（原帖方案）** | `SSDT-ARPT_RP04_Mediatek.aml` 拷入 `EFI/OC/ACPI/` + `ACPI>Add` 启用 | 默认按 **RP04** 写；**其它 root port 要改其中 4 行重新编译** |
| **B. DeviceProperties（免编译）** | 在 `DeviceProperties>Add` 里给网卡路径加 `device-id` | ★ 不用编译 SSDT，改 plist 即可 |

**B 的 `device-id` 是 4 字节小端 base64**：

| 目标 | device-id 字节 | `<data>` 值 |
|---|---|---|
| **MT7922（推荐）** | `22 79 00 00` | **`InkAAA==`** |
| MT7925 | `25 79 00 00` | **`JXkAAA==`** |

生成命令：`printf '\x22\x79\x00\x00' | base64`（`0x22`=22、`0x79`=79）。
★ **切勿改动 `vendor-id`（保持 `0x14c3`）**；路径用
`ioreg -l | grep -B30 'device-id' | grep -E 'acpi-path|pcidebug'` 找（或 Hackintool PCIe 列表 / Linux `lspci`）。
★★ **如果卡被 `SSDT-Disable_Network_*.aml` 藏掉了**（`ioreg -l | grep -A40 'pci14c3'` 显示 `ffffffff`），
**先禁用它** —— 这条对第三方路线同样成立（§4.4）。

### 相关 boot-args

| boot-arg | 作用 |
|---|---|
| **`wlan.debug.enable=0x1`** | 解锁 `AppleSunriseWLAN.dext` 的 `drv.I` 详细日志（排错用，稳定后去掉）。★ 只是**调试开关，不是启用开关** |
| **`mtk.wlan.startdelay=30`** | DEXT 延迟 30 s 启动 —— **0x7922 伪装后 DEXT 每 ~10 s 重试崩溃会拖垮系统**；Fenvi AX5400 实测 30 够，**ASUS PCE-AXE59BT 需 `=45`** |
| **`mtk.wlan.hangonstart=1`** | 驱动挂起自锁，**保证能进系统**（Wi-Fi 不可用，**终极手段**） |

### ★ 日志判读表（Debug 的核心）

收集：`log show --style compact --debug --last boot --predicate 'drv.'`
（**info 级要加 `--info`**；纯 `drv.` 谓词可能为空，换 `--info` 再试，属正常）。

| 日志行 | 含义 | 对策 |
|---|---|---|
| `DK: AppleSunriseWLAN::start ok` | DEXT 已 attach、**HAL 注入成功** | — |
| `Failed to open .../wifi.cfg` | 缺配置文件 | Dext 内补入 |
| `Failed to open .../WIFI_MT7922_patch_mcu_1_1_hdr.bin` | 缺 MCU 补丁固件 | 系统卷快照注入 |
| `request_firmware: Failed to find firmware file` | 同上（另一条代码路径） | 同上 |
| `wlanCfgSet:(INIT ERROR) wifi config there is no empty entry`（**刷屏**，键如 `LlwLatencyDbg`/`NanWarmUpTime`/`AwdlGenCap`） | `wifi.cfg` 缺失，配置表仅 256 项 | Elias64Fr：**不致命**（但补固件后会出现更严重错误） |
| `wlanDownloadPatch:(INIT WARN) FW[2] load error!` | 固件加载失败 | 补固件 |
| `wifiFirmwareLoader: Waiting for firmware to load`（再无后续） | 固件加载器卡死 | 佐证固件缺失是根因 |
| `wlanRemove` + `Disabling PCI device` | **驱动放弃并移除设备** | ★ 调试失败的**终点信号** |
| `IOUserServer(com.apple.AppleSunriseWLAN) has crashed too many times` panic | DEXT 崩溃循环 | `startdelay` / `hangonstart` 缓解 |
| `corecapture: Missing ivars in CCLogPipe` | CoreCapture 日志管道问题 | 观察项，非阻塞 |

### 26.7.1 到底「自带」了什么（**按芯片分，别信传言**）

> 曾传言「升级到 26.7.1 就自带全部固件」**并不准确**。26.7.1(25G241) 实测：

| 部件 | 26.7.1 状态 |
|---|---|
| **蓝牙固件**（MT7922 / MT7923） | ✅ **已在 `AppleSunriseBluetooth.dext` 内**（`BT_RAM_CODE_MT7922_1_1_hdr.bin`）⇒ 走 PCIe 的 **什么都不用装** |
| **MT7932 / RZ717 的 Wi-Fi 固件** | ✅ 已在 `AppleSunriseWLAN.dext` 内（IZUBA 一套）⇒ **换这张卡才是真正的零操作解** |
| **MT7922 / RZ616 的 Wi-Fi 固件** | ❌ **仍缺失**（dext 内没有 `*7922*` 文件，日志仍报 `Failed to open WIFI_MT7922_patch_mcu_1_1_hdr.bin`）⇒ **仍需按本包补** |

### 不想动系统卷？按这个优先级挑

| 方案 | 做法 | 代价 |
|---|---|---|
| **① 换 MT7932（RZ717）卡** | 26.7.1 已内置其全部 Wi-Fi 固件 | 换硬件 |
| **② 第三方 kext 路线** | `SimpleMtkWlan` + `SimpleMtkBtFw`（固件打包在 kext 内，**只动 EFI、完全不碰系统卷**） | 以太网式接口、无原生 Wi-Fi 菜单、无 AirDrop/Handoff/Continuity、无 802.11ax |
| **③ 只要蓝牙** | `/etc/bluetool/` + `BT_RAM_CODE_MT7922_1_1_hdr.bin`（26.7.1+ 已内置免操作） | — |
| **④ 仍用原生驱动** | 上面的「写固件 + bless 快照」 | 需一次 bless；**本身就是可回滚写法**，`wifi.cfg` 可不写 |

★ **bless 快照法比「长期关 SIP」安全**：macOS 本来就工作在快照上，建新快照后从新快照启动；
**改回 SIP + authenticated-root 重启会自动清理**，无需手动还原。

### AirDrop / Handoff / Continuity 呢？

- **原生路线理论上支持 AWDL** —— f10 在 macOS 26.3 beta + KDK_26.3 kext 上是**唯一见到完整 AWDL 支持**的配置；
- **但 MT7922 实测成功率有限，不保证** ⇒ **别为了 AirDrop 走这条路**；
- 要 AirDrop / Continuity / Wi-Fi 6 ⇒ **换 Broadcom 或 Intel 卡**（第三方路线更是**设计上不可能**，§4.1）。

### 回滚

1. 改回 **RELEASE** 版 OpenCore、删掉 `wlan.debug.enable=0x1` 等 boot-arg、禁用 SSDT / `Kernel>Add` 条目 ⇒ 回到原状
2. 系统卷改动：**启用 SIP + authenticated-root 重启即自动清理**，无需手动还原

> ⚠️ **保留**：**本机（Z690）没有 MediaTek 卡，以上均未复现**。
> `wlan.debug.enable=0x1` 是**调试开关不是启用开关**；26.0–26.2 这套手动注入流程
> **已被 Apple 后续更新取代**（现在先试「什么都不装」，§1.5 步骤 1–4）。

### Sequoia（macOS 15）怎么办

Sequoia **没有**这两个 dext ⇒ 原生路线走不通，只能走下面的第三方路线（§3 / §4）。

## 2. 项目分工（上游 vs fork —— 别认错仓库）

| 项目 | 管什么 | 形态 | 有 Release？ | 现状 |
|---|---|---|---|---|
| ★ **`flxxxxddd/SimpleMtkWlan`**（**fork**，分支 `mt7921-fixes`） | **Wi-Fi（PCIe）** | kext | ✅ **v1.1.0 / v1.2.0**（CI 构建） | **★ 第三方路线就用它** —— MT7921/RZ608 实测能上网 |
| `laobamac/SimpleMtkWlan`（**上游**） | Wi-Fi（PCIe） | kext（+ `mtk80211` 兼容层） | ❌ **无**（必须自编译） | 上游主线，bring-up 中；fork 的修复**还没回到主线** |
| `laobamac/SimpleMtkBtFw` / fork `flxxxxddd/SimpleMtkBtFw` | **蓝牙固件加载**（firmware loader + patcher） | **两个** kext | ✅ **`1.0.0`** | 可用（fork 说明：AirPods 音频可用） |
| `laobamac/SimpleMTKClient` | Wi-Fi 菜单栏客户端 | App（`SimpleMTK`） | ❌ **上游确无 release**（2026-10-16 API+网页双查） | **必需的** —— 见 §4.1。2026-10-16 已在本机从其源码编译出 `SimpleMTK-1.0.0.zip`（内嵌 Sparkle 2.10.0 源码构建；因本机 `sandbox-exec` 被系统禁用，需先剥离两个未用的 SPM 依赖再编 KeychainAccess/Sparkle） |
| ★ **`GeekAudio/mediatek-sunrise-hackintosh`**（**MT7922 Sunrise Pack**，2026-10-16 新建） | **原生路线的一站式包**：Wi-Fi 固件（linux-firmware + SHA）· 两个版本的 `AppleSunrise.kext` · SSDT · `DeviceProperties` 伪装 · `Kernel>Add` 片段 · boot-args 清单 · macOS 15 第三方 kext 全套（含**预编译 SimpleMTK.app**） | 文件集合 | 无 release（直接 clone） | **要走原生 Sunrise 先拿这个**，不用翻 69 页帖子找附件 |

> **fork 与上游的关系**：`flxxxxddd/SimpleMtkWlan` fork 自 `laobamac/SimpleMtkWlan`，
> 在**上游 + PR #5**（`mavizao` 的 MT7922 关联/TX 修复）之上再修了一大批问题（清单见 §4.6）。
> ★ **fork 仓库的 issue 是关的**（`has_issues=false`）⇒ **反馈问题要回上游（`laobamac/SimpleMtkWlan`）开 issue**。
> ★ **默认分支是 `mt7921-fixes`，不是 `main`** —— 手工 clone 后记得切过去。

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

## 4. 路线 B：Wi-Fi（第三方：`flxxxxddd/SimpleMtkWlan`）

### 4.1 ★★ 先接受三条硬限制（决定它能不能满足你）

1. **它是「以太网式」接口（`enX`），不是原生 Wi-Fi（`IO80211Family`）**
   ⇒ **没有 macOS 原生 Wi-Fi 菜单**，扫描 / 连网全靠 **SimpleMTK** 菜单栏客户端。
2. **❌ AirDrop / Handoff / Continuity** —— README 原话 *"not possible with this design"*
   ⇒ **这是设计决定的，不是 bug，别去排查**。
3. **❌ 802.11ax（HE / Wi-Fi 6）尚未支持**；**睡眠 / 唤醒未测试**。

### 4.2 实测能到什么程度（README 的 Tested hardware 原表）

| 卡 | PCI ID | 系统 | 结果 |
|---|---|---|---|
| **MT7921K（AMD RZ608）** | `14c3:0608` | 15.8.1 Sequoia，Intel 台式 | 5 GHz VHT80 **30–50 Mbit/s**（2SS、信号弱、100 M 宽带；同位置 MacBook ≈85）；2.4 GHz 可用；**开机自动加入** |
| **MT7922** | `14c3:7922` | Tahoe（上游 PR #5） | 5 GHz 上只有 legacy 20 MHz |
| MT7921 | `14c3:7961` | — | 与 RZ608 同芯片族，**预期可用** |

### 4.3 能力矩阵（README Status 摘要）

| 能力 | 状态 |
|---|---|
| probe / 固件加载 / MSI 中断 | ✅ |
| 扫描（2.4 GHz + 5 GHz） | ✅ |
| WPA2-PSK（CCMP）关联、四次握手 | ✅ |
| 硬件 RX 解密（芯片漏掉的走软件兜底） | ✅ |
| 切换网络 / 频段 | ✅ |
| **802.11n**（HT20/40、MCS 0–15、SGI、RX STBC、WMM） | ✅ |
| **802.11ac**（VHT20/40/80、2×2 MCS 0–9、RX STBC） | ✅ |
| A-MPDU（RX Block Ack + TX 聚合） | ✅ |
| 开机自动加入、同路由器下 **5 GHz 优先** | ✅ |
| AUTH / ASSOC 重传（丢一帧不再整轮重扫） | ✅ |
| 卡死自愈（DMA stall 看门狗、attach 时 PCIe FLR） | ✅ |
| **802.11ax（HE）** | ❌ 尚未 |
| **原生 macOS Wi-Fi 菜单** | ❌ 用 SimpleMTK |
| **睡眠 / 唤醒** | ⚠️ 未测试 |
| **AirDrop / Handoff / Continuity** | ❌ 该设计下不可能 |

### 4.4 安装（**有 release，不用自编译**）

1. 从 `flxxxxddd/SimpleMtkWlan` 的 **Releases** 取最新 **`SimpleMtkWlan-x.y.z-RELEASE.zip`**
   （排错期用 `-DEBUG.zip`；另附 `-RELEASE-dSYM.zip`、`SHA256SUMS.txt`、`mtklog.sh`）
2. `SimpleMtkWlan.kext` → `EFI/OC/Kexts/`，在 `config.plist → Kernel → Add` 加一条：

```xml
<dict>
    <key>Arch</key>           <string>x86_64</string>
    <key>BundlePath</key>     <string>SimpleMtkWlan.kext</string>
    <key>Comment</key>        <string>MediaTek Wi-Fi</string>
    <key>Enabled</key>        <true/>
    <key>ExecutablePath</key> <string>Contents/MacOS/SimpleMtkWlan</string>
    <key>MaxKernel</key>      <string></string>
    <key>MinKernel</key>      <string></string>
    <key>PlistPath</key>      <string>Contents/Info.plist</string>
</dict>
```

3. ★★ **确认这张卡没被 SSDT 藏起来** —— 很多预制 EFI 会带一张 `SSDT-Disable_Network_*.aml`，
   把网卡的 `vendor-id` / `device-id` 改成 `0xFFFF` 让 macOS 忽略它
   ⇒ **不禁用它，驱动永远匹配不上**：

```bash
ioreg -l | grep -A40 'pci14c3'   # 应看到 vendor-id = <c3140000>，而不是 ffffffff
```

4. 装 **SimpleMTK**（`laobamac/SimpleMTKClient`，**没有 release，需 Xcode 编译**）→ 重启 → 从菜单栏加入网络

**可选 boot-args**：`-novht`（关 802.11ac）、`-noht40`（关 HT40）。

### 4.5 ★ 排错（README 给的，都很实用）

- **看驱动日志** —— 驱动带一个**常驻 ring buffer**，启动失败后仍在、**免 root** 可读：

  ```sh
  ./tools/mtklog.sh > mtk.txt
  ```

  周期性的 `stats` 行会给出 RX 计数、**硬件 vs 软件解密（`rx_hwdec` / `rx_swdec`）** 与丢包原因。
- **重启后「SimpleMtkWlan is not running」** —— **热重启不会给 M.2 卡断电**；
  驱动现在会自动恢复（WFSYS reset → PCIe FLR），仍不行就**彻底关机再上电**。
- **速度慢** —— 看 `stats` 里的 `rx_swdec`，应**远小于** `rx_hwdec`。
  ★ **测速必须关掉 SimpleMTK 菜单**（客户端会触发扫描；已连接时限 2 分钟一次）。
- **2.4 GHz 无线鼠标/键盘在 Wi-Fi 也走 2.4 GHz 时卡顿** —— **同频段射频共存，不是驱动 bug**：
  让卡只留在 5 GHz（SimpleMTK 里只保留 5 GHz 网络），或用 USB 延长线把接收器挪离天线。
- **开机后连网慢** —— 选网是 SimpleMTK 这个 App 做的，**它登录后才启动**，这之前驱动一直在扫描。
- **吞吐不及真 Mac** —— **AP 发来的 Block Ack Request 固件还没往上送** ⇒ 乱序要靠 100 ms 超时补齐，
  这是当前**主要**的吞吐瓶颈。
- **开机 ~2 s 的 `element modified after free` panic** —— 测试机上是 **`NVMeFix.kext`** 造成的，
  **不是本驱动**（★ 很有价值：别一看到 panic 就赖在 Wi-Fi 上）。

### 4.6 fork 相对上游改了什么（判断值不值得跟 / 想自己编译时看）

> 前提：在 **上游 + PR #5**（`mavizao`：association context、TX 序列化、packet ownership）之上。

- **固件加载**：不再需要 16 KB jumbo mbuf cluster（开机时拿不到 ⇒ `ENOMEM`、没有 MAC、没有接口）
- **中断**：注册真正的 **MSI** 向量而不是 INTx，不再手工置 MSI enable 位；重新使能前先排空 pending
- **TX DMA 卡死**：多 mbuf 帧线性化进一个 cluster（**第一帧 DHCP 就把 WFDMA 卡死了**）
- **组播流量**：芯片**不解密组播帧** ⇒ 广播 ARP/DHCP 全被丢；现在也给 `net80211` 软件 CCMP 配了密钥兜底
- **切网络**：切走前先把 deauth 发到旧 AP 所在信道、认证期间忽略过期 disassoc、离开时移除 peer station
  并在固件里关掉 BSS（否则**切一次之后硬件解密就失效**）
- **漫游**：关掉 RSSI 触发的后台漫游（它在同一路由器的 2.4 / 5 GHz 之间几秒一跳）
- **802.11n / 802.11ac**：HT/VHT caps、WMM、完整 peer STA record、RX Block Ack + TX A-MPDU 交给固件、
  **必须宣称 HT20/40**（AP 只对宣称 40 MHz 的客户端发 80 MHz）、STA_REC_VHT、宽度取自关联协商
- **加入**：5 GHz 在 15 RSSI 点内优先、清理过期 peer / 扫描结果、首次 AUTH 前先 deauth、
  **AUTH/ASSOC 最多重传 3 次**（以前丢一个关联响应要等 ~20 s）
- **健壮性**：DMA stall 看门狗（硬复位 + 重载固件）、attach 时芯片恢复（WFSYS reset → PCIe FLR）、TXWI 泄漏修复
- **可调试**：常驻 `MtkDebugLog` ring buffer（发布在 PCI 设备上）、周期性硬件/stats dump、数据路径静默
- **构建**：从干净 clone 就能编（MacKernelSDK 作 submodule，无绝对路径）、host 测试修好、CI + release

### 4.7 自己编译（只有想跟最新代码时才需要）

```bash
git clone --recurse-submodules https://github.com/flxxxxddd/SimpleMtkWlan.git
cd SimpleMtkWlan                     # ★ 默认分支是 mt7921-fixes，不是 main
xcodebuild -project SimpleMtkWlan.xcodeproj -scheme SimpleMtkWlan \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
# -> build/Build/Products/Release/SimpleMtkWlan.kext
./tests/run-all.sh                   # host 测试（抽出真实驱动函数对 stub 跑，带 ASan/UBSan）
```

- 要求：**完整 Xcode**（command line tools 不够）；内核头来自 `acidanthera/MacKernelSDK`
  （**git submodule**；已 clone 但没带就 `git submodule update --init`）
- ★ **改了 `mtk80211/` 或 `include/` 下的头文件必须 `rm -rf build` 重编** ——
  它们在系统头文件搜索路径上，Xcode **不跟踪依赖**，否则会链进过期目标文件
- 许可 **GPLv2**；固件按 MediaTek 固件许可再分发（同 linux-firmware）

### 4.8 风险与前置

- 备份 EFI、备好可引导 U 盘；**禁用该 kext 即回到「无驱动」状态**
- **它是第三方路线**：没有原生 Wi-Fi 菜单、没有 AirDrop / Continuity、不支持 802.11ax
  ⇒ **要这些功能就换卡**（Broadcom / Intel），见 §6 决策树
- ★ 装上后 **`en0` 归属可能变化**（它是以太网式接口）⇒ 参考 **`network-en0-order.md`**

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
│           └─ 不认 ⇒ **先拿 `GeekAudio/mediatek-sunrise-hackintosh`**（固件/HAL kext/伪装片段都在里面），
│              再按 §1.5 的「社区做法」补：注入 AppleSunrise.kext（HAL）+ device-id 伪装 + 固件（看芯片！）
│
├─ 系统是 Sequoia，或蓝牙走 USB（0x0e8d）
│   └─► 路线 ②：SimpleMtkBtFw（有 release，成功率高）
│           记得 §3.2 的两个坑：不改产品名 + 注入两条 NVRAM data
│
└─ 要 Wi-Fi
   ├─ macOS 26+ 且芯片在 7922 / 7923 / 7932 里 ─► ★ 先试原生（路线 ①）
   │
   ├─ 要「原生 Wi-Fi 菜单 / AirDrop / Continuity / Wi-Fi 6(HE)」
   │   └─► ✗ 第三方路线给不了（§4.1）⇒ 换卡：
   │        Broadcom（原生，broadcom-wifi.md）或 Intel + AirportItlwm（intel-wifi.md）
   │
   └─ 接受「以太网式接口 + 菜单栏客户端」，只要能上网
       ├─ MT7921 / MT7921K(RZ608) ─► ★ 路线 ③：flxxxxddd/SimpleMtkWlan release（§4）
       │                               实测 5 GHz VHT80 30–50 Mbit/s、开机自动加入
       └─ MT7922 ─► 先试原生；原生不行才上 ③（fork 在 Tahoe 上只有 legacy 20 MHz）
                    ★ 先确认卡没被 SSDT-Disable_Network 藏起来（§4.4 第 3 步）
                    ★ 必装 SimpleMTK 客户端；测速时把它的菜单关掉
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
| Wi-Fi kext 加载但无接口 | ★★ **卡被 SSDT 藏了**（`vendor-id` 被改成 `0xFFFF`）⇒ `ioreg -l \| grep -A40 'pci14c3'`；设备 ID 是否在支持列表 |
| Wi-Fi 能扫描但一连接就卡死/panic | ★ 用 **fork 的 release**（上游主线仍是这条症状；fork 已修关联/TX，见 §4.6）；仍发生则跑 `mtklog.sh` 看日志 |
| 重启后驱动 not running | **热重启不给 M.2 卡断电** ⇒ 驱动会自动恢复（WFSYS reset → PCIe FLR）；不行就**彻底关机再上电**（§4.5） |
| Wi-Fi 慢 / 不如真 Mac | ① `stats` 里 `rx_swdec` 应远小于 `rx_hwdec`；② **测速时关掉 SimpleMTK 菜单**；③ 剩余瓶颈 = AP 的 Block Ack Request 固件未上送（100 ms 乱序超时） |
| 2.4 GHz 无线键鼠在上网时卡顿 | **同频段射频共存，不是驱动 bug** ⇒ 卡留在 5 GHz，或把接收器用延长线挪开 |
| 开机 ~2 s 的 `element modified after free` panic | 测试机上是 **`NVMeFix.kext`**，**不是本驱动** —— 别赖错对象 |
| **原生路线**：`IOUserServer(com.apple.AppleSunriseWLAN) has crashed too many times` panic / DEXT 反复重启拖垮系统 | 0x7922 伪装后的已知现象 ⇒ 加 **`mtk.wlan.startdelay=30`**（个别卡 **45**）；终极手段 **`mtk.wlan.hangonstart=1`**（§1.5） |
| **原生路线**：日志停在 `wlanRemove` + `Disabling PCI device` | ★ **驱动已放弃设备** —— 调试失败的**终点信号**：多半缺 `wifi.cfg` / 固件没写对位置或名字（`WIFI_RAM_CODE_MT7922_1.bin` 要改名 **`W7922_1.bin`**）⇒ 照 `§1.5` 日志判读表逐条对 |
| **原生路线**：满屏 `wlanCfgSet ... no empty entry` | 缺 `wifi.cfg` —— **不致命**（观察项），但只补固件缺它仍可能收不了场 |
| **原生路线**：device-id 伪装后仍不匹配 | ★ 三个都要查：① 有没有被 `SSDT-Disable_Network` 藏掉（`vendor-id` 变 `ffffffff`）② `device-id` 值是小端 base64（`0x7922 → InkAAA==`）③ **PXSX 下还要补 DEXT 相关属性**（§1.5） |
| 装了蓝牙但另一套 BT 固件加载器也在 | 移除冲突项（同一条纪律见 `intel-wifi.md` §5「换网卡后要清理」） |

## 8. 安全提示与边界

- 三个 kext 都**非 Apple 签名** ⇒ 需要 `SecureBootModel=Disabled`，SIP 视情况放宽；**只在确实要用这张卡时这么做**
- `SimpleMtkWlan` 是 **GPLv2 的实验性项目**；`flxxxxddd` 的 fork **有 CI 构建的 release**（v1.1.0 / v1.2.0），
  但**上游主线仍是 bring-up 状态、没有 release** ⇒ **第三方路线认准 fork 的 release**（§2 / §4）。
  从源码构建前先看清 `CREDITS.md` 与固件再分发条款（固件按 MediaTek 固件许可，同 linux-firmware）
- ★ **fork 的 issue 是关的** ⇒ 反馈/求助回上游 `laobamac/SimpleMtkWlan`；fork 默认分支是 **`mt7921-fixes`**
- 与 `broadcom-wifi.md` / `intel-wifi.md` 的关系：**同一台机器不要同时注入三套网卡驱动**；
  换卡后按 `intel-wifi.md` §5 的纪律把旧的一套**禁用或删除**，并注意 **`en0` 归属**会随驱动挂载顺序变化（⇒ **`network-en0-order.md`**）
- ★ **MT7922 Sunrise Pack 的许可是分层的**：仓库文本与补丁 **MIT**；`firmware/*.bin` 走 **linux-firmware 再分发条款**；
  `SSDT-ARPT_RP04_Mediatek.aml` 原作者 **Elias64Fr** 公开发布于帖子，**使用时请署名**。
- **本 reference 是通用流程**；本机（Z690）用的是 Broadcom `BCM943602CDP`，**没有 MT7922**。
  - **§0.1 的原生路线事实（两个 dext、`IOPCIMatch`、自带固件、`bluetoothd` 字符串）是在本机 macOS 26.7.1 上实测读出的** —— 这部分是硬证据
  - **§1.5 的「社区做法」与 §3/§4 的第三方路线**未在本机复现（没有对应硬件）—— 按 §0.3 / §1 先确认芯片与形态，再逐步验证
  - **§4 的能力/限制/排错全部来自 fork 的 README 与 release 说明**（2026-10-13 的 v1.2.0），**不是本机实测** ⇒ 用前先看一眼仓库有没有更新
