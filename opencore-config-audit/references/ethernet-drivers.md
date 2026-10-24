# 有线网卡驱动方案（Intel / Realtek）

> 依据：Apple 原版 `AppleIntelI210Ethernet.kext` 的 `Info.plist` 与签名链实测 ·
> `laobamac` 的 **`SimpleVGBE`** / **`SimpleGBE`** / **`SimpleHacPlugins`** / **`SimpleRTK5`** 官方 README ·
> dortania **`KdkSupportPkg`** 全量 release 核查。
> **相关**：`network-en0-order.md`（★ 换驱动会改变 `en0` 归属）、`intel-wifi.md` §5（换网卡后要清理旧驱动）、
> `laobamac-toolkit.md`（工具索引）。

## 0. 两条路线，先选路再动手

macOS **原生不认**的板载 / 扩展有线网卡，只有两条路：

| 路线 | 做法 | 代价 | 适用 |
|---|---|---|---|
| **A. 原版 kext 仿冒** | 用 Apple 原版 I210 kext + `device-id` 伪造 + `e1000=0` | **最多千兆**；寄存器代际不匹配，非官方支持 | 想要 **Apple 原版、原生网络栈、零第三方 kext** |
| **B. 第三方驱动** | `SimpleVGBE` / `SimpleEthernet` / `SimpleRTK5` 等 | 非 Apple 签名；作者停更就没人修 | 要 **2.5G 速率**，或原版路线跑不起来 |

> ★★ **两条路没有普适优劣，按需求选**：要「Apple 原版 + 零第三方 kext」选 A（**必然降到千兆**）；
> 要 2.5G 或 A 跑不起来选 B。**别默认 A 更好** —— 它是拿速率换纯度。
> ★ 本机（I225-V）当前选的是 A，选择理由与实测结果 ⇒ `machine-facts.md`。
> ★ **另有一条 ACPI 路线**：`5T33Z0/OC-Little-Translated` 的 **`Intel_I225-V_Fix_(SSDT-I225V)`**
> （用 SSDT 修，而不是装 kext）—— 值得对照，见 `acpi-ssdt.md` §0.1。

---

## 1. ★★★ 路线 A：原版 kext + `device-id` 仿冒（I225/I226 → I210）

### 1.1 三条事实叠加才成立

这条路线不是「试试看」，它成立的原因可以逐条验证：

| # | 事实 | 出处 |
|---|---|---|
| ① | Apple 原版 `AppleIntelI210Ethernet.kext` 的 `IOPCIPrimaryMatch` = `0x15338086 0x15348086 0x15358086 0x15368086 0x15378086 0x15388086 0x15398086 0x157B8086 0x157C8086`（I210/I211/I350 系列），**不含 `0x15F3`（I225-V）** | 该 kext 的 `Contents/Info.plist` |
| ② | 它的 **`IOProbeScore = 1000`**，而系统自带 `com.apple.DriverKit-AppleEthernetE1000.dext` 是 **3000** | 同上 / `AppleEthernetE1000` 的 dext plist |
| ③ | dext 的匹配是 `IOPCIMatch = 0x00008086&0x0000ffff` —— **只比 vendor-id，不看 device-id** | dext 的 `Info.plist` |

推论：

- ① ⇒ **必须把 `device-id` 伪造成列表里的值**（常用 `0x1533`），否则 kext 根本不匹配。
- ② ⇒ 两者都匹配时 **dext 先 probe**，I210 轮不到 ⇒ **必须把 dext 关掉**。
- ③ ⇒ **改 `device-id` 不能让 dext 退出**（它不看 device-id），只能从 kernel 层禁：
  boot-arg **`e1000=0`**。

⇒ **三件套缺一不可**：**原版 kext + `device-id` 注入 + `e1000=0`**。
远景 `lwx1901` 的原话也是这个口径：*"请添加启动参数 `e1000=0` 以屏蔽掉
`com.apple.DriverKit-AppleEthernetE1000.dext`，同时通过 OC 内核加载调用
`AppleIntelI210Ethernet.kext`。**警告：以上两个驱动程序不得同时加载**。"*

> ★★★ **`e1000=0` 是硬前提，不是优化项。** 只放 kext 不改 device-id / 不加参数 = 100% 不生效。

### 1.2 kext 从哪来：只有 macOS 12 Monterey

`AppleIntelI210Ethernet.kext` 位于 Monterey 12 的
`/System/Library/Extensions/IONetworkingFamily.kext/Contents/PlugIns/`，
**Ventura 13 起被 Apple 移除**。

已经排除的来源（都实测过，别再重复试）：

| 来源 | 结果 |
|---|---|
| **KDK（dortania/KdkSupportPkg）** | ❌ **只有 Ventura 13 及以后**，最老 tag `22A5295h`（13.0 beta 1），**没有 Monterey** |
| Ventura 13.7.6 的 KDK（`22H625`，691 MB） | ❌ 实测 `pkgutil --payload-files` 里 Ethernet 只剩 Broadcom / Aquantia / Mellanox / USB / Vmxnet3，**无 I210** |
| macOS 26（实测）`/System/Library/Extensions/` | ❌ 已移除 |
| macOS 26（实测）`/Library/Extensions/` | ❌ 无 |

⇒ 只能从 **Monterey 12 的安装镜像 / 真机** 提取，或使用别人从 Monterey 提取的副本。

**拿到后必须先验签名，判据是签名链，不是文件名、不是版本号**：

```bash
codesign -dvvv --verbose=4 /path/to/AppleIntelI210Ethernet.kext 2>&1 \
  | /usr/bin/grep -E "Identifier|Authority|Signed Time|TeamIdentifier"
```

原版应为：

```
Identifier=com.apple.driver.AppleIntelI210Ethernet
Authority=Software Signing
Authority=Apple Code Signing Certification Authority
Authority=Apple Root CA
```

> 一个已验证可用的副本：`github.com/0xHJK/Intel-NUC9-i7-9850H-macOS` 的 EFI 目录里那份
> `AppleIntelI210Ethernet.kext` —— `2.3.1` / `DTPlatformBuild=21G410`（Monterey 12.6）/
> universal（x86_64 + arm64e）/ 签名时间 2022-12-20，签名链同上，**是 Apple 原版**。
>
> ★★ **不要用 `SimpleGBE` 这类第三方 I210 驱动来做这件事** —— 本路线的全部价值就是「用 Apple 原版」，
> 换成第三方等于退回路线 B，还白丢了 `e1000=0` 的收益。

**依赖检查**（原版 kext 是给 Monterey 编的，要确认 macOS 26 的框架版本够）：

```bash
plutil -p AppleIntelI210Ethernet.kext/Contents/Info.plist | /usr/bin/grep -A6 OSBundleLibraries
```

要求 `IONetworkingFamily >= 1.5`、`IOPCIFamily >= 1.7`、`kpi.bsd >= 13.0.0`。
macOS 26 上 `IONetworkingFamily` 是 **3.4**，全部满足。

### 1.3 三件套改动

**前置**：备份 `config.plist`；**这台机器上原来在用的第三方有线驱动必须同时 `Enabled=false`**
（`AppleIGC` / `SimpleVGBE` / 你实际装的那个）—— 两套驱动会抢同一块卡（见 §5 纪律）。

#### ① boot-args 末尾追加 `e1000=0`

★★ **只追加，不动现有**。现有参数（`nvfb` / `nvaccel` / `gfxrst` / `amfi` …）一个字符都别改：

```diff
- <string>…gfxrst=4 -v</string>
+ <string>…gfxrst=4 -v e1000=0</string>
```

#### ② `Kernel > Add` 新增一条

```xml
<dict>
    <key>Arch</key><string>Any</string>
    <key>BundlePath</key><string>AppleIntelI210Ethernet.kext</string>
    <key>Comment</key><string>Apple I210 kext (from Monterey) for I225 spoof</string>
    <key>Enabled</key><true/>
    <key>ExecutablePath</key><string>Contents/MacOS/AppleIntelI210Ethernet</string>
    <key>MaxKernel</key><string></string>
    <key>MinKernel</key><string></string>
    <key>PlistPath</key><string>Contents/Info.plist</string>
</dict>
```

kext 本体放 `EFI/OC/Kexts/AppleIntelI210Ethernet.kext`（约 552 KB）。

#### ③ `DeviceProperties` 注入 `device-id`

```xml
<key>PciRoot(0x0)/Pci(0x1C,0x2)/Pci(0x0,0x0)</key>
<dict>
    <key>device-id</key><data>MxUAAA==</data>   <!-- 0x1533 小端 -->
    <key>built-in</key><data>AQ==</data>
    <key>model</key><string>Intel I210 Ethernet</string>
</dict>
```

**PCI 路径不要抄上面的，自己解**（不同主板/插槽必然不同）：

```bash
# ① 找到 I225 的 IOPCIDevice 节点（device-id 0x15F3，部分批次 0x125C）
ioreg -p IODeviceTree -l -w0 | /usr/bin/grep -B3 -A12 '"IOName" = <"ethernet">'
# ② 顺着父节点名往上拼：RP03@1C,2 → Pci(0x1C,0x2)；D068@0 → Pci(0x0,0x0)
ioreg -p IODeviceTree -n RP03 -r -d1
```

或用 Hackintool 的「PCI」页直接复制路径。

**`device-id` 的 base64 怎么算**（小端，4 字节）：

```bash
printf '\x33\x15\x00\x00' | base64     # 0x1533 → MxUAAA==
printf '\xf3\x15\x00\x00' | base64     # 0x15F3（原始值，用于核对）
```

> 节点上 `IODEXTMatchCount` 若 ≥ 2，说明**多个 dext 在抢这块卡**（E1000 / IXGBE / IXL），
> 这是 §1.1 事实③的现场实证。

### 1.4 校验与落盘

```bash
plutil -lint /Volumes/EFI/EFI/OC/config.plist
<ocvalidate 路径>/ocvalidate /Volumes/EFI/EFI/OC/config.plist
diff "EFI存档/config.plist.bak-*-before-i210" /Volumes/EFI/EFI/OC/config.plist
```

`diff` **应该只有三处**：boot-args 末尾、新增 kext 条目、新增 DeviceProperties 段。
多于三处 ⇒ 说明改到了别的东西，回滚重来。

ESP 写盘纪律：`sync && sleep 8` 再重启（FAT 缓存未落盘会卡死），另见 `SKILL.md` 的「改 ESP 的安全流程」。

### 1.5 重启后判据

```bash
networksetup -listallhardwareports | /usr/bin/grep -A2 Ethernet
ifconfig en0
kmutil showloaded | /usr/bin/grep -i i210
route -n get default
ls -lt /Library/Logs/DiagnosticReports/com.apple.DriverKit-AppleEthernet*.ips 2>/dev/null | head -3
```

成功的标志（四条同时满足）：

```
kmutil showloaded → com.apple.driver.AppleIntelI210Ethernet (2.3.1)
networksetup       → Hardware Port: Ethernet / Device: en0
ifconfig en0       → inet <DHCP 地址> + status: active + media: 1000baseT <full-duplex,flow-control>
IO 注册表          → D068@0 (IOPCIDevice) → AppleIntelI210 → en0 (IOEthernetInterface) → IONetworkStack
```

**失败判据表**：

| 现象 | 含义 | 下一步 |
|---|---|---|
| `en0` 没出现，`kmutil` 也没有 I210 | kext 没加载 | `/var/log/system.log` 看 kext 报错；查 `Enabled`、`BundlePath`、依赖版本 |
| `kmutil` 有 I210，但没有 `en0` | kext 加载了、驱动不了硬件 | I225 与 I210 寄存器不兼容 ⇒ 回滚，改走路线 B |
| 出现 `en1` 而不是 `en0` | 驱动抢到了，但 `en0` 被别的网卡占着 | 见 `network-en0-order.md` |
| 速率显示 `2500baseT` | 不可能是这条路 | 说明 dext 还在跑，`e1000=0` 没生效 |
| 出 panic | 硬件不兼容 | 立刻回滚（§1.7） |

### 1.6 预期与风险（说在前面）

- **速率必然降级**：I225-V 是 2.5G，I210 是千兆 ⇒ **最多千兆**，媒体类型显示 `1000baseT`。这是预期，不是故障。
- **硬件代际不匹配**：I210 走 Linux `igb` 栈、I225 走 `igc` 栈，寄存器布局不同。
  Apple 的 I210 驱动能「认」上 I225 靠的是部分寄存器兼容，**不是官方支持**，PHY 层可能有隐患。
- **历史实测不乐观**：同一篇远景帖里，一个楼主先报「没卡死」、几小时后改口「还是崩了」；
  另一位去掉原驱动换 I210 后**直接黑屏无信号**，硬等 5 分钟进系统仍「没起作用」。
  ⇒ **必须提前准备好回滚手段**（U 盘 EFI 副本 + config 备份）。
- **残留噪音（可接受）**：`e1000=0` 不能完全阻止 E1000 dext 启动，启动十几秒后仍可能落一份
  `com.apple.DriverKit-AppleEthernetE1000-<时间>.ips`（`IOService::init() (.cold.2)` 断言）。
  **不影响功能**（I210 照样 attach 拿到 `en0`），不用管。
  加参数后 `IXGBE` 那份通常不再出现（说明参数至少影响了 IXGBE）。
  想彻底消掉可再追加 `dk.e1000=0`（同样是追加），但**能用就别为消噪音再动一次**。

### 1.7 回滚

```bash
cp "EFI存档/config.plist.bak-<时间戳>-before-i210" /Volumes/EFI/EFI/OC/config.plist
rm -rf /Volumes/EFI/EFI/OC/Kexts/AppleIntelI210Ethernet.kext
sync
```

回滚后回到「无有线但不崩」的状态，再按 §2 / §3 选第三方驱动。

**若起不来 / 黑屏**：`Reset NVRAM` 没用（`e1000=0` 在 `config.plist` 里，不在 NVRAM）。
真正的手段是**用 U 盘 EFI 启动进系统，把备份盖回去** —— 所以 **U 盘 EFI 副本是这条路线的前置条件**，
改之前先确认 U 盘那份是能亮的。

---

## 2. 路线 B · Intel 2.5G —— I225 / I226

| 方案 | 说明 |
|---|---|
| **`laobamac/SimpleVGBE`** | *"Intel **2.5G** Ethernet driver for macOS. Based on **I225** firmware in LinuxKernel V6.5"* —— 支持 **I225 / I226**（具体硬件 ID 见仓库 `igc_hw.h`）；移植自 Linux 的 IGC 驱动 |
| **`laobamac/SimpleHacPlugins` → `SimpleEthernet`** | **Lilu 插件**，注入 i225/226/210/211 驱动。原文：*"Put it into `EFI/OC/Kexts` and enable it, then reboot. **Only Ventura and newer system need it!**"*；Sonoma 14.5 实测 **2.5G 速率与虚拟机网络正常** |
| ~~`AppleIGC.kext`~~ | ★ 本机曾用，**因 `com.sxx.AppleIGC` 1.9d2 触发网络 panic 已禁用**（`uipc_mbuf.c:4839`）；上游 issue 仍未关闭 |

**支持情况（`SimpleVGBE`）**：IPv4/IPv6 DHCP · TCP 校验和 · **TSO / TSO6** · 网线热插拔与重分配 · 支持 Sequoia
**已知限制**：强制速率受 `igc_ethtool_set_link_ksettings()` 影响**无法生效**

## 3. 路线 B · Intel 千兆 —— I210 / I211 / 82575·76·80 / I350

| 方案 | 说明 |
|---|---|
| `laobamac/SimpleGBE` | 移植自 Ubuntu 的 `EthernetIgb-5.17.4`；支持 **I210 · I211 · 82575/82576/82580 · I350/I350T4**；**支持 Sequoia**；自 v1.0.1 起支持**自定义速率与 MTU 9000** |
| `SimpleHacPlugins → SakuraLegacyFix` | Intel **I350 / X540** —— **测试中，暂无下载**（作者说将并入 `SakuraEthernet`） |

> ⚠️ **`SimpleGBE` 自 2026-06-18 起进入存档状态**，不再更新（作者原话）。
> ★ 同一条目也能驱动 I210 硬件，但**做仿冒请用 §1 的 Apple 原版**，别混。

## 4. 路线 B · Realtek —— RTL8125 / RTL8126

| 方案 | 说明 |
|---|---|
| **`laobamac/SimpleRTK5`** | **RTL8125 / 8126 的 2.5 / 5GbE 驱动**；原生兼容 macOS 网络栈（**支持 AppleVTD**）；支持 **ASPM** 与 **TSO**；可用 boot-arg / 设备属性调**轮询间隔** |
| ~~`laobamac/SimpleRTLHV`~~ | ★ **已并入 `SimpleRTK5`，不要再单独用**（原定位：RTL8125 2.5G 的 Lilu 插件） |

## 5. 装法与纪律

**装**：

1. `.kext` 放进 `EFI/OC/Kexts/`，`Kernel → Add` 加条目
   ★ **`SimpleEthernet` 是 Lilu 插件** ⇒ 必须排在 **`Lilu` 之后**
2. 改 ESP 走**安全流程**：备份 → 改 → `plutil -lint` → `ocvalidate` → `sync` → 卸载重挂 → 复验 sha

**★★ 纪律：一次只换一套** ——
**同一台机器不要同时注入多套有线驱动**（`AppleIGC` + `SimpleVGBE` 会**互相抢设备**；
原版 I210 与任何第三方 I210 驱动同理）。
换驱动时先把旧的那套 `Enabled=false` 或删掉（判据见 `disks-and-kexts.md`）。

**验证**：

```bash
ifconfig en0 | head -3                  # 有没有 inet + status: active
networksetup -listallhardwareports      # ★ 确认 en0 归属（见 network-en0-order.md）
system_profiler SPEthernetDataType | head -30
```

> ★★ **换完必须复查 `en0`** —— 换驱动会改变挂载顺序，`en0` 可能换人 ⇒
> `ROM` / iMessage / FaceTime / App Store 会**静默失效**（详见 `network-en0-order.md`）。
> ★ **AirDrop / 接力不受影响**（它只看 `awdl0`，见 `airdrop-handoff.md`）。

## 6. 安全提示

- 第三方 kext 都**非 Apple 签名** ⇒ 需要 `SecureBootModel=Disabled`，SIP 视情况放宽
  （§1 的 Apple 原版 kext 不受此限，但仍要 `e1000=0`）
- 从 Releases / 第三方 EFI 取包时**必须验签名链或哈希**，别只看文件名
  （`SimpleGBE` 这类**已存档**的项目不会再修 bug）
- 有线网卡**不影响 Wi-Fi**，但会影响 `en0` 归属与网络服务顺序 ⇒ 改完顺带看一眼「系统设置 → 网络」里的服务顺序
