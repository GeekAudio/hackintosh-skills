# 使用说明

> 面向**使用者**的速查。
> 如果你是来改 skill 本身的（加触发词、调调用方式），直接跳到 [第四部分](#四给-skill-维护者)。

---

## 一、怎么用

### 方式 1：直接说需求（推荐，什么都不用记）

**用自然语言把问题说清楚就行**，系统会自动挑到合适的技能。例如：

```
「帮我审一下我的 OpenCore 配置」
「我这块无线网卡是 MT7922，macOS 能驱动吗」
「开机很慢，帮我看看卡在哪」
「装系统的时候找不到硬盘」
「换个 OpenCore 主题」
```

不用记技能名，也不用记命令。

### 方式 2：手动指定

- 输入框里打 **`/`** → 从列表里选技能
- 或点输入框左下角的 **`+` → 技能** → 选中后发送

适合「我知道要用哪个，别猜」的场景。常用技能还可以**置顶**，或用**最近使用**快速找到。

---

## 二、这两个技能能做什么

### `opencore-config-audit` —— OpenCore 配置审查与维护

| 你想做什么 | 直接这么说 |
|---|---|
| **查 BIOS** | 「帮我审一下 BIOS 设置」「装系统找不到硬盘」「CFG Lock 要不要关」 |
| 审配置 | 「审一下我的 OpenCore 配置」「校验一下 config.plist」 |
| 补 SSDT | 「看日志还有没有要补的 SSDT」 |
| 查开机慢 | 「开机很慢，分析一下时间线」「卡在苹果 logo」 |
| 精简 | 「kext 精简一下，不用的删掉」「屏蔽一下其它磁盘」 |
| 装驱动 | 「装 NVIDIA 驱动」「Intel 无线网卡怎么配」「我这块 MT7922 能用吗」「博通网卡怎么配」 |
| 调 CPU | 「CPU 频率被压住了」「睿频怎么开」 |
| 换机型 | 「换一下 SMBIOS 机型」「三码怎么配」 |
| 升系统 | 「从 15 升到 26 要改什么」「升级后 Wi-Fi 没了」 |
| 换构建 | 「从 release 换成 debug 版 OpenCore 并开日志」 |

**你会拿到**：审查报告 · 可回滚的配置改动（每步都有校验）· 校验过的 SSDT/kext 清单 · 分析文档

### `opencore-picker-theme` —— 启动选择器主题（OpenCanopy）

| 你想做什么 | 直接这么说 |
|---|---|
| 换主题 | 「换个 OpenCore 主题」「图标集怎么装」 |
| 排错 | 「选择器界面不出现」「图标显示不对/变形」「启动没有声音」 |
| 调属性 | 「PickerAttributes 怎么配」「Flavour 是什么」 |
| 查图标 | 「检查一下 Resources 树合规吗」「缺哪个图标」 |

**你会拿到**：Resources 树合规检查 · 图标集/字体/标签获取 · 属性位与 Flavour 配置方案

---

## 三、安装

```bash
# 用户级（所有项目都能用）
cp -R opencore-config-audit ~/.workbuddy-ai/skills/
cp -R opencore-picker-theme  ~/.workbuddy-ai/skills/
```

装完后，新建一个对话，随便说一句上面的示例话术验证是否生效。

---

## 四、给 skill 维护者

<details>
<summary>展开：调用控制字段、默认行为、排查</summary>

### 4.1 `SKILL.md` 里控制调用的字段（`frontmatter`）

| 字段 | 类型 | 作用 |
|---|---|---|
| `name` | 字符串 | 技能名（也是覆盖设置的键） |
| `description` | 字符串 | **主要触发依据** —— 模型靠它判断「这个需求该不该用我」 |
| `description_zh` / `description_en` | 字符串 | 中/英描述（分别用于中文/英文环境） |
| `when-to-use` | 字符串 | 「什么时候用」的补充说明 |
| `allowed-tools` | 数组 | 允许该技能使用的工具 |
| `disable` | 布尔 | 整体禁用 |
| **`disable-model-invocation`** | 布尔 | ★ **禁止自动调用**（`true` = 只能手动调） |
| **`user-invocable`** | 布尔 | 是否出现在 `/` 手动调用列表里 |
| `license` / `version` | 字符串 | 元信息 |

### 4.2 默认行为

| 字段 | 默认 | 含义 |
|---|---|---|
| `disable` | `false` | 默认启用 |
| `disable-model-invocation` | **`false`** | **默认允许自动调用** |
| `user-invocable` | **`true`**（只要不显式写 `false`） | **默认出现在 `/` 列表里** |

`/` 列表的筛选规则：`user-invocable` 不为 `false`，且来源是 `userSettings / user / builtin / plugin`
（`connector` 来源的排除）。

> ⇒ **自己装的技能默认可以被自动调用；内置技能默认不行**，需要用 `/` 显式调。

### 4.3 覆盖设置（优先级最高）

设置里的 `skillOverrides` 以**技能名**为键，可取值三个：

| 值 | 含义 |
|---|---|
| `user-invocable-only` | **禁止自动调用**，只能手动调用 |
| `off` | 关闭该技能 |
| `name-only` | 只在列表里以名字出现 |

```json
{ "skillOverrides": { "opencore-config-audit": "user-invocable-only" } }
```

> ★ **插件来源（`plugin`）的技能不接受覆盖**，会被跳过。

### 4.4 排查：为什么没被调用？

| 现象 | 检查 |
|---|---|
| 说了需求但技能没生效 | ① `disable` 是不是 `true`；② `skillOverrides` 有没有设成 `user-invocable-only` / `off` |
| `/` 列表里看不到 | `user-invocable` 是不是被显式设成 `false`；或来源是 `connector`（会被排除） |
| 装完不生效 | 触发词够不够具体 —— 往 `description` 里补上用户会说的说法 |
| 内置技能不能自动调用 | 设计如此（见 4.2）⇒ 用 `/` 显式调 |
| 改了 frontmatter 没反应 | 调用相关字段**以覆盖设置为准**，会盖掉文件里的值 |

</details>
