# 发布到 WorkBuddy

> 把本仓库的 skill 装进 WorkBuddy 有**两条路线**，先看这张表选一条。

| | **路线 A：自有市场仓库**（推荐，**本仓库已配好**） | **路线 B：上架到 SkillHub** |
|---|---|---|
| 面向 | 公开分发 / 小范围分享 / 团队内部 | 进公共技能商店被搜到 |
| 用户怎么装 | `/plugin marketplace add GeekAudio/hackintosh-skills` 然后 `/plugin install …` | 在 **<https://skillhub.cn>** 上浏览并安装 |
| **在哪操作** | 你的 Git 仓库 | **网页：<https://skillhub.cn>**（登录后提交） |
| 需要审核吗 | **不需要** | 平台侧有校验 / 精选机制 |
| 需要账号吗 | 不需要（只要有公开仓库） | **需要** SkillHub 账号 |
| 更新方式 | 改完 `git push` 即可，用户端同步市场元数据 | 重新走一遍提交流程 |

---

## 路线 A：自有市场仓库

### A.1 本仓库已经配好的文件

```
hackintosh-skills/
├── .codebuddy-plugin/
│   └── marketplace.json          ← 市场清单（必需，缺了整仓库都不显示）
└── opencore-config-audit/
    ├── .codebuddy-plugin/
    │   └── plugin.json           ← 插件元数据
    ├── SKILL.md                  ← 技能正文
    ├── USAGE.md
    ├── references/  scripts/
```

### A.2 用户怎么装（三步）

```bash
# ① 添加市场
/plugin marketplace add GeekAudio/hackintosh-skills

# ② 安装插件（<插件名>@<市场名>）
/plugin install opencore-config-audit@hackintosh-skills
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
  'opencore-config-audit/.codebuddy-plugin/plugin.json']];print('JSON OK')"

# ② 每个 skill 仍然合法
python3 <skill-creator>/scripts/quick_validate.py opencore-config-audit

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

## 路线 B：上架到 SkillHub（公共技能商店）

### ★ 先分清三件容易混的事

| 你以为的 | 实际是什么 | 是不是「上架商店」 |
|---|---|---|
| WorkBuddy 技能面板 → **「上传技能」** | 弹窗标题其实是 **`Import Skill`** —— 把技能**导入到你自己的**个人库 / 项目 | ❌ **不是**（这是本地导入） |
| 技能设置里的 **「上传到 WorkBuddy Cloud」** | 说明原文：*"{names} will be available in **cloud sessions** after upload"* —— 同步到**你自己的云端会话**（功能开关 `EnableSkillToCloud` **默认关闭**） | ❌ **不是**（这是同步自己的云） |
| **`https://skillhub.cn`** | **SkillHub —— 专为中国用户优化的 AI Skills 社区**（腾讯云托管），有精选、分类、下载量/星标、付费技能、企业专区、比赛 | ✅ **这才是商店** |

### B.1 商店与接口地址

| 用途 | 地址 |
|---|---|
| **商店网站（人去的）** | **<https://skillhub.cn>** |
| 技能列表页 | `https://skillhub.cn/skills` |
| **教程** | `https://skillhub.cn/tutorials` ← **上架前先看这个** |
| **签名验证文档** | `https://skillhub.cn/docs/verify-signature` ← 与发布校验有关 |
| 比赛 / 获奖 | `https://skillhub.cn/contest` · `/contest/winners` |
| 企业专区 | `https://skillhub.cn/enterprise-zone` |
| 技能 API | `https://api.skillhub.cn` —— `/api/skills`（列表）· `/api/v1/categories`（分类）· `/api/v1/search?q=`（语义搜索） |
| 技能详情页 | `https://api.skillhub.cn/<作者>/<slug>`（例：`/indiv-ebandao/dev-expert`） |
| 应用侧网关 | `https://lightmake.site`（WorkBuddy 内部用它拉列表/搜索/分类） |

> 站点的 `robots.txt` + `sitemap.xml` 是公开的，上面这些路由都来自它。

### B.2 上架前：把包准备好

```bash
python3 <skill-creator>/scripts/package_skill.py opencore-config-audit ./dist
# → dist/opencore-config-audit.zip（内含 SKILL.md，带 YAML 的 name + description）
```

**自检**：

```bash
# ① 内容
python3 - <<'EOF'
import zipfile
z='dist/opencore-config-audit.zip'; zf=zipfile.ZipFile(z); n=zf.namelist()
md=[x for x in n if x.endswith('/SKILL.md')][0]
fm=zf.read(md).decode('utf-8').split('---')[1]
print(z, '| SKILL.md ✅' if ('name:' in fm and 'description:' in fm) else '❌', '| 文件数', len(n))
EOF

# ② ★ 脱敏（必做）
bash opencore-config-audit/scripts/redact-check.sh opencore-config-audit
# 退出码 0 = 干净；1 = 有命中，先处理再打包
```

> ★★ **三码（serial/MLB/UUID）+ ROM 用的 MAC 等同于这台机器的 Apple 身份**（iMessage / FaceTime 认的就是它们）。
> **上传即公开** —— 打包前务必跑一遍 `redact-check.sh`，再人工扫一眼。

### B.3 上架

**在浏览器里打开 <https://skillhub.cn>** → 登录 → 找提交/发布入口（先看 `/tutorials`）。

> ⚠️ **具体入口我没法替你确认**：站点是 SPA 且提交入口在登录之后，
> 我这边只能用 curl 拿到外壳 HTML，看不到登录后的界面。**以站内教程为准。**

### B.4 这一步需要你来做

打包与自检**本仓库已经做完**（`dist/` 里就是可直接上传的包）。
但**登录与提交必须有你的账号**，我代替不了。

### 两条路线可以并存

先把仓库做成可添加的市场（路线 A）**给自己和熟人用**，
等技能稳定了再打包上架官方（路线 B）—— 两条互不冲突。
