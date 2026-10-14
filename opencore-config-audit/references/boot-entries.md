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

## 7. ★★ 在 macOS 里添加 / 修改启动项

### 7.0 三条前提，先搞清楚再动手

**前提 1：写 NVRAM 需要提权。**
本机实测：**普通用户/沙箱里写任何 NVRAM 变量都会直接报
`Error setting variable … (iokit/common) general error`**（连一个普通变量都写不进去）。
⇒ 必须走 **Terminal + `sudo`**，或提权 AppleScript
（`osascript -e 'do shell script "…" with administrator privileges'`）。
★ `dump` / `backup` **不需要**提权，只有 `add` / `del` / `restore` 需要。

**前提 2：`RequestBootVarRouting=true` 会把 `Boot*` 重定向走。**
官方定义（`UEFI>Quirks>RequestBootVarRouting`，Failsafe `false`）：

> *Request redirect of all `Boot` prefixed variables from `EFI_GLOBAL_VARIABLE_GUID` to
> `OC_VENDOR_VARIABLE_GUID`. … This quirk requires `OC_FIRMWARE_RUNTIME` protocol implemented in
> `OpenRuntime.efi`. … Operating systems are jailed and only controlled by OpenCore boot environment.*

源码（`Platform/OpenRuntime/UefiRuntimeServices.c` · `IsEfiBootVar()`）：

```c
if (!CompareGuid (VendorGuid, &gEfiGlobalVariableGuid)) return FALSE;
if (StrnCmp (L"Boot", VariableName, L_STR_LEN (L"Boot")) != 0) return FALSE;
…
// Boot0001 → OCBt0001,  BootOrder → OCBtOrder
CopyMem (&NewVariableName[0], OC_VENDOR_BOOT_VARIABLE_PREFIX, …);
```

⇒ **在 macOS 里写 `8BE4DF61-…:Boot####`，很可能被改名成 `OC_VENDOR:OCBt####`**，
**回读也走同一条重定向**（所以「回读一致」**证明不了**它落到了固件）。

**反过来也有一条重要事实**：OpenCore **自己**写启动项时会**临时关掉这层保护** ——
`OcRegisterBootstrapBootOption()` 用 `OcDisableNvramProtection()` / `OcRestoreNvramProtection()` 包住整段写入。
⇒ **「让 OpenCore 自己写」是唯一确定落到固件的那条路**（§7.1）。

**前提 3：验收只看 BIOS。**
⇒ 写完**重启进 BIOS 启动菜单**看有没有那条项、是不是第一；
或看 OpenCore 引导日志里的 `OCB:` 行（§4.3）。**别拿 `nvram` 回读当成功证据。**

### 7.1 六条路线对照

| # | 路线 | 在哪做 | 可靠性 | 要重启 | 要 Windows | 提权 |
|---|---|---|---|---|---|---|
| **A** | **`LauncherOption=Full`，让 OpenCore 自己建**（★ 推荐） | 改该 ESP 的 config | ★★★ 确定写固件 | 是 | 否 | 否 |
| **B** | **OpenShell 的 `bcfg`** | OpenCore 选择器 → OpenShell | ★★★ 固件级 | 是 | 否 | — |
| **C** | 带 `FullNvramAccess=true` 的工具 | OpenCore 选择器 → 工具 | ★★★ | 是 | 否 | — |
| **D** | `nvram` 直写 `Boot####` | macOS 终端 | ★ 可能被重定向 | 是 | 否 | **要** |
| **E** | `bless --setBoot` | macOS 终端 | ✗ 改的是 `efi-boot-device` | — | 否 | 要 |
| **F** | EasyUEFI / `bcdedit` | Windows | ★★★ | 是 | **是** | — |

### 7.2 路线 A（推荐）：让 OpenCore 自己写

1. 确认该 ESP 的 config：`Misc>Boot>LauncherOption=Full`、`LauncherPath=Default`、
   `UEFI>Quirks>RequestBootVarRouting=true`、`UEFI>Drivers` 里有 `OpenRuntime.efi`（启用）
2. **从这块 ESP 启动一次**
3. OpenCore 用 `OcDisableNvramProtection()` 绕过重定向 ⇒ 建/更新**真正的** `Boot####` 并置 `BootOrder` 首位
4. 判据：引导日志里出现 `OCB: Creating boot option OpenCore of NNN bytes` /
   `OCB: Moving boot option to the front from N position`
5. ★ **前提**：同一台机器上**不能有第二块 ESP 也是 `Full` + 同一 `LauncherPath`**（§1 的坑）

### 7.3 路线 B：OpenShell 的 `bcfg`

1. `Misc>Tools` 里启用 `OpenShell.efi`（本机已启用），在 OpenCore 选择器里选它
2. ★★ **先解除 NVRAM 保护**，二选一：
   - 官方路线：跑 `\EFI\OC\Tools\OpenControl.efi disable`（之后必须 reboot 或 `OpenControl restore`）
   - 或把该工具的 `Misc>Tools>FullNvramAccess` 设 `true`
     （官方：*"Disable `OpenRuntime` NVRAM protection during usage of a tool … may be required … if a tool
     needs to access NVRAM directly **without the redirections put in place by `RequestBootVarRouting`**"*）
3. 在 OpenShell 里：

```text
bcfg boot dump -v                              # 列出全部启动项
map -r                                         # 刷新文件系统映射，找出 ESP 的 FS 号
bcfg boot add 1 FS0:\EFI\OC\OpenCore.efi "OpenCore"
bcfg boot mv 1 0                               # 挪到第一位
bcfg boot rm <n>                               # 删除
```

4. ★★ **ASUS 上不要用 `Boot0000`**（源码注释：条目重复 + BIOS 变砖，见 §5）

### 7.4 路线 C：带 `FullNvramAccess` 的工具

官方 `Misc>Tools>FullNvramAccess`：*"Disable `OpenRuntime` NVRAM protection during usage of a tool."*
⇒ 给需要**直写 NVRAM** 的工具开这个开关（EFI 版 EasyUEFI、`bcfg` 类工具）。
★ **只对 `Tools` 有效**，`Entries` 恒为 `false`。

### 7.5 路线 D：`nvram` 直写（本机实测，含完整字节模板）

**先决条件**：要么该次启动的 config 用 `RequestBootVarRouting=false`，要么接受「可能只写进 `OC_VENDOR`」并去 BIOS 验证。

```bash
G=8BE4DF61-93CA-11D2-AA0D-00E098032B8C

sudo nvram "$G:BootOrder"                       # 读
sudo nvram "$G:Boot0001"                        # 读某条
sudo nvram "$G:Boot0001=<%XX 载荷>"              # 写
sudo nvram "$G:BootOrder=%01%00%80%00"           # 写顺序 = [Boot0001, Boot0080]
sudo nvram -d "$G:Boot0001"                     # 删
```

**`EFI_LOAD_OPTION` 载荷结构**（本机实测 **154 字节**，与 OpenCore 自报的字节数分毫不差）：

```text
off  0 : Attributes            UINT32   01 00 00 00        (LOAD_OPTION_ACTIVE)
off  4 : FilePathListLength    UINT16   0x0082  (=130)
off  6 : Description           UTF-16LE + NUL   "OpenCore" = 18 B
off 24 : DevicePath            130 B
         ├ ACPI  PciRoot(0x0)                    12 B   ← HID 固定 0x0A0341D0 + UID
         ├ Pci   (0x6,0x0)                        6 B   ← ★ 字节序是【Function 在前, Device 在后】
         ├ Pci   (0x0,0x0)                        6 B
         ├ NVMe  (0x1, ⟨EUI64 8 字节⟩)            16 B
         ├ HD    (1, GPT, ⟨ESP 分区 GUID 16 字节⟩, 0x1000, 0x39000)  42 B
         │        ★ 起始 LBA 单位是【512 字节块】，不是字节数
         ├ FilePath  \EFI\OC\OpenCore.efi        44 B   ← UTF-16LE，【无结尾 NUL】
         └ End   7f ff 04 00                      4 B
合计 4 + 2 + 18 + 130 = 154 B
```

**编码**：`nvram` 的值用 `%XX` 表示不可打印字节。
★★ **陷阱**：macOS 自己的输出会把 `0x20` 打成**字面空格**，而**值里的字面空格会被 `nvram` 当成参数分隔符**
⇒ 「读出来什么样就写回去」**会失败**。**写之前必须统一重新编码**（本技能的脚本把每个字节都写成 `%XX`）。

**★ 本机实测结论（重要）**：
- 提权后写 `Boot0001`（154 B）→ **回读逐字节一致**；`BootOrder` 也能改写。
- 但**提权写一个新的 `Boot0002` 后读不回来** ⇒ 与「被重定向到 `OC_VENDOR`」一致。
- ⇒ **回读一致 ≠ 已落固件**。**验收只能看 BIOS。**

**用脚本**（`scripts/oc-nvram-bootentry.sh`，本机实测）：

```bash
S=~/.workbuddy-ai/skills/opencore-config-audit/scripts/oc-nvram-bootentry.sh
bash $S dump                                    # 只读：列出 BootOrder + 每条 Boot####（已解析设备路径）
bash $S backup ~/nvram-bootentry-备份            # 只读：备份
sudo bash $S add --esp disk2s1 --name OpenCore \
     --dp-prefix 'PciRoot(0x0)/Pci(0x6,0x0)/Pci(0x0,0x0)/NVMe(0x1,⟨你的 NVMe EUI64⟩)' --first
sudo bash $S add --esp disk2s1 --name OpenCore --from-entry Boot0001 --first   # 复用已有项的前缀
bash $S add ... --dry-run                        # ★ 只生成载荷、不写入（用来核对）
sudo bash $S del 2                               # 删除 Boot0002
sudo bash $S restore ~/nvram-bootentry-备份       # 回滚
```

★ 校验过：`--dp-prefix`（文本）、`--from-entry`、以及 OpenCore 当年写的那条，**三者生成的载荷逐字节相同**。

### 7.6 路线 E：`bless` —— 能读，但**建不了 BIOS 条目**

`man bless`（EFI 系统）：

> `--setBoot` — Set the system to boot off the specified partition. … **On EFI-based systems, the
> `efi-boot-device` variable is changed.**

⇒ 它改的是 **Apple 自己的 `efi-boot-device`**，**不是固件启动菜单里的 `Boot####`**；
PC 固件不消费这个变量 ⇒ **别指望它能在 BIOS 里建出条目**。
它可靠能做的是**读**：`sudo bless --info --getBoot`。
（★ 本条依据 man 页，**未在本机复现**。）

### 7.7 路线 F：Windows

`bcdedit /enum firmware` 列出固件项；EasyUEFI 图形界面增删/排序最直观。
★ 用完记得**回 macOS 复查** `BootOrder`（Windows 会把**自己**标成最优先，官方 Note 3）。

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
