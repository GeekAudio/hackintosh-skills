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

## 路线 B：上架官方 SkillHub

### B.1 打包（这一步已经做好了）

用官方 skill-creator 的打包脚本（**会先自动校验再压缩**）：

```bash
python3 <skill-creator>/scripts/package_skill.py opencore-config-audit ./dist
```

产物（zip 内**自带技能名作为顶层目录**）：

```
dist/opencore-config-audit.zip     ~150 KB
```

### B.2 上传前自检（对照平台的文件要求）

平台弹窗里写明的两条要求：

| 要求 | 本仓库的情况 |
|---|---|
| **文件夹或 `.zip` 必须包含 `SKILL.md`** | ✅ |
| **`.md` 里必须有 YAML 格式的 `name` 与 `description`** | ✅ |

自己再核一遍：

```bash
# ① 内容自检（SKILL.md + YAML frontmatter + 文件数）
python3 - <<'EOF'
import zipfile
for z in ('dist/opencore-config-audit.zip',):
    zf=zipfile.ZipFile(z); n=zf.namelist()
    md=[x for x in n if x.endswith('/SKILL.md')][0]
    fm=zf.read(md).decode('utf-8').split('---')[1]
    print(z, '| SKILL.md ✅' if ('name:' in fm and 'description:' in fm) else '❌',
          '| 文件数', len(n))
EOF

# ② ★ 脱敏自检（技能里带了脚本，直接跑）
bash opencore-config-audit/scripts/redact-check.sh opencore-config-audit
# 退出码 0 = 干净；1 = 有命中，先处理再打包
```

> ★★ **打包前务必扫敏感信息**：三码（serial/MLB/UUID）、ROM 用的 MAC、内存条序列号、
> 主机名、任何 token / 密钥。**这些一旦上传就公开了** —— 三码 + ROM MAC 等同于这台机器的
> Apple 身份凭证（iMessage / FaceTime 认的就是它们）。
>
> `scripts/redact-check.sh` 就是干这个的（只读）。**注意：自动扫描只是兜底**，
> 它按模式匹配，判不了「这个值是不是本机专有的」—— 仍要人工扫一眼。

### B.3 上传（在应用里操作）

**入口**：技能面板 → **「上传技能」**（也可以在输入框左下角 `+` → 技能）。

技能面板的标签页：**推荐 / SkillHub / 插件 / Knot / 企业技能 / 已安装**。

**弹窗流程**：

1. **拖入**（或点选）**文件夹或 `.zip`**
   - 拖文件夹时若为空会提示「请选包含 SKILL.md 的技能文件夹」
   - 文件夹打包超时会提示改用点选
2. **选择上传作用域** —— **个人库**（Personal Library）或 **项目**（Project）
3. 填 **name / title / description**
4. 点 **「选择并导入」** → 依次看到 **Security checking… → Uploading… → Importing…**

**上传时实际提交的字段**（后台接口）：

| 字段 | 说明 |
|---|---|
| `entity_type` | 固定 `skill` |
| `file` | 你的 zip / 文件夹 |
| `name` | 技能标识（必填） |
| `title` | 标题（可选） |
| `description` | 描述（可选） |

### B.4 ★ 上传前会有一道 `preflight` 检查（会被拦或要求确认）

上传不是直接传 —— 先跑一次 **preflight**，返回三件事：

| 返回 | 含义 | 你要做什么 |
|---|---|---|
| `can_upload: false` | **被拦下**，不允许上传 | 按返回的 `issues` 逐条修 |
| `need_confirmation: true` | **要求确认**后才能传 | 逐项确认 `confirmation_types` |
| `confirmation_types` | 需要确认的类别 | ★ 其中一类是 **`credential`** —— **检测到疑似凭据** ⇒ 回去把密钥/token 从技能里清掉 |

> ⇒ **所以「打包前扫敏感信息」不是可选项** —— 扫出来不清，上传时会被要求确认，甚至直接拦。

### B.5 上传后：服务端检查（这就是「审核」）

上传成功后会返回一个 `status`，前端**轮询**直到出结果：

- 成功 → 拿到 `version` / `updated_at`
- 失败 → 看 `check_error`

所以「审核」是**在服务端做的**，不是人工先审 —— 先把包传上去，再由服务端判定。

### B.6 可能被策略挡住的几种情况

| 提示 | 原因 |
|---|---|
| `Your administrator has disabled personal Skill uploads.` | 管理员关掉了个人上传 |
| `You are not on the allowlist for Skill uploads.` | 不在允许名单里 |
| `You are not allowed to upload Skills.` | 在禁止名单里 |
| `Skill package exceeds the {limit} size limit.` | **包体积超限**（本仓库两个包都只有百 KB 级，不用担心） |
| `Service unavailable, please contact your administrator.` | 服务不可用 |

### B.7 这一步需要你来做

打包和自检**本仓库已经做完**（`dist/` 里就是可直接上传的 zip）。
但**上传必须有你的账号**，我代替不了。

> 上架后如果平台反馈需要改（描述字数、图标、分类等），改完**重新打包再传**即可。

### 两条路线可以并存

先把仓库做成可添加的市场（路线 A）**给自己和熟人用**，
等技能稳定了再打包上架官方（路线 B）—— 两条互不冲突。
