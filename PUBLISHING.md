# 发布到 WorkBuddy

> 把本仓库的 skill 装进 WorkBuddy 有**两条路线**，先看这张表选一条。

| | **路线 A：自有市场仓库**（推荐，**本仓库已配好**） | **路线 B：官方 SkillHub 上架** |
|---|---|---|
| 面向 | 公开分发 / 小范围分享 / 团队内部 | 进官方市场被搜索到 |
| 用户怎么装 | `/plugin marketplace add GeekAudio/hackintosh-skills` 然后 `/plugin install …` | 从「技能」面板搜索并安装 |
| 需要审核吗 | **不需要** | **需要**（打包 → 上传 → 审核 → 发布） |
| 需要账号/后台吗 | 不需要（只要有公开仓库） | 需要平台账号与上传后台 |
| 更新方式 | 改完 `git push` 即可，用户端同步市场元数据 | 重新走一遍上传流程 |

---

## 路线 A：自有市场仓库

### A.1 本仓库已经配好的文件

```
hackintosh-skills/
├── .codebuddy-plugin/
│   └── marketplace.json          ← 市场清单（必需，缺了整仓库都不显示）
├── opencore-config-audit/
│   ├── .codebuddy-plugin/
│   │   └── plugin.json           ← 插件元数据（每个插件一个）
│   ├── SKILL.md                  ← 技能正文
│   ├── USAGE.md
│   ├── references/  scripts/
└── opencore-picker-theme/
    ├── .codebuddy-plugin/plugin.json
    ├── SKILL.md
    └── …
```

### A.2 用户怎么装（三步）

```bash
# ① 添加市场
/plugin marketplace add GeekAudio/hackintosh-skills

# ② 安装插件（<插件名>@<市场名>）
/plugin install opencore-config-audit@hackintosh-skills
/plugin install opencore-picker-theme@hackintosh-skills
```

> 快捷方式：`/plugin market` = `/plugin marketplace`；`rm` = `remove`。
> 也可以先运行 `/plugin` 进「发现」标签页浏览。

**添加市场的其他来源**（同样支持）：

```bash
/plugin marketplace add https://gitlab.com/team/plugins.git      # 其他 Git 主机
/plugin marketplace add https://gitlab.com/team/plugins.git#v1.0.0   # 指定分支/标签
/plugin marketplace add ./my-marketplace                          # 本地目录（开发调试）
/plugin marketplace add https://example.com/marketplace.json      # HTTP 托管
```

> ⚠️ **URL 型市场**（直接给 marketplace.json 的 HTTP 地址）对**相对路径**支持不好，
> 安装时可能报「路径未找到」⇒ **优先用 Git 型**（`owner/repo`）。

### A.3 字段说明（官方 schema）

**`.codebuddy-plugin/marketplace.json`（市场清单）**

| 字段 | 类型 | 必需 | 说明 |
|---|---|---|---|
| `name` | string | ✅ | 市场标识符（kebab-case，无空格） |
| `owner` | object | ✅ | 市场维护者信息（`name` / `email`） |
| `plugins` | array | ✅ | 可用插件列表 |
| `description` | string | | 市场简要描述 |
| `version` | string | | 市场版本 |

**`plugins[]` 里的每一条**

| 字段 | 类型 | 必需 | 说明 |
|---|---|---|---|
| `name` | string | ✅ | 插件标识符（kebab-case，无空格） |
| `source` | string/object | ✅ | 插件获取来源（见下） |
| `description` | string | ✅ | 插件简要描述 |
| `version` | string | | 插件版本 |
| `author` | object | | 作者信息 |
| `homepage` / `repository` | string | | 主页 / 源码仓库 URL |
| `license` | string | | SPDX 标识符（如 `MIT`） |
| `keywords` | array | | 用于发现与分类的标签 |
| `category` | string | | 插件分类 |
| **`strict`** | boolean | | **默认 `true`**：插件目录里**必须**有 `plugin.json`。<br>`false` 时 `plugin.json` 可选，本条即完整清单 |
| `commands` / `agents` / **`skills`** / `hooks` / `mcpServers` | string/array/object | | **组件路径覆盖** —— 自定义各组件的位置 |

**`source` 的三种写法**

```jsonc
// ① 同仓库相对路径（本仓库用的就是这个）
"source": "./opencore-config-audit"

// ② GitHub 仓库
"source": { "source": "github", "repo": "owner/plugin-repo" }

// ③ 任意 Git URL
"source": { "source": "url", "url": "https://gitlab.com/team/plugin.git" }
```

**`.codebuddy-plugin/plugin.json`（插件元数据）**

字段同上（`name` / `version` / `description` / `author` / `repository` / `license` / `keywords` / `category`），
外加**组件路径**：

| 字段 | 说明 |
|---|---|
| `skills` | Skill 的路径。**本仓库写的是 `["./SKILL.md"]`** —— 直接指向插件根目录的 `SKILL.md`，所以现有布局不用改 |
| `commands` / `agents` / `hooks` / `mcpServers` | 命令 / Agent / 钩子 / MCP 服务器 |

### A.4 再加一个新技能

1. 在仓库根新建目录 `my-new-skill/`，放 `SKILL.md`（必需）、`USAGE.md`、`references/`、`scripts/`
2. 新建 `my-new-skill/.codebuddy-plugin/plugin.json`，**`"skills": ["./SKILL.md"]`** 别忘
3. 在根 `.codebuddy-plugin/marketplace.json` 的 `plugins[]` 里加一条，`"source": "./my-new-skill"`
4. 校验 JSON 合法 → `git push`（用户端同步市场元数据后即可看到）

### A.5 上线前自检

```bash
# ① JSON 语法
python3 -c "import json;[json.load(open(p)) for p in ['.codebuddy-plugin/marketplace.json',
  'opencore-config-audit/.codebuddy-plugin/plugin.json',
  'opencore-picker-theme/.codebuddy-plugin/plugin.json']];print('JSON OK')"

# ② 每个 skill 仍然合法
python3 <skill-creator>/scripts/quick_validate.py opencore-config-audit
python3 <skill-creator>/scripts/quick_validate.py opencore-picker-theme

# ③ source 指向的目录确实存在，且里面有 .codebuddy-plugin/plugin.json
```

### A.6 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| 加了市场但看不到插件 | `marketplace.json` 路径不对（必须在仓库根的 `.codebuddy-plugin/` 下），或 JSON 语法错 |
| 装了插件但技能不显示 | 清缓存：`rm -rf ~/.workbuddy-ai/plugins/cache`，重启后重新安装 |
| 安装后「文件未找到」 | **插件会被复制到缓存**，所以**引用插件目录之外的路径无法工作** —— 所有资源必须放在插件目录内 |
| URL 型市场报路径错误 | 改用 Git 型市场（`owner/repo`） |

---

## 路线 B：上架官方 SkillHub

官方流程是四步：**打包 → 校验 → 上传 → 审核 → 发布**。用官方 skill-creator 里的打包脚本：

```bash
# 打包（会先自动校验，再压成 zip；zip 内已含技能目录名）
python3 <skill-creator>/scripts/package_skill.py opencore-config-audit ./out

# 输出形如：
#   🔍 Validating skill...
#   ✅ Skill is valid!
#   Added: opencore-config-audit/SKILL.md
#   ...
#   ✅ Successfully packaged skill to: ./out/opencore-config-audit.zip
```

然后把 zip **上传到平台的技能后台**，等审核通过后发布。

> ⚠️ **这一步本仓库无法代做** —— 需要你的平台账号与上传入口（在 WorkBuddy 的「技能」面板里）。
> 走这条路线前，建议先确认平台对技能的要求（描述字数、图标、分类、示例等），
> 因为**审核标准由平台定**，和路线 A 的「自己仓库自己说了算」不一样。

### 两条路线可以并存

先把仓库做成可添加的市场（路线 A）**给自己和熟人用**，
等技能稳定了再打包上架官方（路线 B）—— 两条互不冲突。
