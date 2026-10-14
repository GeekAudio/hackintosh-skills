# 使用说明（怎么调用这两个 skill）

> 面向**人**的速查。skill 内部的技术细节在各自的 `SKILL.md` 与 `references/` 里。

## 一、两种调用方式

### 方式 1：自动调用（推荐，什么都不用记）

**直接用自然语言说需求**，模型会按 skill 的 `description` 自动匹配并加载。

```
「根据官方文档审一下我的 OpenCore 配置」
「看一下这个网卡 MT7922 支持情况，把流程加进 skill」
「开机很慢，帮我分析一下时间线」
「装系统找不到硬盘」
```

这两个 skill 都**允许模型自动调用**（实测：`disableModelInvocation = false`），所以上面这些话会直接命中。

### 方式 2：显式调用

- 输入框里打 **`/`** → 从列表里选已安装的技能
- 或点输入框左下角的 **`+` → 技能** → 选中后发送

适合「我知道要用哪个 skill，别猜」的场景。

---

## 二、SKILL.md 里控制调用的字段（`frontmatter`）

从应用实现里读出来的完整字段表：

| 字段 | 类型 | 作用 |
|---|---|---|
| `name` | 字符串 | 技能名（也是 override 的键） |
| `description` | 字符串 | **主要触发依据** —— 模型靠它判断「这个需求该不该用我」 |
| `description_zh` / `description_en` | 字符串 | 中/英描述（分别用于中文/英文环境） |
| `when-to-use` | 字符串 | 「什么时候用」的补充说明 |
| `allowed-tools` | 数组 | 允许该 skill 使用的工具 |
| `disable` | 布尔 | 整体禁用该 skill |
| **`disable-model-invocation`** | 布尔 | ★ **禁止模型自动调用**（`true` = 只能手动调） |
| **`user-invocable`** | 布尔 | 是否出现在 `/` 手动调用列表里 |
| `license` / `version` | 字符串 | 元信息 |

### ★ 覆盖机制（优先级最高）

应用设置里有 `skillOverrides`，以 **skill 名**为键，可取值三个：

| 值 | 含义 |
|---|---|
| `user-invocable-only` | **禁止模型自动调用**，只能用户手动调用 |
| `off` | 关闭该 skill |
| `name-only` | 只在列表里以名字出现 |

```json
{ "skillOverrides": { "opencore-config-audit": "user-invocable-only" } }
```

> 注意三点：
> 1. **`source = plugin` 的 skill 会被跳过** —— 插件来源的技能不接受 override。
> 2. 本机 `~/.workbuddy-ai/skills/` 下那两个 `.migration.json` 文件，就是这个字段从
>    `disabled` → `modelInvocation` → `override` 演进留下的迁移记录。
> 3. 输入框里还有**置顶 / 最近使用**（`wb-input:skills:pinned` / `:recent`）。

### 默认值（都不用自己写）

| 字段 | 默认 | 含义 |
|---|---|---|
| `disable` | `false` | 默认启用 |
| `disable-model-invocation` | **`false`** | **默认允许模型自动调用** |
| `user-invocable` | **`true`**（只要不显式写 `false`） | **默认出现在 `/` 列表里** |

`/` 列表的筛选规则：`user-invocable !== false` **且** `source ∈ {userSettings, user, builtin, plugin}`
（`connector` 来源的排除）。

### 本机现状（实测）

| skill | `disable` | `disable-model-invocation` | 结果 |
|---|---|---|---|
| `opencore-config-audit` | false | **false** | 已启用 · **可自动调用** · 在 `/` 列表里 |
| `opencore-picker-theme` | false | **false** | 已启用 · **可自动调用** · 在 `/` 列表里 |
| 内置 / 插件 / 连接器技能（20 个） | false | **true** | 需**显式**调用 |

> 统计验证：`disableModelInvocation = true` 的恰好 20 个 = 内置 17 + 插件 2 + 连接器 1。
> ⇒ **用户自己装的 skill 默认允许自动调用，内置的默认不允许。**

---

## 三、两个 skill 的速查

### `opencore-config-audit` —— OpenCore 配置审查与维护

| 你想做什么 | 直接这么说 |
|---|---|
| **审 BIOS** | 「帮我审一下 BIOS 设置」「装系统找不到硬盘」「CFG Lock 要不要关」 |
| 审配置 | 「按官方文档审一下我的 config」「跑一下 ocvalidate」 |
| 补 SSDT | 「看日志还有没有要补的 SSDT」 |
| 查开机慢 | 「开机很慢，分析一下时间线」「卡在苹果 logo」 |
| 精简 | 「kext 精简一下，不用的删掉」「屏蔽一下其它磁盘」 |
| 装驱动 | 「装 NVIDIA 驱动」「Intel 无线网卡怎么配」「MT7922 支持吗」「博通网卡按系统分路线」 |
| 调 CPU | 「CPU 频率被压住了」「睿频怎么开」 |
| 换机型 | 「换 SMBIOS 机型 + 三码」 |
| 升系统 | 「从 15 升到 26 要改什么」「升级后 Wi-Fi 没了」 |
| 换构建 | 「从 release 换成 debug 版 OpenCore 并开日志」 |

**会产出什么**：审查报告 · 可回滚的 config 改动（含 sha 校验）· 校验过的 SSDT/kext 清单 · 分析文档
**配套脚本（11 个）**：`bios-audit.ps1`（Windows 只读审 BIOS）· `oc-edit-safe.sh` · `oc-verify.sh` · `oc-swap-build.sh` · `grab-logs.sh` · `boot-timeline.sh` · `find-boot-gap.sh` · `mask-other-disks.sh` · `cpu-freq-probe.sh` · `mem-check.sh` · `fetch-opencore-docs.sh`

### `opencore-picker-theme` —— 选择器主题（OpenCanopy）

| 你想做什么 | 直接这么说 |
|---|---|
| 换主题 | 「换个 OpenCore 主题」「图标集怎么装」 |
| 排错 | 「选择器界面不出现」「图标显示不对/变形」「启动没有声音」 |
| 调属性 | 「PickerAttributes 怎么配」「Flavour 是什么」 |
| 查图标 | 「检查一下 Resources 树合规吗」「缺哪个图标」 |

**会产出什么**：Resources 树合规检查 · 图标集/字体/标签获取 · 属性位与 Flavour 配置方案
**配套脚本（2 个）**：`oc-theme-check.sh` · `oc-fetch-iconset.sh`

---

## 四、安装

```bash
# 用户级（所有项目都能用）
cp -R opencore-config-audit ~/.workbuddy-ai/skills/
cp -R opencore-picker-theme  ~/.workbuddy-ai/skills/
```

装好后确认：

```bash
python3 <skill-creator>/scripts/quick_validate.py ~/.workbuddy-ai/skills/opencore-config-audit
# → Skill is valid!
```

---

## 五、排查：为什么没被调用？

| 现象 | 检查 |
|---|---|
| 说了需求但 skill 没生效 | ① `disable` 是不是 `true`；② 设置里 `skillOverrides` 有没有把它设成 `user-invocable-only` / `off` |
| `/` 列表里看不到 | `user-invocable` 是不是被显式设成 `false`；或 `source` 是 `connector`（会被排除） |
| 装完不生效 | `SKILL.md` 的 `description` 里有没有覆盖你的说法（触发词不够具体就补上）；改完需重新加载 |
| 内置技能不能自动调用 | **这是设计如此**（内置默认 `disable-model-invocation = true`）⇒ 用 `/` 显式调用 |
| 改了 frontmatter 没反应 | 调用相关字段（`disable` / `disable-model-invocation` / `user-invocable`）**以设置里的 override 为准**，会盖掉文件里的值 |
