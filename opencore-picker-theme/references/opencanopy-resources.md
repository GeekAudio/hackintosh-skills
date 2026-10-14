# OpenCanopy 资源目录、图标清单与尺寸

> 依据：`OpenCorePkg` 文档 **OpenCanopy 章节** 与 **`Docs/Flavours.md`**（版本要与机器上的 OpenCore 一致）。
> 官方还提供 `Docs/AcpiSamples` 之外的资源仓库：**`acidanthera/OcBinaryData`**（字体 + 三套图标集）。

## 1. 资源目录结构

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

- 文档原话：预定义图标保存在 **`PickerVariant` 推导出的子目录**里（`EFI\OC\Resources\Image\<...>`）
- 图标集可以是**第三方厂商格式**（`<厂商>\<图标集>`），`PickerVariant` 写 `Acidanthera\GoldenGate`
- **`PickerMode` 必须是 `External`**，OpenCanopy 才会加载；`UEFI>Drivers` 里要有 `OpenCanopy.efi`

## 2. 图标清单（.icns）

文档说明：**所有尺寸都是 1x 缩放下的规范值**，其它缩放级别按比例放大。
「可选图标缺失时，会用最接近的可用图标」；外置盘优先用 `Ext` 前缀版本（例：`OldExtHardDrive.icns`）。

### 2.1 强制图标（缺了 OpenCanopy 起不来）

来自 OpenCanopy 章节的 **mandatory** 标记 + `Flavours.md` 的「System Icons / Required」：

| 图标 | 尺寸（1x） | 用途 |
|---|---|---|
| `HardDrive.icns` | 128×128 | 通用可引导系统（**Flavours.md：Required，缺了 OpenCanopy 不启动**） |
| `ExtHardDrive.icns` | 128×128 | 外置盘上的可引导系统（**Required**） |
| `Cursor.icns` | 最大 144×144 | 鼠标指针 |
| `Selected.icns` | 144×144 | 选中项背景 |
| `Selector.icns` | 最大 144×40 | 选中框 |
| `SetDefault.icns` | 最大 144×40 | 「设为默认」指示（**宽度必须与 `Selector` 一致**） |
| `Left.icns` | 40×40 | 向左滚动 |
| `Right.icns` | 40×40 | 向右滚动 |
| `BtnFocus.icns` | — | 关机/重启按钮的焦点框 |
| `Dot.icns` | — | 密码输入的小圆点 |
| `Enter.icns` | — | 密码输入的确认符号 |
| `Lock.icns` | — | 密码锁 |
| `Password.icns` | — | 密码输入区域 |
| `Restart.icns` / `ShutDown.icns` | — | 额外的重启/关机按钮 |

### 2.2 官方图标集**提供**的可选图标（OcBinaryData 有）

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

### 2.3 ★ 官方图标集**不提供**的可选图标（日志里报 Not Found 是正常的）

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
是 OpenCanopy 在探测这些可选图标后的正常回退**，不是资源损坏。
（本机实测：GoldenGate / Syrah / Chardonnay 三套官方集**各只有 25 个 `.icns`**，逐个下载验证过 —— 想消除这些行只能自己补图标。）

### 2.4 ★ 文档与资源包的一处出入（实测）

`Docs/Flavours.md` 把 **`Other`** 列在「Optional — **Provided by OcBinaryData**」里，但**当前三套官方集都没有 `Other.icns`**
（实测三套均为 HTTP 404，OC 日志里也会报 `…\Other.icns - Not Found`）。
⇒ 想要「自定义条目」的图标得自己提供；**别把它当资源损坏去修**。
（`scripts/oc-theme-check.sh` 会把这个差异直接列出来，省得每次重新查。）

## 3. 标签（`Resources/Label`）

- 文件名后缀 `.lbl`（1x）/ `.l2x`（2x）；**全部标签都是必需的**
- 文档原话：**所有标签高度必须正好 12 px**，宽度不限；字体是 Helvetica 12 pt × 缩放因子
- 生成工具：官方自带的 **`disklabel`**（预渲染标签）与 **`icnspack`**（打 `.icns`）
- 标签清单：`EFIBoot`（通用系统）、`Apple`、`AppleRecv`、`AppleTM`、`Windows`、`Other`、`ResetNVRAM`、
  `SIPDisabled`、`SIPEnabled`、`Shell`、`FirmwareSettings`、`Tool`
- 没有预渲染标签时的兜底顺序：`.contentDetails`（或 `.disk_label.contentDetails`）里的文字 → 条目名本身

## 4. 字体（`Resources/Font`）

- 格式 = **AngelCode binary BMF**（`.bin`）
- 官方推荐生成链：**dpFontBaker**（用 CoreText 效果最好）→ **fonverter** 导出二进制
- 用 `UEFI>Output>ConsoleFont` 指定字体文件；文本渲染器与缩放见 `picker-attributes.md`

## 5. 音频辅助（`Resources/Audio`）

- 放 `.mp3`；`Misc>Boot>PickerAudioAssist` 打开「语音辅助」（读条目名）
- 配合 `UEFI>Audio` 那组设置：`AudioSupport` / `AudioDevice` / `AudioOutMask` / `MinimumAudibleGain` / `AudioSetupDelay` 等
- 条目音效（entry sound）由 **Flavour** 决定（见 `flavours.md`）—— 这也是 `OC_ATTR_USE_FLAVOUR_ICON` 的作用之一
- 想让开机有「启动音」属于 UEFI Audio 的 `AudioBeep`/`AudioTone` 范畴，与主题是两件事

## 6. 背景与配色

- `Background.icns` 放在图标集目录里 = 居中背景图（**官方集不提供**）
- 背景色由 NVRAM `4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14:DefaultBackgroundColor` 决定；
  `PickerVariant=Auto` 会按它挑图标集（`Syrah Black` → GoldenGate，`Light Gray` → Chardonnay）

## 7. 相关官方工具

| 工具 | 用途 |
|---|---|
| `disklabel` | 生成 `.disk_label` / `.l2x`（配合 `OC_ATTR_USE_DISK_LABEL_FILE`） |
| `icnspack` | 把 PNG 打成 `.icns` |
| `OcBinaryData` 仓库 | 官方图标集 / 字体 / 标签 / 音频的现成资源 |
