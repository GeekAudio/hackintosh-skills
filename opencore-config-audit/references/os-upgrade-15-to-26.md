# 系统升级：macOS 15 (Sequoia) → 26 (Tahoe) 的配置修改

> ★ **OCLP 的另一选择**：`laobamac/OCLP-Mod`（OCLP 的 mod 版：中文界面、Sequoia 的 Intel 无线、
> KDK/MetalLib 加速下载）。⚠️ **该项目 2026-06-13 已存档**，已存在的版本仍可用，但**API 节点会逐步关闭**
> ⇒ ★ **在 OCLP-Mod 设置里关掉 `SimpleHacAPI`**。索引见 `laobamac-toolkit.md`。

> 本文是**大版本升级**的专用流程（不是装机流程；装机见 `lifecycle.md`）。
> 核心命题：**同一份 OpenCore 配置要同时服务两个 Darwin 大版本 ⇒ 必须用 `MinKernel` / `MaxKernel` 把按版本分构建的 kext 分流**。
> 实测基线（本文的升级终点）：macOS **26.7.1 (25G241)** / Darwin **25.6.0**、机型 `MacPro7,1`、博通 BCM943602CDP。

## 升级前先确定范围

1. **默认保留机型与身份信息**，将系统升级与 SMBIOS 迁移分别评估。若用户已要求组合迁移，按 [SMBIOS 专题](smbios-and-serials.md) 制定分步验证方案。兼容性绕过也须核实目标系统，不能自动套一组参数，见 §5。
2. **按版本分构建的 kext 必须做版本分流** —— 用 `MinKernel` / `MaxKernel`。详见 §1、§2。

## 0. 升级前核对哪些依赖会受影响

| 会被打断的 | 为什么 | 是不是「配置坏了」 |
|---|---|---|
| **Wi-Fi 直接消失** | 按 Sequoia 构建的无线 kext 条目写着 `MaxKernel=24.99.99` ⇒ 升到 Darwin 25 后**被 OpenCore 跳过** | **不是**。这是必然 |
| **OCLP root patch 全部失效** | 系统升级会把系统卷恢复成原生状态（`IO80211.framework` 变空壳、补丁记录消失） | **不是**。每次大版本升级都这样 |
| **FileVault 挡住 OCLP** | OCLP 的 Post-Install 拒绝在 FileVault 开启时打补丁 | 不是 |
| **`/Library/Extensions` 里的第三方 kext 被搬走** | OCLP 打补丁前会清理 **mtime < 2021-10-01** 的 kext，搬到 `/Library/Relocated Extensions`（NVIDIA 那批的时间戳是 `1970-01-01`） | 不是 |

> 表中问题取决于当前驱动、补丁与版本范围；未使用这些依赖的机器不一定受影响。升级前记录适用项，升级后按实际加载与功能验证，不把单机升级结果当作必然现象。
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

### 1.2 版本范围怎样匹配

OpenCore 按 **`MinKernel ≤ 当前 Darwin 版本 ≤ MaxKernel`** 匹配，包含两个端点。
`MinKernel` 留空表示无下限，`MaxKernel` 留空表示无上限；两者同时填写时，下限不能高于上限。
依据：[OpenCore 官方 Add Properties](https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.tex)。

| 需要限制的范围 | `MinKernel` | `MaxKernel` |
|---|---|---|
| 仅 Darwin 24.x | `24.0.0` | `24.99.99` |
| 仅 Darwin 25.x（macOS 26） | `25.0.0` | `25.99.99` |
| Darwin 25 及以后，且作者确认支持 | `25.0.0` | 留空 |

单写 `MaxKernel=24.99.99` 也允许更早的内核；单写 `MinKernel=25.0.0` 也允许未来的 Darwin 26 及以后。
因此，「仅 macOS 26」需要同时限定 `25.0.0`–`25.99.99`，不能把 `MinKernel` 填成 macOS 的 `26.0.0`。

作为旧版驱动的上限，`MaxKernel=25.0.0` 会包含 Darwin 25.0.0；`MaxKernel=24.0.0` 则会排除 24.1.0 等后续版本。

### 1.3 条目字段（`Kernel > Add` 一条的完整形态）

以下示例用于一份**仅支持 Darwin 25.x** 的 kext；文件路径以实际包内容为准。

| 字段 | 值 | 说明 |
|---|---|---|
| `Arch` | `x86_64` | |
| `BundlePath` | `Xxx.kext` | 相对于 `EFI/OC/Kexts/`；plugin 填包含父 bundle 的嵌套路径，见下 |
| `Comment` | 自由文本 | 建议写清「给哪个系统、来自哪」 |
| `Enabled` | `True` / `False` | |
| `ExecutablePath` | `Contents/MacOS/<可执行名>` | 相对于本条 `BundlePath` 指向的 bundle；无代码 kext 留空 |
| `PlistPath` | `Contents/Info.plist` | 同样相对于本条 bundle |
| **`MinKernel`** | **`25.0.0`** | ★ 版本分流 |
| **`MaxKernel`** | **`25.99.99`** | 与下限组成有效的 Darwin 25.x 区间 |

**★ plugin 的写法**（实例：博通卡驱动是 `IO80211FamilyLegacy.kext` 里的一个 plugin）：

```
BundlePath     = IO80211FamilyLegacy.kext/Contents/PlugIns/AirPortBrcmNIC.kext
ExecutablePath = Contents/MacOS/AirPortBrcmNIC
PlistPath      = Contents/Info.plist
MinKernel      = 23.0.0
MaxKernel      = 24.99.99
```

父 bundle 的嵌套前缀只出现在 `BundlePath`；不要在 plugin 的 `ExecutablePath` / `PlistPath` 中再次拼接它。

### 1.4 三条规则

1. **同一份 EFI 要兼容两个系统，且同一功能有分别构建的产物时，为两份构建建立独立条目**，用各自支持的 `MinKernel` / `MaxKernel` 分流。文件也要使用不同的 bundle 目录名，避免互相覆盖；只运行一个系统时只需对应构建。
2. **按每份构建的支持范围填写上下限**：Darwin 24.x 的上限是 `24.99.99`，Darwin 25.x 的上限是 `25.99.99`。不要将新旧构建的边界拼到同一条目，也不要在未经确认时让专用构建覆盖未来内核。
3. **同一构建已支持多个目标系统的通用 kext 无需复制成两份**。保留作者要求的版本限制；没有限制要求时可留空。仍需核实该构建确实支持目标系统。

---

## 2. ★ 逐部件版本限制清单

### 2.1 网卡（最常踩，也是本文重点）

| 网卡 | Sequoia (Darwin 24) 条目 | Tahoe (Darwin 25) 条目 | 来源 |
|---|---|---|---|
| **博通 BCM43602 / BCM943602CDP** | `IO80211FamilyLegacy.kext`（`Min 23.0.0`）<br>+ **plugin** `…/PlugIns/AirPortBrcmNIC.kext`（`Min 23.0.0` / **`Max 24.99.99`**） | **`AirPortBrcmNIC-Tahoe.kext`**<br>（`Min 25.0.0` / `Max 25.99.99`，部署范围限于 macOS 26；**OCLP 3.0.0-rc.3 起才提供**） | `broadcom-wifi.md` |
| **Intel** | `AirportItlwm-Sequoia.kext`（`Min 24.2.0` / `Max 24.99.99`） | `AirportItlwm-Tahoe.kext`（`Min 25.0.0` / `Max 25.99.99`） | `intel-wifi.md`；bundle 目录名按两份构建分别命名 |
| **MediaTek MT792x** | 无版本分流（本来就都实验性） | 同左 | `mediatek-wifi.md` |

> ★★ **博通这条是踩过的坑**：`AirPortBrcmNIC.kext` 的 `MaxKernel=24.99.99` 是 **OCLP 2.5.1 写死的**，
> 而 **OCLP 2.5.1 根本没有 Tahoe 支持** ⇒ 升到 26 后 Wi-Fi 直接消失。
> **必须换 OCLP 3.0.0-rc.3+**（它的 `payloads/Config/config.plist` 里才有 `AirPortBrcmNIC-Tahoe.kext` 那条）。
> 相关条目的部署示例（组件参考 OCLP 来源，Tahoe 专用条目限定到 Darwin 25.x）：
>
> ```
> [1] IOSkywalkFamily.kext                      Min 23.0.0  Max —
> [2] IO80211FamilyLegacy.kext                  Min 23.0.0  Max —
> [3] …/AirPortBrcmNIC.kext                     Min 23.0.0  Max 24.99.99   ← Darwin 23–24
> [4] AirPortBrcmNIC-Tahoe.kext                 Min 25.0.0  Max 25.99.99   ← 仅 Darwin 25（3.0.0 新增）
> ```

OCLP 来源配置中 Tahoe 条目的上限可能留空，表示没有上限。本文的部署示例只覆盖已验证的 macOS 26，
因此将该专用条目收口到 `25.99.99`；这属于部署范围限制，不能据此认定来源配置也设置了该上限。后续系统是否可用仍需重新核对兼容性。

### 2.2 网卡配套（不分版本，但升级时状态会变）

| 项 | Sequoia / Tahoe 的差别 |
|---|---|
| `Kernel > Block > com.apple.iokit.IOSkywalkFamily` | 两版都要（`Min 23.0.0`），让第三方驱动接管 |
| 蓝牙 NVRAM data（`bluetoothExternalDongleFailed` / `bluetoothInternalControllerInfo`） | 仅在所用蓝牙驱动要求时配置其规定值；需覆盖已有同名变量时才先列入 `NVRAM > Delete`，不能统一注入固定控制器数据 |
| `USB` 端口映射（蓝牙端口 `UsbConnector=255` Internal） | 两版都要 |
| `built-in` / `IONameMatch` | 两版都要 |

### 2.3 显卡 / 其它

| 部件 | 版本限制怎么处理 |
|---|---|
| **NVIDIA（NullMoth 驱动）** | 对系统目录 / AuxKC 安装的驱动，`Kernel>Add` 的 `MinKernel` / `MaxKernel` 不负责分流。按[驱动作者](https://github.com/nullmoth/nvidia-macos-driver)对应版本安装器选择目标 macOS 的完整组件组合，不能只覆盖单个 `NVAccel.kext` 推定升级完成 |
| Lilu / VirtualSMC / WhateverGreen / RestrictEvents / NVMeFix / USBToolBox / XHCI-unsupported / UTBMap / AMFIPass | 留空（通用）。**但要用「支持新系统」的新版本**——升级时顺手更新到最新 |
| `BlueToolFixup` | 写 `Min 21.0.0`（跨版本通用，不需要分流） |

---

## 3. 升级时序（按实际驱动路线选择）

### 阶段 A：升级**前**（在 macOS 15 上做）

1. **需要 OCLP root patch 时先检查 FileVault 要求**；仅在所用补丁版本要求关闭时处理 —— 该类 Post-Install 可能拒绝打补丁（`Cannot patch due to the following reasons: FileVault is enabled`）。
   - `fdesetup status` 看状态；**若显示 `in progress`（正在加密）⇒ 只能等它跑完**，加密/解密迁移**不能并发**
   - 检查 `fdesetup` 输出与后续 `status`，不要只凭退出码判断加密状态已改变
   - ⚠️ `fdesetup` 按**短名**（RecordName）匹配，不认 RealName
2. **仅使用 root patch 的机器检查补丁前置条件**。若同时安装 NullMoth 等第三方驱动，先备份系统卷补丁状态与驱动，并核对所用 OCLP 版本的清理规则、驱动安装器的共存说明及文件时间戳。历史案例中有旧时间戳驱动被移动；不能据此对所有扩展批量 `touch`。本技能未附带专用保护脚本，不依赖未提供的本地工具。
3. **备份 EFI**（整个 `EFI` 文件夹，不只 config）+ 记下当前 `opencore-version` 与 `uname -r`。
4. **升级前准备并校验版本分流**：按实际网卡路线取得兼容目标构建的 Tahoe kext，与现用版本使用不同外层目录；同步配置 §2 的 `Kernel>Add`、`MinKernel` / `MaxKernel` 和依赖。在 macOS 15 上 Tahoe 条目应因 `MinKernel=25.0.0` 而不加载；升级前完成完整备份及校验。
5. **★ 确认机型不在白名单时，加绕过参数（不动机型）**：`-no_compat_check` + `revpatch=sbvmm`（§5.3）。
   > 这一步**只改 boot-args**。**不要**顺手把机型换成白名单里的 —— 那是另一件事（§5.2）。
6. **★ 核对一遍「不许动」清单**：`PlatformInfo` 三处 `SystemProductName`、`BoardProduct`、三码 —— 全都没动。

### 阶段 B：升级**中**

5. 从「系统设置 → 通用 → 软件更新」升级。
   - **不要**用 OCLP 的 "Build and Install OpenCore" —— 它会重写整个 EFI，把你的 boot-args / SMBIOS / DeviceProperties 全冲掉。**我们只要 root patch。**

### 阶段 C：升级**后**（在 macOS 26 上做）

6. **确认版本分流生效**（§2）—— 在 Darwin 25 上确认预先配置的 Tahoe 条目命中 `25.0.0–25.99.99`，旧系统专用条目不加载；按目标网卡检查实际驱动及依赖，不重复添加相同条目。
7. **使用 OCLP 博通路线时重打 root patch**：`OpenCore-Patcher.app` → **Post-Install Root Patch** → Start Root Patching。
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
| `Misc > Security > SecureBootModel` | 按所用驱动 / 补丁路线确定 | 区分 EFI 注入、系统目录安装与 root patch。不能仅凭“第三方 kext”就要求关闭；使用需关闭 Apple Secure Boot 的补丁时按其文档配置 |
| `csr-active-config` | 保留当前值，确有要求再调整 | OCLP root patch 的 SIP 位随系统、补丁和机型变化；以该版本前置检查为准。第三方驱动并不统一要求某个非零值，不复制参考机器的位掩码 |

依据：[同版 OpenCore 配置文档](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex)、[OCLP SIP 与 root patch 说明](https://dortania.github.io/OpenCore-Legacy-Patcher/POST-INSTALL.html#sip-settings)。恢复安全设置前先撤销不兼容的系统补丁并验证可启动，不能把重新开启 SIP 当成卸载补丁。

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
| `-v` | **按用户已有偏好执行，未要求调整时保留**（见 `lifecycle.md` §6.3） |

> 用 `revpatch=` / `revcpu=` 需要 **`RestrictEvents.kext`**（Lilu 插件）。

---

## 5. 机型兼容性与身份信息单独决策

### 5.1 默认保留稳定身份

仅请求系统升级时保留现有 `SystemProductName`、board-id、serial、MLB、UUID 和 ROM。若用户明确要求迁移机型，先核对目标系统支持范围与收益，再按 [SMBIOS 专题](smbios-and-serials.md) 分步验证；不重复索取已有授权。

### 5.2 核对当前配置的依赖

| 项目 | 核对什么 |
|---|---|
| ACPI / SSDT | 当前表是否含机型匹配条件或已有错误；参考机器的 `xh_adls3` 案例不代表其他主板也要修补 |
| CPUFriend | 仅对已注入数据的机器检查适用性，必要时重建或回退 |
| 内存、USB、显卡及系统补丁 | 核对已有注入 / 补丁与目标机型、系统的匹配条件 |
| 身份信息与服务 | 保留稳定值，需变更的字段按任务范围核对，不自动重置网络、账号或 ByHost 偏好 |

### 5.3 支持范围与兼容性参数

执行时对照目标 macOS 的机型支持信息和相关驱动作者文档。若保留不在支持范围内的 SMBIOS，分别评估安装、启动和 OTA 更新；三者不能以一次启动成功互相证明。

`-no_compat_check` 与 RestrictEvents 的 `revpatch=sbvmm` 是既有方案中使用过的参数，须核对其在目标系统和具体驱动版本中的作用，不能作为所有升级的默认组合。参考 [RestrictEvents 官方说明](https://github.com/acidanthera/RestrictEvents)。CPU 显示名、PCI / RAM 警告属于其他需求，不随升级自动添加对应参数。

### 5.4 检查安装器的隐含修改

运行厂商升级脚本前读取当前版本的参数与实际修改范围。若脚本会重写机型、身份信息或整份 EFI，而这些不属于本次任务，就选择保留现值的受支持路径，或先制作候选差异再处理。

历史版本 `nullmoth-setup.sh --update prepare` 曾包含机型修改，OCLP 的构建安装操作也与单纯 root patch 不同；这些是需要核实的副作用示例，不假定任何当前版本仍完全相同。

## 6. 验证判据

```bash
# ① Darwin 版本 —— 确认真的升上去了
uname -r                              # 期望 25.x

# ② 无线内核栈 —— 四个都要在（博通路线）
kmutil showloaded --list-only | grep -E "IOSkywalkFamily|IO80211FamilyLegacy|AirPort.BrcmNIC|corecapture"

# ③ ★ Wi-Fi 死活看 en1，别只看 system_profiler
#    ★★ 核对实际无线接口及 en0 的 built-in 状态（不要求无线必须是 en0）⇒ network-en0-order.md
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
| **EFI 挂载失败** | `diskutil mount <实际ESP设备>` 失败 | 先确认目标设备、实际错误、挂载点权限及卷是否已挂载；确为权限问题时按需提权。单条失败消息不能排除文件系统问题，也不据此固定使用 `disk1s1` |
| **FAT 驱动实现差异** | 挂载选项里出现 `fskit` | 以当前挂载信息与实际驱动为准，再核对相关行为；不只凭 macOS 大版本猜实现 |
| **FAT 报目录项错误** | 文件系统检查报告 `.Trashes` 等目录的错误 | Finder 移到废纸篓会使用 `.Trashes`；普通 `rm` 直接删除目录项，不能推定它被转成 safe-delete。先备份可读文件并只读检查，确需修复时再对已确认的卷执行修复 |
| **`log show` 时间过滤失效** | `--start/--end` 报 `Wall Clock adjustment detected` 返回整个日志库 | 用**流式过滤**，见 `boot-timeline.md` |

---

## 8. Wi-Fi 路线怎么选

下表比较已有的 OCLP 与 AppleBCMWLANCompanion 路线；具体芯片和系统构建仍按作者说明核对。

| | OCLP legacy 无线路线 | AppleBCMWLANCompanion（BCMC） |
|---|---|---|
| root patch | 需要 | 不需要；既有 OCLP 无线补丁须按作者迁移流程撤销 |
| AWDL / AirDrop | 按支持硬件与补丁组合验证 | 当前作者 Issues 仍列 AWDL 不可用；Handoff 不与 AirDrop 混为一谈 |
| SIP / AMFI | 按补丁版本的前置检查调整 | 支持保持保护，作者建议干净系统与 SIP 开启；只有实际组件要求相冲突时才判定不可共存 |
| VT-d / AppleVTD | 按当前设备与其它驱动需求配置 | 默认 IOMapper 路线需核对 VT-d；作者自 1.1.0 提供 `bcmc-disable-io-mapper` 替代选项，具有内存和性能代价 |
| 系统更新 | 可能需完整系统下载，更新后核对并重打所需 root patch | 当前作者 Issues 记录 OTA panic；升级前按该版本说明停用并准备恢复 |
| 选择依据 | 目标芯片、系统构建、所需功能与实际验证 | 同左，不能把项目存在等同于目标机器已通过验证 |

依据：[BCMC Getting Started](https://github.com/0xFireWolf/AppleBCMWLANCompanion/blob/main/Documentation/GettingStarted.md)、
[BCMC Issues](https://github.com/0xFireWolf/AppleBCMWLANCompanion/blob/main/Documentation/Issues.md)、
[OCLP 更新说明](https://dortania.github.io/OpenCore-Legacy-Patcher/UPDATE.html)。

另有无需该系统卷补丁的实验候选：[SimpleBCM](https://github.com/laobamac/SimpleBCM) 作者仍要求重启实测；
[AirportBrcmCompat](https://github.com/GeekAudio/AirportBrcmCompat) 的 1.0.1-rc1 记录了特定 BCM43602、25G241 / 25G332 与内核 UUID 范围的验证及待验项。
这些证据不能推广为全部 Tahoe / 博通卡均可用，也不能再把 OCLP 称为唯一候选。先核对目标兼容范围，再逐级验证加载、联网和双向 AirDrop 实收。

---

## 9. 回滚

| 回滚什么 | 怎么做 |
|---|---|
| EFI 改动 | 用升级前的完整 EFI 备份恢复已确认的目标 ESP，核对文件和哈希；不依赖未附带的专用脚本 |
| OCLP root patch | OCLP 的 **Revert Root Patches**（或 Uninstaller） |
| 被移动的第三方 kext | 先查原安装器日志与搬移位置，按对应版本安装器重新安装或从已验证备份恢复，并重建其要求的内核集合；文件复制完成不代表实际加载 |
| 整个系统 | 升级前的时间机器备份（**大版本升级前一定要做**） |

---

## 10. 排错

| 现象 | 检查 |
|---|---|
| 升级后 Wi-Fi 完全消失 | **正常**。查 §2.1 的条目有没有 `MinKernel=25.0.0` 那条；`kmutil showloaded` 看 `AirPort.BrcmNIC` 在不在 |
| `IOSkywalkFamily` 在，但 `IO80211FamilyLegacy` 不在 | 看 OC 日志（`opencore-*.txt`）里该 kext 的注入结果；确认 `Kernel > Block` 没把它自己挡住 |
| root patch 打不上 | FileVault 是否真关了（`fdesetup status`）；是否用了 2.5.1（**它没有 Tahoe 支持**） |
| 打补丁时第三方 kext 不见了 | 查补丁与安装器日志及 `/Library/Relocated Extensions`；确认是被移动、安装未完成还是加载失败，再按 §9 恢复，不能只凭现象认定原因 |
| **机型不被支持、开不了机** | 加 `-no_compat_check`（**别去换机型**，§5.3） |
| **能开机但收不到系统更新** | 漏了 **`revpatch=sbvmm`**（§5.3）—— `-no_compat_check` 不解决这个问题 |
| 开不了机（**如果**你换了机型） | **主板 OEM SSDT 解析不过**（ASUS 的 `xh_adls3` 这类表 ⇒ `HS06 AE_NOT_FOUND`，见 `smbios-and-serials.md` §2）；用 U 盘 EFI 启动并回退。**这也是「升级时不许改机型」这条约束的原因** |
| 发现机型被改了 | 大概率跑过 `nullmoth-setup.sh --update prepare --pkg`（§5.5）。用升级前的 EFI 备份还原 `PlatformInfo` |
| EFI 挂不上 | 见 §7：要提权；或先 `diskutil repairVolume` |
| 升级后开机很慢 | 见 `boot-timeline.md`（`nvrmsettle` / `-wegnoigpu` 两类已知固定延迟） |

---

## 11. 与其它 reference 的关系

- **网卡细节** → `broadcom-wifi.md`（博通，按系统分路线）、`intel-wifi.md`（Intel，Sequoia/Tahoe 两套 ABI）、`mediatek-wifi.md`（MediaTek）
- **机型与三码**（**独立决策，不跟升级混在一起做**）→ **`smbios-and-serials.md`**（ACPI 依赖、身份一致性、CPUFriend 与内存配置的条件检查）
- **安全改 ESP 的流程** → [技能入口的修改与复验](../SKILL.md#修改与复验) + `scripts/oc-edit-safe.sh`
- **日志判读** → `logs-and-debug.md`；**耗时分析** → `boot-timeline.md`
- **装机六阶段** → `lifecycle.md`（本文是它的「大版本升级」补充）
