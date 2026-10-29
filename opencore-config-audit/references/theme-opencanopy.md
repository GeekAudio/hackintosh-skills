# OpenCanopy 选择器主题（启动界面外观）

> **依据**：`OpenCorePkg` 文档的 **OpenCanopy 章节** + **`Docs/Flavours.md`** + `Misc → Boot` / `UEFI → Output` 的属性表。
> **版本必须与机器上的 OpenCore 一致**。资源仓库：**`acidanthera/OcBinaryData`**（字体 + 三套官方图标集）。
>
> 本文由原先独立的两份主题文档合并而成：**开关与属性** · **资源与图标清单** · **Flavour** · **排错**。

## ★ 铁律（先读）

1. **必需图标缺一个，OpenCanopy 直接不启动** —— 先跑 `scripts/oc-theme-check.sh` 再谈美化
2. **图标集是「目录」不是「文件」**：放在 `EFI/OC/Resources/Image/<厂商>/<图标集>/`，
   用 `Misc>Boot>PickerVariant` 指向（**反斜杠**，如 `Acidanthera\GoldenGate`）
3. **`PickerMode` 必须是 `External`**，否则 OpenCanopy 根本不加载（`Builtin` = 纯文本界面）
4. **改 `Resources/` 也是改 ESP** ⇒ 一样要走安全流程（备份 → 改 → 校验 → `sync` → 卸载重挂 → 复验 sha）
5. **`OCUI: Failed to load image … - Not Found` 多数是正常的** —— OpenCanopy 会探测一批**可选**图标，
   而官方图标集**并不提供**它们（见 §3.3）。**别去「补」**
6. **不要顺手改主题** —— 用户没要求换外观时，`PickerMode`/`PickerVariant`/`PickerAttributes`/`Resources` 一律不动
7. **图标文件名区分大小写**（OpenCore 读的是精确名字），FAT 上也不要放怪字符
8. **1x 尺寸是规范值**，@2x 按倍数放大；尺寸不对会被拒绝或显示异常

---

## 1. 开关总表

### 1.1 `Misc > Boot > PickerMode`

| 值 | 说明 |
|---|---|
| `Builtin` | OpenCore 自带**纯文本**界面（默认） |
| **`External`** | **用外部启动管理协议**（= OpenCanopy）；不可用时**静默回退 Builtin** |
| `Apple` | 用 Apple 的启动管理（可用时），可能绕过策略检查 |

⇒ **OpenCanopy 要求 `External`**；同时 `UEFI → Drivers` 里要启用 **`OpenCanopy.efi`**（顺序在 `OpenRuntime.efi` 之后）。

### 1.2 `Misc > Boot > PickerVariant`

图标集目录名（相对 `Resources/Image`）。别名：

| 值 | 效果 |
|---|---|
| `Auto` | 按 `DefaultBackgroundColor` 自动选：`Syrah Black` → `Acidanthera\GoldenGate`，`Light Gray` → `Acidanthera\Chardonnay` |
| `Default` | 等价于 `Acidanthera\GoldenGate` |
| `Acidanthera\GoldenGate` / `Acidanthera\Syrah` / `Acidanthera\Chardonnay` | 显式指定（macOS 11 / OS X 10.10 / Mac OS X 10.4 风格） |

> 写的是**相对路径**，所以用**反斜杠**分隔。

### 1.3 `Misc > Boot > PickerAttributes`（位掩码，可相加）

| 位 | 名称 | 作用 | 依赖 / 注意 |
|---|---|---|---|
| `0x0001` | `OC_ATTR_USE_VOLUME_ICON` | 用卷自己的图标：按顺序找 `.VolumeIcon.icns`（Preboot 的按卷目录 → Preboot 根 → 卷根） | 覆盖该盘「内部/外部」的默认图标选择 |
| `0x0002` | `OC_ATTR_USE_DISK_LABEL_FILE` | 用 `.disk_label`（`.disk_label_2x`）里的预渲染标题 | 用 `disklabel` 生成；**路径与大小写必须与 config 一致** |
| `0x0004` | `OC_ATTR_USE_GENERIC_LABEL_IMAGE` | 给没有自定义条目的项用**预定义标签图** | 统一但信息更少 |
| `0x0008` | `OC_ATTR_HIDE_THEMED_ICONS` | 某些类别**优先用内置图标**以贴合主题风格（如强制内置 Time Machine 图标） | **要求 `0x0001`** |
| `0x0010` | `OC_ATTR_USE_POINTER_CONTROL` | 允许用鼠标/触控板操作选择器 | 需要指针设备（`UEFI>AppleInput` 那组） |
| `0x0020` | `OC_ATTR_SHOW_DEBUG_DISPLAY` | 显示额外计时/调试信息 | **只在 Builtin 选择器 + DEBUG/NOOPT 构建下有效** |
| `0x0040` | `OC_ATTR_USE_MINIMAL_UI` | 极简界面：**不显示关机/重启按钮** | 对 OpenCanopy 与内置选择器都生效 |
| `0x0080` | `OC_ATTR_USE_FLAVOUR_ICON` | 按 **content flavour** 选图标（与音频辅助音效） | Flavour 规则见 §4 |
| `0x0100` | `OC_ATTR_USE_REVERSED_UI` | 反转关机/重启按钮位置（贴合旧版 macOS） | 需要**未设** `0x0040` |

**常用组合**：`0`（官方默认）／`0x01`（卷图标）／`0x81`（卷图标 + Flavour）／`0x90`（Flavour + 指针控制）

### 1.4 其它影响外观的开关

| 位置 | 键 | 说明 |
|---|---|---|
| `Misc>Boot` | `ShowPicker` | 强制显示选择器（否则按默认项直接启动） |
| `Misc>Boot` | `Timeout` | 自动启动前的等待秒数（`0` = 不自动启动） |
| `Misc>Boot` | `TakeoffDelay` | 处理选择器/热键前的延迟（微秒）；某些键盘需要 5000–10000 |
| `Misc>Boot` | `HideAuxiliary` | 隐藏 recovery / Time Machine / 系统项（按**空格**进 Extended Mode 展开） |
| `Misc>Boot` | `PickerAudioAssist` | 语音辅助（读条目名） |
| `Misc>Boot` | `ConsoleAttributes` | 内置选择器的前景/背景色位 |
| `Misc>Security` | `AllowSetDefault` | 允许 CTRL+Enter 设默认项（配合 `SetDefault.icns` 才有意义） |
| `Misc>Security` | `ExposeSensitiveData` | `0x04` = 在选择器标题里显示 OpenCore 版本 |
| `UEFI>Output` | `TextRenderer` | `SystemGraphics` / `BuiltinGraphics` / …（见 §6.6） |
| `UEFI>Output` | `Resolution` | `Max` 让内置渲染器用满分辨率（HiDPI 前提） |
| `UEFI>Output` | `UIScale` | `1` 普通 / `2` HiDPI / `0` 自动按像素面积 / `-1` 不变 |
| `UEFI>Output` | `ConsoleFont` | 位图字体文件（`Resources/Font/*.bin`） |
| `UEFI>Output` | `ClearScreenOnModeSwitch`、`IgnoreTextInGraphics` | **只对 `System*` 渲染器生效** |
| `UEFI>Audio` | `AudioSupport`、`AudioDevice`、`AudioOutMask`、`MinimumAudibleGain` … | 开机声音/语音辅助的底层设置 |

### 1.5 ★ 三条容易踩的搭配关系

1. **`0x0008` 必须搭 `0x0001`** —— 单开 `0x0008` 不生效
2. **`ClearScreenOnModeSwitch` / `IgnoreTextInGraphics` 只对 System 渲染器有效** ——
   若 `TextRenderer` 改成 `BuiltinGraphics`，这两个开关会**静默失效**
3. **HiDPI（`UIScale=2`）要配 @2x 资源**：图标 `.icns` 里的 @2x 块、标签 `.l2x`；否则会被放大得模糊

---

## 2. 资源目录结构

```
EFI/OC/Resources/
├── Image/                      # 图标集（PickerVariant 指向这里）
│   └── Acidanthera/
│       ├── GoldenGate/         # 每个目录 = 一套图标集
│       ├── Syrah/
│       └── Chardonnay/
├── Font/                       # 位图字体（AngelCode binary BMF，.bin）
├── Label/                      # 预渲染标签（*.lbl = 1x，*.l2x = 2x）
└── Audio/                      # 音频辅助（*.mp3）
```

- 预定义图标保存在 **`PickerVariant` 推导出的子目录**里（`EFI\OC\Resources\Image\<...>`）
- 图标集可以是**第三方厂商格式**（`<厂商>\<图标集>`）

---

## 3. 图标清单（`.icns`）

文档说明：**所有尺寸都是 1x 缩放下的规范值**，其它缩放级别按比例放大。
「可选图标缺失时，会用最接近的可用图标」；外置盘优先用 `Ext` 前缀版本（例：`OldExtHardDrive.icns`）。

### 3.1 强制图标（缺了 OpenCanopy 起不来）

来自 OpenCanopy 章节的 **mandatory** 标记、`Flavours.md` 的「System Icons / Required」，
并以 [OpenCore 1.0.8 `GuiApp.c`](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Platform/OpenCanopy/GuiApp.c)
与 [`GuiApp.h`](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Platform/OpenCanopy/GuiApp.h) 的尺寸常量及 `AllowLessSize` 核对。
表中的“最大”同时限制宽、高，允许更小的正数尺寸；不是要求图像填满上限。

| 图标 | 尺寸（1x） | 用途 |
|---|---|---|
| `HardDrive.icns` | 128×128 | 通用可引导系统（**Required，缺了 OpenCanopy 不启动**） |
| `ExtHardDrive.icns` | 128×128 | 外置盘上的可引导系统（**Required**） |
| `Cursor.icns` | 最小 4×4，最大 144×144 | 鼠标指针 |
| `Selected.icns` | 144×144 | 选中项背景 |
| `Selector.icns` | 最大 144×40 | 选中框 |
| `SetDefault.icns` | 最大 144×40 | 「设为默认」指示（**宽度必须与 `Selector` 一致**） |
| `Left.icns` | 40×40 | 向左滚动 |
| `Right.icns` | 40×40 | 向右滚动 |
| `BtnFocus.icns` | 最大 144×144 | 关机/重启按钮的焦点框 |
| `Dot.icns` | 最大 10×10 | 密码输入的小圆点 |
| `Enter.icns` | 最大 75×30 | 密码输入的确认符号 |
| `Lock.icns` | 最大 144×144 | 密码锁 |
| `Password.icns` | 最大 288×30 | 密码输入区域；不能套用 144×144 的统一上限 |
| `Restart.icns` / `ShutDown.icns` | 最大 128×128 | 额外的重启/关机按钮 |

例如 `Selector` / `SetDefault` 都为 40×20 且同宽是允许的；不要把高度 40 当成固定值。
2x 资源的固定尺寸、最大尺寸与 `Cursor` 下限按比例翻倍；其它可变图标只要求实际像素为正。
同一缩放级别的 `Selector` 与 `SetDefault` 仍须同宽。
检查器检查所有图标集的必需 1x 图，并核对已提供的 2x 图尺寸；缺少 2x 图不代表已验证 HiDPI 可用。

### 3.2 官方图标集**提供**的可选图标（OcBinaryData 有）

| 图标 | 尺寸 | 回退 |
|---|---|---|
| `AppleRecv.icns` | 128×128 | → `HardDrive` |
| `AppleTM.icns` | 128×128 | → `HardDrive` |
| `ExtAppleRecv.icns` / `ExtAppleTM.icns` | 128×128 | → `ExtHardDrive` |
| `Windows.icns` | 128×128 | → `HardDrive` |
| `OpticalDrive.icns` | 128×128 | → `HardDrive` |
| `Other.icns`（自定义条目） | 128×128 | → `HardDrive` |
| `Shell.icns`（如 OpenShell） | 128×128 | → `Tool` |
| `Tool.icns`（其它工具） | 128×128 | → `HardDrive` |
| `NetworkBoot.icns` / `FirmwareSettings.icns` | 128×128 | — |

### 3.3 ★ 官方图标集**不提供**的可选图标（日志里报 `Not Found` 是正常的）

`Docs/Flavours.md` 里单列了一节 **「Additional Optional — NOT provided by OcBinaryData」**：

| 图标 | 回退 |
|---|---|
| `Apple.icns`（macOS） | → `HardDrive` |
| `ExtApple.icns` | → `ExtHardDrive` |
| `ExtWindows.icns` | → `ExtHardDrive` |
| `ExtOpticalDrive.icns` | → `ExtHardDrive` |
| `ResetNVRAM.icns` | → `Tool` |
| `Background.icns`（选择器背景图） | 无（提供才用） |

⇒ **`OCUI: Failed to load image … Apple.icns / ExtWindows.icns / ResetNVRAM.icns / Background.icns … - Not Found`
是 OpenCanopy 探测这些可选图标后的正常回退**，不是资源损坏。
（三套官方集**各只有 25 个 `.icns`** —— 想消除这些行只能自己补图标。）

### 3.4 ★ 文档与资源包的一处出入

`Docs/Flavours.md` 把 **`Other`** 列在「Optional — **Provided by OcBinaryData**」里，
但**当前三套官方集都没有 `Other.icns`**（下载为 404，OC 日志里也会报 `…\Other.icns - Not Found`）。
⇒ 想要「自定义条目」的图标得自己提供；**别把它当资源损坏去修**。
（`scripts/oc-theme-check.sh` 会把这个差异直接列出来。）

---

## 4. Flavour：图标与音效的选择规则

### 4.1 什么时候用

打开 `PickerAttributes` 的 **`0x0080`（`OC_ATTR_USE_FLAVOUR_ICON`）** 后：
条目图标（OpenCanopy）与条目音效（OpenCanopy + 内置选择器）都由 **content flavour** 决定。

**不开 `0x0080` 时**走的是「按条目类型直接找图标」的老逻辑（`AppleRecv.icns`、`Windows.icns` 之类）。

### 4.2 Flavour 从哪来

| 条目类型 | Flavour 来源 |
|---|---|
| **工具（Tool）** | `Misc>Tools` 条目自己的 `Flavour` 字段 |
| **自动发现的条目**（含 `OpenLinuxBoot` 等协议生成的条目） | 引导器旁边若有 `.contentFlavour` 文件，读它 |
| **`Misc>Entries` 里的自定义条目** | `Flavour` 为 `Auto` 时读 `.contentFlavour`；否则用 `Flavour` 字段指定的值 |
| 读到的 flavour 是 `Auto` 或没有 `.contentFlavour` | 用条目类型对应的默认 flavour |

- Flavour 值的语法：**`:` 分隔的名字序列，总长 ≤ 64 字符**
- **外置盘**：同时支持 `Ext<Flavour>.icns` 与 `<Flavour>.icns`；
  **只有在盘是外置时才用 `Ext<Flavour>.icns`**；若外置盘上找不到 `Ext<Flavour>.icns`，
  **出于安全考虑 OpenCore 会退到 `ExtHardDrive.icns`，而不会用 `<Flavour>.icns`**
- **优先级**：同时存在时，**`.VolumeIcon.icns` 优先于 `.contentFlavour`**

### 4.3 回退链

```
UEFIShell:Shell  →  UEFIShell.icns  →  Shell.icns  →  Tool.icns  →  HardDrive.icns
```

即：**按 flavour 序列从左到右找图标，找不到就往下退**，最终退到类型兜底（OS 类退 `HardDrive.icns`）。

### 4.4 推荐命名（`Docs/Flavours.md` 的要点）

**macOS —— 自动按版本选，通常不用手动指定**

- `Apple12:Apple`（Monterey）… `Apple11:Apple`（Big Sur）… `Apple10_15:Apple`（Catalina）… 一直到 `Apple10_4`
- **Recovery**：`AppleRecv11:AppleRecv:Apple11:Apple`（自动带版本号）
- **Time Machine**：`AppleTM11:AppleTM:Apple11:Apple`（**不会**自动带版本，要手动指定才会被找到）
- 图标作者角度：**`Apple` 推荐提供**，`AppleRecv` / `AppleTM` 建议提供，其余可选

**Windows —— 基础 flavour 自动，版本要手动**

- `Windows`（自动检测；回退 `HardDrive`）
- `Windows11:Windows`、`Windows10:Windows`、`Windows8_1:Windows` … 需手动指定（写在 `.contentFlavour` 里）

**Linux / 其它 OS / 引导器 —— 全可选**

- Linux：`Linux`（基础）+ 各发行版 `Arch:Linux`、`Debian:Linux`、`Ubuntu:Linux`、`Lubuntu:Ubuntu:Linux` …
- 其它：`Android`、`BSD`、`FreeBSD:BSD`、`ReactOS`
- 引导器：`Bootloader`、`Grub:Bootloader`、`OpenCore:Bootloader`

**工具**

- **`Tool`**（通用工具图标，推荐提供；缺失回退 `HardDrive`）
- Shell 类：`Shell` / `UEFIShell:Shell` —— 只提供一个时，通用风格命名 `Shell.icns`，
  带特定文字的命名 `OpenShell.icns` / `UEFIShell.icns`

> `Docs/Flavours.md` 明确说：**清单是为了命名一致，不是要求图标集必须提供全部**。
> 官方建议图标作者「只提供真有需求的那些」，未提供的最终都会回退到 OC 默认。

### 4.5 实用做法

1. **只想换掉某个条目的图标**：不要动全局 `0x0080`，直接在 `Misc>Entries` 给那个条目写 `Flavour`
2. **想让某个盘固定用某个图标**：放 `.VolumeIcon.icns` 在卷根（或 Preboot 的按卷目录），开 `0x0001`
   —— 它**优先于** `.contentFlavour`，且不需要 `0x0080`
3. **想让 Windows 显示 Win11 图标**：在该盘的引导器旁放 `.contentFlavour`，内容写 `Windows11:Windows`（需要 `0x0080`）
4. **改完要重启才生效**，验证看 OC 日志的 `OCUI:` 行（找图标的尝试与回退都会打出来）

---

## 5. 标签 / 字体 / 音频 / 背景

### 5.1 标签（`Resources/Label`）

- 文件名后缀 `.lbl`（1x）/ `.l2x`（2x）；使用 `PickerAttributes` 的通用标签图像时，需要当前缩放级别的完整标签。资源树检查器按完整资源包检查两种缩放。
- 标签在 **1x** 下高度为 **12 px**，2x 标签按比例为 **24 px**；其它尺寸与生成要求按同版本 OpenCanopy 文档核对
- 生成工具：官方自带的 **`disklabel`**（预渲染标签）与 **`icnspack`**（打 `.icns`）
- 标签清单：`EFIBoot`（通用系统）、`Apple`、`AppleRecv`、`AppleTM`、`Windows`、`Other`、`ResetNVRAM`、
  `SIPDisabled`、`SIPEnabled`、`Shell`、`FirmwareSettings`、`Tool`、`NetworkBoot`；最后一项也在上述 `GuiApp.c` 的 `mLabelNames` 中
- 没有预渲染标签时的兜底顺序：`.contentDetails`（或 `.disk_label.contentDetails`）里的文字 → 条目名本身

### 5.2 字体（`Resources/Font`）

- 每种缩放需要一对文件：`Font_1x.bin` + `Font_1x.png`，以及 `Font_2x.bin` + `Font_2x.png`。格式为 **AngelCode binary BMF v3** 数据与对应 PNG 字形图集
- 检查器检查这四个文件的存在和签名；签名正确不代表字体块、图集与实际渲染已完整验证
- 官方推荐生成链：**dpFontBaker**（用 CoreText 效果最好）→ **fonverter** 导出二进制
- 用 `UEFI>Output>ConsoleFont` 指定字体文件；文本渲染器与缩放见 §1.4 / §6.6

### 5.3 音频辅助（`Resources/Audio`）

- 放 `.mp3`；`Misc>Boot>PickerAudioAssist` 打开「语音辅助」（读条目名）
- 配合 `UEFI>Audio` 那组设置（§1.4）
- **条目音效**由 **Flavour** 决定（§4）—— 这也是 `0x0080` 的作用之一
- 「开机启动音」由 **`UEFI>Audio>PlayChime`** 控制（`Auto` / `Enabled` / `Disabled`），与主题图标是不同设置；`Auto` 还受 `StartupMute` NVRAM 变量影响。底层需已配置 `AudioDxe.efi`、正确的音频设备和通道，以及对应声音资源。字段以[同版本官方文档](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex)为准，不添加不存在的 `AudioBeep` / `AudioTone` 键。

### 5.4 背景与配色

- `Background.icns` 放在图标集目录里 = 居中背景图（**官方集不提供**）
- 背景色由 NVRAM `4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14:DefaultBackgroundColor` 决定；
  `PickerVariant=Auto` 会按它挑图标集

---

## 6. 排错

### 6.1 先做两件事

```bash
scripts/oc-theme-check.sh /Volumes/EFI/EFI/OC/Resources     # 资源是否齐全/合规
grep -a "OCUI:" /Volumes/EFI/opencore-*.txt | tail -40      # OC 加载图标时的真实过程
```

`OCUI:` 行会明确写出「找哪个文件、第几次尝试、成功还是 Not Found」—— **这是唯一的权威依据**，别靠猜。
（`Misc>Debug>Target` 含 `0x40` 时 OC 日志才写在 ESP 的 `opencore-*.txt` 里，见 `logs-and-debug.md`。）

### 6.2 完全看不到图形界面（还是文本界面）

| 检查 | 期望 |
|---|---|
| `Misc>Boot>PickerMode` | 必须是 **`External`** |
| `UEFI>Drivers` | **`OpenCanopy.efi` 已启用**（顺序在 `OpenRuntime.efi` 之后） |
| `Resources/Image/<图标集>/` | 目录存在，且**必需图标齐全**（见 §3.1） |
| `PickerVariant` | 指向的目录**真的存在**；写的是相对路径（反斜杠） |
| OC 日志 | 有没有 `OCUI: Failed to load image …` 指向**必需**图标（那就是根因） |

> 回退行为：`External` 不可用时会**静默退回 Builtin 文本界面** —— 所以「看到文本界面」本身就是线索。

### 6.3 界面出来了，但图标不对 / 是通用图标

| 现象 | 原因 | 处理 |
|---|---|---|
| 某个系统显示成通用硬盘图标 | 该图标**没提供**（或 flavour 没命中） | 补图标，或在该盘放 `.contentFlavour` / `.VolumeIcon.icns` |
| 外置盘图标和内置盘一样 | 外置盘上**没有** `Ext<Flavour>.icns`，OC 按安全规则退到 `ExtHardDrive.icns` | 补 `Ext*` 版本图标 |
| 设了 `0x0080` 但没变化 | `.contentFlavour` 不在**引导器旁边**；或 `Misc>Entries` 的 `Flavour` 写错 | 见 §4.2 |
| 卷图标不生效 | 没开 `0x0001`；或 `.VolumeIcon.icns` 放错位置 | 放在卷根 / Preboot 按卷目录；开 `0x0001` |
| 想让 Time Machine 用内置图标 | — | 开 `0x0008`（**必须同时开 `0x0001`**） |

### 6.4 日志里一堆 `Not Found` —— 先别急着修

`OCUI: Failed to load image … <名字>.icns prefix:<图标集> icon:N - Not Found` 的常见两类：

1. **`(1/2)` / `(2/2)`**：OpenCanopy 先试图标集目录，再试基础目录 —— 两次都失败才报
2. **名字属于「Additional Optional」**（§3.3）：**官方 OcBinaryData 根本不提供这些文件** ⇒ 这些行**是正常的**

⇒ **只有必需图标报 `Not Found` 才是故障。**

### 6.5 图标显示变形 / 被裁切 / 很糊

| 现象 | 原因 |
|---|---|
| 被裁切 | `.icns` 里的 1x 尺寸不符合规范（见 §3.1 的尺寸列） |
| `Selector` / `SetDefault` 宽度不一致 | 文档要求 `SetDefault` **必须与 `Selector` 同宽** |
| 模糊 | HiDPI（`UIScale=2`）但没有 @2x 资源 |
| 标签被拉伸 | 核对对应缩放资源：**1x 高 12 px，2x 高 24 px** |

### 6.6 文字太大 / 太小 / 位置怪

- `UEFI>Output>UIScale`：`1` 普通 / `2` HiDPI / `0` 按像素面积自动 / `-1` 不变
- `UEFI>Output>Resolution=Max`（Builtin 渲染器要用满分辨率）
- `UEFI>Output>TextRenderer`：`SystemGraphics` 用固件渲染（`ClearScreenOnModeSwitch`/`IgnoreTextInGraphics` 只对它生效）；
  `BuiltinGraphics` 自己渲染（支持 HiDPI）
- 字体：`UEFI>Output>ConsoleFont` 指向 `Resources/Font/*.bin`

### 6.7 没有声音 / 语音辅助不工作

| 检查 | 说明 |
|---|---|
| `Resources/Audio/` | 有 `.mp3` |
| `UEFI>Drivers` | 需要使用音频时，已启用与 OpenCore 同版的 `AudioDxe.efi` |
| `UEFI>Audio>AudioSupport` | 开着 |
| `UEFI>Audio>AudioDevice` | 设备路径正确（可从 OC 日志的 `OCAU: 1/3 …` 行里抄） |
| `UEFI>Audio>AudioOutMask` | 输出通道位掩码；`-1` = 全部通道（日志里 `HDA: | Port widget @ … (bitmask N)` 可查） |
| `UEFI>Audio>MinimumAudibleGain` | 系统音量低于它会**不播放**（`-128` = 不限制） |
| `Misc>Boot>PickerAudioAssist` | 语音辅助总开关 |
| `UEFI>Audio>PlayChime` | 启动音策略；它与读条目的语音辅助分别设置 |
| 条目音效 | 由 **Flavour** 决定（要 `0x0080`） |

### 6.8 改完不生效

- **必须重启**（选择器是引导期组件）
- 确认改的是**真正被引导的那份 config**：`nvram 4D1FDA02-…:boot-path` 指向哪个分区
- ESP 改完要 `sync` → 卸载 → 重挂（FAT 有写缓存），并复验 sha
- 目录/文件名**大小写敏感**（FAT 卷在 macOS 上不敏感，但 OpenCore 读的是精确名字）

### 6.9 ★ 安全提醒

`Resources/` 也在 ESP 上 ⇒ 改动同样走「备份 → 改 → 校验 → `sync`/卸载重挂 → 复验 sha」。
**主题换坏了会导致看不到选择器**（最坏情况进不了系统），所以：

- 动之前先把整个 `Resources/` 目录备份出来
- 保留一份**能用的**图标集不动（例如保留 `Acidanthera\GoldenGate` 原样，另建目录放新主题）
- 逃生口：选择器进不去就改 `PickerMode=Builtin`（或把 `PickerVariant` 指回原图标集）

---

## 7. 相关官方工具

| 工具 | 用途 |
|---|---|
| `disklabel` | 生成 `.disk_label` / `.l2x`（配合 `OC_ATTR_USE_DISK_LABEL_FILE`） |
| `icnspack` | 把 PNG 打成 `.icns` |
| `OcBinaryData` 仓库 | 官方图标集 / 字体 / 标签 / 音频的现成资源 |
| `scripts/oc-theme-check.sh` | Resources 树合规检查（必需图标 / 实际尺寸块 / 标签 / 字体 / 音频） |
| `scripts/oc-fetch-iconset.sh` | 从官方 OcBinaryData 取图标集、字体、标签、音频 |
