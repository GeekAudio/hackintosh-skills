# 系统升级：macOS 15 (Sequoia) → 26 (Tahoe) 的配置修改

> ★ **OCLP 的另一选择**：`laobamac/OCLP-Mod`（OCLP 的 mod 版：中文界面、Sequoia 的 Intel 无线、
> KDK/MetalLib 加速下载）。⚠️ **该项目 2026-06-13 已存档**，已存在的版本仍可用，但**API 节点会逐步关闭**
> ⇒ ★ **在 OCLP-Mod 设置里关掉 `SimpleHacAPI`**。索引见 `laobamac-toolkit.md`。

> 本文是**大版本升级**的专用流程（不是装机流程；装机见 `lifecycle.md`）。
> 核心命题：**同一份 OpenCore 配置要同时服务两个 Darwin 大版本 ⇒ 必须用 `MinKernel` / `MaxKernel` 把按版本分构建的 kext 分流**。
> 实测基线（本文的升级终点）：macOS **26.7.1 (25G241)** / Darwin **25.6.0**、机型 `MacPro7,1`、博通 BCM943602CDP。

## ★★ 两条硬约束（先读这两条，再往下）

1. **升级时不许改机型** —— `PlatformInfo` 里任何 `SystemProductName` / `BoardProduct` / 三码都不动。
   **机型不在新版白名单里 ⇒ 加 boot-arg 绕过**（`-no_compat_check` + `revpatch=sbvmm`），**不是换机型**。详见 §5。
2. **按版本分构建的 kext 必须做版本分流** —— 用 `MinKernel` / `MaxKernel`。详见 §1、§2。

## 0. 结论先行：升级会「必然」打断什么

| 会被打断的 | 为什么 | 是不是「配置坏了」 |
|---|---|---|
| **Wi-Fi 直接消失** | 按 Sequoia 构建的无线 kext 条目写着 `MaxKernel=24.99.99` ⇒ 升到 Darwin 25 后**被 OpenCore 跳过** | **不是**。这是必然 |
| **OCLP root patch 全部失效** | 系统升级会把系统卷恢复成原生状态（`IO80211.framework` 变空壳、补丁记录消失） | **不是**。每次大版本升级都这样 |
| **FileVault 挡住 OCLP** | OCLP 的 Post-Install 拒绝在 FileVault 开启时打补丁 | 不是 |
| **`/Library/Extensions` 里的第三方 kext 被搬走** | OCLP 打补丁前会清理 **mtime < 2021-10-01** 的 kext，搬到 `/Library/Relocated Extensions`（NVIDIA 那批的时间戳是 `1970-01-01`） | 不是 |

> ★★ **先记住这句**：**升级后 Wi-Fi 必死、root patch 必丢 —— 这是设计使然，不是你把配置改坏了。**
> 所以升级流程的重点不是「排查」，而是**按顺序做那几件必做的事**（§3）。

---

## 1. ★★ 核心机制：`MinKernel` / `MaxKernel` 与 Darwin 版本

### 1.1 Darwin ↔ macOS 对照

macOS 的「大版本」在内核里是 **Darwin 主版本号**，`Kernel > Add/Block/Patch` 的 `MinKernel` / `MaxKernel`
写的就是它（格式 `MAJOR.MINOR.PATCH`，**空 = 不限制**）：

| macOS | Darwin | 典型 `MinKernel` 写法 |
|---|---|---|
| 14 Sonoma | 23.x | `23.0.0` |
| **15 Sequoia** | **24.x** | `24.0.0` / 上限 `24.99.99` |
| **26 Tahoe** | **25.x** | **`25.0.0`** |
| （查自己的机器） | — | `uname -r` |

### 1.2 ★ `24.99.99` 这个写法是什么意思

它是**「把上限钉死在整个 Darwin 24，但不误伤 Darwin 25」**的惯用写法：

```
MaxKernel = 24.99.99   ⇒ 只在 Darwin 23 / 24 生效，Darwin 25 起自动跳过
MinKernel = 25.0.0     ⇒ 只在 Darwin 25 起生效
```

**不要**写 `MaxKernel = 25.0.0`（会把 Darwin 25 本身也框进去）或 `MaxKernel = 24.0.0`（会把 24.1–24.99 全排除）。
`24.99.99` 是 OCLP 官方配置里用的写法，跟着用。

### 1.3 条目字段（`Kernel > Add` 一条的完整形态）

| 字段 | 值 | 说明 |
|---|---|---|
| `Arch` | `x86_64` | |
| `BundlePath` | `Xxx.kext` | **plugin 要写全路径**，见下 |
| `Comment` | 自由文本 | 建议写清「给哪个系统、来自哪」 |
| `Enabled` | `True` / `False` | |
| `ExecutablePath` | `Contents/MacOS/<可执行名>` | plugin 同理要带前缀路径 |
| `PlistPath` | `Contents/Info.plist` | |
| **`MinKernel`** | **`25.0.0`** | ★ 版本分流 |
| **`MaxKernel`** | **`24.99.99`** | ★ 版本分流 |

**★ plugin 的写法**（实例：博通卡驱动是 `IO80211FamilyLegacy.kext` 里的一个 plugin）：

```
BundlePath     = IO80211FamilyLegacy.kext/Contents/PlugIns/AirPortBrcmNIC.kext
ExecutablePath = Contents/MacOS/AirPortBrcmNIC
PlistPath      = Contents/Info.plist
MinKernel      = 23.0.0
MaxKernel      = 24.99.99
```

### 1.4 三条规则

1. **同一个功能如果上游提供了「按内核版本分别构建」的产物 ⇒ 必须写两条条目、用 `MinKernel`/`MaxKernel` 分开**。
   **不能**只留一条（会有一个系统用不了），也**不能**两条都不写限制（会两个系统都加载 ⇒ 冲突/panic）。
2. **上限一律用 `24.99.99`** 收口到 Darwin 24。
3. **通用 kext（Lilu / VirtualSMC / WhateverGreen / RestrictEvents / USBToolBox …）不需要写** ——
   它们跨版本通用，留空即可。**只给「按系统分构建」的那些写。**

---

## 2. ★ 逐部件版本限制清单

### 2.1 网卡（最常踩，也是本文重点）

| 网卡 | Sequoia (Darwin 24) 条目 | Tahoe (Darwin 25) 条目 | 来源 |
|---|---|---|---|
| **博通 BCM43602 / BCM943602CDP** | `IO80211FamilyLegacy.kext`（`Min 23.0.0`）<br>+ **plugin** `…/PlugIns/AirPortBrcmNIC.kext`（`Min 23.0.0` / **`Max 24.99.99`**） | **`AirPortBrcmNIC-Tahoe.kext`**<br>（`Min 25.0.0`，**OCLP 3.0.0-rc.3 起才提供**） | `broadcom-wifi.md` |
| **Intel** | `AirportItlwm-Sequoia`（`Min 24.2.0` / `Max 24.99.99`） | `AirportItlwm-Tahoe`（`Min 25.0.0`） | `intel-wifi.md` |
| **MediaTek MT792x** | 无版本分流（本来就都实验性） | 同左 | `mediatek-wifi.md` |

> ★★ **博通这条是踩过的坑**：`AirPortBrcmNIC.kext` 的 `MaxKernel=24.99.99` 是 **OCLP 2.5.1 写死的**，
> 而 **OCLP 2.5.1 根本没有 Tahoe 支持** ⇒ 升到 26 后 Wi-Fi 直接消失。
> **必须换 OCLP 3.0.0-rc.3+**（它的 `payloads/Config/config.plist` 里才有 `AirPortBrcmNIC-Tahoe.kext` 那条）。
> 三条条目的正确形态（对照 OCLP 官方配置）：
>
> ```
> [1] IOSkywalkFamily.kext                      Min 23.0.0  Max —
> [2] IO80211FamilyLegacy.kext                  Min 23.0.0  Max —
> [3] …/AirPortBrcmNIC.kext                     Min 23.0.0  Max 24.99.99   ← Darwin 23–24
> [4] AirPortBrcmNIC-Tahoe.kext                 Min 25.0.0  Max —          ← Darwin 25+（3.0.0 新增）
> ```

### 2.2 网卡配套（不分版本，但升级时状态会变）

| 项 | Sequoia / Tahoe 的差别 |
|---|---|
| `Kernel > Block > com.apple.iokit.IOSkywalkFamily` | 两版都要（`Min 23.0.0`），让第三方驱动接管 |
| 蓝牙 NVRAM 两条 data（`bluetoothExternalDongleFailed` / `bluetoothInternalControllerInfo`） | 两版都要，且 `NVRAM > Add` 与 `Delete` 都要有 |
| `USB` 端口映射（蓝牙端口 `UsbConnector=255` Internal） | 两版都要 |
| `built-in` / `IONameMatch` | 两版都要 |

### 2.3 显卡 / 其它

| 部件 | 版本限制怎么处理 |
|---|---|
| **NVIDIA（NullMoth 驱动）** | **不用 `MinKernel`** —— 它装在 `/Library/Extensions` 从 AuxKC 加载，**不在 EFI 里**。<br>升级靠**换文件**：`/Library/NullMoth/kexts/26/NVAccel.kext` 覆盖 `26` 版，再 `kmutil create` 重建 AuxKC |
| Lilu / VirtualSMC / WhateverGreen / RestrictEvents / NVMeFix / USBToolBox / XHCI-unsupported / UTBMap / AMFIPass | 留空（通用）。**但要用「支持新系统」的新版本**——升级时顺手更新到最新 |
| `BlueToolFixup` | 写 `Min 21.0.0`（跨版本通用，不需要分流） |

---

## 3. ★★ 升级时序（照着做）

### 阶段 A：升级**前**（在 macOS 15 上做）

1. **先关 FileVault** —— 否则 OCLP 的 Post-Install 会拒绝打补丁（`Cannot patch due to the following reasons: FileVault is enabled`）。
   - `fdesetup status` 看状态；**若显示 `in progress`（正在加密）⇒ 只能等它跑完**，加密/解密迁移**不能并发**
   - ⚠️ `fdesetup disable` **失败时仍返回退出码 0**，别只看 `$?`
   - ⚠️ `fdesetup` 按**短名**（RecordName）匹配，不认 RealName
2. **跑 OCLP 前置保护脚本**（★ **必做，不能跳**）—— 防 OCLP 打补丁时把时间戳为 `1970-01-01` 的 NVIDIA kext 搬去 `Relocated Extensions`：
   ```bash
   sudo bash prep-oclp-rootpatch.sh     # 只修 mtime、不改内容，并全目录备份
   ```
3. **备份 EFI**（整个 `EFI` 文件夹，不只 config）+ 记下当前 `opencore-version` 与 `uname -r`。
4. **准备 Tahoe 专用 kext**：从 **OCLP 3.0.0-rc.3+** 取 `AirPortBrcmNIC-Tahoe.kext`（或 Intel 的 `AirportItlwm-Tahoe`）。
5. **★ 确认机型不在白名单时，加绕过参数（不动机型）**：`-no_compat_check` + `revpatch=sbvmm`（§5.3）。
   > 这一步**只改 boot-args**。**不要**顺手把机型换成白名单里的 —— 那是另一件事（§5.2）。
6. **★ 核对一遍「不许动」清单**：`PlatformInfo` 三处 `SystemProductName`、`BoardProduct`、三码 —— 全都没动。

### 阶段 B：升级**中**

5. 从「系统设置 → 通用 → 软件更新」升级。
   - **不要**用 OCLP 的 "Build and Install OpenCore" —— 它会重写整个 EFI，把你的 boot-args / SMBIOS / DeviceProperties 全冲掉。**我们只要 root patch。**

### 阶段 C：升级**后**（在 macOS 26 上做）

6. **补版本分流的 kext 条目**（§2.1）—— 装 `AirPortBrcmNIC-Tahoe.kext` + 在 `Kernel > Add` 加 `MinKernel=25.0.0` 那条。重启，先让内核栈通。
7. **重打 OCLP root patch**：`OpenCore-Patcher.app` → **Post-Install Root Patch** → Start Root Patching。
   应看到 **"Networking: Modern Wireless"**。
8. **重启**，然后按 §6 验证。

> **FileVault 的例外**：若系统卷 `Sealed: Broken` 而又必须开 FileVault，
> 需要补 OCLP 的 **`Force FileVault on Broken Seal`** 内核补丁（见 §4.5）。

---

## 4. 升级时必须改的 config 项

### 4.1 `Kernel > Add` —— 补版本分流条目

见 §2.1。**这是「升级 15→26」最核心的一处改动。**

### 4.2 `Kernel > Block > com.apple.iokit.IONDRVSupport`

**桌面机 + 第三方显卡驱动**：**`Enabled = true`**（屏蔽掉系统自带的，让驱动抢 display index 0）。

但**安装器 / 升级期要反过来**：**`Enabled = false`**（允许固件 framebuffer 活过 PCI setup）。
装好驱动后再改回 `true`。

> 判据：**若内屏挂在「无驱动的 Intel iGPU」上** ⇒ 必须 `false`（否则内屏黑）；否则桌面机用 `true`。

### 4.3 BAR 相关（安装器友好 ↔ 日常）

| 键 | 升级 / 安装期 | 升级后（日常） |
|---|---|---|
| `UEFI > Quirks > ResizeGpuBars` | **`-1`**（交给固件，不 resize） | 按需（例：`13` = 8 GB） |
| `Booter > Quirks > ResizeAppleGpuBars` | **`0`**（安装器用小 BAR） | **`-1`**（日常） |

**为什么**：安装器跑在固件 framebuffer 上，大 BAR 会让它卡在 PCI configuration。

### 4.4 安全与 SIP

| 键 | 值 | 说明 |
|---|---|---|
| `Misc > Security > SecureBootModel` | **`Disabled`** | 第三方 kext 非 Apple 签名，必须 |
| `csr-active-config` | 按需放宽 | 实测可用 `430A0000`（≈ `0x0A43`：UNTRUSTED_KEXTS + UNRESTRICTED_FS + KERNEL_DEBUGGER + UNRESTRICTED_NVRAM + UNAPPROVED_KEXTS + UNAUTHENTICATED_ROOT）。**OCLP 与第三方驱动都要求它非 0** |

### 4.5 `Kernel > Patch` —— OCLP 的 FileVault 补丁（按需）

系统卷 Seal 被 OCLP 破了、又开着 FileVault 时必需：

```
Identifier = com.apple.filesystems.apfs
Base       = _apfs_filevault_allowed     ← 用符号定位，Find 留空
Replace    = b801000000c3                ← mov eax,1; ret
MinKernel  = 20.4.0
Count / Skip / Limit = 0
```

### 4.6 boot-args

| token | 什么时候要 |
|---|---|
| **`-no_compat_check`** | ★ **机型不在新版白名单里时必需**（见 §5）—— 解决「能不能启动」 |
| **`revpatch=sbvmm`** | ★ **同上，解决「能不能收到/安装系统更新」**（见 §5.3）—— 这个容易被漏掉 |
| `revpatch=cpuname` + `revcpu=1` + `revcpuname=<名字>` | CPU 名称显示（如 `revcpu=1`） |
| `-wegnoigpu` | 藏掉无驱动的核显（否则 `IOGraphicsFamily` bring-up 会等它，实测慢 ~60 s） |
| `-v` | **偏好项，必须问客户**（见 `lifecycle.md` §6.3） |

> 用 `revpatch=` / `revcpu=` 需要 **`RestrictEvents.kext`**（Lilu 插件）。

---

## 5. ★★ 硬约束：升级时不改机型，用参数绕过

### 5.1 约束

> **升级系统时，`PlatformInfo` 的机型相关字段一个都不动。**
> **机型不在新版白名单里 ⇒ 加 boot-arg 绕过，不是换机型。**

具体「不许动」的：

- `PlatformInfo > Generic > SystemProductName`
- `PlatformInfo > SMBIOS > SystemProductName`
- `PlatformInfo > DataHub > SystemProductName`
- `PlatformInfo > SMBIOS > BoardProduct`（board-id）
- 序列号 / MLB / UUID（三码）

### 5.2 为什么这是硬约束，而不是「两种路线可选」

换机型**不是一个孤立改动，而是一次耦合改动**：

| 连带影响 | 后果 |
|---|---|
| **board-id 变 ⇒ ACPI 表重新解析** | ★ 已知真因（案例）：BIOS 里那张 **`OEM Table ID = xh_adls3`** 的 SSDT 解析不过（**`HS06 AE_NOT_FOUND`**）⇒ 循环重启。**不是 USB 图**（见 `smbios-and-serials.md` §2） |
| **board-id 变了** | 触发**系统卷重建 / 校验** ⇒ 若 OCLP 已破封印，**可能卡住**（踩过） |
| XCPM profile 跟着换 | CPU 频率行为变化（`MacPro7,1` 强制 `hwp=on` ⇒ 必须重做 CPUFriend 数据） |
| AGDC 路径、ByHost 偏好 | 显示/服务行为漂移，排查面变大 |

⇒ **升级本身已经是高风险操作，不要在同一轮里叠加第二个耦合改动。**
机型该不该换是**独立的决策**（换机型见 **`smbios-and-serials.md`**），跟升级解耦。

### 5.3 绕过用什么参数（两个都要，别只加一个）

| 参数 | 解决什么 | 不加的后果 |
|---|---|---|
| **`-no_compat_check`** | **能不能启动** —— 关掉对机型的兼容性检查 | 直接拒绝启动 |
| **`revpatch=sbvmm`** | **能不能更新** —— 强制 VMM SB 机型，*"allowing OTA updates for unsupported models on macOS 11.3 or newer"*（RestrictEvents 原文） | 能开机，但**收不到 / 装不上系统更新** |
| `revpatch=cpuname` + `revcpu=1` + `revcpuname=<名字>` | CPU 名称显示 | 「关于本机」里 CPU 名字不对 |
| `revpatch=pci` / `revblock=pci` | 屏蔽 `MacPro7,1` 机型的 PCI / RAM 配置警告 | 弹配置警告（机型是 MacPro7,1 但硬件不匹配时） |

**★ 最容易漏的是 `revpatch=sbvmm`** —— 很多人只加 `-no_compat_check`，能开机就以为完事了，
结果到了下次系统更新才发现「收不到更新」。**两个是不同层次的问题。**

### 5.4 白名单（**只用来判断「需不需要绕过」**）

macOS 26 大幅削减了 Intel 机型支持。参考上游脚本的判定，白名单是：

```
iMac20,1   iMac20,2   MacPro7,1   MacBookPro16,1   MacBookPro16,2   MacBookPro16,4
```

**`iMacPro1,1` 被剔除了** —— 它正是 Sequoia 时代最常用的 Intel 机型。

| 机型在不在白名单 | 该怎么做 |
|---|---|
| **在** | 什么都不用加 |
| **不在** | **加 `-no_compat_check` + `revpatch=sbvmm`**，机型保持不变 |

### 5.5 ★ 明确不要做的事

| 不要做 | 为什么 |
|---|---|
| 改任何一处 `SystemProductName` | 违反约束；且 board-id 变会触发 **ACPI 重新解析**（ASUS 的 `xh_adls3` 这类表会炸）+ 系统卷重建（§5.2） |
| 改 `BoardProduct`（board-id） | 触发系统卷重建，与 OCLP 冲突 |
| **跑 `nullmoth-setup.sh --update prepare --pkg <包>`** | ★ **最隐蔽的陷阱**：它会**自动**把机型改成 `MacPro7,1`、board-id 改成 `Mac-27AD2F918AE68F61`、补 `RestrictEvents.kext`。**这条路径与约束正面冲突，必须避开。**<br>（正常点按钮 / 正常更新驱动**不会**触发它 —— 该按钮在 1.0.15 起已从 App UI 移除，只剩脚本能力；实测该脚本跑完后 `PlatformInfo` 仍是原机型） |
| 用 OCLP 的 "Build and Install OpenCore" | 会重写整个 EFI，冲掉调好的 boot-args / SMBIOS / DeviceProperties |

### 5.6 约束的代价（要如实告知）

保留原机型 = **放弃新版专属的机型界面**。例如 `PlatformInfo > Memory` 的 `Devices` 数组
**只在 MacPro 机型上**才会画出那张 12 槽内存图（见 `memory-injection.md`）——
机型不是 MacPro 就做不出来，**没有 boot-arg 能替代**。

所以取舍是：

| | 保留原机型 + 参数绕过（**约束默认**） | 换机型 |
|---|---|---|
| 能开机 / 能更新 | ✅（靠 `-no_compat_check` + `revpatch=sbvmm`） | ✅ |
| 升级风险 | **低**（只动 boot-args） | 高（ACPI/SSDT + board-id + CPUFriend + 三码 一起动） |
| 机型专属界面 | ❌ 拿不到 | ✅ |
| 与升级是否解耦 | ✅ **解耦** | ❌ 耦合 |

⇒ **默认走左边。** 真想要机型专属功能时，**单独一次**做机型切换（走 **`smbios-and-serials.md`** 的完整流程），
**不要**把它塞进升级那一次。

---

## 6. 验证判据

```bash
# ① Darwin 版本 —— 确认真的升上去了
uname -r                              # 期望 25.x

# ② 无线内核栈 —— 四个都要在（博通路线）
kmutil showloaded --list-only | grep -E "IOSkywalkFamily|IO80211FamilyLegacy|AirPort.BrcmNIC|corecapture"

# ③ ★ Wi-Fi 死活看 en1，别只看 system_profiler
#    ★★ 并确认「无线 = en0」（打补丁/换卡会改变驱动挂载顺序）⇒ network-en0-order.md
networksetup -listallhardwareports
ifconfig en1                          # 期望有 inet + status: active
ifconfig awdl0                        # 在 = AirDrop / 接力可用

# ④ root patch 是否打上
ls /System/Library/CoreServices/OpenCore-Legacy-Patcher.plist
ls -l /System/Library/Frameworks/IO80211.framework/Versions/A/   # 要有二进制，不能只剩 Resources

# ⑤ 第三方 kext 有没有被搬走
ls /Library/Relocated\ Extensions 2>/dev/null || echo "OK: 不存在"

# ⑥ OC 注入结果
ls -lt /Volumes/EFI/opencore-*.txt | head
```

| 判据 | 期望 |
|---|---|
| `uname -r` | `25.x` |
| 无线四件套 | 全 ✅ |
| `en1` | 有 `inet` + `active` |
| `awdl0` | 存在 |
| `OpenCore-Legacy-Patcher.plist` | 存在 |
| `/Library/Relocated Extensions` | **不存在** |

---

## 7. macOS 26 新增的环境坑

| 坑 | 现象 | 正确做法 |
|---|---|---|
| **EFI 挂载必须提权** | `diskutil mount disk1s1` 报 `Volume on disk1s1 failed to mount` | **不是文件系统坏了**：macOS 26 的 `/Volumes` 权限变成 `drwxr-xr-x root wheel`，普通用户**建不了挂载点**。用 `osascript -e 'do shell script "mkdir -p /Volumes/EFI; diskutil mount disk1s1" with administrator privileges'` |
| **FAT 换成 FSKit 实现** | 挂载选项里出现 `fskit` | 行为与旧 `msdosfs` 有差异，别按旧经验判断 |
| **在 EFI 上删文件会留 `.Trashes`** | 挂载失败、`..' entry in /.Trashes/501/OC has incorrect start cluster` | `rm -rf` 在 FAT 上会被 safe-delete 转成「移到废纸篓」⇒ 坏目录项。**修法：`diskutil repairVolume diskXsY`** |
| **`log show` 时间过滤失效** | `--start/--end` 报 `Wall Clock adjustment detected` 返回整个日志库 | 用**流式过滤**，见 `boot-timeline.md` |

---

## 8. 两条 Wi-Fi 路线怎么选

| | **OCLP 3.0.0-rc.3+（legacy 路线）** | AppleBCMWLANCompanion（BCMC） |
|---|---|---|
| root patch | **需要** | 不需要 |
| **AWDL / AirDrop / 接力** | **保留** ✅ | **不支持** ❌（项目 `Documentation/Issues.md` 原文：*"AWDL is not currently available"*） |
| SIP | 可放宽 | **要求开启 SIP**（与第三方显卡驱动**直接冲突**） |
| VT-d / AppleVTD | 不需要 | **需要** |
| OTA 升级 | 正常 | **会 kernel panic**（升级前必须先关掉） |
| 成熟度 | prerelease，但**是唯一支持 Tahoe 的** | "Beta Testing — Not Recommended for Daily Use" |

> ⇒ **换博通卡的目的就是 AirDrop / 接力 ⇒ 选 OCLP。** 只有当 OCLP 失败时才退到 BCMC（那时 AirDrop 会没）。

---

## 9. 回滚

| 回滚什么 | 怎么做 |
|---|---|
| EFI 改动 | 用升级前的 EFI 备份整个覆盖回去；或 `add-tahoe-wifi-kext.sh --revert` 这类专用脚本 |
| OCLP root patch | OCLP 的 **Revert Root Patches**（或 Uninstaller） |
| 被搬走的 kext | `prep-oclp-rootpatch.sh --restore` |
| 整个系统 | 升级前的时间机器备份（**大版本升级前一定要做**） |

---

## 10. 排错

| 现象 | 检查 |
|---|---|
| 升级后 Wi-Fi 完全消失 | **正常**。查 §2.1 的条目有没有 `MinKernel=25.0.0` 那条；`kmutil showloaded` 看 `AirPort.BrcmNIC` 在不在 |
| `IOSkywalkFamily` 在，但 `IO80211FamilyLegacy` 不在 | 看 OC 日志（`opencore-*.txt`）里该 kext 的注入结果；确认 `Kernel > Block` 没把它自己挡住 |
| root patch 打不上 | FileVault 是否真关了（`fdesetup status`）；是否用了 2.5.1（**它没有 Tahoe 支持**） |
| 打补丁时 NVIDIA kext 不见了 | 没跑 §3 的前置保护脚本。去 `/Library/Relocated Extensions` 找回来 |
| **机型不被支持、开不了机** | 加 `-no_compat_check`（**别去换机型**，§5.3） |
| **能开机但收不到系统更新** | 漏了 **`revpatch=sbvmm`**（§5.3）—— `-no_compat_check` 不解决这个问题 |
| 开不了机（**如果**你换了机型） | **主板 OEM SSDT 解析不过**（ASUS 的 `xh_adls3` 这类表 ⇒ `HS06 AE_NOT_FOUND`，见 `smbios-and-serials.md` §2）；用 U 盘 EFI 启动并回退。**这也是「升级时不许改机型」这条约束的原因** |
| 发现机型被改了 | 大概率跑过 `nullmoth-setup.sh --update prepare --pkg`（§5.5）。用升级前的 EFI 备份还原 `PlatformInfo` |
| EFI 挂不上 | 见 §7：要提权；或先 `diskutil repairVolume` |
| 升级后开机很慢 | 见 `boot-timeline.md`（`nvrmsettle` / `-wegnoigpu` 两类已知固定延迟） |

---

## 11. 与其它 reference 的关系

- **网卡细节** → `broadcom-wifi.md`（博通，按系统分路线）、`intel-wifi.md`（Intel，Sequoia/Tahoe 两套 ABI）、`mediatek-wifi.md`（MediaTek）
- **机型与三码**（**独立决策，不跟升级混在一起做**）→ **`smbios-and-serials.md`**（主板 OEM SSDT、顺序铁律、**换机型必须换码**、CPUFriend 重做、连带项清单）
- **安全改 ESP 的流程** → `SKILL.md` 铁律 1–16 + `scripts/oc-edit-safe.sh`
- **日志判读** → `logs-and-debug.md`；**耗时分析** → `boot-timeline.md`
- **装机六阶段** → `lifecycle.md`（本文是它的「大版本升级」补充）
