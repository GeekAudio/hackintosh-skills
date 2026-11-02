# MediaTek 首选：MtkWireless Wi-Fi 与蓝牙

MediaTek MT7921 / MT7922 的驱动选择，**优先评估 [Dino-VN/MtkWireless](https://github.com/Dino-VN/MtkWireless)**。先确认其发布物覆盖目标硬件与系统；不覆盖时使用 [MediaTek 芯片识别与备选路线](mediatek-wifi.md)。已有稳定配置先准备可回滚候选，不因优先级变化自动替换正在工作的驱动。EFI 完整构建仍按 [1401 流程](1401-efi-workflow.md)。

本次核对：2026-11-02，正式版 [v1.0.7](https://github.com/Dino-VN/MtkWireless/releases/tag/v1.0.7)，tag commit `9f4d5977501920a3be4cd231d1669e476be76665`。核对了源码、配置片段和实际 RELEASE ZIP；此处没有本机 MediaTek 硬件验收。使用前重新查发布记录，尤其是系统 build 对应的 bluetoothd 补丁。

## 1. 硬件、系统与两个独立 kext

| 组件 | 适用范围 | 依赖 / 边界 |
|---|---|---|
| `MtkWirelessWifi.kext` | x86_64、macOS 26 Tahoe / Darwin 25；PCIe `14c3:7961`、`0608`、`7922`、`0616` | 原生 Wi-Fi 菜单、IO80211 / Skywalk；不依赖 Lilu，不需 SimpleMTK 客户端；不能将 Tahoe 构建用于 Sequoia |
| `MtkWirelessBT.kext` | 支持列表中的 MT7921 / MT7922 **USB** 蓝牙 | 依赖 Lilu；按上游配置配合 BlueToolFixup。USB VID:PID / 通用 USB 匹配按本版 plist 核对，不把 PCIe 蓝牙当成 USB 控制器 |

Wi-Fi ID 对应 MT7921、MT7921K / RZ608、MT7922、MT7922 / RZ616。**匹配表包含不等于每种模块都已实测**；MT7923 / MT7925 / MT7932 等不能只凭同品牌套用。Wi-Fi 与蓝牙可分别选用，只安装目标设备需要的组件；多卡机器保留其它设备仍需的驱动。

例如 USB `0489:e0d8` **在 v1.0.7 匹配表内**，plist 的 vendor / product 整数分别为 `1161 / 57560`；它保留 CVSD，不属于两个已验证 mSBC 的 ID。不能因全文搜不到冒号格式的 ID 就认定不匹配，也不能因固件 loader 匹配就承诺宽带通话。

先记录 `sw_vers -productVersion`、`sw_vers -buildVersion`、`uname -r`，以及 PCI ID、蓝牙 USB VID:PID、当前加载驱动。依据：[Wi-Fi 文档](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/docs/WIFI.md)、[Wi-Fi 匹配表](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/kext/Wifi/Info.plist)、[BT 匹配表](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/kext/BT/Info.plist)。

## 2. 功能按硬件、版本与系统 build 报告

v1.0.7 的 README 主要记录一台 MT7921 `14c3:7961` + USB BT `0489:e0cd`、MacPro7,1、25G241 的结果；release 补充了 **25G332 上 Instant Hotspot 的握手、DHCP 与流量验证**。本次固定 main（见 §5）的支持矩阵比 tag README 更新，不能只抄旧段落或将单机结果推广到所有卡。

| 功能 | 本次可采用的结论 |
|---|---|
| 原生 Wi-Fi、扫描 / 关联 / DHCP | 上游报告 WPA2 / WPA3-transition、5 GHz、80 MHz、802.11ac 的硬件结果；目标机仍需实测 |
| AWDL、双向 AirDrop、Handoff / 通用剪贴板、AirPlay to Mac | 上游已有可用报告，不能继续套用旧 AirportMtkWlan v1.5.0 “无 AWDL”的结论；BLE advertising 的 bluetoothd 页面补丁需匹配 **25G241 / 25G332** |
| Instant Hotspot | **v1.0.7+，25G332 限定**；同 iCloud / 家庭共享等前提另核；25G241 缺对应 BLE RPA 补丁，不能靠同一版本号承诺可用 |
| HFP 16 kHz mSBC | 上游针对 USB `0489:e0cd` / `13d3:3610` 的验证；其它 ID 保留 CVSD。观察实际页面补丁匹配与双向通话，不由固件加载推出麦克风正常 |
| WPA3-SAE / PMF、802.11ax、DFS、漫游、睡眠恢复 | 有实现或开关，不等于均已完成硬件 / 稳定性验收；逐项查所用 release 与目标场景 |
| 6 GHz | 默认关闭，`amtk_6ghz=1` 仅开放实验扫描等路径；OWE / SAE-H2E 尚未实现，不能宣传 Wi-Fi 6E 网络可正常加入 |
| iPhone 镜像及其它连续互通功能 | 不把 AirDrop 成功外推为 iPhone 镜像、自动解锁或随航可用；按各功能的平台前提与实测判断 |

依据：[正式版说明](https://github.com/Dino-VN/MtkWireless/releases/tag/v1.0.7)、[固定 main 的 README](https://github.com/Dino-VN/MtkWireless/blob/967f14072a6254554e942c326fef5924190edf4a/README.md)、[BLE advertising](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/docs/BLE-ADVERTISING.md)、[6 GHz 限制](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/docs/WIFI-6GHZ.md)。

## 3. 从正式包准备 OpenCore 候选

1. 备份完整目标 EFI、当前配置与相关 NVRAM 原值，保留可用引导。下载对应 release 的 **RELEASE ZIP**；DEBUG ZIP 用于确有需要的诊断。保留版本与 SHA256，不能仅凭下载成功认定包完整。
2. 解压后检查实际 kext / plist / 二进制；v1.0.7 包根目录为 `MtkWireless-1.0.7-RELEASE`，kext 位于其 `Kexts/`，配置片段是包内 **`config-snippet.plist`**（源码位于 `docs/`）。不要把整个片段替换成完整 config。
3. 按目标设备迁移互斥项：Wi-Fi 替换该卡的 `AirportMtkWlan` / `SimpleMtkWlan`；BT 替换该控制器的 `SimpleMtkBtFw` **和** `SimpleMtkBtPatcher`。配置引用与文件一起处理，核对旧 SSDT 是否隐藏目标设备。**不按驱动品牌批量删除其它卡仍需的 Intel / 博通组件**。
4. 合并 `Kernel > Add`，使用下表的真实路径和依赖顺序。BT 采用 **Lilu → BlueToolFixup → MtkWirelessBT**；Wi-Fi 可独立启用，采用片段中的 Tahoe 范围。

| BundlePath | ExecutablePath | MinKernel / MaxKernel |
|---|---|---|
| `Lilu.kext` | `Contents/MacOS/Lilu` | 依据现有 Lilu 与目标系统支持范围 |
| `BlueToolFixup.kext` | `Contents/MacOS/BlueToolFixup` | 片段 MinKernel `21.0.0`；保留所用版本的实际适用范围 |
| `MtkWirelessWifi.kext` | `Contents/MacOS/MtkWirelessWifi` | **`25.0.0` / `25.99.99`**，不是营销版本 `26` |
| `MtkWirelessBT.kext` | `Contents/MacOS/MtkWirelessBT` | 片段未设上下限不等于承诺所有 macOS 均受支持；按目标 build 和实际补丁判断 |

各条 `PlistPath=Contents/Info.plist`，`Arch=x86_64`；只启用本次需要且文件真实存在的条目。BT 文档使用正常发布的 BlueToolFixup，不要求顺手换成某个定制版本。

5. BT 的 `NVRAM > Add` 使用 GUID `7C436110-AB2A-4BBB-A880-FE41995C9F82`：

| 键 | 类型 | 值 |
|---|---|---|
| `bluetoothInternalControllerInfo` | Data | **14 个零字节** |
| `bluetoothExternalDongleFailed` | Data | **1 个零字节 `00`** |

上游片段将这两个名字列入同 GUID 的 Delete，以替换已有控制器信息；先读取原值，再按确需覆盖的范围合并。不要清空整个 NVRAM，也不将其它 Add 项机械加入 Delete；只用 Wi-Fi 时不附带这些 BT 改动。

6. 执行语义 diff、引用检查与同版官方校验，记录实际检查结果。写 ESP 后按技能工作流回读核对哈希，重启验证实际加载。1401 产物手改会破坏 profile 绑定，按其重建或离线备选流程处理。

本次实际核验的 v1.0.7 RELEASE ZIP SHA256：`4888ace9e3b1b8f0af5c5b55b764bcf96c5f684a81237f6e9c661982f110a7d6`。文件升级后重新取作者发布元数据，不能沿用此值验证其它版本。

配置依据：[同版片段](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/docs/config-snippet.plist)、[BT 安装](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/docs/BLUETOOTH.md)。Wi-Fi 文档还描述系统侧 `kmutil load` 路线及其批准 / SIP 条件，并将 OC 路线标为未实测；**EFI 注入与系统侧安装分开判断**，不因 unsigned 字样自动关闭 SIP / AMFI / SecureBootModel。VT-d / IOMapper、Skywalk 或旧 root patch 也按实际依赖核对，不机械复制另一驱动的必需项。

## 4. 分层验证与本地调试

```sh
sw_vers -buildVersion
kmutil showloaded --list-only | grep -i -E 'MtkWireless|Lilu|BlueToolFixup'
ioreg -l -w0 | grep -E 'RustCore|RustSelfTestFailed|AwdlLayoutOk'
ioreg -l -w0 -r -n IOResources | grep -A12 '"MtkWirelessBT"'
ioreg -l -w0 | grep -A30 MtkBtLog
```

- `RustSelfTestFailed=0` 只证明相应 Rust 自检，`AwdlLayoutOk` 只说明布局检查；接着分别证明接口 / 控制器、Wi-Fi 关联、DHCP、实际流量、BT 配对 / 音频，再验证目标连续互通功能。双向 AirDrop 用实际收件和文件完整性验收，不以发现对端或 `awdl0` 存在代替。
- 蓝牙核对 `THIRD_PARTY_DONGLE` / On、`MtkBtLog`、`LeFeaturesShimEnabled` 与 `Bluetoothd*Patched`。build 不匹配而补丁为 0 时，记录未匹配，不用随机 boot-args 强开页面补丁。
- `-mtkbtdbg` 是 BT 的 Lilu 调试开关；`-mtkbtnomsbc` 可回退 CVSD，`amtk_awdl=0` 会关闭 AWDL，`amtk_he=0` / `amtk_pmf=0` 会改变协商能力。只针对具体故障选用并记录原值，不将整张参数表默认追加到 boot-args。
- Instant Hotspot 单独查 **25G332、BLE RPA / 页面补丁、iPhone 激活、关联 IE、WPA2 握手、DHCP 与流量**。`amtk_apple_ie=0` 会禁用 v1.0.7 的 Apple vendor IE 修正，不能作为默认参数；相关 join 状态见 `MTKWiFiJoin` / `MTKWiFiJoinLastFailed` 与 [Instant Hotspot 文档](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/docs/INSTANT-HOTSPOT.md)。不把同屏发现 iPhone 当作热点已完成连接。
- 上游沿用部分 `AirportMtkWlan` / `AirportMtkAwdlInterface` 类名；类名含旧名称不证明旧 kext 同时加载。以 bundle ID、实际已加载列表与依赖判断。正式 ZIP 未附 `mtkctl` 可执行文件；需要 `sta` / `log` 时按上游源码工具路径准备，不假定系统已有这个命令。

### 上游采集脚本的实际副作用

- [`Collect-AirDrop-AWDL.command`](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/scripts/Collect-AirDrop-AWDL.command)：在仓库 `diagnostics/airdrop-awdl-*` 写本地报告，提权抓取约 90 秒 AWDL IPv6 与日志，不重启蓝牙。
- [`Collect-AirDrop-BT.command`](https://github.com/Dino-VN/MtkWireless/blob/v1.0.7/scripts/Collect-AirDrop-BT.command)：会写 HCITraces 偏好、重启 bluetoothd、抓包并复制 HCI 日志；cleanup 删除该偏好而非恢复原值。需要此层诊断时先保存原偏好与恢复方式，不把它称为纯只读采集。
- 两者不自动上传；包内可能含设备 / 网络 / 对端标识与数据，按实际发送范围脱敏。原版脚本与输出放在 EFI / 1401 构建清理目录之外，使用所核对的同版源码，不假设采集器已在 RELEASE ZIP 中。

## 5. main 一键安装器是另一条操作路径

本次 main commit `967f14072a6254554e942c326fef5924190edf4a` 新增 [`scripts/install.sh`](https://github.com/Dino-VN/MtkWireless/blob/967f14072a6254554e942c326fef5924190edf4a/scripts/install.sh)，**v1.0.7 tag / ZIP 不含它**。选择它时先固定并审阅脚本，不把 main 新增功能当作旧 release 已有内容。

该脚本自动检测硬件、寻找当前启动 ESP，下载驱动 / 缺失依赖并改配置；`--efi` 指**包含 `EFI/OC` 的根目录**，不是 `EFI` 子目录。`--dry-run` 仍可能下载、创建临时文件和挂载启动 ESP；`--version v1.0.7` 只固定 MtkWireless 包，不固定它补装的 Lilu / BlueToolFixup 最新版。

清理名单还包含 Intel / 博通系列且不按多设备用途保留，连已禁用的配置条目也会删除；多卡或需要保留其它设备的机器使用上面的定向迁移。脚本有确认与桌面备份，但未运行官方 ocvalidate，失败分支只恢复 config 的情况也不代表 kext 全部回滚。不能由完成提示或功能摘要认定现场功能通过，也不为运行脚本随手降低现有 Vault / 安全设置。

未覆盖目标系统、PCIe 蓝牙或所需功能时，回到 [MediaTek 备选](mediatek-wifi.md)；连续互通判据见 [AirDrop / Handoff](airdrop-handoff.md)，接口编号变化按 [en0 专题](network-en0-order.md)判断，不默认重建网络身份。
