# opencore-picker-theme —— 使用说明

> 给**使用者**看的速查。技术细节在 `SKILL.md` 与 `references/` 里，不用管。

## 怎么用

**直接用自然语言说需求就行**，不用记技能名。也可以手动指定：输入框打 **`/`** → 选 `opencore-picker-theme`；或点输入框左下角 **`+` → 技能**。

## 说这些话就会触发

| 你想做什么 | 直接这么说 |
|---|---|
| 换主题 | 「换个 OpenCore 主题」「换个开机图标」「图标集怎么装」 |
| 换背景 / 字体 | 「换个选择器背景」「启动界面字体太小」 |
| 加声音 | 「开机提示音怎么加」「选择器没有声音」 |
| 排错 | 「选择器界面不出现」「图标显示不对」「图标变形了」「启动没有声音」 |
| 调属性 | 「PickerAttributes 怎么配」「PickerVariant 是什么」「Flavour 是什么」 |
| 查图标 | 「检查一下 Resources 树合规吗」「缺哪个图标」 |
| 让选择器更干净 | 「隐藏辅助启动项」「只显示系统盘」 |

## 你会拿到什么

- **权威对照**：必需图标清单与尺寸（**缺一个 OpenCanopy 就不启动**）、官方图标集**不提供**哪些可选图标
  —— 这能解释日志里那些 `OCUI: … Not Found` 为什么是正常的，不用去「补」
- **合规检查**：读的是图标的**真实像素尺寸**，不是文件名猜的
- **配置方案**：`PickerAttributes` 位组合、Flavour 解析与回退链
- **排错顺序**：界面不出现 / 图标不对 / 变形 / 无声 / 字体异常，按顺序查

## 配套脚本（2 个）

| 脚本 | 作用 |
|---|---|
| `oc-theme-check.sh` | Resources 树合规检查（必需图标、真实像素尺寸、Selector/SetDefault 同宽、标签/字体/音频） |
| `oc-fetch-iconset.sh` | 从官方 OcBinaryData 取图标集 / 字体 / 标签 / 音频 |

## 参考文档（4 份）

`opencanopy-resources.md`（目录结构与必需/可选图标清单）· `picker-attributes.md`（属性位与依赖）·
`flavours.md`（Flavour 命名与回退链）· `theme-troubleshooting.md`（排错顺序）

## 注意

- 主题是**你能看见的东西** —— 换之前会先问你要哪种风格，不会替你决定。
- 改的是 EFI 里的 `Resources/` 与 `config.plist`，会走安全流程（备份 → 校验 → 复验）。
