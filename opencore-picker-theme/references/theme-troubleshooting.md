# 主题排错

## 0. 先做两件事

```bash
scripts/oc-theme-check.sh /Volumes/EFI/EFI/OC/Resources     # 资源是否齐全/合规
grep -a "OCUI:" /Volumes/EFI/opencore-*.txt | tail -40      # OC 加载图标时的真实过程
```

`OCUI:` 行会明确写出「找哪个文件、第几次尝试、成功还是 Not Found」——**这是唯一的权威依据**，别靠猜。

## 1. 完全看不到图形界面（还是文本界面）

| 检查 | 期望 |
|---|---|
| `Misc>Boot>PickerMode` | 必须是 **`External`** |
| `UEFI>Drivers` | **`OpenCanopy.efi` 已启用**（且顺序在 `OpenRuntime.efi` 之后） |
| `Resources/Image/<图标集>/` | 目录存在，且**必需图标齐全**（缺一个 OpenCanopy 就不启动，见 `opencanopy-resources.md` §2.1） |
| `PickerVariant` | 指向的目录**真的存在**；写的是相对路径（用反斜杠 `Acidanthera\GoldenGate`） |
| OC 日志 | 有没有 `OCUI: Failed to load image …` 指向**必需**图标（那就是根因） |

> 回退行为：`External` 不可用时会**静默退回 Builtin 文本界面** —— 所以"看到文本界面"本身就是线索。

## 2. 界面出来了，但图标不对/是通用图标

| 现象 | 原因 | 处理 |
|---|---|---|
| 某个系统显示成通用硬盘图标 | 该图标**没提供**（或 flavour 没命中） | 补图标，或在该盘放 `.contentFlavour` / `.VolumeIcon.icns` |
| 外置盘图标和内置盘一样 | 外置盘上**没有** `Ext<Flavour>.icns`，OC 按安全规则退到 `ExtHardDrive.icns` | 补 `Ext*` 版本图标 |
| 设了 `0x0080` 但没变化 | `.contentFlavour` 不在**引导器旁边**；或 `Misc>Entries` 的 `Flavour` 写错 | 见 `flavours.md` §2 |
| 卷图标不生效 | 没开 `0x0001`；或 `.VolumeIcon.icns` 放错位置 | 放在卷根 / Preboot 按卷目录；开 `0x0001` |
| 想让 Time Machine 用内置图标 | — | 开 `0x0008`（**必须同时开 `0x0001`**） |

## 3. 日志里一堆 `Not Found` —— 先别急着修

`OCUI: Failed to load image … <名字>.icns prefix:<图标集> icon:N - Not Found` 的常见两类：

1. **`(1/2)` / `(2/2)`**：OpenCanopy 先试图标集目录，再试基础目录 —— 两次都失败才报。
2. **名字属于「Additional Optional」**（`Apple` / `ExtApple` / `ExtWindows` / `ExtOpticalDrive` / `ResetNVRAM` / `Background`）：
   **官方 OcBinaryData 根本不提供这些文件** ⇒ 这些行**是正常的**，没有东西可补。
   （`Docs/Flavours.md` 明确写了这一节；本机实测三套官方集各只有 25 个 `.icns`）

⇒ 只有**必需图标**报 `Not Found` 才是故障。

## 4. 图标显示变形/被裁切/很糊

| 现象 | 原因 |
|---|---|
| 被裁切 | `.icns` 里的 1x 尺寸不符合规范（见 `opencanopy-resources.md` 的尺寸列） |
| `Selector` / `SetDefault` 宽度不一致 | 文档要求 `SetDefault` **必须与 `Selector` 同宽** |
| 模糊 | HiDPI（`UIScale=2`）但没有 @2x 资源（`.icns` 里的 @2x 块、标签 `.l2x`） |
| 标签被拉伸 | 标签**高度必须正好 12 px**（宽度不限） |

## 5. 文字太大/太小/位置怪

- `UEFI>Output>UIScale`：`1` 普通 / `2` HiDPI / `0` 按像素面积自动 / `-1` 不变
- `UEFI>Output>Resolution=Max`（Builtin 渲染器要用满分辨率）
- `UEFI>Output>TextRenderer`：`SystemGraphics` 用固件渲染（`ClearScreenOnModeSwitch`/`IgnoreTextInGraphics` 只对它生效）；
  `BuiltinGraphics` 自己渲染（支持 HiDPI）
- 字体：`UEFI>Output>ConsoleFont` 指向 `Resources/Font/*.bin`（AngelCode BMF 格式）

## 6. 没有声音 / 语音辅助不工作

| 检查 | 说明 |
|---|---|
| `Resources/Audio/` | 有 `.mp3` |
| `UEFI>Audio>AudioSupport` | 开着 |
| `UEFI>Audio>AudioDevice` | 设备路径正确（可从 OC 日志的 `OCAU: 1/3 …` 行里抄） |
| `UEFI>Audio>AudioOutMask` | 输出通道位掩码；`-1` = 全部通道（日志里 `HDA: | Port widget @ … (bitmask N)` 可查） |
| `UEFI>Audio>MinimumAudibleGain` | 系统音量低于它会**不播放**（`-128` = 不限制） |
| `Misc>Boot>PickerAudioAssist` | 语音辅助总开关 |
| 条目音效 | 由 **Flavour** 决定（要 `0x0080`） |

## 7. 改完不生效

- **必须重启**（选择器是引导期组件）
- 确认改的是**真正被引导的那份 config**：`nvram 4D1FDA02-…:boot-path` 指向哪个分区
- ESP 改完要 `sync` → 卸载 → 重挂（FAT 有写缓存），并复验 sha
- 目录/文件名**大小写敏感**（FAT 卷在 macOS 上不敏感，但 OpenCore 读的是精确名字）

## 8. 安全提醒

`Resources/` 也在 ESP 上 ⇒ 改动同样走「备份 → 改 → 校验 → `sync`/卸载重挂 → 复验 sha」；
**主题换坏了会导致看不到选择器**（最坏情况进不了系统），所以：
- 动之前先把整个 `Resources/` 目录备份出来
- 保留一份**能用的**图标集不动（例如保留 `Acidanthera\GoldenGate` 原样，另建一个目录放新主题）
- 出问题时的逃生口：选择器进不去就改 `PickerMode=Builtin`（或临时把 `PickerVariant` 指回原图标集）
