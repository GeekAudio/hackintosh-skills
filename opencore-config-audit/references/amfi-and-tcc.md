# AMFI ↔ TCC 冲突：关掉 AMFI 之后，App 拿不到权限怎么办

> 依据：**`GeekAudio/tcc-helper` 官方 README**（GUI/CLI 用法、自动授权思路、五个工程坑，逐条引用）
> + OCLP / `tccplus` 文档（AMFI 关闭 ⇒ 不弹窗 + 不生成条目）+ 上游 NVIDIA 驱动仓库逐行核对。
> ★ **一句话**：**「AMFI 关闭」和「TCC 弹窗」不能同时要** ——
> 解法是**用 `tcc-helper` 把「已授权」条目直接写进 TCC 数据库**，代价是**不持久**
> （系统大版本更新 / `tccutil reset` / 清理工具都会抹掉）。

## 0. 现象三连（对号入座就是这个问题）

1. 语音 / 摄像头类 App 报 **「没有权限」**；
2. **不弹权限窗**（点多少次都不弹）；
3. **「系统设置 → 隐私与安全性」里根本没有那个 App 的开关**（不是灰的，是**不存在**）。

★ **第三条才是判据** —— 与「用户点了拒绝」的区别就在这里：
被拒的 App **在列表里有条目**（只是开关关着）；这个问题是**条目压根不生成**。

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

> ★ **判据**：`sysctl -n kern.bootargs` / `nvram boot-args` 里有没有 `amfi`；
> 再看用户 TCC 库里的麦克风条目数（§6 第 1 条）—— **条目数 0 或极少 = 弹窗被抑制**。

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
⇒ **本机**：上游把「AMFI 参数 **+** AMFIPass」**两个并列列为必需** ⇒ **只能二选一**，见 §3。

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
- ★ **签名是 ad-hoc**（作者没有 Developer ID）⇒ **首次打开要「右键 → 打开」**（或被 Gatekeeper 拦一次）

### 4.2 GUI 用法（五步）

1. **目标数据库** —— 选 **用户库**（麦克风 / 摄像头 / 音频采集 / 蓝牙…）或 **系统库**（辅助功能 / 屏幕录制…）。
   面板会显示自检结果；**系统库属主是 root，写它时会弹管理员密码**。
2. **自动授权（推荐）** —— 打开 App 就自动扫一遍，列出「谁声明了要什么权限、还缺几条」，
   勾选后点「授权选中的」，**一次事务写完**（§4.3）。
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

   - **条目数 0 或极少** ⇒ **弹窗被抑制**（AMFI 关着）⇒ 本文档；
   - 条目在但 `auth_value=0` ⇒ 是**被拒**（`tccutil reset` 后重试，或直接改 `auth_value=2`）。
2. **查 boot-args 里有没有 `amfi`**：`sysctl -n kern.bootargs` / `nvram boot-args`。
3. **查 `csr-active-config` 要看字节**：用 `plistlib` 读；
   ⚠️ **`PlistBuddy -c Print` 打的是 base64** —— 本机显示 `C` 其实是 `430a0000`（= `0x0A43`）。
4. ★★ **诊断纪律（先分三类，别一上来就写库）**：
   ① **条目不存在** ⇒ 本文档（AMFI 抑制）
   ② **条目存在但被拒** ⇒ 用户操作，`tccutil reset` 后重试
   ③ **条目存在且已允许但仍失败** ⇒ **App 自身 / 设备问题，别再折腾 TCC**
   ★ 还有一类最容易漏：**授权的对象选错了** —— 要授权的是**真正申请权限的那个 helper / 子组件**（§4.2 第 3 步）。

## 7. 注意与边界

- **条目不持久** —— 系统大版本更新 / `tccutil reset` / 清理工具都会抹掉，**需要重跑**
- **用户库不可读时** ⇒ 给这个 App 勾「**完全磁盘访问权限**」；
  也可以点面板上的「给自己完全磁盘访问」（**写系统库，需要管理员密码**）
- **撤销**：用「撤销」按钮，或 `tccutil reset <service> <bundle-id>`
- ★ 这是**有意降低系统安全边界**的操作 ⇒ **只给确实需要的 App 授权**
- ★ 同一个机制适用于**所有** TCC 服务（把 `service` 换掉即可）；
  但**屏幕录制 / 辅助功能**在部分系统上还要额外处理 ⇒ **先用 §6 第 1 条确认到底是「没条目」还是「被拒」**

## 8. 出处

- `GeekAudio/tcc-helper` → `README.md`（GUI/CLI 用法、自动授权思路、五个坑）+ `Sources/TCCAuto.swift`（`usageMap`）+ Release `v1.0.0`。
- OCLP / `tccplus` 文档：AMFI 关闭 ⇒ 不弹窗 + 不生成隐私条目（原文见 §1）。
- 相关：`nvidia-driver.md` §8（驱动的安全边界）· `broadcom-wifi.md`（OCLP 根补丁侧）。
