# EFI 构建、调试与收尾：1401 优先，手工方法备选

从零构建和依据失败日志重建，先读 [1401 首选流程](1401-efi-workflow.md)。已有稳定 EFI 的局部问题先检查当前配置，不因工具优先级更新就强制重新装机或覆盖身份。

```text
1401 检查目标 PC → 构建候选 EFI / BIOS 指南 → 审阅校验 → 制作测试安装棒
       ↑                                              ↓
按原棒日志 + 屏幕停止行重建 ← 保留失败证据 ← 实际启动测试
       ↓ 启动及所需功能验收通过
保留救援入口、备份与最终回执；按用户目标处理日常日志 / 构建
```

## 1. 首选：构建与重建

Windows 1401 的完整入口为 **Check this PC → Build the Mac setup → Your BIOS steps → Create the macOS stick**。先本地构建，制棒步骤才擦除选中 USB。当前实现优先使用 OpenCore DEBUG，启动失败也能回 Windows 读取原棒日志继续重建；不再默认等进 macOS 后才手工换 DEBUG。

每轮记录目标硬件、OS、原 EFI、日志 / 停止行、规则变化、校验类型及实际启动结果。详见[输入、输出与重建闭环](1401-efi-workflow.md#3-启动失败保留原棒证据再重建)。需要完全本地操作、手工提供停止行或诊断器未覆盖的问题，按该专题选择 CLI 或备选分层方法。

## 2. 安装器配置与已安装配置

按本次工具对实际硬件生成的设置和 BIOS 指南操作。NVIDIA 安装器用的小 BAR 与安装驱动后的大 BAR 有不同目的；不把日常驱动配置提前套到安装棒，也不把 Windows EFI 修复器的安装棒策略直接覆盖到稳定系统。

Mac 1401 的 Check my EFI 是已有启动 EFI 的检查入口；驱动 Setup 会修改配置 / 安全设置，须审阅其变更。它不是完整生成器。仅要 EFI 诊断时不附带安装驱动，详见 [1401 的平台分工](1401-efi-workflow.md#1-工具分工与输入)。

## 3. 已有 EFI 的手工 DEBUG 切换（备选）

以下用于非 1401 场景、1401 不覆盖的问题，或用户明确要求精确同版本切换。需要更多 OC 输出 / SysReport 而现有构建不提供时才切换，不是每个任务的固定步骤。

1. 确认**目标 EFI**版本；宿主 NVRAM 只反映本次运行的引导器，不代表离线副本。
2. 备份完整 EFI，取同版本官方 RELEASE / DEBUG 包；同步 `OpenCore.efi`、`BOOTx64.efi` 与目标已使用的官方同名 Drivers，保留第三方驱动。
3. 可用 `scripts/oc-swap-build.sh debug <目标版本> --efi <EFI根目录>`，审阅替换计划；失败按备份恢复并复验，不带失败状态重启。
4. 对配置执行语义 diff、同版 ocvalidate、启用引用检查及 SHA；实际 ESP 写入后 sync、卸载重挂、SHA 复验。
5. 需要 SysReport 时在 DEBUG 下按需一次性开启 `Misc>Debug>SysReport`，取证后关闭。它可能包含设备与身份信息，发布前脱敏。

同版本 DEBUG / RELEASE 文件可能不同，不以大小猜身份；用官方包及哈希确认。对仍需 1401 写棒的产物，不绕过其机器 / 文件绑定直接改包，见 [profile 边界](1401-efi-workflow.md#2-首次构建先得到可审查的候选)。

## 4. 日志采集与判断

优先保留 1401 原棒 OC 日志、panic、实际停止行与本轮构建 / 诊断结果。工具未覆盖时按 [分层排障](boot-failure-debug.md)、[日志与调试](logs-and-debug.md)、[启动时间线](boot-timeline.md)补证；macOS 环境可按需用 `grab-logs.sh` / `boot-timeline.sh` / `find-boot-gap.sh`。

- `EXITBS:START` 是交接标记，成功启动日志也可结束于此，不能独立作为失败证据。
- ACPI 错误 0 命中只表示该采集中未观察到；还需核实启动时间、覆盖、原始表与实际症状。
- Windows 校验器被 4551 阻止时，1401 的 Sample / 文件检查通过也不能称为官方 ocvalidate 已通过。
- 报告 ID、构建成功、profile 绑定和写入回读分别证明各自步骤；它们都不替代启动与功能验收。

## 5. 修补的两条路径

**首选**：1401 支持且有对应证据时，由本轮日志 / 停止行驱动重新构建，审阅 `policy_changes`、`notices`、`validation` 后重新试启动。原始输出会被清理，历史副本放在输出目录之外；不要一边手改已绑定产物，一边让旧 profile 通过写棒检查。

**备选**：RapidEFI / 官方手工方案，或仅需修正稳定 EFI 的局部问题时，读取同版文档，用 `oc-edit-safe.sh begin/finish` 包装实际配置编辑。按可归因的小组改动，依赖条目和文件一起改；有 ACPI / SSDT 需求再对照目标机器原始表。

不把新生成的 SMBIOS / 三码、可选驱动、安全设置自动覆盖到原有稳定配置；原工具无法可靠迁移保留项时，先保留原 EFI，准备离线候选。

## 6. 日常化（按目标与偏好）

问题修复并经启动、显示 / 网络 / 输入等所需功能验收后，保留当前有效 EFI、备用引导、身份与关键自定义设置、最终 SHA 和回滚位置。实验驱动、日志和 `-v` 按用户已有选择处理，不为“恢复默认”清理仍需的组件或诊断证据。

1401 安装棒的日志策略服务于后续诊断，不默认一做完就清空或换 RELEASE。已有 EFI 明确需要切回 RELEASE 时，走 §3 的同版本备选方法；只调整需要的 `Misc>Debug` 项，并复验。不把 App Verbose、OpenCore 构建和 NVIDIA driver DEBUG 混为一谈。

示例（仅手工备选，版本 / 路径须替换为已确认目标）：

```bash
scripts/oc-swap-build.sh release 1.0.8 --efi /path/to/EFI
```

`-v` 未请求调整就保留。若后续继续由 1401 管理，重建可能恢复工具的诊断策略，应核对本轮输出而非假设手工日常值永久保留。

## 7. 系统升级与备用构建方法

macOS 大版本升级单独按 [15 → 26 专题](os-upgrade-15-to-26.md)判断网卡分流、图形载荷、FileVault 与 root patch 的实际需求；不是统一关闭 FileVault 或所有机器都重打补丁。

没有首选工具所需环境 / 输入，或其规则无法满足本次明确保留项时，保留 [RapidEFI 备选流程](rapidefi-first-efi.md)及 [OpenCore 官方方法](official-docs-method.md)。[kext / OC 更新](kext-and-oc-update.md)是另一类维护任务，完整重建不替代每个依赖和功能的判断。
