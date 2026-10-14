# Flavour：图标与音效的选择规则

> 依据：`OpenCorePkg` 文档 `PickerAttributes` 里 `OC_ATTR_USE_FLAVOUR_ICON (0x0080)` 一节，
> 以及仓库里的 **`Docs/Flavours.md`**（推荐命名清单）。

## 1. 什么时候用

打开 `PickerAttributes` 的 **`0x0080`（`OC_ATTR_USE_FLAVOUR_ICON`）** 后：
条目图标（OpenCanopy）与条目音效（OpenCanopy + 内置选择器）都由 **content flavour** 决定。

**不开 `0x0080` 时**走的是"按条目类型直接找图标"的老逻辑（`AppleRecv.icns`、`Windows.icns` 之类）。

## 2. Flavour 从哪来（文档给的算法）

| 条目类型 | Flavour 来源 |
|---|---|
| **工具（Tool）** | `Misc>Tools` 条目自己的 `Flavour` 字段 |
| **自动发现的条目**（含 `OpenLinuxBoot` 等启动协议生成的条目） | 引导器旁边若有 `.contentFlavour` 文件，读它 |
| **`Misc>Entries` 里的自定义条目** | `Flavour` 为 `Auto` 时读 `.contentFlavour`；否则用 `Flavour` 字段指定的值 |
| 读到的 flavour 是 `Auto` 或没有 `.contentFlavour` | 用条目类型对应的默认 flavour |

- Flavour 值的语法：**`:` 分隔的名字序列，总长 ≤ 64 字符**
- **外置盘**：同时支持 `Ext<Flavour>.icns` 与 `<Flavour>.icns`；
  **只有在盘是外置时才用 `Ext<Flavour>.icns`**；如果外置盘上找不到 `Ext<Flavour>.icns`，
  **出于安全考虑 OpenCore 会退到 `ExtHardDrive.icns`，而不会用 `<Flavour>.icns`**
- **优先级**：同时存在时，**`.VolumeIcon.icns` 优先于 `.contentFlavour`**

## 3. 回退链（以文档给的例子为准）

```
UEFIShell:Shell  →  UEFIShell.icns  →  Shell.icns  →  Tool.icns  →  HardDrive.icns
```
即：**按 flavour 序列从左到右找图标，找不到就往下退**，最终退到类型兜底（OS 类退 `HardDrive.icns`）。

## 4. 推荐命名（`Docs/Flavours.md` 的要点）

### macOS —— **自动按版本选，通常不用手动指定**

- `Apple12:Apple`（Monterey，`Apple12.icns`）… `Apple11:Apple`（Big Sur）… `Apple10_15:Apple`（Catalina）… 一直到 `Apple10_4`
- **Recovery**：`AppleRecv11:AppleRecv:Apple11:Apple`（自动带版本号）
- **Time Machine**：`AppleTM11:AppleTM:Apple11:Apple`（**不会**自动带版本，要手动指定才会被找到）
- 图标作者角度：**`Apple` 推荐提供**，`AppleRecv` / `AppleTM` 建议提供，其余可选

### Windows —— 基础 flavour 自动，版本要手动

- `Windows`（自动检测；回退 `HardDrive`）
- `Windows11:Windows`、`Windows10:Windows`、`Windows8_1:Windows` … 需手动指定（在 `.contentFlavour` 里写）

### Linux / 其它 OS / 引导器 —— 全可选

- Linux：`Linux`（基础）+ 各发行版 `Arch:Linux`、`Debian:Linux`、`Ubuntu:Linux`、`Lubuntu:Ubuntu:Linux` …
- 其它：`Android`、`BSD`、`FreeBSD:BSD`、`ReactOS`
- 引导器：`Bootloader`、`Grub:Bootloader`、`OpenCore:Bootloader`

### 工具

- **`Tool`**（通用工具图标，推荐提供；缺失回退 `HardDrive`）
- Shell 类：`Shell` / `UEFIShell:Shell` —— 只提供一个时，通用风格命名 `Shell.icns`，
  带特定文字的命名 `OpenShell.icns` / `UEFIShell.icns`

> `Docs/Flavours.md` 明确说：**清单是为了命名一致，不是要求图标集必须提供全部**。
> 官方建议图标作者「只提供真有需求的那些」，未提供的最终都会回退到 OC 默认（OS 类 → `HardDrive.icns`）。

## 5. 实用做法

1. **只想换掉某个条目的图标**：不要动全局 `0x0080`，直接在 `Misc>Entries` 给那个条目写 `Flavour`
2. **想让某个盘固定用某个图标**：放 `.VolumeIcon.icns` 在卷根（或 Preboot 的按卷目录），开 `0x0001`
   —— 它**优先于** `.contentFlavour`，且不需要 `0x0080`
3. **想让 Windows 显示 Win11 图标**：在该盘的引导器旁放 `.contentFlavour`，内容写 `Windows11:Windows`
   （需要 `0x0080`）
4. **改完要重启才生效**，验证看 OC 日志的 `OCUI:` 行（找图标的尝试与回退都会打出来）
