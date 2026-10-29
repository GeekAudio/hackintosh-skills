# AMFI ↔ TCC 冲突：关掉 AMFI 之后，App 拿不到权限怎么办

> 依据：**`GeekAudio/tcc-helper` 官方 README**（GUI/CLI 用法、自动授权思路、五个工程坑，逐条引用）
> + OCLP / `tccplus` 文档（AMFI 关闭 ⇒ 不弹窗 + 不生成条目）+ 上游 NVIDIA 驱动仓库逐行核对。
> ★ **一句话**：**「AMFI 关闭」和「TCC 弹窗」不能同时要** ——
> 解法是**用 `tcc-helper` 把「已授权」条目直接写进 TCC 数据库**，代价是**不持久**
> （系统大版本更新 / `tccutil reset` / 清理工具都会抹掉）。

## 0. 现象线索（还需确认运行态 AMFI 与实际请求对象）

1. 语音 / 摄像头类 App 报 **「没有权限」**；
2. **不弹权限窗**（点多少次都不弹）；
3. **「系统设置 → 隐私与安全性」里根本没有那个 App 的开关**（不是灰的，是**不存在**）。

缺少条目是线索，**不能单独证明 AMFI 被关闭**。先确认 App / helper 实际发起了目标权限请求、
检查当前启动参数与相关日志，再判断是否属于本文的 AMFI 场景；不要仅凭列表为空就写 TCC 数据库。

## 1. 根因：AMFI 被关闭

boot-args 里有这两条（任一条即可）⇒ **AMFI 被禁用**：

```
amfi_get_out_of_my_way=0x1
amfi=0x80
```

后果（**OCLP / `tccplus` 文档原话**）：

> *"macOS will fail to prompt users for special permissions upon application start
> as well as omit the entries in System Preferences"*

⇒ **既不弹窗，也不在隐私列表里生成条目** ⇒ App 永远拿不到权限，
**不是 App 坏了、也不是麦克风/摄像头设备坏了**。

> 核对 `sysctl -n kern.bootargs` 中实际生效的参数；NVRAM / config 的改动尚未启动时不代表当前状态。
> 再检查请求权限的具体组件、目标数据库和日志；条目数为 0 或极少本身不能定性。

## 2. 谁在要求关 AMFI（以及 AMFIPass 的位置）

**不是你想关，是驱动要求的**。典型：

| 来源 | 要求 |
|---|---|
| **NullMoth NVIDIA 驱动**（`nvidia-driver.md`） | 官方**必需清单是两件套**：boot-args 带 `amfi_get_out_of_my_way=0x1 amfi=0x80` **且** `Lilu.kext` / `AMFIPass.kext` 要启用；安装器 `nullmoth-setup.sh` 主动写入并自动补齐这两个 kext |
| **OCLP 根补丁 / 博通 Wi-Fi 侧** | 走的是 **`AMFIPass.kext`**（**保留 AMFI** 的做法），不是关 AMFI |
| 其它第三方 kext | 视驱动而定；**先查驱动 README 有没有明确要求**，别默认「黑苹果就要关 AMFI」 |

★★ **别把 kext 和 boot-arg 搞混**：`AMFIPass.kext` 是**驱动必需项**；
被 `NDSecurityState.m` 列进「不安全覆盖」名单的是 **`-amfipass*` 这个 boot-arg**。

⇒ **别的机器**：优先用 `AMFIPass.kext` 顶替 AMFI 参数（**保留 AMFI** ⇒ TCC 弹窗正常，**根本不会有本文档这个问题**）。
⇒ **需要关 AMFI 的场景**（如 NullMoth 驱动）：上游把「AMFI 参数 **+** AMFIPass」**两个并列列为必需** ⇒ **只能二选一**，见 §3。

## 3. 结论：只能二选一

| 选 | 做法 | 代价 |
|---|---|---|
| **保驱动**（现行） | 留着 AMFI 参数，用 **`tcc-helper` 手工注入 TCC 条目**（§4） | **不持久** —— 系统大版本更新 / `tccutil reset` / 清理工具会抹掉，需重跑 |
| **保弹窗** | 去掉 AMFI 参数 | ★★ 上游不支持该组合 + 未验证；**失败后果 = WindowServer 加载不了 NVIDIA bundle ⇒ 黑屏只剩鼠标** ⇒ **不要做** |

## 4. ★★ 解法：`GeekAudio/tcc-helper`

<https://github.com/GeekAudio/tcc-helper> —— Swift 写的 **GUI（SwiftUI）+ CLI**，MIT 许可。

> **它替代了早期那些一次性 shell 脚本**：把「扫谁需要什么权限」这件事**从系统里反推**出来，
> 而不是靠人肉列 App 清单。

### 4.1 装

- **Release**：`v1.0.0` 的 **`TCC.Helper-1.0.dmg`** ⇒ 挂载后把 App 拖进 `Applications`
- **自构建**：`./build.sh`（出 App）/ `./make-dmg.sh`（出 DMG）—— 只依赖 **Xcode 命令行工具**（`swiftc`），**不需要 Xcode 工程文件**
- 当前工具为 ad-hoc 签名。先确认来源与下载完整性；可信未公证 App 按
  [Apple 单应用“仍要打开”流程](https://support.apple.com/en-us/102445) 在系统设置中建立例外。
  不把右键打开、删除隔离标记或全局关闭 Gatekeeper 当作所有系统的默认做法。

### 4.2 GUI 用法（五步）

1. **目标数据库** —— 选 **用户库**（麦克风 / 摄像头 / 音频采集 / 蓝牙…）或 **系统库**（辅助功能 / 屏幕录制…）。
   面板会显示自检结果；**系统库属主是 root，写它时会弹管理员密码**。
2. **扫描候选** —— 自动扫描只能提供线索，不能替代授权范围。只选择本次任务要求的 App / helper 与权限；
   已有明确授权时按其执行，不把“修一个 App”扩展为给扫描到的所有 App 授权。先预演，再写入所需条目（§4.3）。
3. **目标 App（手动）** —— 把 `.app` 拖进虚线框，或用「选择目标…」。
   ★★ **要授权的是「真正申请权限的那个组件」，不一定是主 App**
   （例：Loopback 的麦克风/系统音频权限属于它包内的 `Audio Routing Kit (ARK).app`（`com.rogueamoeba.arkaudiod`），
   **给 `Loopback.app` 授权没用**）⇒ 选目标时可以**钻进 `.app` 内部**选子组件；
   「从运行中的 App 选…」能直接列出在跑的**后台 helper**。
4. **权限服务（手动）** —— **109 个服务**，**运行时从系统 `tccd` 二进制里抽出来**的，中英文都能筛。
5. **操作** —— 预演（不写库）/ 授权 / 撤销 / 刷新条目。
   **写入前自动备份 `TCC.db`，写完自动 `killall tccd`**，并回读验证。

### 4.3 ★★ 自动授权：不猜、也不靠人肉挑，从系统里反推

**线索 ①：App 自己就声明了** —— `Info.plist` 里的 usage description 就是它的权限申请清单：

| Info.plist 键 | 对应 TCC 服务 |
|---|---|
| `NSMicrophoneUsageDescription` | `kTCCServiceMicrophone` |
| `NSCameraUsageDescription` | `kTCCServiceCamera` |
| `NSAudioCaptureUsageDescription` | `kTCCServiceAudioCapture`（系统音频采集） |
| `NSAppleEventsUsageDescription` | `kTCCServiceAppleEvents` |
| `NSDesktopFolderUsageDescription` … | 桌面 / 文稿 / 下载 / 网络宗卷 / 可移除宗卷 |
| `NSBluetoothAlwaysUsageDescription` | `kTCCServiceBluetoothAlways` |

（完整映射见源码 `Sources/TCCAuto.swift` 的 `usageMap`；**会按系统真实服务清单过滤**，系统不认识的键不会写。）

**线索 ②：真正申请权限的往往是后台组件** —— 所以还会扫：

- **launchd 注册的每个 job** → 解析回它所属的 `.app`（`Program` / `ProgramArguments[0]` 往上找 `.app`）
- **包内子组件**：`Contents/{Library/LoginItems, Library/LaunchServices, XPCServices, PlugIns, Helpers, Resources, MacOS}`
- **组件目录**：`/Library/Audio/Plug-Ins/HAL`（音频驱动，**ARK 就在这儿**）、`/Library/PrivilegedHelperTools` 等
- **正在运行的 App**

**效果**：Loopback 那个坑，自动模式**自己就找出了 `com.rogueamoeba.arkaudiod`**，
并认出它需要 `kTCCServiceMicrophone` + `kTCCServiceAudioCapture` —— **完全不用人工翻包**。

### 4.4 CLI 用法（与 GUI 共用同一套逻辑，DMG 里自带）

`auto` 是扫描预演；`auto --apply` 会批量写入，只在本次任务已授权相应批量范围时使用。
单个 App 的修复使用限定目标和服务的 `dry` / `grant`，不把扫描结果视为所有候选的授权。

```sh
bin/tcchelper-cli auto                                  # 预演（只列，不写）
bin/tcchelper-cli auto --apply                          # 真正写入
bin/tcchelper-cli auto --root /Applications --no-running # 限定扫描范围
bin/tcchelper-cli auto --service kTCCServiceAudioCapture # 只处理某一个服务

bin/tcchelper-cli services                              # 列出全部服务
bin/tcchelper-cli inspect  <App>                        # 看 bundle id / 签名 / DR
bin/tcchelper-cli list     <App> [--db user|system]     # 列出该 App 的条目
bin/tcchelper-cli dry      <App> <service> [--db ...]   # 预演
bin/tcchelper-cli grant    <App> <service> [--db ...] [--path]
bin/tcchelper-cli revoke   <App> <service> [--db ...] [--path]
```

★ **`--path` = 按绝对路径授权**（`client_type=1`），用于**没有 bundle 的裸可执行文件**。

### 4.5 原理：写的是 `access` 表

| 列 | 值 |
|---|---|
| `service` | `kTCCService…` |
| `client` | bundle id（`client_type=0`）或绝对路径（`client_type=1`） |
| **`auth_value`** | **`2` = 允许**（0 拒绝 / 3 未决） |
| `auth_reason` | `4` = 服务策略（**系统自己生成的条目用的就是这个**） |
| `auth_version` | `1` |
| **`csreq`** | DER blob，由目标 App 的 **designated requirement** 生成 |
| `indirect_object_identifier` | 字面量 **`'UNUSED'`**（不是空串） |

**`csreq` 生成**：`codesign -d -r- <App>` 取 `designated =>` **之后**的文本 → `csreq -r- -b out.bin`。
★ **magic 必须是 `fade0c00`**；把 `designated =>` 前缀一起喂进去会得到 **`fade0c01`（集合格式）⇒ TCC 不认**。

## 5. ★ 五个工程坑（代码里都处理了，自己写脚本时会全踩一遍）

1. **`codesign -dvvv -r-` 把 DR 打在 stdout、详细信息打在 stderr** ⇒
   **只看一个流会把有签名的 App 误判成「无签名」**，两个流都要解析。
2. **ad-hoc 签名的 App 没有显式 DR** —— codesign 打成 `# designated => cdhash H"…"`（带 `#`，是注释）。
   这种情况 **`csreq` 留空**，靠 Bundle ID 匹配（**系统给 Apple 守护进程写的条目也是这样**）。
3. **别用临时表做写权限自检** —— `create temp table` **只写 temp 库**、永远「成功」，测不出主库只读；
   要用**主库上的 DDL + `rollback`**。
4. ★ **扫描阶段绝不能对每个 App 跑 `codesign`** —— 每次是一个子进程，
   36 个 App 串行要 **17–21 秒**，界面直接卡死 ⇒ 改成**惰性 + 并行**（`DispatchQueue.concurrentPerform`）后：
   扫描 **0.9 s** + 签名检查 **2.1 s**。
5. ★ **`systemServices()` 必须缓存** —— 它要读几 MB 的 `tccd` 再跑正则，而扫描会对**每个 App** 调一次；
   不缓存 = 几十遍全量扫描。

## 6. 排查判据（下次直接照做）

1. **查用户 TCC 库的条目**：

   ```bash
   sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
     "select service,client,auth_value from access where service like '%Microphone%';"
   ```

   - **条目数 0 或极少**：确认请求是否真的发生、组件 / 服务与数据库是否选对；结合运行态 AMFI 与日志判断，不能直接定性。
   - 条目在且 `auth_value=0`：按系统设置与用户意图处理；需要重置时限定具体服务和 App，不能默认把拒绝改为允许。
2. **查 boot-args 里有没有 `amfi`**：`sysctl -n kern.bootargs` / `nvram boot-args`。
3. **查 `csr-active-config` 要看字节**：用 `plistlib` 读；
   ⚠️ **`PlistBuddy -c Print` 打的是 base64** —— 本机显示 `C` 其实是 `430a0000`（= `0x0A43`）。
4. ★★ **诊断纪律（先分三类，别一上来就写库）**：
   ① **条目不存在**：先核对实际请求、组件、服务、数据库、运行态 AMFI 与日志
   ② **条目存在但被拒**：按用户期望在系统设置处理，必要时限定范围重置后重试
   ③ **条目存在且已允许但仍失败**：继续查实际请求组件、签名 / 条目匹配与设备或 App 日志，不只凭一行记录排除 TCC
   ★ 还有一类最容易漏：**授权的对象选错了** —— 要授权的是**真正申请权限的那个 helper / 子组件**（§4.2 第 3 步）。

## 7. 注意与边界

- **条目不持久** —— 系统大版本更新 / `tccutil reset` / 清理工具都会抹掉，**需要重跑**
- **用户库不可读时** ⇒ 给这个 App 勾「**完全磁盘访问权限**」；
  也可以点面板上的「给自己完全磁盘访问」（**写系统库，需要管理员密码**）
- **撤销**：用「撤销」按钮，或 `tccutil reset <service> <bundle-id>`
- ★ 这是**有意降低系统安全边界**的操作 ⇒ **只给确实需要的 App 授权**
- 只使用工具明确支持且与当前系统数据库结构匹配的服务；不要仅替换 `service` 就推断任意 TCC 权限都能同样写入。
  屏幕录制 / 辅助功能按目标系统与工具当前说明单独验证。

## 8. 出处

- `GeekAudio/tcc-helper` → `README.md`（GUI/CLI 用法、自动授权思路、五个坑）+ `Sources/TCCAuto.swift`（`usageMap`）+ Release `v1.0.0`。
- OCLP / `tccplus` 文档：AMFI 关闭 ⇒ 不弹窗 + 不生成隐私条目（原文见 §1）。
- 相关：`nvidia-driver.md` §8（驱动的安全边界）· `broadcom-wifi.md`（OCLP 根补丁侧）。

---

## 附录：Gatekeeper 与未公证 App

Gatekeeper 的启动评估与运行后 TCC 权限分别排查，不能用关闭其中一个替代另一个。

### A.1 先确认来源与完整性

| 提示 | 处理 |
|---|---|
| 身份不明的开发者 / Apple 无法检查恶意软件 | 核对作者来源、目标版本、下载哈希或签名；可信完整产物可按单应用例外打开 |
| 已损坏 / 已修改 / 应移到废纸篓 | 也可能是真损坏或篡改；先重新获取可信产物并核对完整性，不默认删除隔离标记 |
| App 能打开但无法使用麦克风 / 摄像头 | 查实际权限请求、组件、运行态参数与日志；不能仅凭该症状认定 AMFI 问题 |

依据：[Apple 安全打开 App](https://support.apple.com/en-us/102445)。

### A.2 可信未公证 App：建立单应用例外

确认产物可信完整后，先尝试打开，再到「系统设置 → 隐私与安全性」选择该 App 的「仍要打开」，
确认目标 App 后重试。具体入口按目标 macOS 的当前界面和
[工具作者说明](https://github.com/GeekAudio/tcc-helper/blob/main/README.md) 核对。
该方式不会把所有下载 App 的评估全局关闭。

### A.3 全局策略只在任务确有需要时调整

可先只读查看：

```bash
spctl --status
spctl --help
```

全局修改 Gatekeeper 不作为常规安装或“已损坏”提示的后备修复。
只有用户明确请求该全局变更、或该操作确属任务所需且已获授权时，才按目标 macOS 文档 / 当前界面操作，
记录原状态与恢复方式；不要从 `strings` 中存在某个旧参数就推断它仍是受支持接口。
关闭 Gatekeeper 也不解决 kext 加载或 TCC 授权问题。
