# AMFI ↔ TCC 冲突：关掉 AMFI 之后，App 拿不到权限怎么办

> 依据：**OCLP / `tccplus` 文档原文**（AMFI 关闭 ⇒ 不弹窗、不生成隐私条目）+ **上游 NVIDIA 驱动仓库逐行核对**
> （`README.md` / `docs/HOW-IT-WORKS.md` / `nullmoth-setup.sh` / `NDSecurityState.m`）+ **本机 10-15 实测**。
> ★ **一句话**：**「AMFI 关闭」和「TCC 弹窗」不能同时要** —— 但**代价可以用「手工注入 TCC 条目」补回来**，
> 只是**不持久**（系统更新 / `tccutil reset` / 清理工具都会抹掉）。

## 0. 现象三连（对号入座就是这个问题）

1. 语音 / 摄像头类 App 报 **「没有权限」**；
2. **不弹权限窗**（点多少次都不弹）；
3. **「系统设置 → 隐私与安全性」里根本没有那个 App 的开关**（不是灰的，是**不存在**）。

★ 与「用户点了拒绝」的区别：被拒的 App **在列表里有条目**（只是开关关着）；
这个问题是**条目压根不生成**。

## 1. 根因：AMFI 被关闭

boot-args 里有这两条（任一条即可）⇒ **AMFI 被禁用**：

```
amfi_get_out_of_my_way=0x1
amfi=0x80
```

后果（**OCLP / `tccplus` 文档原话**）：

> *"macOS will fail to prompt users for special permissions upon application start
> as well as omit the entries in System Preferences"*

⇒ **既不弹窗，也不在隐私列表里生成条目** ⇒ App 永远拿不到权限，**不是 App 坏了、也不是麦克风设备坏了**。

> ★ **判据**：`sysctl -n kern.bootargs` / `nvram boot-args` 里有没有 `amfi`。
> 再看用户 TCC 库里的麦克风条目数（§6 第 1 条）—— **条目数 0 或极少 = 弹窗被抑制**。

## 2. 谁在要求关 AMFI

**不是你想关，是驱动要求的**。典型：

| 来源 | 要求 |
|---|---|
| **NullMoth NVIDIA 驱动**（`nvidia-driver.md`） | 官方表格明写 boot-args 要带 `amfi_get_out_of_my_way=0x1 amfi=0x80`，注释 *"the AMFI args let WindowServer load the driver bundle"*；**安装器 `nullmoth-setup.sh` 主动写入**（`WANT_ARGS`），还专门为这两个 token 做归属记录 |
| **OCLP 根补丁 / 博通 Wi-Fi 侧** | 需要加载非 Apple 签名 kext —— 但它们走的是 **`AMFIPass.kext`**（**保留 AMFI** 的做法），不是关 AMFI |
| 其它第三方 kext | 视驱动而定；**先查驱动 README 有没有明确要求**，别默认「黑苹果就要关 AMFI」 |

★ 关 AMFI 是**有意降低系统安全性**，只在驱动**明确要求**时做；不装驱动就把这几条恢复原值。
（同时通常还要 `SecureBootModel=Disabled` + 放宽 `csr-active-config`。）

## 3. ★★ 首选方案：`AMFIPass.kext` —— 一般情况用它，本机这条路被驱动自己堵死

**`AMFIPass`（Lilu 插件）就是为了「不关 AMFI 也能加载非 Apple kext」而存在的** ——
它让 AMFI 保持开启，只对指定 kext 放行。**能改用它就改用它**：AMFI 一开着，TCC 弹窗与条目全都正常，
**根本不会有本文档这个问题**。

- ★★ **但本机的 NVIDIA 驱动明确不接受它**：上游全仓库搜 `AMFIPass` 只命中一处 ——
  `app/DiagnosticsNative/authority/NDSecurityState.m`，它把 **`-amfipass*` 与 `amfi=0x80` / `amfi_get_out_of_my_way`
  归进同一份「不安全覆盖」名单**。
- ⇒ **对这台机器，「用 AMFIPass 顶替 AMFI 参数」是无上游依据的** ——
  工作区早先那份 `1401文档对齐检查-20261011.md` 写「`AMFIPass.kext` = 驱动要求」是**错的**，
  正确表述是「为博通 Wi-Fi / OCLP 根补丁侧保留」。
- ⇒ **通用结论**：**先查驱动是否接受 AMFIPass**；接受 ⇒ 用它（问题自动消失）；不接受 ⇒ 走 §5。

## 4. 结论：只能二选一

驱动要 AMFI **关**、TCC 弹窗要 AMFI **开** —— **不存在「改 boot-args 两全」的写法**。

| 选 | 做法 | 代价 |
|---|---|---|
| **保驱动**（现行） | 留着 AMFI 参数，**手工注入 TCC 条目**（§5） | **不持久** —— 系统大版本更新 / `tccutil reset` / 清理工具会抹掉，需重跑 |
| **保弹窗** | 去掉两条 boot-args，改用 `-amfipassbeta` 顶替 | ★★ **上游未背书 + 本机未验证**；**失败后果 = WindowServer 加载不了 NVIDIA bundle（没显示）** ⇒ **不要做** |

> ★ **本机踩过一次**：试过「保弹窗」那条，`config.plist` sha `45648427…` 已落盘，
> 核对上游后**已回滚**。**别再试第二次**。

## 5. 解法：直接注入 TCC 条目（`scripts/tcc-grant-mic.sh`）

### 5.1 原理

**绕过弹窗机制，直接往用户 TCC 库里写一条「已授权」** —— 字段取值**对齐系统自己生成的条目**
（拿本机真实弹窗授权过的条目当模板，如屏幕录制 / 辅助功能）。

### 5.2 用户 TCC 库位置与表

```
~/Library/Application Support/com.apple.TCC/TCC.db     ← 麦克风在这里（用户库）
/Library/Application Support/com.apple.TCC/TCC.db      ← 系统库（另一些服务）
```

表 = **`access`**，主键 `(service, client, client_type, indirect_object_identifier)`。

| 列 | 取值 | 说明 |
|---|---|---|
| `service` | `kTCCServiceMicrophone` | 麦克风；摄像头是 `kTCCServiceCamera` |
| `client` | bundle id | 如 `com.tencent.qq` |
| `client_type` | `0` | 0 = bundle id |
| `auth_value` | **`2`** | 0 = 拒绝 / **2 = 允许** / 3 = 未决 |
| `auth_reason` | `4` | 4 = 服务策略（系统自己的条目用的就是这个） |
| `auth_version` | `1` | |
| **`csreq`** | **DER blob** | 见 §5.3 —— **不能省**，少了它 tccd 不认 |
| `policy_id` | `NULL` | |
| `indirect_object_identifier_type` | `0` | |
| `indirect_object_identifier` | `'UNUSED'` | **字面量**，不是空串 |
| `flags` | `0` | |

### 5.3 ★★ `csreq` 生成（最容易踩的一步）

```
codesign -d -r- <App.app>            # 取输出里 designated => 之后的 DR 文本
printf '%s\n' "$DR" | csreq -r- -b out.bin
```

- ★ **magic 必须是 `fade0c00`**（与库内既有条目一致，通常 156–204 B）。
- ⚠️ **把 `designated =>` 前缀一起喂进去** ⇒ 生成 `fade0c01`（集合格式）⇒ **TCC 不认**。
- ⚠️ **`csreq -r-` 是从 stdin 读** —— 不喂 stdin 会**挂住**（踩过，被 SIGTERM）。

### 5.4 操作顺序

1. **备份 `TCC.db`**（脚本自动做，带时间戳）。
2. `INSERT OR REPLACE` 写入条目。
3. **`killall tccd`** 让它重新读库 —— ★ **root 那份 `tccd` 会拒绝被 kill，属正常**。
4. **回读验证**：条目**扛住 `tccd` 重启 = 被接受**。

### 5.5 撤销

```
tccutil reset Microphone                 # 清全部麦克风授权
tccutil reset Microphone <bundle-id>     # 清单个
```

### 5.6 脚本用法

```bash
scripts/tcc-grant-mic.sh --scan                 # 扫 /Applications 里声明要用麦克风的 App
scripts/tcc-grant-mic.sh --list                 # 列出当前麦克风授权条目
scripts/tcc-grant-mic.sh --dry-run <App.app> …  # 只生成 csreq 并预演，不写库
scripts/tcc-grant-mic.sh <App.app|bundle-id> …  # 真正写入
scripts/tcc-grant-mic.sh --reset [bundle-id]    # 撤销
```

> ★ **写入 TCC.db 需要放宽的 SIP**（文件受系统保护）—— 本机 `csr-active-config = 0x0A43` 本来就够。
> ★ **`--scan` 只是帮你找候选**：真正要授权哪些 App 由你决定，脚本不自动全写。

## 6. 排查判据（下次直接照做）

1. **查用户 TCC 库的麦克风条目**：

   ```bash
   sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
     "select service,client,auth_value from access where service like '%Microphone%';"
   ```

   - **条目数 0 或极少** ⇒ **弹窗被抑制**（AMFI 关着）⇒ 本文档；
   - 条目在但 `auth_value=0` ⇒ 是**被拒**，另一回事（`tccutil reset` 后重试，或直接改 `auth_value=2`）。
2. **查 boot-args 里有没有 `amfi`**：`sysctl -n kern.bootargs` / `nvram boot-args`。
3. **查 `csr-active-config` 要看字节**：用 `plistlib` 读；
   ⚠️ **`PlistBuddy -c Print` 打的是 base64** —— 本机显示 `C` 其实是 `430a0000`（= `0x0A43`）。

## 7. 通用化与边界

- **不限于麦克风**：同样的机制适用于**所有** TCC 服务 ——
  把 `service` 换成 `kTCCServiceCamera`（摄像头）/ `kTCCServiceScreenCapture`（屏幕录制）/
  `kTCCServiceAccessibility`（辅助功能）等，字段格式一样。
  ★ 但**屏幕录制 / 辅助功能**在部分系统上还要额外处理，**先用 §6 第 1 条确认到底是「没条目」还是「被拒」**。
- **不限于 NVIDIA 驱动**：只要 boot-args 里关了 AMFI，都会中招 ⇒ **先按 §3 试 AMFIPass**。
- ★★ **诊断纪律**：遇到「App 要权限拿不到」，**先分三类** ——
  ① **条目不存在**（本文档，AMFI 抑制）② **条目存在但被拒**（用户操作，`tccutil reset`）③ **条目存在且已允许但仍失败**（App 自身 / 设备问题，别再折腾 TCC）。
- ★ 中招的**多是 Electron / Chromium 系应用**（它们走系统标准授权路径），但**不是只有它们**。

## 8. 出处

- OCLP / `tccplus` 文档：AMFI 关闭 ⇒ 不弹窗 + 不生成隐私条目（原文见 §1）。
- NullMoth NVIDIA 驱动：`README.md`（boot-args 表）· `docs/HOW-IT-WORKS.md` ·
  `app/Resources/nullmoth-setup.sh`（`WANT_ARGS` / `SIP_BITS`）· `app/DiagnosticsNative/authority/NDSecurityState.m`（AMFIPass 归类）。
- 相关：`nvidia-driver.md` §3 / §8（驱动的安全边界）· `broadcom-wifi.md`（OCLP 根补丁侧）。
