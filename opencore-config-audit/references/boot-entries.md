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

### 3.1 首选：把 `LauncherOption` 改 `Disabled`（**两个 ESP 都要改**）

```text
Misc > Boot > LauncherOption   Full  →  Disabled      （LauncherPath 保持 Default）
```

- **硬盘 ESP 和 U 盘 ESP 的 config 都要改** —— 只改一边，从另一边引导时**照样会改写**。
- 改完 OpenCore 不再碰 NVRAM，启动项完全交给**固件 / EasyUEFI** 管理。
- **本机执行记录（2026-10-15 02:20）**：硬盘 ESP（`disk2s1`，512 G「系统」盘）
  `Full → Disabled`，`plutil -lint` OK、官方 `ocvalidate` *No issues found*、
  `sync` → 卸载 → 提权重挂 → 复验 sha `b06951b2…`；
  备份 `_oc-backup-before-launcheropt-disabled-20261015-022012.plist` + ESP 内同名 `.bak`。
  **U 盘那一半待做**（当时没有外接盘）。

### 3.2 备选：U 盘 `Disabled`、硬盘 `Full`

保留「硬盘每次开机自愈」的好处，同时 U 盘不再改写 NVRAM。
**代价**：U 盘自己那条项要靠固件/EasyUEFI 管；且**只要有一边是 `Full` 且从它启动过，硬盘项就可能已被重指**。

### 3.3 兜底：`\EFI\BOOT\BOOTx64.efi`

**两个 ESP 都保留 `\EFI\BOOT\BOOTx64.efi`**（本机 53,248 B，另有 `bootx64.efi.win` 备用）。
`LauncherOption=Disabled` 时它**重新参与引导** ⇒ 启动项真丢了，也能从 **BIOS 启动菜单直接选那块硬盘**启动，
进去后再用 EasyUEFI 把项加回来。

### 3.4 入口真的丢了，怎么恢复

1. **最省事**：开机按 `F8`/`F11`（ASUS 是 `F8` 弹启动菜单）→ 直接选那块硬盘 → 进系统后用 EasyUEFI 重加。
2. **Windows 侧**：`bcdedit /enum firmware` 能看到固件项；EasyUEFI 图形界面重加最直观。
3. ★★ **要手工 `bcfg boot add/rm` 必须先解除 NVRAM 保护**：
   `UEFI>Quirks>RequestBootVarRouting=true` 会保护 NVRAM ⇒ 官方要求**先跑 `OpenControl.efi disable`**
   （OpenCore 的 `Tools/OpenControl.efi`），之后 reboot 或 `OpenControl restore`。

## 4. 取证命令

### 4.1 读固件启动项（macOS 侧）

```bash
G=8BE4DF61-93CA-11D2-AA0D-00E098032B8C          # EFI Global Variable GUID

# 启动顺序（UINT16 小端数组，每个 = 一条 Boot#### 的编号）
nvram $G:BootOrder

# 逐条看内容（名字 + 设备路径 + 文件路径都在里面）
nvram $G:Boot0000
nvram $G:Boot0080
```

> ⚠️ **`nvram -p` 不会列出 `Boot####`**（本机实测只出 19 个变量，全是 Apple/工具侧变量）。
> **必须按 `GUID:名字` 单独读**。读不到的编号会报 `(iokit/common) data was not found`。

### 4.2 本机 2026-10-15 实测快照（`LauncherOption=Disabled` 之后）

| 变量 | 内容 | 说明 |
|---|---|---|
| `BootOrder` | `80 00`（= 只有 `Boot0080`） | 固件启动顺序里**只有 macOS 那条** |
| `Boot0080` | 名字 `Mac OS X`，路径 `\System\Library\CoreServices\boot.efi` | ★ **macOS 自己 `bless` 出来的项**（GPT 卷 GUID `64EBE4AE-…`），**不是 OpenCore 的** |
| `Boot0000` | 名字 `Windows Boot Manager`，路径 `\EFI\MICROSOFT\BOOT\BOOTMGFW.EFI` | ★ 见 §5 的 ASUS 坑 |
| `Boot0001`… | `data was not found` | — |

⇒ **没有 OpenCore 自己的项** —— 与 `LauncherOption=Disabled` 一致：引导靠 `\EFI\BOOT\BOOTx64.efi` 兜底。

### 4.3 引导期日志

```bash
grep -E "OCB: (Have existing option|Creating boot option|Moving boot option)" \
     /Volumes/EFI/opencore-*.txt
```

## 5. 代价与取舍（改之前必须知道）

| 项 | 内容 |
|---|---|
| ★ **官方警告** | *"When `LauncherOption` is not enabled, **other operating systems may overwrite OpenCore settings**"* ⇒ 多系统时**官方建议开启**。本机缓解 = `\EFI\BOOT\BOOTx64.efi` 兜底 + EasyUEFI 重加 |
| **官方 Note** | **在 OpenCore 之前执行 NVRAM reset 会抹掉这条项**（OpenCore 内部执行的 reset 一般不会）⇒ 刷 BIOS / 清 NVRAM 后要重加 |
| **官方 Note 3（Intel Visual BIOS）** | Intel NUC 等固件的 bug：**只要有一条指向 USB 设备的启动项，之后插任何 U 盘都只显示那一条**。官方建议：**任何会从 U 盘启动的 OpenCore 都设 `Disabled` 或 `System`**。本机是 ASUS 不是 Intel NUC，**只是同类现象，不是本机病因** |
| ★★ **ASUS 专属坑** | 源码注释：*"**Boot0000 is reserved on ASUS boards** and is treated like a deleted entry. Setting Boot0000 will essentially cause entries to **duplicate and eventual BIOS brick** … Reproduced on ASUS ROG STRIX Z370-F GAMING."* ⇒ **在 ASUS 板上不要手工创建 `Boot0000`** |
| **固件兼容性** | 官方 Note 1：部分固件 NVRAM 实现有缺陷（Haswell 等）⇒ `LauncherOption` **只应在已知兼容的板子上用**（`acidanthera/bugtracker#1222`） |

## 6. 判据纪律

- **先分清「消失的是哪一条项」**：OpenCore 的？Windows 的？还是 macOS `bless` 出来的 `Boot0080`？
  三者由不同主体创建，处置完全不同。
- **这是 NVRAM / 固件层问题** ⇒ 与 kext、驱动、`SecureBootModel` **无关**；「多等一会儿」不会变好。
- **别与「选择器里看不到某个系统」混** —— 那是 `ScanPolicy` / `HideAuxiliary` / `Misc>Entries`（见 `pitfalls.md` §A）。
- **改了 `LauncherOption` 之后**：下一次从「另一边」的 ESP 引导时，**复查一遍** `BootOrder` 是否又变了。
- **多系统机器**：`Full` 与 `Disabled` 各有代价，**没有免费选项** —— 选完写进报告，并留好 §3.3 的兜底。
