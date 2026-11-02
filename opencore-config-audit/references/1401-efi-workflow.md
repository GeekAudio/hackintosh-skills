# 首选：用 1401 构建 EFI，并按启动证据诊断、重建

从零装机、需要重建候选 EFI，或安装棒启动失败时，**优先使用 [nullmoth/1401](https://github.com/nullmoth/1401)**。按它实际采集的硬件、日志与规则推进；[RapidEFI](rapidefi-first-efi.md)、[官方手工配置](official-docs-method.md)及[同版本构建切换](../scripts/oc-swap-build.sh)保留为备选。已有稳定 EFI 的局部问题先检查，不因首选工具变化就强制整份重建。

本次核对：2026-11-01，正式版 [v2.6.6](https://github.com/nullmoth/1401/releases/tag/v2.6.6)，commit `f5a9254079601d69a2e165fcd9f659e4f882bab9`。操作前重查版本；旧安装棒不会因升级了 App 自动更新，需要按下述流程重建。

## 1. 工具分工与输入

| 入口 | 能做什么 | 不能混淆的边界 |
|---|---|---|
| **Windows 1401.exe** | 检查目标 PC，生成完整候选 EFI / BIOS 指南，制作安装棒，读取失败日志后诊断和重建 | Build 先写本地输出；Create / Erase 才擦除所选 USB。不是点击 Build 就覆盖 live ESP |
| **Windows Check your EFI** | 检查选定驱动器 / 目录中的已有 EFI，先只读显示问题，再选择是否修复 | 是 1401 策略检查器，不是完整官方 ocvalidate；修复可能应用安装器或 NVIDIA 规则，不能全盘照搬到稳定系统 |
| **Mac 1401.app** | Check my EFI、挂载实际启动 EFI、驱动安装 / 更新 / 恢复、日志与其它工具 | 不提供整套 EFI 生成按钮；Verbose 开关只改 `-v`，Setup 修改现有配置 / 驱动，不等于完整重建 |
| **包内 Python 引擎** | 用目标机器的 Report + ACPI 构建审查目录，显式提供日志与停止行作本地诊断 / 重建 | 不把某台 VM 或本机的扫描冒充另一台目标机；不要发明 GUI 的 Report / SysReport 导入按钮 |

Windows GUI 的完整扫描需在**目标 PC 的 Windows**中进行。没有这条路径时，可评估 [1401 Probe](https://github.com/nullmoth/1401-probe) 取得该机器数据；Linux Probe 的 `report.json` + `acpi/tables` 可经包内 `p1401.probe_report` 转换为标准输入。这是高级 CLI 路径，不是 Windows GUI 导入功能，也不是将 OpenCore SysReport 直接改名成 Report.json。

项目基于固定版本的 OpCore-Simplify / Hardware Sniffer 加自己的规则，不只服务 NVIDIA。社区实验驱动由实际硬件和目标 OS 筛选，按需要选择；不要为了“更全”默认打开实验驱动或 AMD 持久 NVRAM 选项。

## 2. 首次构建：先得到可审查的候选

1. 从[正式发布页](https://github.com/nullmoth/1401/releases)取得 Windows ZIP，保留整个 `1401` 目录，核对提供的 SHA256SUMS / 签名。以管理员运行 `1401.exe`。
2. **Check this PC → Build the Mac setup → Your BIOS steps**。确认扫描识别的是目标 CPU / GPU / 主板 / 存储控制器，并选择目标 macOS；当前界面提供 15 / 26，不能照旧 README 声称 NVIDIA 固定封顶 15。
3. 审阅本次 BIOS 指南和构建结果：目标 OS、SMBIOS、禁用设备、触发的规则、依赖、校验结果。指南基于该机器生成，不将某台机器的 VT-d / IOMMU、DevirtualiseMmio、DVMT 或 SIP 值扩大成所有机器的默认值。
4. 需要制作安装棒时，备份所选 USB 的全部数据，再用 **Create the macOS stick / Erase and create**。这是**擦整个所选 USB**的步骤。App 会核对扫描 / EFI 绑定、盘身份、恢复镜像与写入结果；仍须确认选择的是准备擦除的盘。
5. 按指南调整 BIOS，从该安装棒启动，记录实际停止位置或安装 / 启动结果。安装后的驱动配置与安装器配置分别处理；不要把已安装 NVIDIA 系统的大 BAR 等设置提前抄进安装棒。

双系统机器在候选审阅与启动验收中加入 [Windows 共存检查](windows-coexistence.md)：记录原生直启与经 OC 的设备、身份和启动项基线；不机械关闭 TPM / VT-d、Booter quirk 或重写现有 UUID。

实际工作根是 `%LOCALAPPDATA%\NullMoth\1401`：

| 数据 | 当前实现中的位置 / 含义 |
|---|---|
| 硬件扫描 | `scan-<run_id>\Report.json`、`scan-<run_id>\ACPI\`；`latest-scan.json` 指向本轮扫描 |
| GUI 构建 | `efi\EFI\OC\config.plist`、`efi\EFI\BOOT\BOOTx64.efi` 等；重建会清理旧输出，先将历史副本存到输出目录之外 |
| 本地过程日志 | `diagnostic-reports\` 内按时间和阶段命名的报告；不要只找旧版 `build-log.txt` |
| 机器 / 文件绑定 | 输出根 `.machine-profile.json`，写到 USB 后为 `NullMoth\system-profile.json`；记录扫描、EFI 哈希及待验功能，不是现场启动成功证明 |

profile 的 `build_bound_live_unverified` 状态明确表示启动、显卡、网络仍待验证，USB 仍需映射。**手改已生成 EFI 会破坏哈希绑定，写棒可能拒绝**；不要为通过检查手工伪造 profile。按工具重建，或把已审查的离线手工候选作为明确的备选流程。

身份也须单独核对：通常在同一已有输出根、机器 key 和 SMBIOS 匹配时沿用上次构建身份；旧产物缺少 `.1401-identity-for` 标记时仍可能沿用，不能把自动保留当成机器身份已核实。**全新输出目录不会自动从 live EFI 导入三码 / ROM / 自定义参数**。有保留要求时先记录并检查迁移路径，不使用 `--new-identity` 顺手换身份；工具不能可靠保留时，保留原 EFI，转入备选离线审校，不直接覆盖。

## 3. 启动失败：保留原棒证据，再重建

1. **擦棒之前先存档**原棒的 `opencore-*.txt`、`panic-*.txt`、原 EFI、构建日志与 BIOS 改动；拍下或抄下屏幕最后一行。复制到独立的 `attempt-01` 等目录，不把证据放进即将清空的输出或 USB。
2. 回到 Windows，把原棒插好，使用当前 1401。**Scan for logs and send them** 会先显示本地编号建议；仅需本地诊断时取消发送。初始扫描不上传；失败报告和发送日志是独立流程，详见 §6。
3. 结合目标硬件、原日志和停止行读建议，再执行 Build。构建器会读取插入 USB 的最新 OC 日志、panic 与已保存的停止行，对下一轮应用有依据的修正。若直到写棒时才发现新日志，App 会要求先重建；不要跳过而反复启动同一旧棒。
4. **取消发送不会保存新输入的停止行供下次 GUI 构建。** 要保证停止行参与完全本地重建，用 §4 的显式 CLI；不要为了保存这一行而引导用户上传。
5. 审阅本轮 `policy_changes` / `notices` / `validation`，确认与证据相关、身份及功能保留项未被误改，再按本轮实际输出路径重制棒、重启验证（GUI 构建用 GUI 制棒；独立 CLI 候选按 §4 处理）。每轮保留输入、改动、结果；重建完成不等于已经修好启动。

当前实现的重要分支：

| 证据 | 1401 的诊断 / 重建方向 |
|---|---|
| `EB.MM.AKM` / STOP 0x16 / 可用 slide 很少 | 结合平台和历次日志调整内存交接设置；v2.6.6 对 Intel 给出对应 BIOS 清单，不固定套某个 quirk |
| `EXITBS:START` | 联合 CPU 类型、MAT 与此前尝试判断；成功启动的 OC 日志也会结束于这里，**仅有该行不能证明卡死** |
| `MAT support is 0` | 使用无 MAT 固件的对应内存映射组合，避免互相矛盾的设置 |
| `boot-args - ignored, exists` | 日志未发现内置 macOS 时，可重建为替换安装棒旧参数；发现已有内置 macOS 时保留其参数，并提示受控地重置 NVRAM。用户已确认存在内置系统时，不因日志未枚举到就认定可删除其变量；先核实候选与恢复路径，不无条件 Delete 所有变量或先执行整机重置 |
| 停止行确在 `VoodooGPIO` / `VoodooI2C` 启动 | 可在重建中停用相关 I²C 触控板栈、用 USB 鼠标继续；日志仅列出该 kext 不足以判定它卡住 |
| `element modified after free` / 可疑驱动 | 检查 `USBInjectAll + USBToolBox`、`IntelMausi + IntelSnowMausi` 重复功能组合及实际 panic；不能只按旧单机案例认定一定是 NVMeFix |
| PCI configuration、VMD / AHCI、缺 HfsPlus、panic / 黑屏 | 先读取工具给出的对应编号步骤，再按[分层排障](boot-failure-debug.md)补证，不把一个现象当成唯一根因 |

## 4. 完全本地的高级诊断 / 重建

以下为 **Windows CMD** 示例，在正式包的 `engine\app` 下执行；路径、目标 OS 和停止行替换为真实输入。用目标机扫描数据，输出放入独立审查目录。**build 会清空旧 out，不能把备份、日志、live ESP 或 USB 根目录作为 out**。

```bat
..\python\python.exe -E -s -B -X utf8 -u -m p1401.diagnose --log "C:\1401-review\attempt-01\opencore-boot.txt" --stopped "实际屏幕停止行" --report "C:\1401-input\Report.json"

..\python\python.exe -E -s -B -X utf8 -u -m p1401 build "C:\1401-input\Report.json" "C:\1401-input\ACPI" "C:\1401-rebuild\attempt-02" --macos 25 --boot-log "C:\1401-review\attempt-01\opencore-boot.txt" --stopped-at "实际屏幕停止行" --json > "C:\1401-review\rebuild-result.json" 2> "C:\1401-review\rebuild-stderr.txt"
```

- CLI 的 **`--macos 24` = Sequoia 15，`--macos 25` = Tahoe 26**，不是营销版本号 15 / 26。诊断用 `--stopped`，构建用 `--stopped-at`；多个日志可重复 `--log` / `--boot-log`。
- 这些入口只作本地诊断 / 依赖下载 / 构建，不调用 usbwriter 就不擦棒、不写 live ESP，也不上传报告。`rebuild-result.json` 是示例重定向的文件名，不是工具自动产物；保存在 out 之外。
- `diagnose` 即使读不到日志也可能退出 0；检查 `note`、输入是否读到和 findings，而非把 0 当成无故障。`build` 的成功 / 失败返回 0 / 1，JSON 包含 `policy_changes`、`validation`、`notices`、`out_dir` 等，逐项检查。

### 独立候选如何进入下一次测试

**GUI Create 固定使用工作根的 `efi`，不会自动采用上述 `attempt-02`**，也没有选择任意 CLI 产物的按钮。不能回到 GUI 直接 Create 就声称本次停止行修正已写入。可继续由 GUI 自己 Build / 审阅其真实输入，或在已授权擦测试棒后使用下列受支持 CLI。

下面的列盘 / 写棒是另一组操作，不属于前两条纯本地诊断与构建。无参数列盘通常只枚举，但 Windows 存储服务异常时可能修复 WMI 注册、临时挂载 Windows ESP 后卸载，**不能当作严格只读系统检查**。

```bat
..\python\python.exe -E -s -B -X utf8 -u -m p1401.usbwriter
```

用刚输出的 `Number`、`UniqueId`、`Size`（字节）、`FriendlyName` 填下列占位值。先确认目标是准备擦除的测试 USB，并已备份数据；**write 没有 dry-run、不会再次询问，调用本身就会擦盘**。

```bat
set "M1401_USB_DISK=<Number>"
set "M1401_USB_ID=<UniqueId>"
set "M1401_USB_BYTES=<Size>"
set "M1401_USB_MODEL=<FriendlyName>"
..\python\python.exe -E -s -B -X utf8 -u -m p1401.usbwriter write %M1401_USB_DISK% "C:\1401-rebuild\attempt-02" 25 --profile "C:\1401-input\Report.json" --stick-id "%M1401_USB_ID%" --stick-size "%M1401_USB_BYTES%" --stick-name "%M1401_USB_MODEL%"
```

- 三个位置参数依次是盘号、**构建输出根**、Darwin 主版本；不是输出中的 `EFI` 子目录。保留同一1401包和构建缓存，供写入前读取匹配校验材料。
- `--profile` 指本次扫描的 **Report.json**，不是 `system-profile.json`。写前复核扫描 / EFI 哈希、schema2绑定、文件与校验结果，不能将任意手改EFI或旧profile冒充该候选；4551 降级也仍需如实记录。
- 使用刚读到的设备身份，不能只凭旧盘号；保留非USB / 启动盘 / 系统盘 / 离线 / 只读 / 容量 / 现有系统分区等护栏。`--allow-large`、`--erase-os-partitions` 不作为默认参数。
- 镜像下载 / chunklist校验、EFI / profile写入与回读在流程中逐步完成；后段失败可能已经擦盘，必须记录“未就绪”而非声称原数据仍在。配置含 `nvaccel=1` 时还会准备 NVIDIA 包并可能下载，不能把它称为仅复制一个EFI文件夹。此CLI不自动上传诊断。

参数来源：[构建CLI](https://github.com/nullmoth/1401/blob/v2.6.6/p1401/__main__.py)、[本地诊断](https://github.com/nullmoth/1401/blob/v2.6.6/p1401/diagnose.py)、[列盘 / 写棒](https://github.com/nullmoth/1401/blob/v2.6.6/p1401/usbwriter.py)。本技能没有执行这些上游命令或取得目标机启动验收结果。

## 5. DEBUG、校验与已有 EFI

**三种含义分开：** 当前 1401 构建优先下载同版本 **OpenCore DEBUG** 及 SHA-256，索引没有 DEBUG 才退 RELEASE；不需要先打开某个“1401 App DEBUG”开关。Mac App 的 Verbose 只改内核 `-v`；NVIDIA 驱动的 DEBUG 构建又是另一回事。已有 EFI 只需同版 DEBUG / RELEASE 精确切换时，才使用[手工备选](lifecycle.md#3-已有-efi-的手工-debug-切换备选)。

| 检查结果 | 报告时怎么写 |
|---|---|
| 同版本官方 ocvalidate 实际执行且通过，文件 / 引导文件检查也通过 | 分别记录官方校验与文件检查结果 |
| Windows 4551 阻止 ocvalidate，改用同包 Sample.plist / SampleCustom.plist 的 schema + 文件 / 引导文件检查 | 可记录 1401 降级检查通过；`validation.ocvalidate.ok=None` 表示**官方 ocvalidate 未运行**，不能把整体 `ok=True` 写成它通过 |
| Check your EFI / Check my EFI 无问题 | 记录该检查器所覆盖的 1401 策略检查；不等于完整官方校验或已启动验收 |

Windows **Check your EFI** 的修复需确认并备份 `config.plist.1401-backup-<时间>`；先看每条作用对象，尤其 NVIDIA 安装器 BAR / SIP 规则。Mac **Check my EFI** 只读检查本次启动的 EFI，修复 / Setup 是另外的写入步骤；Mac 备份使用 `config.plist.before-1401-<日期>` 等实际回执路径。不要把 Windows 修复器的安装棒策略套在已工作的驱动配置上。

Windows 端优先用 App 自带构建校验和写棒复验；本技能的 Bash 脚本用于有相应环境时的补充 / 备选检查，不要求为了走首选流程先安装一套 macOS 命令行工具。

## 6. 写入、上传、恢复与备选

- **本地采集与发送分开**：Check this PC / 本地诊断不上传；失败日志和 Send logs 有发送确认。仅获本地构建 / 排障授权时取消发送、保存本地材料。需要提交时先预览脱敏和发送范围；已有明确发送授权则依其执行，不重复询问。收到 report ID 只证明那次提交，不能代替启动或功能验证。
- **Mac 驱动 Setup 有实际改动**：会定位启动 EFI、预览 / 授权、备份后写配置及驱动，可能调整 SIP / SecureBootModel。用户只要重建 EFI 或只读检查时，不顺手安装 NVIDIA、Xe、测试驱动或改权限。MediaTek 驱动优先按 [MtkWireless](mtkwireless.md)核对本轮候选；生成器未覆盖目标方案时选择其支持的重建或离线备选，不伪造 profile。Xe / AMD CPU 等功能仍按各自专题核对。
- **回退先用完整备份与备用引导**。选择器的 Start once without NVIDIA driver / Remove NVIDIA driver 处理驱动范围；前者当前也会单次停用 WEX。它们不是完整 EFI、BIOS 或其它补丁的还原器。
- 没有合适 Windows / 目标输入、1401 不覆盖当前场景，或需精确保留其无法迁移的配置时，使用 [RapidEFI 备选](rapidefi-first-efi.md) / [手工方案](official-docs-method.md)、[生命周期中的手工 DEBUG 与复验](lifecycle.md)。保留用户已选硬件和功能，不因某工具不覆盖就默认替换它们。

## 7. 更新记录如何影响本技能

| 正式版本（北京时间日期） | 本次采用的变化 |
|---|---|
| [2.6.6，2026-11-01](https://github.com/nullmoth/1401/releases/tag/v2.6.6) | EB / 少量 slides 的 Intel BIOS 提示；缺驱动列出实际目录；恢复下载和写棒诊断更明确；自更新及随棒 NullMoth 载荷签名校验 |
| [2.6.5，2026-10-31](https://github.com/nullmoth/1401/releases/tag/v2.6.5) | 按日志修复旧 boot-args 阻挡新构建、I²C 停止与重复功能 kext；不能只重建不验证生效参数 |
| [2.6.2，2026-10-26](https://github.com/nullmoth/1401/releases/tag/v2.6.2) | Windows 先给编号排障步骤；结合硬件、日志和停止行；非英文账户路径及 Mac EFI 问题显示改进 |
| [2.6.0，2026-10-26](https://github.com/nullmoth/1401/releases/tag/v2.6.0) | 构建器与 Mac 检查共用机器条件规则，不将某条修复变成所有平台的默认 |
| [2.5.5，2026-10-26](https://github.com/nullmoth/1401/releases/tag/v2.5.5) | 无 MAT 日志参与重建；不再只依赖手工猜内存映射开关 |
| [2.0.1，2026-10-15](https://github.com/nullmoth/1401/releases/tag/v2.0.1) | NVIDIA 可构建 Tahoe，废除旧文档固定封顶 15 的假设 |

README / HOW-IT-WORKS 仍有旧表述时，以本次固定 tag 的实现及版本记录交叉核对，不能只抄概述。核心证据：[构建 / 身份保留](https://github.com/nullmoth/1401/blob/v2.6.6/p1401/engine.py)、[日志修正规则](https://github.com/nullmoth/1401/blob/v2.6.6/p1401/bootfix.py)、[校验与降级](https://github.com/nullmoth/1401/blob/v2.6.6/p1401/validate.py)、[机器绑定](https://github.com/nullmoth/1401/blob/v2.6.6/p1401/machine_handoff.py)、[Windows 实际流程](https://github.com/nullmoth/1401/blob/v2.6.6/windows/App/MainForm.cs)、[更新记录](https://github.com/nullmoth/1401/blob/v2.6.6/CHANGELOG.md)。
