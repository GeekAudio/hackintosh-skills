---
name: opencore-config-audit
description: 审查、修改与维护黑苹果 OpenCore EFI：config.plist 校验、BIOS/ACPI、启动故障与耗时、kext 与硬件驱动、系统升级、SMBIOS 和 OpenCanopy。用于明确的 OpenCore/黑苹果任务，以及本技能的使用说明；普通 macOS 应用或权限问题仅在证据指向 EFI、驱动或 AMFI 配置时使用。
metadata:
  version: "0.43.1"
  description_en: Audit and maintain hackintosh OpenCore EFI configurations, diagnose boot failures, and manage ACPI, kexts, hardware drivers, macOS upgrades, SMBIOS and OpenCanopy. Use for OpenCore/hackintosh tasks and skill usage questions; general macOS app issues require evidence of an EFI, driver or AMFI connection.
  agent_created: "true"
---

# OpenCore 配置审查与维护

以目标机器的配置、日志和同版本官方文档为依据，完成可回滚、可复验的 EFI 维护。

用户只问本技能怎么用或有哪些能力时，读取 [USAGE.md](USAGE.md)，按问题介绍相应能力；无需执行诊断或修改系统。

## 按任务加载

先选与当前请求有关的专题，按需追踪其中的链接；不要一次读完所有参考文档，也不要把一次故障排查扩成全机整治。

| 当前任务 | 读取的专题 |
|---|---|
| 装不上、黑屏、卡代码、循环重启 | [分层排障](references/boot-failure-debug.md)，先定位固件 / OC / 内核 / 用户态 |
| 配置审查、逐键判断 | [官方文档方法](references/official-docs-method.md)；需取证时读 [日志与调试](references/logs-and-debug.md) |
| 开机慢、停顿 | [启动时间线](references/boot-timeline.md) |
| 工具缺失、版本不对 | [工具链](references/toolchain.md)；只补当前任务需要的工具 |
| 装机前 BIOS、硬件选型 | [BIOS 设置](references/bios-settings.md)、[权威来源](references/ecosystem-sources.md)、[工具索引](references/laobamac-toolkit.md) |
| 尚无 EFI、从零安装 | [基础 EFI](references/rapidefi-first-efi.md)、[生命周期](references/lifecycle.md)；已有可用 EFI 时无需重走装机流程 |
| ACPI / SSDT 检查、编译 | [ACPI 与 SSDT](references/acpi-ssdt.md) |
| 启动项丢失、切换引导盘 | [固件启动项](references/boot-entries.md) |
| 磁盘屏蔽、kext 精简 | [磁盘与 kext](references/disks-and-kexts.md) |
| 更新 OpenCore / kext、切换 DEBUG / RELEASE | [更新判断与兼容性](references/kext-and-oc-update.md) |
| macOS 15 → 26 | [系统升级](references/os-upgrade-15-to-26.md)，核对目标系统与各驱动的支持范围 |
| NVIDIA | [显卡驱动](references/nvidia-driver.md) |
| Intel / MediaTek / 博通无线 | [Intel](references/intel-wifi.md)、[MediaTek](references/mediatek-wifi.md)、[博通](references/broadcom-wifi.md)，只选目标芯片对应项 |
| 有线网卡、接口顺序 | [有线驱动](references/ethernet-drivers.md)、[en0 与接口顺序](references/network-en0-order.md) |
| AirDrop / 接力 | [连续互通排障](references/airdrop-handoff.md) |
| 黑苹果驱动相关的 AMFI / TCC / Gatekeeper | [权限与安全设置](references/amfi-and-tcc.md) |
| 板载声卡、AppleHDA、定制 layout | [AppleALC](references/applealc-custom.md) |
| USB 端口、蓝牙断连、睡眠即醒 | [USB 映射](references/usb-port-mapping.md) |
| 睿频、P/E 核、CPU 显示名 | [Intel 睿频](references/intel-turbo.md)、[小核](references/e-cores.md)、[CPU 名称](references/cpu-name.md)，按症状选择 |
| HiDPI、内存显示 | [HiDPI](references/hidpi.md)、[内存注入](references/memory-injection.md) |
| 换 SMBIOS 机型、三码 | [SMBIOS 与身份信息](references/smbios-and-serials.md) |
| OpenCanopy 外观、图标、音频 | [选择器主题](references/theme-opencanopy.md) |
| 排查已记录的陷阱 | [案例与陷阱](references/pitfalls.md)，先核实案例适用条件 |

[machine-facts.md](references/machine-facts.md) 是参考机器的历史记录。只有确认任务针对该机器时才读取，并重新核实版本、硬件、盘与实时配置；其中的标识符、路径、端口和参数不得作为其他机器的默认值。

## 基线与判断

1. 确认用户目标、目标机器和输入是离线 EFI 副本还是正在使用的 ESP。离线审查直接检查提供的文件。
2. 确认 OpenCore 版本、构建、macOS / Darwin 版本及相关硬件。macOS 可读 `nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version`；不能运行时从配置、二进制和日志交叉核实，区分已知事实与推测。
3. 按需用 [toolcheck.sh](scripts/toolcheck.sh) 检查依赖；缺工具的处理见工具链专题。`ocvalidate` 必须与目标 OpenCore 版本一致，缺失或版本不明时不能声称官方校验通过。
4. 获取同版官方发布包与 `Configuration` 文档。官方说明和驱动作者源码 / README 优先于论坛与本机案例；涉及最新版本、兼容范围或下载地址时重新核实一手来源。
5. 用 `Sample.plist` 做语义对照，结合日志解释偏离。把结论分为「有依据保留 / 建议修改 / 可选清理 / 证据不足」；默认值差异本身不是错误，`ocvalidate` 通过也不代表硬件适配正确。
6. 先分析已有证据；不足以诊断时再考虑 DEBUG 构建、SysReport 或额外日志。卡死、panic、循环重启是现象，不能只凭现象认定根因。

## 修改与复验

- 盘号和挂载点会变化。按卷 / 分区 UUID 与当前设备信息确认目标；不能硬编码 `disk0`，也不能仅凭卷名 `EFI` 决定写入对象。EFI 分区不写入屏蔽清单。
- 改 live 配置前重新读取并计算 sha256，备份原件；用 [oc-edit-safe.sh](scripts/oc-edit-safe.sh) 的 `begin` / `finish` 包装修改。中断后重新检查磁盘文件与备份，不假定文件自动回滚。发现并发写入时重新比对基线。
- 以便于归因的小组改动推进；相互依赖的文件和条目一起修改。移动 kext / SSDT / 驱动时同步配置引用；删多个数组元素时从高索引往低删。
- 完成 `plutil -lint`、同版本 `ocvalidate`、启用条目引用检查及语义 diff。任何一项失败即停止后续同步和成功报告，修复或回滚。
- 校验后同步工作区镜像与版本存档，核对 sha。实际写 ESP 后执行 `sync` → 卸载 → 重挂 → sha 复验；离线副本无需挂卸载。无法完成复验时明确标注未完成。
- 换 OpenCore 版本或构建时同步官方 `OpenCore.efi`、`BOOTx64.efi` 及已使用的同名 Drivers，保留仍需使用的第三方驱动；升级前复核配置迁移与依赖。
- 更新前识别上游、Dortania commit 构建、厂商修改与钉版关系，不能仅凭 tag、版本号、体积或构建年代认定来源或兼容性。按版本分构建的 kext 以 `MinKernel` / `MaxKernel` 避免重叠或遗漏。
- 按用户已表达的偏好执行；未请求调整时保留 `-v`、主题、选择器超时、SMBIOS、ROM 和电脑名。确实影响当前任务且无法推断的选择再询问，不重复索取已有授权。
- 系统升级与换机型分别评估；不要把换机型当成升级的默认步骤。ACPI、CPUFriend、内存注入等依赖按目标配置检查，不能把单机修法套用到所有主板。
- 放宽 SIP / AMFI / SecureBootModel 或写 TCC 前核实当前任务确需此改动、用户授权和恢复路径；普通应用故障不能直接推出应改 EFI 或安全设置。
- 需要重启才生效的修改，在重启后检查实际加载与功能；写入或回读成功只能证明对应步骤完成。

## 脚本索引

脚本在技能目录的 `scripts/` 中。运行前看文件头的参数、依赖和副作用，使用目标路径；不要把下面的索引当成必须全部执行的清单。

| 用途 | 脚本 |
|---|---|
| 工具、官方资料 | [toolcheck.sh](scripts/toolcheck.sh)、[fetch-opencore-docs.sh](scripts/fetch-opencore-docs.sh)、[get-iasl.sh](scripts/get-iasl.sh) |
| 配置验证与安全编辑 | [oc-verify.sh](scripts/oc-verify.sh)、[oc-edit-safe.sh](scripts/oc-edit-safe.sh) |
| 切换构建 | [oc-swap-build.sh](scripts/oc-swap-build.sh) |
| 日志、耗时与停顿窗口 | [grab-logs.sh](scripts/grab-logs.sh)、[boot-timeline.sh](scripts/boot-timeline.sh)、[find-boot-gap.sh](scripts/find-boot-gap.sh) |
| kext、CPU、内存检查 | [kext-inventory.sh](scripts/kext-inventory.sh)、[cpu-freq-probe.sh](scripts/cpu-freq-probe.sh)、[e-cores-check.sh](scripts/e-cores-check.sh)、[cpu-name-check.sh](scripts/cpu-name-check.sh)、[mem-check.sh](scripts/mem-check.sh) |
| Windows BIOS 只读检查 | [bios-audit.ps1](scripts/bios-audit.ps1) |
| 固件启动项 | [oc-nvram-bootentry.sh](scripts/oc-nvram-bootentry.sh)，区分读取与写入命令 |
| 磁盘屏蔽 | [mask-other-disks.sh](scripts/mask-other-disks.sh) |
| 主题检查与资源下载 | [oc-theme-check.sh](scripts/oc-theme-check.sh)、[oc-fetch-iconset.sh](scripts/oc-fetch-iconset.sh) |
| 输出发布前脱敏 | [redact-check.sh](scripts/redact-check.sh) |

支持 dry-run 的写入命令先预演；没有此选项的命令先审阅计划与备份。提权、挂载、NVRAM、系统卷写入均依实际任务和运行环境处理。

## 交付

报告以结果开头，说明改动、保留项及原因、验证结果、尚需重启 / 用户操作的步骤和备份回滚位置。只有实际完成的检查才写「通过」；缺失证据写明限制。序列号、MLB、ROM 等身份信息不得写入公开报告或仓库。
