# 使用说明

本仓库有两个技能，各自的详细使用说明在**技能目录内**：

| 技能 | 使用说明 |
|---|---|
| `opencore-config-audit` | [`opencore-config-audit/USAGE.md`](opencore-config-audit/USAGE.md) |

> 放在技能目录内是**有意的**：安装时 `cp -R <skill> ...` 只复制技能目录，
> 放在这里的说明会**跟着一起装过去**，用户在对话里问「使用说明」就能拿到。
> 本文件只讲**怎么调用**和**怎么改技能**。

---

## 一、怎么调用

### 方式 1：直接说需求（推荐，什么都不用记）

**用自然语言把问题说清楚就行**，系统会自动挑到合适的技能。例如：

```
「帮我审一下我的 OpenCore 配置」
「我这块无线网卡是 MT7922，macOS 能驱动吗」
「开机很慢，帮我看看卡在哪」
「装系统的时候找不到硬盘」
「换个 OpenCore 主题」
```

### 方式 2：手动指定

- 输入框里打 **`/`** → 从列表里选技能
- 或点输入框左下角的 **`+` → 技能** → 选中后发送

常用技能还可以**置顶**，或用**最近使用**快速找到。

### 方式 3：问「使用说明」

直接问技能本身即可，例如：

```
「opencore-config-audit 怎么用」
「这个技能有哪些能力」
「给我看一下使用说明」
```

技能被加载后会**输出它自己的 `USAGE.md`**（在 `SKILL.md` 里写了这条指令）。
`/` 手动调用后再问同样有效。

---

## 二、安装

**方式一：作为插件市场安装（推荐）**

```bash
/plugin marketplace add GeekAudio/hackintosh-skills
/plugin install opencore-config-audit@hackintosh-skills
```

**方式二：手动复制（离线 / 只装一个）**

```bash
cp -R opencore-config-audit ~/.workbuddy-ai/skills/
```

装完后，新建一个对话，随便说一句上面的示例话术验证是否生效。

> 发布 / 分发自己的技能见 [`PUBLISHING.md`](PUBLISHING.md)。

---

## 三、给 skill 维护者

<details>
<summary>展开：调用控制字段、默认行为、覆盖设置、排查</summary>

### 3.1 `SKILL.md` 里控制调用的字段（`frontmatter`）

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

### 3.2 默认行为

| 字段 | 默认 | 含义 |
|---|---|---|
| `disable` | `false` | 默认启用 |
| `disable-model-invocation` | **`false`** | **默认允许自动调用** |
| `user-invocable` | **`true`**（只要不显式写 `false`） | **默认出现在 `/` 列表里** |

`/` 列表的筛选规则：`user-invocable` 不为 `false`，且来源是 `userSettings / user / builtin / plugin`
（`connector` 来源的排除）。

> ⇒ **自己装的技能默认可以被自动调用；内置技能默认不行**，需要用 `/` 显式调。

### 3.3 覆盖设置（优先级最高）

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

### 3.4 「使用说明」是怎么被输出的

应用**没有**内置的「打印使用说明」命令。这里是靠约定实现的：

1. 每个技能目录里放一份 **`USAGE.md`**（给使用者看）
2. `SKILL.md` 里写明：**用户问「怎么用 / 使用说明 / 有哪些能力」时，直接输出 `USAGE.md`**
3. `description` 里加上对应的触发词，保证这类提问能被匹配到

⇒ 所以 `USAGE.md` **必须放在技能目录内**（和 `SKILL.md` 同级），放到仓库根目录不会随安装复制过去。

### 3.5 排查：为什么没被调用？

| 现象 | 检查 |
|---|---|
| 说了需求但技能没生效 | ① `disable` 是不是 `true`；② `skillOverrides` 有没有设成 `user-invocable-only` / `off` |
| `/` 列表里看不到 | `user-invocable` 是不是被显式设成 `false`；或来源是 `connector`（会被排除） |
| 装完不生效 | 触发词够不够具体 —— 往 `description` 里补上用户会说的说法 |
| 问「使用说明」没输出 | `USAGE.md` 在不在**技能目录内**；`SKILL.md` 里有没有那条输出指令 |
| 内置技能不能自动调用 | 设计如此（见 3.2）⇒ 用 `/` 显式调 |
| 改了 frontmatter 没反应 | 调用相关字段**以覆盖设置为准**，会盖掉文件里的值 |

</details>
