# 踩过的坑（症状 → 原因 → 正确做法）

## A. 配置/概念类

| 症状 | 原因 | 正确做法 |
|---|---|---|
| 用 `ScanPolicy` 屏蔽后 **Windows 启动不了** | `ScanPolicy` 是**安全策略**（限制扫描不受信来源），不是显示开关 | 保持 `ScanPolicy=0`；少显示用 `HideAuxiliary` / `Misc>Entries` |
| 以为 `ocvalidate` 过了就没问题 | 它只查 schema / 类型 / 必填 / 顺序 | 取值是否**符合文档**要逐键人工比对（见 `official-docs-method.md`） |
| 改了 SSDT **文件名**后担心表身份变了 | 表身份由**内容**解析决定，不由文件名 | 改名安全；只要同步改 `ACPI>Add>Path` |
| 把 `NVRAM>Add` 的键写进去却不生效 | 文档规则：**只有同时在 `Delete` 里**才会覆盖已存在的变量 | Add 的每个键都要在 `Delete` 里出现 |
| `plutil` 报 `Key path not found NVRAM.Delete.0.<GUID>` | `NVRAM>Delete` 是 **dict（GUID→数组）**，不是数组 | 键路径写 `NVRAM.Delete.<GUID>` |
| `plutil -remove 'Kernel.Add.15'` 连删几条后删错 | 删数组元素后**索引会前移** | **从高索引往低删** |
| 把 `-wegnoigpu` / `-v` 这类开关当成"日志开关" | 它们影响的是**另一段**（macOS 图形栈 / macOS verbose），与 OC 段无关 | 刷屏归因先分清 OC 段 vs macOS 段（见 `logs-and-debug.md`） |
| 开了"完整 debug"却拿不到更多信息 | 有些层把 verbose 宏**写死**（例：某端口的 `#define bootverbose 0`） | 先确认"谁负责提供这个数据"，再决定改数据的来源 |

## B. 磁盘/分区类

| 症状 | 原因 | 正确做法 |
|---|---|---|
| 按 `disk0/disk2` 写的东西下次开机失效 | **盘号会漂**（同一次会话里前后两次 `diskutil list` 都可能互换） | 一律按**卷 UUID**；ESP 现查 `diskutil list \| grep "EFI EFI"` |
| `awk '/^\/dev\/disk/'` 抓不到分区 | `diskutil list` 里**分区标识不带 `/dev/` 前缀** | 用 `grep -oE 'disk[0-9]+s[0-9]+'` |
| 写了 fstab 后 EFI 分区挂不上（担心） | — | **EFI 永不写进 fstab**；写完按 UUID 找 ESP 做一次 卸载→挂载→读 config 验证 |
| 卸载 ESP 后 `PlistBuddy` 报 `File Doesn't Exist, Will Create` | ESP 未挂载（不是文件损坏） | 先 `ls -d /Volumes/EFI` 探一下再读写 |
| `diskutil mount <dev>` 普通调用失败 `failed to mount` | 需要提权 | 走 `osascript -e 'do shell script "diskutil mount <dev>" with administrator privileges'` |
| ESP 上出现 `._xxx` 文件 | macOS 在 FAT 上生成的 AppleDouble | 无害（OpenCore 只按 config 里的路径读文件）；在意就删 |

## C. 日志/取证类

| 症状 | 原因 | 正确做法 |
|---|---|---|
| `log show \| head -N` 抓不到本次开机的内容 | `log show` 是**旧→新**输出，`head` 只留最早一批 | 用 `--start "<开机时间>"` 或改用 `tail` |
| 沙箱里 `log show` / `lsof` / `sudo` 不可用 | 沙箱限制 | 提权 AppleScript：`osascript -e 'do shell script "/bin/bash <脚本>" with administrator privileges'`；脚本内写文件再 `chmod 644` |
| 脚本里含空格的路径静默失败 | `OUT=/Users/x/WorkBuddy AI/…` 被当成"赋值 + 命令" | 一律 `OUT="…"` 加引号 |
| ESP 上找不到 `opencore-*.txt` | `Target` 不含 `0x40`，或该次启动没写 | 查 `Target`；改用 DataHub 读法（`0x04`） |
| 日志里一堆 `Not Found` 以为坏了 | NVRAM 变量 / APFS preboot 分区 / OpenCanopy 可选图标都会打 | 先分类再判断（见 `logs-and-debug.md` §7） |
| `OCUI: Failed to load image … - Not Found` 想"补图标" | 那些名字在**任何官方图标集里都不存在** | 不动；官方 GoldenGate/Syrah/Chardonnay 各只有 25 个 `.icns` |
| `AppleAHCIPort … COMRESET did not proceed` 以为硬盘坏了 | 空端口（`PxSSTS 0x4` = PHY offline）也会打 | 先看 `ioreg -r -c IOAHCIDevice` 有没有子设备、`diskutil list` 有没有丢盘 |

## D. 工具/协作类

| 症状 | 原因 | 正确做法 |
|---|---|---|
| 用 Bash `grep` 查中文/多模式，得出"文件里没有" | Bash `grep` 对 `\|` 交替与中文给过**假阴性** | 用 **Grep 工具（ripgrep）** 复核 |
| 会话被中断后，工作区文件少了一整节 | **turn aborted 会回滚工作区文件的改动** | 中断后先复查文件是否还在（报告/脚本/备份） |
| `git push \| sed` 之后拿不到退出码 | 管道吃掉了退出码 | 别把 `git push` 接进管道；需要过滤就先存文件 |
| GitHub API 报 `SSL_ERROR_SYSCALL` | API 路径拼接错误 | 路径**必须以 `/` 开头**（`/repos/...`，不是 `repos/...`） |
| 以为"ID 重复 = 上传了两次" | 内容寻址：相同内容返回同一 ID | 先比对 sha256 再判断 |
| 上报前不看本地回执 | 服务端/客户端可能只上报了一部分 | 先读本地的 receipt/清单文件（如 `upload-receipt.json`），核对条数与 sha |
| 脚本报 `unbound variable`，变量名还是乱码 | **`$VAR` 后面紧跟全角字符**（`）` `，` `：` `★`）时，bash 会把多字节字节当成变量名的一部分 | 写成 **`${VAR}`**；写完扫一遍：`awk 'match($0, /\$[A-Za-z_][A-Za-z0-9_]*[^ -~]/)' *.sh` |
| 换 OpenCore 构建后行为诡异/混搭 | 只换了 `OpenCore.efi`，没换 Drivers（同版本下 RELEASE/DEBUG 的**所有** Drivers 内容都不同） | 连**官方同名** Drivers 一起换，第三方驱动保留（`scripts/oc-swap-build.sh` 已按此实现） |

## F. 固件启动项（NVRAM `Boot####` / `LauncherOption`）

| 症状 | 原因 | 正确做法 |
|---|---|---|
| **用 U 盘引导一次后，硬盘上的 OpenCore 启动项从 BIOS 启动菜单消失，只剩 Windows** | `Misc>Boot>LauncherOption=Full` 让 OpenCore 每次开机维护「自己那条」启动项，而它**只按文件路径后缀（`OpenCore.efi`）认项、不看设备** ⇒ 从 U 盘启动时把硬盘那条**重指到 U 盘**；拔盘后设备不存在 ⇒ 固件清理 | **两个 ESP 都改 `LauncherOption=Disabled`** + 保留 `\EFI\BOOT\BOOTx64.efi` 兜底 ⇒ 详见 `boot-entries.md` |
| 想手工 `bcfg boot add/rm` 但改不动 | `UEFI>Quirks>RequestBootVarRouting=true` 会**保护 NVRAM** | 先跑 `OpenControl.efi disable`，之后再 reboot 或 `OpenControl restore` |
| 在 **ASUS** 板上手工建 `Boot0000` | 源码注释：ASUS 把 `Boot0000` 当「已删除」处理 | **别用 `Boot0000`** —— 会导致条目重复、甚至 BIOS 变砖 |
| `nvram -p` 里看不到 `Boot####`，以为没有启动项 | `nvram -p` **不列出** `Boot####` | 按 `GUID:名字` 单独读：`nvram 8BE4DF61-93CA-11D2-AA0D-00E098032B8C:BootOrder` |
| 把「BIOS 启动菜单里的项」和「OpenCore 选择器里的项」当成一回事 | 前者是**固件 NVRAM**（`Boot####`），后者是 OpenCore 扫出来的 | 少显示系统用 `ScanPolicy`/`HideAuxiliary`；启动项丢失看 `boot-entries.md` |

## E. 流程纪律

- **一次只改一项**；批量改动要在报告里逐条列出「改了什么 / 依据 / 怎么回滚」
- 改动前**先读 live 再对 diff**（可能有并发脚本也在写）
- 改动后**立刻**：`plutil -lint` → `ocvalidate` → 算 sha → 同步镜像与版本存档 → `sync`/卸载/重挂/复验
- 报告里留一节「**明确不动**」并写理由，避免下次被"改回默认"改坏
