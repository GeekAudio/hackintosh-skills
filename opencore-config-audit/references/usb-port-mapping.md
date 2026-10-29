# USB 端口定制（macOS 26 Tahoe）

> **依据**：OpenCore `Docs/Configuration.tex` §`XhciPortLimit` · `Docs/Changelog.md` v1.0.7 ·
> `Library/OcAppleKernelLib/CommonPatches.c` 的 Tahoe 专用分支 ·
> `USBToolBox/tool` 的 `TYPES.md`（Connector 类型权威表）· `corpnewt/USBMap` `tahoe-test` 分支 README ·
> `USBToolBox/kext` issue #14 / #15 + Release 1.2.0 · 本机 26.7.1 / OC 1.0.8 实测。
> **相关**：`acpi-ssdt.md`（★ 另一条路：**用 ACPI 做端口映射**，不装 kext）、
> `disks-and-kexts.md`（kext 是否真的加载）、`machine-facts.md`（本机控制器与现状）、
> `logs-and-debug.md`（`log show` 在本环境失效，用 `/var/log/system.log`）。

## 0. 先判断「要不要做」，别一上来就做

USB 定制的目的**不是**「让所有口都能用」，而是「**让系统只认你真实存在的口，并且类型正确**」。
做错的代价很高（键鼠失灵、蓝牙掉、睡眠即醒、USB3 掉回 480 Mbps）。

**出现这些症状才做**：

| 症状 | 可能原因 |
|---|---|
| 某些口插设备完全没反应 | 该口没被 map 覆盖（Tahoe 下 kext 注入失败或被 15 口截断） |
| USB3 设备只跑 480 Mbps | map 里**一个 SS 端口都没有**（最常见，见 §7） |
| 蓝牙时好时坏 / 睡眠立刻醒 | 蓝牙或内部设备被标成外部口，或该口被删 |
| 插上就 panic / 设备反复重连 | locationID 冲突（端口数超限但 map 不匹配） |
| 睡眠唤醒后 USB 全掉 | 端口属性与硬件不符 |

**先跑这三行，判断现在处于什么状态**：

```bash
# ① 控制器是谁、注入了多少端口
ioreg -l -w0 -r -c AppleUSBXHCI | /usr/bin/grep -E '"port-count"|"ports"|"locationID"'
# ② 实际注册了多少根端口（★ 这是唯一可信的计数，见 §6）
ioreg -p IOService -w0 -r -c AppleUSBXHCI | /usr/bin/grep -c "AppleUSB.*XHCIPort"
# ③ 每个口上挂的是什么
ioreg -p IOUSB -w0 -l | /usr/bin/grep -E "USB Product Name|PortNum"
```

## 1. macOS 26 变了两件事（不知道这两条，旧教程全是坑）

### 1.1 kext 里的键名换了

Tahoe 改了 USB 类的属性名，**旧 map 键名不再被读**：

| 旧键（≤ Sequoia） | 新键（Tahoe） | 值类型 |
|---|---|---|
| `UsbConnector` | **`usb-port-type`** | **Integer**（连接器类型编号，例如 `3` / `255`） |
| `port` | **`usb-port-number`** | Data，**4 字节小端** |

连接器类型与端口编号的类型不同：[USBMap 生成代码](https://github.com/corpnewt/USBMap/blob/master/USBMap.py)
将 `UsbConnector` / `usb-port-type` 写为整数，将 `port` / `usb-port-number` 写为 Data。
[USBToolBox 1.2.0 的转换](https://github.com/USBToolBox/kext/blob/1.2.0/USBToolBox/USBToolBox.cpp)
复制原属性对象，不能靠改键名修正错误类型；手改后用 `plutil -p` 核对类型。

- **`USBToolBox.kext` ≥ 1.2.0**（2025-06-13，官方标 *Tahoe support (WIP)*）会自动写新键
  ⇒ **低于 1.2.0 的版本在 Tahoe 上就是不生效**（issue #15 的根因就是这个，不是「Tahoe 不支持」）。
- 手上是旧 map 时，可用 `corpnewt/USBMap` 的 **`tahoe-test` 分支** →
  `USBMapInjectorEdit.command`，拖入 kext/plist，执行 `U`（update）+ `C`（convert）+ `S`（改 SMBIOS）。

### 1.2 15 端口上限：**Tahoe 上可以突破，但性质是「二进制硬改」**

- **`Kernel → Quirks → XhciPortLimit = true`，从 OpenCore 1.0.7 起对 Tahoe 有效**
  （Changelog：*Improved `XhciPortLimit` compatibility with macOS Tahoe, thx @laobamac*）。
- 机制在 `CommonPatches.c`：Tahoe 分支的 Base 符号是
  **`__ZN16AppleUSBHostPort15setPortLocationEv`**（**无参版**；pre-Tahoe 是带 `j` 的
  `…setPortLocationEj`），Find → Replace = **`0F 0F 87` → `40 0F 87`**，即把上限 `0xF` 改成 `0x40`(64)。
- ★★★ **但「开 quirk」不等于「能用了」** —— 必须**重做 map 并全选所有端口重新导出**。
  沿用旧的 15 口 map，开了也还是那 15 个（社区反馈里「加补丁后还是 15 个」「键鼠动不了」全是这个原因）。
- 官方文档**没有跟着改**，仍写 *"This option should be avoided whenever possible… The only valid solution
  is to limit the amount of used ports to 15"*。
  ★ 这两句不矛盾：官方说的是「**不修改系统**的前提下」；`0F → 40` 正是官方那句 `heavy OS modification`。

> ★★ **这个 quirk 每换一代 macOS 就失效一次、再被修一次**（`v0.9.3` 修过 11–14，`v1.0.7` 修 Tahoe）
> ⇒ **大版本升级后必须复验**，见 §8。

### 1.3 到底要不要开这个 quirk

| 你的情况 | 建议 |
|---|---|
| 物理口 × 2 通道后 **≤ 15 个端口号** | **别开**。按 §4 规划 15 个号就够，最稳 |
| 端口号 **> 15**，且不想砍口 | 开，但接受「升级后可能静默失配」 |
| 只是想**扫描**一次拿全端口清单 | 临时开、扫完关（比 §3.3 的滑动窗口快得多） |

## 2. ★★★ 三个概念先分清（80% 的错误出在这里）

| 概念 | 含义 | 判据 |
|---|---|---|
| **物理口** | 机箱上能插的插座 | 主板规格书 |
| **端口号**（port personality） | macOS 眼里的一个通道。**一个 USB3 口 = 1 个 HS + 1 个 SS = 2 个端口号** | map 里的条目数 |
| **根端口**（root port） | 控制器 `AppleUSB*XHCIPort` 的直接子服务 | `ioreg` 数子服务（§6） |

★★ **`port-count` 不是「端口个数」，是「最大端口号」**。本机实测：22 个根端口、`port-count = 25`
（因为实际端口号是 1–13 和 17–25，有缺口）。
⇒ **不要把 `port-count` 和端口条目数搞混，也不要以为它必须等于条目数。**

★★ **hub 下游端口不算根端口**。板载 ASM107x 这类 hub 下面挂的设备，是 hub 的端口，不是控制器的根端口
⇒ 统计时**必须只数控制器的直接子服务**，否则数字永远对不上。

## 3. 采集真实端口（按可靠性排序）

### 3.1 Windows 侧 `USBToolBox`（最准，能拿到固件自己的说法）

在 Windows 跑 `USBToolBox/tool`，它读的是 **RootHub 描述符**，能直接给出：

```
RootHub.HubInfo.HubInformation.HubDescriptor.bNumberOfPorts   ← 端口总数
RootHub.HubInfoEx.HighestPortNumber                            ← 最大端口号
RootHub.HubPorts[]                                             ← 每个口支持 USB2 / USB3
```

★★★ **这是判断「固件声称有 N 个口，但硬件实际只有 M 个」的唯一硬证据** ——
RHUB 命名空间里存在 `SS10` 不代表板子上真有第 10 个 SS 口（见 §7 第 4 条）。

### 3.2 临时开 `XhciPortLimit` 一次扫全（Tahoe 上最快）

1. 备份 config + 现有 map
2. `Kernel → Quirks → XhciPortLimit = true` → 重启
3. 用 USBToolBox（macOS 版）或 Hackintool 扫一遍，**全选所有端口**导出
4. 扫完**立刻关掉**这个 quirk（除非你决定长期用，见 §1.3）

### 3.3 滑动窗口（不开补丁时的正规做法，`corpnewt/USBMap` `tahoe-test`）

因为一个控制器同时只看得见 15 个 port personality，所以要分两轮：

1. `D. Discover Ports` 至少跑一次
2. `K` 生成 `USBMapDummy.kext` → 放进 `EFI/OC/Kexts` + `Kernel → Add`
3. 重启，确认所有端口变成 `UK01` / `UK02`… （证明 dummy 生效）
4. 用 `USBMapInjectorEdit.command` **禁掉前 15 个里所有非键鼠的**（★ 原文强调：**ONLY TEMPORARY**），
   第 16–26 个**不要动**
5. 重启再扫一轮，这次能看见后半段
6. `P. Edit & Create USBMap.kext`，按物理口类型标注，勾选要保留的（≤15 个）
7. 生成最终 kext 替换 dummy

### 3.4 只靠 `ioreg` 数（验证用，不用于发现）

见 §6。**只能确认「注册了几个」，不能告诉你「哪个物理口是哪个号」** —— 后者必须插拔。

## 4. 规划：15 个号怎么选（不开补丁时）

| 优先级 | 端口 | 理由 |
|---|---|---|
| **必留** | 所有 SS（USB3 通道） | **没有 SS 就没有 USB3**，只会 480 Mbps |
| **必留** | 内部设备（AURA / 蓝牙 / 读卡器）标 `255` | 砍了要改别的功能 |
| **高** | 键鼠所在口的 HS | 砍了当场没输入 |
| 中 | 常用前置 header 的 HS | 看实际使用 |
| 可砍 | 不用的后置口 HS | 该口插 USB2 设备时无反应，可接受 |

★★★ **SS 对应的 HS 不能全砍** —— USB2 设备插在 USB3 口上，走的是那个口的 **HS 通道**。
砍了就是「插 U 盘没反应」，而 USB3 盘插上去却正常，非常难排查。

## 5. 生成 map

### 5.1 Connector 类型（`USBToolBox/tool` 的 `TYPES.md`，权威表）

| 值 | 含义 |
|---|---|
| **0** | USB Type-A（USB2） |
| 1 | USB Mini-AB |
| 2 | ExpressCard |
| **3** | **USB 3 Type-A** |
| 4 | USB 3 Type B |
| 5 | USB 3 Micro-B |
| 6 | USB 3 Micro-AB |
| 7 | USB 3 Power-B |
| **8** | **USB Type-C，只接了 USB2** |
| **9** | **USB Type-C，带切换器**（正反插用同一对 personality） |
| **10** | **USB Type-C，不带切换器**（正反插用不同 personality） |
| **255** | **Internal**（读卡器 / 指纹 / 摄像头 / 板载 hub 等） |

### 5.2 ★★ 9 还是 10：只能实测，别靠猜

- 硬件报告里的 **Type-C 标志**只说明「这是个 Type-C 口」，**不说明有没有切换器**
  ⇒ USBToolBox 按标志猜的 `9` 是**资料默认值，不是实测结论**。
- 判据只有一个：**把 Type-C 设备正插、反插，看 SS 通道换不换**：
  - 不换 ⇒ **9**
  - 换了（落到另一个 SS 端口号）⇒ **10**
- ★ 硬件报告里若出现 **`multiple_companions`**（一个 HS 对应两个 SS，如 5↔20/21），
  说明正反插很可能走不同通道 ⇒ **重点怀疑 10**，但仍要实测确认
  （微软的 `USB_PORT_CONNECTOR_PROPERTIES` 文档**没有**把 multiple-companion 直接定义成「无切换器」）。

### 5.3 `port-count` 怎么定

= **你 map 里出现过的最大端口号**（不是条目数）。填小了，超出部分直接被截断。

### 5.4 两种产物

| 产物 | 来源 | 特点 |
|---|---|---|
| **`UTBMap.kext`** | `USBToolBox/kext`（≥1.2.0）+ tool 生成 | 与 `USBToolBox.kext` 配套；Tahoe 需 1.2.0+ |
| **`USBMap.kext`** | `corpnewt/USBMap` | 独立，不需要 USBToolBox.kext；Tahoe 用 `tahoe-test` 分支 |

**`XHCI-unsupported.kext` 按 PCI ID 与目标 macOS 的原生匹配判断，不能按厂商一刀切。**
[作者 README](https://github.com/RehabMan/OS-X-USB-Inject-All#how-to-install) 列出的典型对象包括
Intel X99、200、300 系列；[实际匹配表](https://github.com/RehabMan/OS-X-USB-Inject-All/blob/master/XHCI-unsupported.kext/Contents/Info.plist)
也包含 Intel `8086` ID。先查目标系统 `AppleUSBXHCIPCI.kext/Contents/Info.plist` 是否已匹配该控制器，
再判断是否需要兼容注入；不要把该 kext 当作任意 ASMedia / Fresco 控制器的通用驱动。

## 6. ★★★ 验证：看「端口有没有注册」，不看「kext 有没有加载」

**kext 加载成功 ≠ 端口注入成功**。唯一可信的判据是**控制器下面真的出现了多少个 port 服务**：

```bash
# ① 数根端口（只数控制器的直接子服务，不含 hub 下游）
ioreg -p IOService -w0 -r -c AppleUSBXHCI \
  | /usr/bin/grep -c "AppleUSB20XHCIPort\|AppleUSB30XHCIPort"

# ② 分别数 USB2 / USB3
ioreg -p IOService -w0 -r -c AppleUSBXHCI | /usr/bin/grep -c "AppleUSB20XHCIPort"
ioreg -p IOService -w0 -r -c AppleUSBXHCI | /usr/bin/grep -c "AppleUSB30XHCIPort"

# ③ 看每个端口的 registered / matched / active 标志与 locationID
ioreg -l -w0 -r -c AppleUSBXHCI | /usr/bin/grep -E "locationID|port-count|registered|active"
```

★ **判定纪律**：
- 计数要**逐个对照** `registered` / `matched` / `active` 标志，
  **不要**把注入字典的条目数当端口数，**不要**把 hub 下游端口算进来。
- **速率**要另测：`system_profiler SPUSBDataType` 里看 `Speed`（`Up to 5 Gb/s` vs `480 Mb/s`）。
- ★ 枚举成功 **≠ 吞吐达标** —— 5 Gbps 链路建立只证明协商成功，**不等于**磁盘读写速度。

## 7. 五个常见误区（都有反例，别再重复推导）

| 误区 | 事实 |
|---|---|
| **「端口号必须连续，跳号就全挂」** | ❌ 反例：本机端口号 **1–13 + 17–25（有缺口）**，仍正常注册 **22 个**根端口服务 |
| **「超过 15 个必失败」** | ❌ 反例：同上，13 HS + 9 SS = 22 个同时在跑，SS 侧建立 5 Gbps 链路 |
| **「开了 `XhciPortLimit` 就好了」** | ❌ 必须**重做 map 并全选端口**；旧 map 不动 = 白开 |
| **「固件里有 SS10，就说明有第 10 个 SS 口」** | ❌ RHUB 命名空间只是**模板**。本机固件列了 SS01–SS10，但 Windows RootHub 描述符说 `bNumberOfPorts=25`、USB3 只有 **17–25 共 9 个** ⇒ 真实只有 SS01–SS09 |
| **「USB3 只跑 480 Mbps = 15 口限制」** | ❌ 更常见的原因是 **map 里一个 SS 端口都没有**（只用了 13 个号，离 15 都没到）。先查 map 内容，别急着开补丁 |

## 8. 风险与回滚

**风险（按发生概率）**：

1. ★★★ **大版本升级后补丁静默失配** —— 表现是 **USB3 又掉回 480 Mbps**，**不是崩系统**。
   ⇒ 每次 macOS 大版本升级后**重新数一遍 SS 端口数**。
2. 端口数与 map 不匹配 ⇒ 键鼠失灵 / 设备反复重连（社区反馈里的「加补丁后键鼠动不了」）。
3. 把内部设备（蓝牙 / AURA）标成外部口 ⇒ 蓝牙掉线、睡眠即醒。

**回滚（两层，别混）**：

```bash
# ① 只回滚 map（保留当前 config）
cp UTBMap-before-<时间戳>.plist <EFI>/EFI/OC/Kexts/UTBMap.kext/Contents/Info.plist
# ② 回滚 quirk
#    Kernel → Quirks → XhciPortLimit = false
sync && sleep 8
```

- ★ **EFI 上要同时留三件**：`config-before-*.plist`、`UTBMap-before-*.plist`、回滚脚本（OpenShell `.nsh`）
  ⇒ 万一进不去系统，能从 OpenShell 直接跑。
- ★★ **回滚脚本不要写死磁盘号 / `fs0`** —— 必须在 OpenShell 里找到正确的 EFI 卷再进 `EFI/OC`。
- ★ 改完按 SKILL.md 的「改 ESP 的安全流程」：`plutil -lint` → `ocvalidate` → `sync` → 卸载重挂 → 复验哈希。
- ★ **ESP 上的 0 字节陷阱**：FAT 写满时 `cp` 会留 0 字节文件，`ls` 看不出来 ⇒ `find … -size 0` 查一遍。

## 9. 示例：本机实测结果（**只作对照，别当模板**）

> 机器：ASUS TUF GAMING Z690-PLUS WIFI D4 / BIOS 4505 / macOS 26.7.1 / OC 1.0.8 RELEASE。
> 控制器 `AppleUSBXHCISPT`。

| 项 | 改前 | 开启后 |
|---|---:|---:|
| 注册根端口 | 13 | **22** |
| HS / SS | 13 / 0 | **13 / 9** |
| 唯一 `locationID` | 13 | 22 |
| `port-count` | 13 | **25**（端口号 1–13 + 17–25） |
| SS 侧速率 | 无 | **5 Gbps**（板载 ASM107x，`174c:3074`） |

**Connector 分配思路**（可复用的判断，不是数值）：

- **HS/SS 两侧都设 `3`**：3/18、4/19、7/22、8/23 —— 这些是 USB3 Type-A 物理连接器，
  **即使设备只协商到 USB2 也不改其物理类型**（★ 这是最容易搞错的一点）。
- **`9`**：1/17、5/20/21、9/24 —— 按硬件报告的 Type-C 标志设，**属资料默认值**；
  其中 5↔20/21 有 `multiple_companion`，正反插未验证，**不能据此改 10**。
- **`255`**：AURA（2）、板载 hub 两侧（6/25）、常驻蓝牙（11）。
- **`0`**：10/12/13（未定型的诊断口）。

**踩过的坑（值得抄）**：
- 早期把「端口数超 15」当成 USB3 慢的原因，实际是 **map 里 0 个 SS**；
- 早期为了凑 15 个号**删掉了 HS14/HS15** —— 删的是**端口号**，不是「选哪 15 个」的规划，方向就错了；
- `SS10@26` 在 Windows 与运行态都不出现，**属固件模板多列**，不该算「补丁失败」。
