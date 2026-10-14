---
name: opencore-picker-theme
description: 配置、制作与排错 OpenCore 的图形启动选择器（OpenCanopy）主题：图标集（Resources/Image 下的图标集目录）、PickerMode/PickerVariant/PickerAttributes、图标 Flavour 系统（Flavour.icns 命名 / Ext 前缀 / .contentFlavour / .VolumeIcon.icns / .disk_label）、标签（Resources/Label）、位图字体（Resources/Font）、音频辅助（Resources/Audio + UEFI Audio）、背景图与 DefaultBackgroundColor、HiDPI（UIScale）与文本渲染。当任务涉及 OpenCore 主题、启动界面/选择器外观、图标集/icon pack、OpenCanopy、PickerAttributes、PickerVariant、Flavour、.icns、启动声音/开机提示音、选择器字体或背景时使用。含「必需图标清单与尺寸」「官方图标集缺哪些可选图标」的权威对照，以及图标集合规检查脚本。另外，**用户问「这个技能怎么用 / 使用说明 / 有哪些能力 / 能干什么」时也适用**（此时输出技能目录下的 `USAGE.md`，不要输出内部流程）。
description_en: Configure, build and troubleshoot the OpenCore graphical boot picker (OpenCanopy) theme — icon sets under Resources/Image, PickerMode/PickerVariant/PickerAttributes, the icon flavour system, labels, bitmap fonts, audio assist, background image, HiDPI and text rendering. Includes the authoritative mandatory-icon list with dimensions, which optional icons OcBinaryData does NOT ship, and a compliance checker for the Resources tree. Also applies when the user asks how to use this skill, for its usage guide, or for a list of its capabilities — in that case output the skill's USAGE.md rather than the internal workflow.
version: 0.1.0
agent_created: true
---

# OpenCore 选择器主题（OpenCanopy）

## 用途

把「启动界面长什么样」这件事做对：换/装图标集、按需自制图标集、用 Flavour 让不同系统显示不同图标、
配标签/字体/音频辅助/背景，并在图标不生效时按顺序排查。

**官方依据**：`OpenCorePkg` 文档的 **OpenCanopy 章节**（资源目录、图标清单与尺寸、标签、字体格式）
与仓库里的 **`Docs/Flavours.md`**（推荐的 flavour 命名规范）。两者都随官方发布包提供，**必须按机器上的 OpenCore 版本取**。

> ★★ **用户问「这个技能怎么用 / 使用说明 / 有哪些能力 / 能干什么」时**：
> **直接输出同目录下的 `USAGE.md`**（那是写给使用者的速查），
> **不要**把本文件的内部流程（铁律、阶段编号、脚本清单）原样倒给用户。
> 同理，用户只是问「能做什么」而没给具体任务时，也走 `USAGE.md`。

## ★ 铁律

1. **必需图标缺一个，OpenCanopy 直接不启动** —— 先跑 `scripts/oc-theme-check.sh` 再谈美化
2. **图标集是「目录」不是「文件」**：放在 `EFI/OC/Resources/Image/<厂商>\<图标集>/`，
   用 `Misc>Boot>PickerVariant` 指向（**反斜杠**，如 `Acidanthera\GoldenGate`）
3. **`PickerMode` 必须是 `External`**，否则 OpenCanopy 根本不加载（`Builtin` = 纯文本界面）
4. **改 Resources 也是改 ESP** ⇒ 一样要走安全流程（备份 → 改 → 校验 → `sync` → 卸载重挂 → 复验 sha）
5. **`OCUI: Failed to load image … - Not Found` 多数是正常的** —— OpenCanopy 会探测一批**可选**图标，
   而官方图标集**并不提供**它们（见 `references/opencanopy-resources.md` 的「Additional Optional」表）。**别去"补"**
6. **不要顺手改主题** —— 用户没要求换外观时，`PickerMode`/`PickerVariant`/`PickerAttributes`/`Resources` 一律不动
7. **图标文件名区分大小写，且 FAT 上不要用怪字符**：用官方命名（`HardDrive.icns`、`ExtHardDrive.icns`…）
8. **1x 尺寸是规范值**，@2x 按倍数放大；尺寸不对会被拒绝或显示异常

## 工作流

### 阶段 1 · 摸清现状

```bash
# 主题相关开关
for k in PickerMode PickerVariant PickerAttributes PickerAudioAssist ShowPicker HideAuxiliary Timeout; do
  printf "  %-18s " "$k"; /usr/libexec/PlistBuddy -c "Print :Misc:Boot:$k" /Volumes/EFI/EFI/OC/config.plist
done
# 资源树
find /Volumes/EFI/EFI/OC/Resources -maxdepth 3 -type d | sort
ls /Volumes/EFI/EFI/OC/Resources/Image/Acidanthera/*/ | head -30
```

同时确认 `UEFI>Drivers` 里 **`OpenCanopy.efi` 已启用**（`PickerMode=External` 的前提）。

### 阶段 2 · 合规检查（先查再改）

```bash
scripts/oc-theme-check.sh /Volumes/EFI/EFI/OC/Resources
```

它检查：必需图标是否齐全、`.icns` 里实际包含哪些尺寸块、标签/字体/音频目录是否就位，并**列出"官方集本来就没有"的可选图标**（避免误判）。

### 阶段 3 · 装 / 换图标集

```bash
scripts/oc-fetch-iconset.sh GoldenGate /Volumes/EFI/EFI/OC/Resources   # 官方三套：GoldenGate / Syrah / Chardonnay
```
再设 `PickerVariant`：
- `Auto` —— 按背景色自动选（`Syrah Black` → GoldenGate，`Light Gray` → Chardonnay）
- `Default` —— 等于 `Acidanthera\GoldenGate`
- `Acidanthera\GoldenGate` / `Acidanthera\Syrah` / `Acidanthera\Chardonnay` —— 显式指定

### 阶段 4 · 自制图标集 / 个性化

按 `references/opencanopy-resources.md` 的清单做图标，按 `references/flavours.md` 的命名规则做 Flavour 图标，
需要时补标签（`Resources/Label`）、字体（`Resources/Font`）、音频（`Resources/Audio`）。

### 阶段 5 · 排错

图标不生效 / 界面不对 / 没有声音 / 字太大太小 ⇒ 按 `references/theme-troubleshooting.md` 的顺序查。
**先看 OC 日志的 `OCUI:` 行**（`Misc>Debug>Target` 含 `0x40` 时写在 ESP 的 `opencore-*.txt` 里）。

## 关键概念速查

| 概念 | 一句话 |
|---|---|
| `PickerMode` | `Builtin`（文本）/ **`External`（OpenCanopy，主题的前提）** / `Apple` |
| `PickerVariant` | 图标集目录（`Image/` 下的相对路径），支持 `Auto` / `Default` 别名 |
| `PickerAttributes` | 一个位掩码：卷图标 `0x01`、`.disk_label` `0x02`、通用标签图 `0x04`、指针控制 `0x10`、极简 UI `0x40`、**Flavour 图标 `0x80`**、反转 UI `0x100` |
| Flavour | 图标选择规则：`<Flavour>.icns` → 前缀逐级回退；**外置盘用 `Ext<Flavour>.icns`**，没有就退到 `ExtHardDrive.icns` |
| 卷图标 | `OC_ATTR_USE_VOLUME_ICON` 打开后找 `.VolumeIcon.icns`（优先级高于 `.contentFlavour`） |
| 标签 | `Resources/Label/*.lbl`（1x）/ `*.l2x`，**高度必须正好 12 px** |
| 字体 | `Resources/Font/*.bin`，格式 = **AngelCode binary BMF** |
| 音频辅助 | `Resources/Audio/*.mp3` + `PickerAudioAssist` + `UEFI>Audio` 设置 |
| HiDPI | `UEFI>Output>UIScale`（`1`/`2`/`0`自动/`-1`不变）；HiDPI 下要 @2x 资源 |

## 资源

- `scripts/oc-theme-check.sh` —— Resources 树合规检查（必需图标 / 实际尺寸块 / 标签 / 字体 / 音频）
- `scripts/oc-fetch-iconset.sh` —— 从官方 OcBinaryData 取图标集、字体、标签、音频
- `references/opencanopy-resources.md` —— **资源目录结构 + 全部图标清单（必需/可选 + 尺寸）+ 标签 + 字体 + 音频**
- `references/picker-attributes.md` —— `PickerAttributes` 全位表、依赖关系、与 `PickerMode`/`UIScale`/背景色的配合
- `references/flavours.md` —— Flavour 解析顺序、`Ext` 回退规则、`.contentFlavour`、推荐命名（基于官方 `Docs/Flavours.md`）
- `references/theme-troubleshooting.md` —— 图标/界面/声音/字体的排错顺序
- `USAGE.md` —— **给使用者看的速查**（用户问「怎么用/使用说明/能干什么」时输出这个）
