# PickerAttributes 与选择器相关开关

> 依据：`OpenCorePkg` 文档 `Misc → Boot Properties` 与 `UEFI → Output Properties`。

## 1. `Misc > Boot > PickerAttributes`（位掩码，可相加）

| 位 | 名称 | 作用 | 依赖 / 注意 |
|---|---|---|---|
| `0x0001` | `OC_ATTR_USE_VOLUME_ICON` | 用卷自己的图标：按顺序找 `.VolumeIcon.icns`（Preboot 的按卷目录 → Preboot 根 → 卷根） | 覆盖该盘"内部/外部"的默认图标选择 |
| `0x0002` | `OC_ATTR_USE_DISK_LABEL_FILE` | 用 `.disk_label`（`.disk_label_2x`）里的预渲染标题 | 用 `disklabel` 工具生成；**预渲染标签的路径与大小写必须与 config 一致** |
| `0x0004` | `OC_ATTR_USE_GENERIC_LABEL_IMAGE` | 给没有自定义条目的项用**预定义标签图** | 好处是统一，代价是信息更少 |
| `0x0008` | `OC_ATTR_HIDE_THEMED_ICONS` | 某些类别**优先用内置图标**以贴合主题风格（例如强制用内置 Time Machine 图标） | **要求 `0x0001`** |
| `0x0010` | `OC_ATTR_USE_POINTER_CONTROL` | 允许用鼠标/触控板操作选择器 | 需要指针设备可用（`UEFI>AppleInput` 那组） |
| `0x0020` | `OC_ATTR_SHOW_DEBUG_DISPLAY` | 显示额外计时/调试信息 | **只在 Builtin 选择器 + DEBUG/NOOPT 构建下有效** |
| `0x0040` | `OC_ATTR_USE_MINIMAL_UI` | 极简界面：**不显示关机/重启按钮** | 对 OpenCanopy 与内置选择器都生效 |
| `0x0080` | `OC_ATTR_USE_FLAVOUR_ICON` | 按 **content flavour** 选图标（与音频辅助音效） | Flavour 规则见 `flavours.md` |
| `0x0100` | `OC_ATTR_USE_REVERSED_UI` | 反转关机/重启按钮位置（贴合旧版 macOS） | 需要未设 `0x0040` |

**常用组合**：`0`（官方默认）／`0x01`（卷图标）／`0x81`（卷图标 + Flavour）／`0x90`（Flavour + 指针控制，本机在用的就是 `144`）

## 2. `Misc > Boot > PickerMode`

| 值 | 说明 |
|---|---|
| `Builtin` | OpenCore 自带**纯文本**界面（默认） |
| **`External`** | **用外部启动管理协议**（= OpenCanopy）；不可用时回退 Builtin |
| `Apple` | 用 Apple 的启动管理（可用时），可能绕过策略检查 |

⇒ **OpenCanopy 要求 `External`**；同时 `UEFI → Drivers` 里要启用 `OpenCanopy.efi`。

## 3. `Misc > Boot > PickerVariant`

图标集目录名（相对 `Resources/Image`）。别名：

| 值 | 效果 |
|---|---|
| `Auto` | 按背景色/`DefaultBackgroundColor` 自动选：`Syrah Black` → `Acidanthera\GoldenGate`，`Light Gray` → `Acidanthera\Chardonnay` |
| `Default` | 等价于 `Acidanthera\GoldenGate` |
| `Acidanthera\GoldenGate` / `Acidanthera\Syrah` / `Acidanthera\Chardonnay` | 显式指定（macOS 11 / OS X 10.10 / Mac OS X 10.4 风格） |

> 写的是**相对路径**，所以用**反斜杠**分隔（`Acidanthera\GoldenGate`）。

## 4. 其它影响外观的开关

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
| `UEFI>Output` | `TextRenderer` | `SystemGraphics` / `BuiltinGraphics` / …（见下） |
| `UEFI>Output` | `Resolution` | `Max` 让内置渲染器用满分辨率（HiDPI 前提） |
| `UEFI>Output` | `UIScale` | `1` 普通 / `2` HiDPI / `0` 自动按像素面积 / `-1` 不变 |
| `UEFI>Output` | `ConsoleFont` | 位图字体文件（`Resources/Font/*.bin`） |
| `UEFI>Output` | `ClearScreenOnModeSwitch`、`IgnoreTextInGraphics` | **只对 `System*` 渲染器生效** |
| `UEFI>Audio` | `AudioSupport`、`AudioDevice`、`AudioOutMask`、`MinimumAudibleGain` … | 开机声音/语音辅助的底层设置 |

## 5. 两条容易踩的搭配关系

1. **`0x0008` 必须搭 `0x0001`** —— 单开 `0x0008` 不生效
2. **`ClearScreenOnModeSwitch` / `IgnoreTextInGraphics` 只对 System 渲染器有效** ——
   如果 `TextRenderer` 改成 `BuiltinGraphics`，这两个开关会**静默失效**（本机就是 `SystemGraphics` + 两者都开的自洽组合）
3. **HiDPI（`UIScale=2`）要配 @2x 资源**：图标 `.icns` 里的 @2x 块、标签 `.l2x`；否则会被放大得模糊
