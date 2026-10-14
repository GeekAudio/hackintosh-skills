# 固件启动项（`Boot####` / `BootOrder`）与 `Misc>Boot>LauncherOption`

> **症状导向**：BIOS 启动菜单里的 **OpenCore 项自己消失、只剩 Windows**；
> 或者「**用 U 盘引导一次，硬盘上那条 OpenCore 项就没了**」⇒ 直接看 §1–§3。
>
> ★ **别和下面两件事混**：`ScanPolicy` / `HideAuxiliary` 管的是 **OpenCore 自己的选择器**显示什么；
> 这里说的是 **固件（BIOS/UEFI）启动菜单**里的启动项（`Boot####` 变量）。

## 0. 一句话结论

`Misc>Boot>LauncherOption` 决定 OpenCore 要不要在**固件 NVRAM 里维护一条「指向自己」的启动项**。

它**认「自己那条项」的方式是：只比对启动项里的文件路径后缀**（`LauncherPath=Default` 时即 `OpenCore.efi`），
**不看是哪个盘**（源码注释原话：*"Using OpenCore.efi … will overwrite any option with this path (e.g. `OC\OpenCore.efi` and `OC2\OpenCore.efi`)"*）。

⇒ 于是**从 U 盘（或任何别的盘）引导一次，它就会把硬盘那条同后缀的项「就地重指」到引导介质**；
介质一拔，那条项指向不存在的设备 ⇒ **固件把它清理掉** ⇒ 启动菜单里只剩 Windows。

## 1. 症状与根因（本机 2026-10-15 实录）

### 1.1 症状

> 只要**用 U 盘引导一次**，硬盘上（EasyUEFI 加的）**OpenCore 启动项就从 BIOS 启动菜单消失，只剩 Windows Boot Manager**。

### 1.2 根因链（官方文档 + OpenCore 源码）

1. `LauncherOption=Full` ⇒ **每次开机** OpenCore 都「创建或更新固件里最高优先级的启动项」（官方原文）。
2. 它**找「自己那条项」**用 `OcDevicePathHasFilePathSuffix (CurrDevicePath, MatchSuffix, …)`，
   `MatchSuffix` 在 `LauncherPath=Default` 时 = **`OpenCore.efi`** ⇒ **只匹配路径后缀，不匹配设备**。
3. 找到后再判 `CurrOptionValid = IsDevicePathEqual (ReferencePath, CurrDevicePath)`：
   - **相等** ⇒ 认为是自己的，保留；
   - **不相等**（设备不同，即「现在是另一块盘在引导」）⇒ 走 `!CurrOptionValid` 分支：
     **用「当前设备路径」重建同一个 `Boot####`**，并把它**移到 `BootOrder` 最前面**。
4. 而 U 盘那份 EFI 的 config **也是** `Full` + `LauncherPath=Default`（= `\EFI\OC\OpenCore.efi`）
   ⇒ 从 U 盘启动时，OpenCore 把**硬盘那条同后缀项重指到了 U 盘**。
5. 关机拔 U 盘 ⇒ 该项指向不存在的设备 ⇒ **固件清理** ⇒ 只剩 Windows。

> ★ **关键认识**：这不是「U 盘抢了硬盘的项」，而是 **OpenCore 自己按「路径后缀」把两项当成同一项**。
> 只要两边都是 `Full` + 同一个 `LauncherPath`，**任何一次从另一块盘引导都会改写**。

### 1.3 官方原文（`Docs/Configuration.tex`，1.0.8）

```
LauncherOption
  Type: plist string
  Failsafe: Disabled                     ← ★ 官方默认值就是 Disabled
  Description: Register the launcher option in the firmware preferences for persistence.
    Disabled --- do nothing.
    Full     --- create or update the top priority boot option in UEFI variable storage at
                bootloader startup.
                · For this option to work, RequestBootVarRouting is required to be enabled.
    Short    --- create a short boot option instead of a complete one.
    System   --- create no boot option but assume specified custom option is blessed.
```

还有两条**直接相关**的官方说明：

- *"This option allows integration with third-party operating system installation and upgrades
  (which may overwrite the `\EFI\BOOT\BOOTx64.efi` file). **The BOOTx64.efi file is no longer used
  for bootstrapping OpenCore if a custom option is created.**"*
  ⇒ **`Full` 之后 `BOOTx64.efi` 就不参与引导了**；改回 `Disabled` 才重新靠它兜底。
- *"When `LauncherOption` is not enabled, other operating systems may overwrite OpenCore settings
  and this property should therefore be enabled when planning to use other operating systems."*
  ⇒ 这是 **`Disabled` 的代价**（见 §5）。

### 1.4 源码依据

| 位置 | 关键代码 / 注释 |
|---|---|
| `Library/OcMainLib/OpenCoreMisc.c` · `BuildLauncherPath()` | *"MatchSuffix allows us to reduce option duplication … Using OpenCore.efi (OPEN_CORE_APP_PATH) will overwrite any option with this path (e.g. `OC\OpenCore.efi` and `OC2\OpenCore.efi`)."* ⇒ `LauncherPath=Default` 时 `MatchSuffix = "OpenCore.efi"` |
| `Library/OcBootManagementLib/DefaultEntryChoice.c` · `InternalGetBoostrapOptionData()` | `IsBooptstrap = OcDevicePathHasFilePathSuffix (CurrDevicePath, MatchSuffix, MatchSuffixLen);` ⇒ **按后缀找项，忽略设备** |
| 同上 · `InternalRegisterBootstrapBootOption()` | `CurrOptionValid = IsDevicePathEqual (ReferencePath, CurrDevicePath);`，`if (!CurrOptionValid) { … }` ⇒ **用当前设备路径重建同一个 `Boot####`**，随后把该索引挪到 `BootOrder` 首位 |

### 1.5 引导期日志判据

OpenCore DEBUG 日志里会出现（`opencore-*.txt`，见 `logs-and-debug.md`）：

```
OCB: Have existing option at Boot0001, invalid     ← 找到了「自己那条」，但设备不对 ⇒ 会被改写
OCB: Creating boot option OpenCore of NNN bytes
OCB: Moving boot option to the front from N position
```

★ 看到 `Have existing option at Boot####, invalid` 就等于**这次开机改写了那条项**。

## 2. `LauncherOption` 取值对照（官方 4 档）

| 值 | 行为 | 备注 |
|---|---|---|
| **`Disabled`** | do nothing（什么都不做） | ★ **官方 Failsafe**；此时靠 `\EFI\BOOT\BOOTx64.efi` 兜底 |
| `Full` | 每次开机**创建/更新**最高优先级启动项 | 需 `UEFI>Quirks>RequestBootVarRouting=true`（成对） |
| `Short` | 建「短」启动项（只含硬盘节点） | 给 Insyde 等**处理不了完整设备路径**的老固件 |
| `System` | **不建项**，假设自定义项已被 `bless` | 配合 `ForceBooterSignature`；靠 `bless` 工具管路径 |

> ★ **`Disabled` 是官方默认值** —— 也就是说本机原先的 `Full` 本身就是**偏离 Failsafe** 的一项。
> ★ `LauncherPath` 只在 `Full`/`Short`/`System` 下有意义；`Disabled` 时源码会把它强制回 `Default`。

## 3. 解决方法

### 3.0 先定策略：三种组合的取舍

| 组合 | 结果 | 评价 |
|---|---|---|
| **硬盘 `Full` + U 盘 `Disabled`** | 从硬盘启动时 OpenCore 自建/置顶并**自愈**；U 盘只读不写 NVRAM | ★ **本机 10-15 02:41 定案** |
| **两个都 `Disabled`** | OpenCore 不再碰 NVRAM —— **但也就没人建启动项了** | 只有「已经有能用的项、且不打算让 OpenCore 管」时才合适 |
| 两个都 `Full` | 互相改写（见 §1） | ✗ 正是这个坑的成因 |

> ★★ **关键认识：`Disabled` 不是「更安全」，它只是「不管」。**
> 要让入口**存在且排第一**，就必须有人去写它 —— 要么让 OpenCore 写（`Full`，见 §3.1），
> 要么人工写（§7）。**「都设 Disabled 就没事了」是错的。**

### 3.1 本机定案：硬盘 `Full` / U 盘那份 `Disabled`

```text
硬盘 ESP 的 config：Misc > Boot > LauncherOption = Full        （LauncherPath = Default）
U 盘 ESP 的 config：Misc > Boot > LauncherOption = Disabled
```

**理由**：只有**从硬盘启动**时 OpenCore 才会建/置顶硬盘那条项（且此后每次开机自愈）；
U 盘那份设 `Disabled` 后**不再改写 NVRAM** ⇒ 不会再把硬盘项搬走。这就是收敛的组合。

- **执行记录（10-15 02:41）**：硬盘 `disk2s1` → `Full`，sha 精确回到 **`a08dfed3…`**（往返无损）；
  U 盘 `disk9s1` → `Disabled`，sha `50889560…` → **`d01b859a…`**。
  两边都 `plutil -lint` OK、官方 `ocvalidate`(1.0.8) *No issues found*、`sync` → 卸载 → 提权重挂 → 复验一致。
- 备份：`_oc-backup-before-launcheropt-back-to-full-20261015-024132.plist`、
  `_usbefi-backup-before-launcheropt-disabled-20261015-023959.plist`。

### 3.2 兜底：`\EFI\BOOT\BOOTx64.efi`

**两个 ESP 都保留 `\EFI\BOOT\BOOTx64.efi`**（本机 53,248 B，另有 `bootx64.efi.win` 备用）。
`LauncherOption=Disabled` 时它**重新参与引导**（官方原文：*"The BOOTx64.efi file is no longer used for
bootstrapping OpenCore **if a custom option is created**."*）
⇒ 启动项真丢了，也能从 **BIOS 启动菜单直接选那块硬盘**启动，进去后再把项加回来（§7）。

### 3.3 入口真的丢了，怎么恢复

1. **最省事**：开机按 `F8`（ASUS 弹启动菜单）→ 直接选那块硬盘 → 进系统后按 §7 重加。
2. **Windows 侧**：`bcdedit /enum firmware` 能看到固件项；EasyUEFI 图形界面重加最直观。
3. ★★ **要手工 `bcfg boot add/rm` 必须先解除 NVRAM 保护**（官方原文）：
   *"if OpenCore has `RequestBootVarRouting` enabled, it will be necessary to run the command
   `\EFI\OC\Tools\OpenControl.efi disable` before using `bcfg`."*
   （`OpenControl disable` 之后**必须 reboot 或 `OpenControl restore` 才能启动 OS**。）
4. **或者**让 OpenCore 自己修：把该 ESP 的 `LauncherOption` 设 `Full`，从它启动一次（§3.1）。

## 4. 取证命令

### 4.1 读固件启动项（macOS 侧）

```bash
G=8BE4DF61-93CA-11D2-AA0D-00E098032B8C          # EFI_GLOBAL_VARIABLE_GUID

# 启动顺序（UINT16 小端数组，每个 = 一条 Boot#### 的编号）
nvram $G:BootOrder

# 逐条看内容（名字 + 设备路径 + 文件路径都在里面）
nvram $G:Boot0000
nvram $G:Boot0080
```

> ⚠️ **`nvram -p` 不会列出 `Boot####`**（本机实测只出 19 个变量，全是 Apple/工具侧变量）。
> **必须按 `GUID:名字` 单独读**。读不到的编号会报 `(iokit/common) data was not found`。
> ★ 想让输出可读，用 `scripts/oc-nvram-bootentry.sh dump`（会解析出名字 / 设备路径 / 文件路径）。

### 4.2 本机实测快照

**（a）`LauncherOption=Disabled` 期间（10-15 02:20–02:41）**

| 变量 | 内容 | 说明 |
|---|---|---|
| `BootOrder` | `80 00`（= 只有 `Boot0080`） | 固件启动顺序里**只有 macOS 那条** |
| `Boot0080` | 名字 `Mac OS X`，路径 `\System\Library\CoreServices\boot.efi` | ★ **macOS 自己 `bless` 出来的项**，**不是 OpenCore 的** |
| `Boot0000` | 名字 `Windows Boot Manager`，路径 `\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI` | ★ 见 §5 的 ASUS 坑 |
| `Boot0001` | `data was not found` | 被删掉的 OpenCore 项 |

⇒ **没有 OpenCore 自己的项** —— 与 `Disabled` 一致：引导靠 `\EFI\BOOT\BOOTx64.efi` 兜底。

**（b）手工重建之后（10-15 02:38 起，当前）**

```
BootOrder = %01%00%80%00          → 顺序 = [Boot0001, Boot0080]

Boot0001  名称 OpenCore           154 字节  ACTIVE
  PciRoot(0x0) / Pci(0x6,0x0) / Pci(0x0,0x0) / NVMe(0x1,⟨EUI64⟩)
  HD(1, GPT, ⟨ESP 分区 GUID⟩, 0x1000, 0x39000) / \EFI\OC\OpenCore.efi
```

⇒ OpenCore 那条项**在 `BootOrder` 第一位**。

### 4.3 引导期日志

```bash
grep -E "OCB: (Have existing option|Creating boot option|Moving boot option)" \
     /Volumes/EFI/opencore-*.txt
```

★ 这三行合起来能**完整还原**设备路径（连大小都对得上）：
`OCB: Creating boot option OpenCore of 154 bytes` + `OCB: 1 -> Boot0001 = HD(...)` +
`OCB: Expanded DP remainder - \EFI\OC\OpenCore.efi`。

## 5. 代价与取舍（改之前必须知道）

| 项 | 内容 |
|---|---|
| ★ **官方警告** | *"When `LauncherOption` is not enabled, **other operating systems may overwrite OpenCore settings**"* ⇒ 多系统时**官方建议开启**。本机缓解 = `\EFI\BOOT\BOOTx64.efi` 兜底 + 随时可重加 |
| **官方 Note** | **在 OpenCore 之前执行 NVRAM reset 会抹掉这条项**（OpenCore 内部执行的 reset 一般不会）⇒ 刷 BIOS / 清 NVRAM 后要重加 |
| **官方 Note 3（Intel Visual BIOS）** | Intel NUC 等固件的 bug：**只要有一条指向 USB 设备的启动项，之后插任何 U 盘都只显示那一条**。官方建议：**任何会从 U 盘启动的 OpenCore 都设 `Disabled` 或 `System`**。本机是 ASUS 不是 Intel NUC，**只是同类现象** |
| ★★ **ASUS / AMI 专属坑（有源码依据）** | `Platform/OpenRuntime/UefiRuntimeServices.c` 注释：*"Many modern AMI BIOSes (e.g. **ASUS ROG STRIX Z370-F GAMING**) have bugs in AMI Post Manager protocol … `GetNextVariableName` … matches every `Boot####` variable as a potential boot option **regardless of the GUID namespace** … the boot option list on most ASUS firmware … is **corrupted (e.g. duplicated options) if `Boot####` variables are present outside `gEfiGlobalVariableGuid`**."* ⇒ **这正是 OpenCore 把 `Boot*` 重定向到 `OC_VENDOR`（改名前缀 `OCBt`）的原因** |
| ★★ **同一注释里的另一条** | *"**`Boot0000` is reserved on ASUS boards** and is treated like a deleted entry. Setting `Boot0000` will essentially cause entries to **duplicate and eventual BIOS brick**."* ⇒ **ASUS 上绝对不要手工创建 `Boot0000`** |
| **固件兼容性** | 官方 Note 1：部分固件 NVRAM 实现有缺陷（Haswell 等）⇒ `LauncherOption` **只应在已知兼容的板子上用**（`acidanthera/bugtracker#1222`） |

## 6. 判据纪律

- **先分清「消失的是哪一条项」**：OpenCore 的？Windows 的？还是 macOS `bless` 出来的 `Boot0080`？
  三者由不同主体创建，处置完全不同。
- **这是 NVRAM / 固件层问题** ⇒ 与 kext、驱动、`SecureBootModel` **无关**；「多等一会儿」不会变好。
- **别与「选择器里看不到某个系统」混** —— 那是 `ScanPolicy` / `HideAuxiliary` / `Misc>Entries`（见 `pitfalls.md` §A）。
- **改了 `LauncherOption` 之后**：下一次从「另一边」的 ESP 引导时，**复查一遍** `BootOrder` 是否又变了。
- **多系统机器**：`Full` 与 `Disabled` 各有代价，**没有免费选项** —— 选完写进报告，并留好 §3.2 的兜底。
- ★★ **从 macOS 写的启动项，验收只看 BIOS，不看回读**（原因见 §7.0）。

## 7. ★★ 官方方法：启动项丢了怎么加回来

> **官方依据**：`Docs/Configuration.pdf`（按机器上的 OpenCore 版本取）——
> `Misc>Boot>LauncherOption`（含 **Note 3**）、`UEFI>Quirks>RequestBootVarRouting`、
> `Misc>Tools`（`FullNvramAccess` / `OpenControl` / `OpenShell` / `BootKicker`）、
> `Misc>Boot>PickerMode` Note 3、Troubleshooting → Tips and Tricks。
> 下文引号内均为**官方原文**。

### 7.0 先搞清两个键（决定「能不能从系统里写」）

| 键 | 官方定义 | 意味着什么 |
|---|---|---|
| `Misc>Boot>LauncherOption=Full` | *"create or update the top priority boot option in UEFI variable storage at bootloader startup"* | OpenCore 每次开机**自己维护**入口（自愈） |
| `UEFI>Quirks>RequestBootVarRouting=true` | *"Request redirect of all `Boot` prefixed variables from `EFI_GLOBAL_VARIABLE_GUID` to `OC_VENDOR_VARIABLE_GUID`."* | ★ **OS 对 `Boot*` 的读写被劫持进 OpenCore 自己的命名空间** |

★★ **最重要的一条推论**：`RequestBootVarRouting=true` 时，**在 macOS / Linux 里写启动项
「看起来成功、读回也一致」，但没落到固件**。官方讲 Linux `efibootmgr` 时说得非常直白：

> *"Linux must be started either **not via OpenCore**, or **via OpenCore with
> `RequestBootVarRouting` disabled** for this to work."*

⇒ **想从操作系统里写启动项，就必须把你「启动时用的那份」config 的 `RequestBootVarRouting` 设成 `false`。**

### 7.1 四种方法（官方给的，按可靠性排）

| 方法 | 在哪做 | 可靠性 | 前提 |
|---|---|---|---|
| **A** `LauncherOption=Full`，让 OpenCore 自己建 | 从该 ESP 启动一次 | ★★★ 直接写固件 | 需 `RequestBootVarRouting=true` |
| **B** **OpenShell + `bcfg`（官方推荐）** | OpenCore 选择器 → Tools → OpenShell | ★★★ 固件级 | 纯 U 盘即可 |
| **C** 先 `OpenControl.efi disable` 再 `bcfg` | 同上 | ★★★ | 方法 B 报「写不进去」时用 |
| **D** 从操作系统里写 | macOS / Linux / Windows | ★ 必须 `RequestBootVarRouting=false` | 见 §7.0 |

> ★ **A 解决不了「鸡生蛋」**：固件里本来就没有 OpenCore 入口时，你**没法启动硬盘上的 OpenCore**，
> 也就没法让它自己建。⇒ 这种情况先用 **B / C / D 建一次**，之后交给 A 自愈。

### 7.2 方法 B（官方推荐）：OpenShell 里 `bcfg boot add`

**纯 U 盘操作，不需要 Windows，也不需要进任何操作系统。** 官方在 `LauncherOption` Note 3 里给的就是这套。

```text
① 插 U 盘，开机按 F8（或进 BIOS）从 U 盘启动
② OpenCore 选择器 → Tools → OpenShell
③ 依次执行：

   map -r                                  ← 列出所有文件系统
   dir FS0:\EFI\OC\                        ← 逐个确认：能列出 OpenCore.efi 的那个就是目标 ESP
   bcfg boot dump                          ← 先看现有启动项，心里有数
   bcfg boot add 0 FS0:\EFI\OC\OpenCore.efi "OpenCore"
                  ↑ 第一个参数 = 插入位置，0 = 排到第一位
                    FS0 换成上一步确认的那个

④ exit 退出 OpenShell → 重启
```

- **认目标 ESP 的诀窍**：它里面**同时**有 `\EFI\OC\OpenCore.efi`（OpenCore）和 `\EFI\Microsoft\Boot\bootmgfw.efi`（Windows）
- **判据**：重启后 BIOS 启动菜单里出现「OpenCore」且**排在第一位**

### 7.3 方法 C：`bcfg` 报「写不进去」时，先解锁 NVRAM 保护

官方原文：

> *"if OpenCore has `RequestBootVarRouting` enabled, it will be necessary to run
> `\EFI\OC\Tools\OpenControl.efi disable` before using `bcfg`."*
> *"(After `OpenControl disable`, it is necessary to either reboot or run `OpenControl restore`,
> before booting an operating system.)"*

1. 把官方发布包里的 `X64/EFI/OC/Tools/OpenControl.efi` 放进 **U 盘**的 `EFI/OC/Tools/`
2. `Misc>Tools` 里加一条指向它，并把 **`FullNvramAccess` 设成 `true`**
   （官方：*"Disable `OpenRuntime` NVRAM protection during usage of a tool."*）
3. 从选择器**跑一次这个工具**，再进 OpenShell 执行 §7.2 的 `bcfg boot add`
4. ★★ **之后必须重启（或先在 OpenShell 里跑 `OpenControl restore`），否则不能引导系统**

### 7.4 方法 D：从操作系统里写（**前提 `RequestBootVarRouting=false`**）

| 系统 | 手段 | 备注 |
|---|---|---|
| Linux | `efibootmgr` | 官方原文点名的就是这个 |
| macOS | `nvram <GUID>:<名字>` | 可读写固件启动项；**`nvram -p` 不会列出它们** |
| Windows | EasyUEFI / Boot Camp 控制面板 | 最直观 |

官方 Troubleshooting 里也把「改默认启动项」的正规入口列全了：

> *"This choice can be altered from UEFI Setup, with the macOS Startup Disk preference,
> or the Windows Boot Camp Control Panel."*

**辅助工具**：`scripts/oc-nvram-bootentry.sh`（`dump` / `backup` / `restore` / `add` / `del`）
—— ★ **`add` / `del` / `restore` 要提权；而且只在 `RequestBootVarRouting=false` 时才有意义。**

### 7.5 附：`BootKicker` —— 官方为「从 U 盘切回硬盘」写的方法（黑苹果通常不可用）

官方在 `PickerMode` Note 3 里描述的场景，与「U 盘里的 OpenCore → 硬盘上的 OpenCore」完全一致：

> *"…it can be used to switch which OpenCore installation is blessed, with `CTRL+Enter`,
> e.g. from a recovery OpenCore installation on USB/CD back to the main installation of OpenCore
> on the hard drive, if this is lost after an NVRAM reset."*

但 Tools 表对它的定义是 *"Display Apple BootPicker menu (**for Macs with compatible firmware**)"*。
⇒ **它依赖 Apple 的 BootPicker 协议，非 Apple 固件（黑苹果）上一般用不了。**
列在这里只是让你知道官方有这条，**别在这上面耗时间**。

### 7.6 日常应该怎么配（建议）

| | `LauncherOption` | `RequestBootVarRouting` | 作用 |
|---|---|---|---|
| **硬盘那份** | `Full` | `true` | 入口**自愈**；且不会被 Windows 抢走 |
| **U 盘那份** | `Disabled` | `false`（想当救援盘）或 `true` | 永远不会抢硬盘的入口；`false` 时还能当「从系统里写启动项」的救援盘 |

> ★ **为什么硬盘要保持 `Full` + `true`**：官方原话 *"When `LauncherOption` is not enabled,
> other operating systems may overwrite OpenCore settings"* —— 关了它，
> **Windows 大更新时可能把 OpenCore 的启动项覆盖掉**。`Full` 正是在防这个。
> ★ 而**任何会从 U 盘启动的 OpenCore，`LauncherOption` 必须是 `Disabled`**（官方 Note 3）—— 见 §1 的根因。

### 7.7 官方出处（可自行核对）

- `Misc > Boot > LauncherOption` —— 四个取值、`LauncherPath`、**Note 3**（USB 场景警告 + `bcfg` 抢救步骤）
- `UEFI > Quirks > RequestBootVarRouting` —— 重定向的定义与目的
- `Misc > Tools` —— `FullNvramAccess`、`OpenControl`、`OpenShell`、`BootKicker`
- `Misc > Boot > PickerMode` —— Note 3（`BootKicker` / `CTRL+Enter`）
- Troubleshooting → Tips and Tricks → *How do I choose the default boot entry?*

★ 以上全部出自 OpenCore 官方 `Configuration.pdf`（随每个发布包提供，在 `Docs/` 下）。
**一切以你机器上那个 OpenCore 版本对应的文档为准** —— 不同版本键名与取值可能变。

## 8. ★ 从「U 盘启动」改成「硬盘启动」

> **本机现状**（`nvram 4D1FDA02-…:boot-path`）：
> 10-15 02:55 = `…/USB(0x18,0x0)/…/\EFI\OC\OpenCore.efi` ⇒ 当时**从 U 盘**引导（`REL-108`）；
> **10-15 03:40 = `PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)/NVMe(0x1,…)/HD(1,GPT,…)/\EFI\OC\OPENCORE.EFI`**
> ⇒ ★★ **已经改成从内置硬盘引导**（OC = `DBG-108`）—— 也就是说**下面这套步骤本机已经走通了**，
> 留作流程参考。

### 8.1 为什么要换

- U 盘不在就**进不了系统**（U 盘成了单点依赖）
- U 盘那份可能是**救援配置**（本机 U 盘是 `iMacPro1,1` 的 FALLBACK 配置），与硬盘那份不是同一套
- `LauncherOption` 两边都 `Full` 时会互相改写（§1）

### 8.2 步骤

1. **确认硬盘 ESP 里有完整、能用的 EFI**
   ```bash
   diskutil list | grep "EFI EFI"                  # 认盘（★ 盘号会漂，别硬编码）
   diskutil mount diskXs1 && ls /Volumes/EFI/EFI/OC/
   ```
   至少要：`EFI/OC/OpenCore.efi`、`config.plist`、`Kexts/`、`Drivers/`、`ACPI/`、`Tools/`、`Resources/`，
   以及 **`EFI/BOOT/BOOTx64.efi`**（兜底入口）。
   ★ 硬盘那份**不能**照抄 U 盘的：`PlatformInfo`（机型/三码）、`ACPI`、`Kernel` 都可能不同。
2. **硬盘 config**：`Misc>Boot>LauncherOption=Full`（让它自建并置顶）、`LauncherPath=Default`、
   `UEFI>Quirks>RequestBootVarRouting=true`
3. **U 盘 config**：`Misc>Boot>LauncherOption=Disabled`（不再改写 NVRAM）
4. 两边都走安全流程：`plutil -lint` → 官方 `ocvalidate`（**必须同版本**）→ 算 sha → `sync` →
   **卸载 → 重挂 → 复验 sha**
5. **重启，并在固件启动菜单里选「那块硬盘」**（不要选 U 盘）
6. 进去之后 OpenCore（硬盘，`Full`）会在开机时把 `Boot####` 建好并置顶
7. ★★ **验收（三步都要做）**
   - 重启进 **BIOS 启动菜单**：有「OpenCore」且在**第一位**
   - `nvram 4D1FDA02-…:boot-path`：指向**硬盘**的 ESP（不是 `USB(...)`）
   - **拔掉 U 盘再重启一次**，确认照样进系统 ← **这一步才算真验收**
8. 可选：把 U 盘留作**救援盘**（保持 `Disabled`），或删掉它那条旧启动项

### 8.3 注意

- ★ **换的不只是启动介质，还是「哪一份 config」** —— 硬盘那份可能是**调试态**
  （本机硬盘 = `DBG-108`，U 盘 = `REL-108`）。**要不要顺手换回 RELEASE / 关掉 debug 日志，是独立决定，先问用户。**
- ★ **别用 `ScanPolicy` 去做「少显示」**（那是安全策略，见 `pitfalls.md` §A）。
- ★ 换完**复查 `en0` 归属**（换引导介质不影响网卡，但如果你同时动了别的，见 `network-en0-order.md`）。
- ★ 每次改完 ESP 都**同步工作区镜像 + 版本存档**，否则下次分不清哪份是哪份。
