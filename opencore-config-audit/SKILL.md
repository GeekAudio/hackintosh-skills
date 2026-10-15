---
name: opencore-config-audit
description: 审查、修改与维护黑苹果的 OpenCore（OpenCorePkg）EFI 配置与驱动安装：**BIOS/UEFI 设置审查（官方 9 条清单 + Dortania Intel/AMD + 社区补充的 VMD / Speed Shift；区分「必须关 / 必须开 / 看情况」；含 Windows 只读审查脚本）**、逐键对照官方文档并用官方 ocvalidate 校验 config.plist、巡检 ACPI/SSDT（对照官方 AcpiSamples）、精简注入的 kext、读取 OpenCore 引导日志与内核日志取证、**更新 kext 与 OpenCore（判「该不该更新」：厂商安装器钉没钉 / Dortania build-repo 构建识别）**、**装不上/进不去系统的分层 debug 流程**、**启动耗时/时间线分析（OC 段 / 内核驱动段 / 用户态段三段拆解，定位卡顿与停顿窗口）**、**系统大版本升级（macOS 15 Sequoia → 26 Tahoe：按 Darwin 版本用 MinKernel/MaxKernel 给网卡等 kext 做版本分流、OCLP root patch、机型白名单、升级时序）**、用 /etc/fstab 屏蔽磁盘、调整 boot-args 与调试开关；并含从零生成基础 EFI（Windows 上用 RapidEFI）、NVIDIA 驱动（NullMoth nvidia-macos-driver）、**AMFI 关闭导致 App 拿不到权限（TCC）时的 tcc-helper 注入修法**、Intel 无线网卡驱动（AirportItlwm / itlwm）、**MediaTek 无线网卡（MT7921 / MT7922 / RZ608 —— 蓝牙可用、Wi-Fi 实验性）**、博通网卡（BCM943602CDP / BCM43602，按 Sequoia/Tahoe 分路线）、板载声卡 AppleALC、HiDPI（非 Retina 屏清晰度）、Intel 睿频/CPU 限频（CPU-S 验证 + CPUFriend 修法）、**Intel 混合架构开小核/关小核（E 核：BIOS `Active Efficient Cores` + `ProvideCurrentCpuInfo` + `CpuTopologyRebuild`）**、MacPro 机型内存定制（摆位规则 + 映射表）与 **SMBIOS 机型切换/三码**（★ **先完善 SSDT → 再换机型 → 再重做 CPUFriend**；主板 OEM SSDT `xh_adls3` 与 `AE_NOT_FOUND` 根因、序列号三类判据、ROM、风控纪律）（先搜前人 layout-id、搜不到再按 codec 定制并提 PR）的完整方法；**并含启动界面外观（OpenCanopy 主题）：图标集、PickerAttributes、Flavour 系统、标签/字体/音频/背景、HiDPI，以及「官方图标集不提供哪些可选图标」的权威对照**。当任务涉及 OpenCore、config.plist、EFI/OC、ocvalidate、SSDT/ACPI、boot-args、kext 注入、启动选择器、开机刷屏或日志、**开机慢/启动耗时/启动卡顿/时间线分析**、**BIOS 设置/UEFI 设置/BIOS 审查/CFG Lock/VMD/Intel RST/Above 4G/Re-Size BAR/CSM/Secure Boot/VT-d/Speed Shift/装系统找不到硬盘**、**OpenCore 主题/启动界面外观/选择器/OpenCanopy/图标集 icon pack/PickerAttributes/PickerVariant/Flavour/.icns/启动声音/开机提示音/选择器字体或背景**、**升级系统/升到 macOS 26/Sequoia 升 Tahoe/升级后 Wi-Fi 没了/kext 版本限制 MinKernel MaxKernel/Darwin 版本分流/机型不被新系统支持/-no_compat_check/收不到系统更新**、**启动项消失/BIOS 里看不到 OpenCore/只剩 Windows/LauncherOption**、**启动项丢失的官方修法（OpenShell `bcfg` / `OpenControl` 解锁 NVRAM / `LauncherOption=Full` 自愈 / 从系统里写）、U 盘启动改硬盘启动、`BootKicker`**、屏蔽磁盘/隐藏磁盘、首次生成 EFI、装 NVIDIA 驱动、装 Intel 无线驱动、**装 MediaTek 无线网卡/MT7922/MT7921/RZ608 驱动或蓝牙**、板载声卡/AppleALC/layout-id、博通网卡/BCM943602CDP/OCLP root patch、HiDPI/显示不清晰/缩放、CPU 睿频/限频/卡顿（CPU-S）、内存定制/关于本机内存图/插槽映射、换机型/SMBIOS/三码/序列号/ROM/iMessage 登录时使用。内置「改 ESP 的安全流程」（备份 → 语义 diff → lint → sha 校验 → 镜像/存档 → 卸载重挂复验）。另外，**用户问「这个技能怎么用 / 使用说明 / 有哪些能力 / 能干什么」时也适用**（此时输出技能目录下的 `USAGE.md`，不要输出内部流程）。
description_en: Audit, edit and maintain a hackintosh OpenCore (OpenCorePkg) EFI configuration and its driver installs — audit BIOS/UEFI firmware settings (OpenCore's official checklist plus Dortania's Intel/AMD lists plus community-only items such as VMD and Intel Speed Shift, split into must-disable / must-enable / conditional, with a read-only Windows audit script), verify every config.plist switch against the official documentation and ocvalidate, review ACPI/SSDT tables against the official AcpiSamples, trim injected kexts, read OpenCore boot logs and kernel logs for evidence, decide whether to update kexts/OpenCore (vendor-pinned vs Dortania build-repo builds), layered debugging when macOS won't install or boot, analyse boot time / startup timeline in three independent phases (OpenCore, kernel/driver, userspace) to locate stalls and gaps, plan a major macOS upgrade (15 Sequoia to 26 Tahoe: per-Darwin-version kext gating with MinKernel/MaxKernel for WiFi cards, OCLP root patching, supported SMBIOS whitelist, upgrade ordering), recover a vanished firmware boot entry (Boot####/BootOrder, LauncherOption), recover a missing firmware boot entry the official way (OpenShell bcfg, OpenControl NVRAM unlock, LauncherOption=Full self-heal, or writing from the OS), migrate from USB boot to internal-disk boot, mask disks with /etc/fstab, and follow the NullMoth NVIDIA driver, recover TCC permissions suppressed by disabled AMFI (GeekAudio/tcc-helper), Intel WiFi (AirportItlwm), MediaTek WiFi (MT7921 / MT7922 / RZ608 — Bluetooth works, Wi-Fi experimental), Broadcom WiFi (BCM943602CDP, Sequoia vs Tahoe routes), onboard audio (AppleALC layout-id / codec customisation), HiDPI scaling on non-Retina displays, Intel Turbo Boost / CPU frequency capping (verified with CPU-S, fixed with CPUFriend), Intel hybrid-architecture E-core enable/disable (BIOS Active Efficient Cores, ProvideCurrentCpuInfo, CpuTopologyRebuild), MacPro memory injection (slot layout mapping), SMBIOS model switching and serials/MLB/UUID/ROM (iMessage; board OEM SSDT / AE_NOT_FOUND root cause; order: finish SSDT first, then SMBIOS, then CPUFriend) and first-time base-EFI generation (RapidEFI on Windows) workflows, plus OpenCanopy boot-picker theming (icon sets, PickerAttributes, the flavour system, labels/fonts/audio/background, HiDPI, and the authoritative list of optional icons the official icon sets do NOT ship). Includes a mandatory safe-edit protocol for the EFI system partition. Also applies when the user asks how to use this skill, for its usage guide, or for a list of its capabilities — in that case output the skill's USAGE.md rather than the internal workflow.
version: 0.28.0
agent_created: true
---

# OpenCore 配置审查与维护

## 用途

把「改黑苹果 OpenCore 配置」从「凭经验试」变成「有文档依据、可回滚、可复验」的流程：
先用**官方文档 + 官方 ocvalidate** 判定配置对不对，再用**官方发布包里的样例**判定 SSDT 该不该加，
用**引导期日志**（OpenCore 自己的 `opencore-*.txt` + macOS 内核日志）判定现状，最后按安全流程落盘。

适用于任何 OpenCore 机器；本机（ASUS Z690 / Alder Lake / macOS 26）的具体事实见
`references/machine-facts.md`，可直接引用。

> ★★ **用户问「这个技能怎么用 / 使用说明 / 有哪些能力 / 能干什么」时**：
> **直接输出同目录下的 `USAGE.md`**（那是写给使用者的速查），
> **不要**把本文件的内部流程（阶段编号、铁律、脚本清单）原样倒给用户。
> 同理，用户只是问「能做什么」而没给具体任务时，也走 `USAGE.md`。

## 流程总览（六阶段生命周期）

**完整流程见 `references/lifecycle.md`。** 一句话版：

```
① Windows 上用 RapidEFI 生成基础 EFI → ② 用它安装 macOS → ③ 进系统后换成 DEBUG OpenCore
        → ④ 收集引导期日志（OC 日志 + 内核日志）→ ⑤ 按官方文档逐项修补
        → ⑥ 日常化：换回 RELEASE + 关掉 debug 日志（-v 问客户）
```

| 阶段 | 关键动作 | 工具/文档 |
|---|---|---|
| ① 生成基础 EFI（Windows） | RapidEFI「刷新硬件信息 → 自动配置 → 输出 EFI」 | `references/rapidefi-first-efi.md` |
| ② 安装 macOS | 装机期用安装器安全设置（`ResizeAppleGpuBars=0`、`ResizeGpuBars=-1`、不屏蔽 IONDRVSupport） | `references/lifecycle.md` §2 |
| ③ 换 DEBUG OpenCore | 换构建必须**连官方同名 Drivers 一起换**（两边的驱动内容全不同） | `scripts/oc-swap-build.sh` |
| ④ 收集日志 | OC 引导日志 + 本次开机内核日志 | `scripts/grab-logs.sh` |
| ⑤ 修补 | 逐键对照官方文档 → 一次只改一项 → 报告留「明确不动」清单 | 本文件 阶段 1–8 |
| ⑥ 日常化 | 换回 RELEASE + `Misc>Debug` 回 Sample 默认值 + `-v` 问客户 | `scripts/oc-swap-build.sh release` |

> 阶段③④是这套流程的关键：**没有 DEBUG 构建就拿不到完整日志，拿不到日志就只能靠猜**。

## ★ 铁律（动 ESP 之前必读）

1. **绝不硬编码盘号**。盘号会漂（同一次会话里前后两次 `diskutil list` 的 `disk0`/`disk2` 就互换过）。一律按**卷 UUID**，或现查 ESP：`diskutil list | grep "EFI EFI"`。
2. **改前备份 + 先读 live 再对 diff**。机器上可能有并发会话/脚本也在写 ESP。
3. **改后立刻验 sha**，并同步工作区镜像与版本存档（见 `scripts/oc-edit-safe.sh`）。
4. **写完必须 `sync` → 卸载 → 重新挂载 → 复验 sha**。FAT 有写缓存，卸载重挂才算真落盘。
5. **一次只改一项**（用户明确要求批量时除外，但报告里要逐条列出、逐条给依据）。
6. **移走 kext 必须同时 `Enabled=false` 或删掉对应条目**，否则会因找不到文件而报错。
7. **会话被用户中断（turn aborted）会回滚工作区文件的改动** ⇒ 中断后先复查文件是否还在（报告、脚本、备份）。
8. **查中文/多模式字符串用 Grep 工具（ripgrep），别用 Bash `grep`**。本机 Bash `grep` 对 `\|` 交替和中文给过**假阴性**（"文件里没有" 其实有）。
9. **改 plist 优先 `plutil`**（保持 XML、改动最小）：`plutil -replace '<keypath>' -bool|-integer|-string|-json <v> <file>`；删数组元素 `plutil -remove 'Kernel.Add.15' <file>` 有效，多条时**从高索引往低删**。
10. **每次改完跑官方 `ocvalidate`**，且必须与机器上的 OpenCore **同版本**（否则校验结论无效）。
11. **ESP 分区永不屏蔽**（引导在它上面，且驱动安装 App 要靠它读写 config.plist）。
12. **不要用 `ScanPolicy` 做「显示过滤」** —— 它是安全策略，用它屏蔽会让 OpenCore 看不到其它 OS（例如 Windows 就启动不了）。要少显示用 `HideAuxiliary` / `Misc>Entries`；要 macOS 里不显示用 `/etc/fstab`。
13. **`-v` 要不要开，必须问客户** —— 它是**偏好项**（屏幕有全文 vs 苹果 logo、开机快慢），不是技术默认值；日志完整性两边一样。同理，任何**用户可见行为**的偏好（选择器超时秒数、主题、是否 verbose）先问再改。
14. **换 OpenCore 构建（RELEASE ↔ DEBUG）必须连官方同名 Drivers 一起换** —— 同版本下两边**所有** Drivers 内容都不同（例 1.0.8：`OpenRuntime.efi` 24,576 → 36,864），只换 `OpenCore.efi` 会得到构建混搭的引导器；第三方驱动（如 `NullMothLogo.efi`）保持不动。
15. **一份配置服务两个 macOS 大版本时，按版本分构建的 kext 必须用 `MinKernel`/`MaxKernel` 分流** —— 上限写 `24.99.99`（收口到 Darwin 24），新版写 `MinKernel 25.0.0`；**同一功能绝不能只留一条、也不能两条都不写限制**。升级系统前先按 `references/os-upgrade-15-to-26.md` 过一遍。
16. **升级系统时不许改机型** —— `PlatformInfo` 里任何 `SystemProductName` / `BoardProduct` / 三码都不动。**机型不在新版白名单里就加 boot-arg 绕过**（`-no_compat_check` 解决「能启动」+ `revpatch=sbvmm` 解决「能更新」，两个都要），**不是换机型**。真要换机型 ⇒ 走 **阶段 8** 的「换机型 / 三码」那一节（`references/smbios-and-serials.md`），那是**独立的一次操作**，别塞进升级那一次。
17. **BIOS 层能关的开关，不要在 OpenCore 里用 quirk 兜底** —— 优先级：**BIOS 设置 > OpenCore quirk**。典型：关不掉 CFG Lock 才用 `AppleXcpmCfgLock`（官方原话 *"should be avoided whenever possible"*）；VT-d 则可**开着 + `DisableIoMapper=true`**（官方说这是首选，因为不妨碍其它系统用 VT-d）。★ 官方与 Dortania **都没写**的两项必须自己查：**VMD 必须关**（否则装系统看不到盘）、**Intel Speed Shift 必须开**（否则 `wrmsr(0x770,1)` #GP）。详见 `references/bios-settings.md`。
18. **不要顺手改主题** —— 用户没要求换外观时，`PickerMode` / `PickerVariant` / `PickerAttributes` / `Resources` **一律不动**。要动就先跑 `scripts/oc-theme-check.sh`（**必需图标缺一个 OpenCanopy 直接不启动**），并留一份**能用的**图标集 + 逃生口（`PickerMode=Builtin`）—— **主题换坏了会看不到选择器，最坏进不了系统**。
19. ★★★ **改机型之前，必须先把 SSDT 完善**（**本机是特例**）—— 本机（ASUS Z690）的 BIOS 有一张
`OEM Table ID = xh_adls3` 的 SSDT；**不先处理掉它，换机型必失败**（10-12 连败 6 次，循环重启）。
⇒ 顺序是「**先把 ACPI/SSDT 层做干净（在旧机型下验证通过）→ 再换 SMBIOS → 再重做 CPUFriend 数据**」，
不是「换完再补」。★ **通用化**：换机型前先审一遍 ACPI（有没有厂商 OEM SSDT、有没有 `AE_NOT_FOUND`）。详见 `references/smbios-and-serials.md` §2。
20. ★★★ **换机型必须连三码一起换** —— **「关于本机」的机型名不是 SMBIOS 决定的，是序列号产品码决定的**
（本机实测：机型已改成 `iMac20,1`，序列号还是 `MacPro7,1` 的码 ⇒ 仍显示 `Mac Pro (2019)`；
清 `com.apple.SystemProfiler.plist` 也没用，它会按同一个码推导回旧值）。**只换机型不换码 = 显示名永远停在旧机型。**
⇒ 换码前先用 **`macserial -i <serial>`** 确认产品码对应目标机型。
★ **连带项一次做全**（漏一个就不完整）：**三码 · ACPI/SSDT 前置 · `CPUFriendDataProvider` · 内存注入槽位数 · `ROM`（= 当前 `en0`）· 电脑名/主机名/SMB 名**。清单见 `references/smbios-and-serials.md` §3.1。

21. ★★★ **「更新 kext / OpenCore」之前，先证明它该更新 —— 判「是不是官方件」的最后一步是 grep 厂商自己的安装脚本，不是查上游 tag。**
**上游 tag 查不到 ≠ 来路不明**：`dortania/build-repo` **按 commit 构建**，上游在最后一次 release 之后又有提交时就把**补丁号 +1**
（本机 `Lilu 1.7.3` / `VirtualSMC·SMCProcessor·SMCSuperIO 1.3.9` / `WhateverGreen 1.7.2` / `RestrictEvents 1.1.7` / `NVMeFix 1.1.4` / `BlueToolFixup 2.7.3`
**上游逐个 404**，但全是 Dortania 构建，且被厂商安装器 `nullmoth-setup.sh` 的 `kurl()` 表**固定 + 校验 SHA-256**）
⇒ **把它们「更新」成上游 release = 降级**（本机做过一次，已回滚）。★ 判据四条要一起看（上游 tag / 构建元数据 / 二进制哈希 / **厂商安装器**），
**只有第 4 条能定性**；★ **厂商钉死的东西一律不动**；★ **「统一更新一遍」这个想法本身就是错的**。详见 `references/kext-and-oc-update.md`。

## 工作流

> ★★ **如果现在的处境是「装不上 / 进不去系统」，先跳到 [阶段 3.5](#阶段-35--装不上--进不去系统--分层-debug-流程)** ——
> 那份分层流程就是为这种情况写的；**不要**从头按 0 → 1 → 2 走。

### 阶段 0 · 摸清基线

> ★★ **先看权威性排序** —— `references/ecosystem-sources.md`：
> **官方文档 > 驱动作者 README > 论坛帖子**。任何论坛结论都要回到 `Configuration.pdf` 或驱动源码验证。

```bash
# OpenCore 版本（决定用哪版官方文档/ocvalidate）
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version   # 例：DBG-108-2026-09-27 = 1.0.8 DEBUG
# ESP 位置与 config sha
diskutil list | grep "EFI EFI"
shasum -a 256 /Volumes/EFI/EFI/OC/config.plist
```

同时确认：ESP 是否已挂载（未挂载时 `PlistBuddy` 会打 `File Doesn't Exist, Will Create`，看着像损坏，其实是没挂载）；
`config.plist` 的 mtime 是否与工作区镜像一致。

### 阶段 0.4 · BIOS / UEFI 审查（**装机前先做，比改 config 更早**）

> ★ **更早一步：配机 / 换件之前先看硬件避坑** —— `laobamac/SimpleBuyersGuide`《黑苹果硬件避坑指南》
> （明确列出**不应购买**的 CPU / GPU / 主板芯片组 / SSD / 网卡 / 无线卡等）。索引见 `laobamac-toolkit.md` §3。

BIOS 设置不对，后面所有 config 都是白调。**三份清单要合起来看**：
OpenCore 官方文档（9 条检查清单）+ Dortania（Intel / AMD 分开）+ 社区实战补充（**VMD、Speed Shift 等官方完全没提**）。

- **Windows 侧先跑** `scripts/bios-audit.ps1`（只读）：能在 Windows 里**直接判定**的项直接给结论
  （固件类型 / Secure Boot / TPM / VT-x / 超线程 / XMP / **VMD 与 RST** / 串口 / 内存槽位 …），
  判不了的明确标成「需人工核」，**不会让你误以为查过了**
- **三类清单**见 `references/bios-settings.md` §3：**必须关**（Fast Boot / Secure Boot / CSM / CFG Lock /
  **VMD** / RST / SGX / PTT / 串口）· **必须开**（VT-x·SVM / Above 4G / HT / XD / XHCI Hand-off /
  OS Type=Windows UEFI / AHCI / DVMT≥64MB / **Speed Shift**）· **看情况**（ReBAR / XMP / iGPU / TB / ErP）
- **★ 判据**：**BIOS 层能解决的一律在 BIOS 层解决**，别用 OpenCore quirk 兜底
- **BIOS 里找不到某项** ⇒ 查 §8 的**厂商命名对照表**（ASUS/MSI/Gigabyte/ASRock 叫法不同），
  或用 §5 的隐藏选项路线（UEFITool + IFR-Extractor，官方给的方法）

### 阶段 0.5 · 还没有 EFI？先在 Windows 上生成一份基础 EFI（可选）

见 `references/rapidefi-first-efi.md`：用 **RapidEFI-Tool**（`JeoJay127/RapidEFI-Tool`，免费离线，配置逻辑遵循
OpenCore 官方文档 + Dortania）在 Windows 上「刷新硬件信息 → 自动配置 EFI → 输出 EFI」，
拿到一份**可用的起点**。

- ★ 官方自述的边界：**「生成结果适合作为基础配置，不等于最终免调试配置」**、
  **「先用备用 U 盘测试启动，不要直接覆盖正在稳定使用的 EFI」**
- ★ 生成后**必须**回到本 skill 的阶段 1–2 用官方文档逐键复核；并补齐 USB 端口映射、平台 SSDT、显卡设置、三码
- 它是第三方工具 ⇒ **不要因为"工具说 OK"就跳过 `ocvalidate`**

### 阶段 1 · 取官方文档 + 校验器，并建「键库」

运行 `scripts/fetch-opencore-docs.sh`：下载**与机器同版本**的官方 RELEASE 包，
拿到 `Utilities/ocvalidate/ocvalidate`、`Docs/Configuration.tex`、`Docs/Sample.plist`、`Docs/AcpiSamples/`，
并从 `Configuration.tex` 抽出**全部配置键**的 `Type / Failsafe / Description` 建成 JSON 键库。

细节与判读方法见 `references/official-docs-method.md`。

### 阶段 2 · 逐键对照

1. `ocvalidate <config>` —— schema/类型/必填/顺序问题（**报错必须清零**）。
2. 导出 live config 全量键值；与 `Sample.plist` 做**语义 diff**，得到「与官方 Failsafe 不同的开关」清单。
3. 对每个偏离项查键库里的官方描述，分三类：
   - **有依据的正确偏离**（保留，别去「改回默认」）
   - **与文档明确指引相反**（建议改）
   - **冗余/失效残留**（可选清理）
4. 关注文档里的**成对关系**，别拆散（见 `references/official-docs-method.md` 的配对表）。

### 阶段 3 · 日志取证（先看日志，再下结论）

运行 `scripts/grab-logs.sh`：抓 OpenCore 引导日志 + 本次开机内核日志（需要提权）。
开关含义、判据清单（MAT support、slide、APFS 驱动门槛、ACPI 表清单等）见 `references/logs-and-debug.md`。

> 口诀：**OC 段刷屏 = `Misc>Debug>Target` 的 `0x02` 位；macOS 段刷屏 = boot-args 的 `-v`**。两者独立。

**「开机很慢」要单独走时间线分析** ⇒ `references/boot-timeline.md`：
把启动拆成 **OC 段 / 内核驱动段 / 用户态段**三段分开量（`scripts/boot-timeline.sh` 总览、
`scripts/find-boot-gap.sh` 精查停顿窗口），先定位「卡在哪一段」再决定查哪个日志。
★ 本机 `log show` 的时间过滤整体失效（`--start/--end` 报时钟校正、`--last` 返回整个日志库）⇒ 一律改用**流式过滤**。

### 阶段 3.5 · 装不上 / 进不去系统 —— **分层 debug 流程**

> ★★ **开不了机时先看这个** ⇒ `references/boot-failure-debug.md`。
> **别一上来就改配置** —— 改了就没法复盘（本机踩过）。

- **第一步永远是分层**：① 固件/OpenCore 自身（连选择器都不出现）· ② OC 引导期 · ③ 内核早期（< 1–2 s）· ④ 内核中后期/用户态
- ★★ **先分清「卡死」还是「循环重启」** —— **循环重启 = 引导看门狗超时，「多等一会儿」无效**；
  **卡死才值得等**（本机踩过反例：其实是在回滚 11 GB 系统卷快照，很慢不是死）
- **四条速查**：
  **① 黑屏连 logo 都没有** ⇒ 先等够 2 分钟（`ResizeGpuBars=13` 本来就黑 ~21 s）；选择器不出现 ⇒ 关第三方开机 logo；
  改主题后不启动 ⇒ 必需图标缺一个（`oc-theme-check.sh`）
  **③ `can't perform kext scan: no kext summary`** ⇒ **极早期（< 1 s）缓存层故障，与 GPU/具体 kext 无关**，别往显卡上查；
  `X86PlatformShim` panic ⇒ **先查 BIOS `Speed Shift`**
  **④ 走到很后面才卡** ⇒ 多半是**用户态服务没起来**（本机实例：`AppleUSBHostHIDDevice` 在等 DriverKit dext ⇒ 没键鼠输入）
- **panic 首选证据** = `/Library/Logs/DiagnosticReports/`（带 `keepsyms=1` 能直接给帧名）
- ★★ **救援顺序**：① 回到上一份能用的配置 → ② **U 盘 EFI**（`LauncherOption=Disabled`）→ ③ Recovery 挂内置 EFI 换回去 →
  ④ 二分（**一次只改一项**）→ ⑤ 从别的系统直接改 ESP；★ **别在进不去的时候顺手多改几项**
- ★ **进不去系统时读 OC 日志**：U 盘 EFI / Recovery 启动 → 挂内置 EFI → 读 `opencore-*.txt`

### 阶段 4 · 安全改 config

用 `scripts/oc-edit-safe.sh` 包装每一次修改：备份 → 改 → `plutil -lint` → `ocvalidate` → 算 sha →
同步工作区镜像 + 版本存档 → `sync`/卸载/重挂/复验。改完在报告里逐条记录「改了什么、依据是什么、怎么回滚」。

### 阶段 5 · ACPI / SSDT 巡检

用阶段 1 下到的官方 `Docs/AcpiSamples/` **逐条对照**本机实际设备，判定「还需要补哪个 SSDT」。
对照表、设备存在性检查命令、SSDT 命名规范见 `references/acpi-ssdt.md`。

### 阶段 6 · 磁盘屏蔽（macOS 侧）

要「macOS 里只看到 Macintosh HD」，用 `scripts/mask-other-disks.sh` 写 `/etc/fstab` + `noauto`
（**按卷 UUID**，并显式排除 EFI）。要「选择器里少显示」，用 `Misc>Boot>HideAuxiliary` / `Misc>Entries`，
**不要用 `ScanPolicy`**。详见 `references/disks-and-kexts.md`。

### 阶段 6.5 · 固件启动项（`Boot####`）—— 丢了 / 要加 / 要换引导盘

> 症状：「BIOS 里 OpenCore 项消失、只剩 Windows」「用 U 盘引导一次硬盘项就没了」「想从 U 盘启动改成硬盘启动」
> ⇒ 详见 `references/boot-entries.md`。**三步要点**：

- **根因**：`Misc>Boot>LauncherOption=Full` 时 OpenCore 每次开机维护「自己那条」启动项，
  而它**只按 .efi 路径后缀认项、忽略设备** ⇒ 从 U 盘引导一次就把硬盘那条重指过去 ⇒ 拔盘后被固件清掉
- **定案组合**：**要入口存在且置顶 ⇒ 目标盘 `Full`（自建+自愈）/ 另一份 `Disabled`（不改写 NVRAM）**；
  ★ **两个都 `Disabled` 是错的** —— 那样没人建启动项
- **加回来（官方方法，按可靠性排）**：
  **B** 选择器 → Tools → OpenShell 里 `bcfg boot add 0 FSx:\EFI\OC\OpenCore.efi "OpenCore"`（★ **官方推荐**，纯 U 盘、不要 Windows）·
  **C** `bcfg` 报「写不进去」⇒ 先跑 `\EFI\OC\Tools\OpenControl.efi disable`（并给该工具 `FullNvramAccess=true`）再重试，**之后必须重启** ·
  **A** `LauncherOption=Full` 让 OpenCore 自己建（★ **解决不了「鸡生蛋」**）·
  **D** 从系统里写（macOS `nvram` / Linux `efibootmgr` / Windows EasyUEFI）—— ★★ **前提：该次启动的 `RequestBootVarRouting=false`**，否则「写成功、读回一致」全是假阳性
- **判据**：重启后 **BIOS 启动菜单**里有「OpenCore」且排第一 —— **别拿 `nvram` 回读当成功证据**
- **工具**：`scripts/oc-nvram-bootentry.sh`（**方法 D 的辅助**：`dump` / `backup` / `restore` / `add` / `del`；写操作要提权且需 `RequestBootVarRouting=false`）

### 阶段 7 · kext 精简

对照 `Kernel>Add` 与 `EFI/OC/Kexts/`：找**禁用项**与**孤儿文件**，逐个判断是否真的不用
（换了硬件的驱动、功能已被其它开关覆盖的补丁）。删除前先把原件备份到工作区，再删文件 + 删条目。
判据与「不能删」清单见 `references/disks-and-kexts.md`。

### 阶段 7.5 · 更新 kext 与 OpenCore（**先证明该更新，再动手**）

> 铁律 21 的展开 ⇒ `references/kext-and-oc-update.md`。**黑苹果里「更新」不是好事。**

- ★★★ **先查厂商自己的安装器 / 文档 / `mirror.json`**（如 `nullmoth-setup.sh` 的 `kurl()` 表）——
  **它们才是「官方源」的定义**；厂商钉死的一律不动
- **判「是不是官方件」四条一起看**：上游 tag · 构建元数据（`DTXcode`/`DTSDKName`）· 二进制 sha256 · **厂商安装器**。
  ★ **`DTXcode` 老 ≠ 可疑**、**版本号比官方高 ≠ 可疑**
- **判 DEBUG / RELEASE 用体积对照**（与官方 REL / DBG 比，DEBUG 通常 1.2–1.9×），比找字符串可靠
- **只有这几种情况才该更新**：上游确实发了新 release **且厂商没钉** · 升级系统需要 `MinKernel`/`MaxKernel` 分流 ·
  有正对你症状的 bug fix。★ 「版本号看着旧」「习惯性全更」**都不算理由**
- **OpenCore 本体**：`nvram 4D1FDA02-…:opencore-version`（`DBG-`/`REL-`）→ ★★ **换构建必须连官方同名 Drivers 一起换**（铁律 14）
  → 用 `scripts/oc-swap-build.sh`；升级版本时先 `scripts/fetch-opencore-docs.sh` 取同版官方包（`ocvalidate` 必须同版本）
- **流程**：备份（EFI + kext 目录 + **版本清单**）→ `scripts/kext-inventory.sh` 记录现状 → 判该不该动 →
  ★ **一次只动一类** → 改 → 自检三条（`ocvalidate` / **config 引用 0 缺失** / **只有被改的 kext 变了**）→
  `sync`+卸载重挂复验 → 重启后 `kmutil showloaded` 对照 → **写清回滚路径**
- ★ **坑**：沙箱里 `PATH` 会被搞坏（`stat`/`strings`/`grep` 突然 command not found）⇒ 脚本里 `export PATH=/usr/bin:/bin:/usr/sbin:/sbin`；
  ★ `rsync -a --delete` 会让目标与源**完全一致**（别用于「只该多几个文件」的场景）

### 阶段 8 · 驱动与硬件特性（NVIDIA / Intel 无线 / 博通网卡 / 板载声卡 / HiDPI / Intel 睿频·小核 / **内存定制 / SMBIOS+三码**）

- **NVIDIA 独显** ⇒ `references/nvidia-driver.md`：适用卡范围（Turing+）、两条安装路线（官方包 / 1401 App）、
  ★「kext 装 `/Library/Extensions` 从 AuxKC 加载 ⇒ **不要**再从 `EFI/OC/Kexts` 注入」、
  官方要求的 OpenCore 设置表（`csr-active-config` / boot-args / `ResizeGpuBars` / `Kernel>Block IONDRVSupport` / `SecureBootModel` / BIOS）、
  恢复路径（选择器里的 1401 项、`-nvoff`）、官方 TROUBLESHOOTING 摘要、Send logs 上报纪律
- **★ AMFI ↔ TCC 冲突（App 拿不到麦克风 / 摄像头 / 屏幕录制权限）** ⇒ `references/amfi-and-tcc.md`：
  **现象三连 = 报没权限 + 不弹窗 + 隐私列表里压根没这个 App 的条目**（★ **第三条才是判据**，与「用户点了拒绝」的区别就在这）；
  根因 = boot-args 的 **`amfi=0x80` / `amfi_get_out_of_my_way=0x1`**（AMFI 关）⇒ macOS **不弹窗、也不生成条目**；
  ★★ **别的驱动首选 `AMFIPass.kext`（保留 AMFI）** ⇒ 问题自动消失；**本机不行**（NullMoth 把 AMFI 参数与 AMFIPass **并列列为必需**）
  ⇒ **只能二选一**，走「保驱动 + 注入 TCC 条目」；
  ★★ **解法 = `GeekAudio/tcc-helper`**（<https://github.com/GeekAudio/tcc-helper>，Swift GUI + CLI，MIT，Release `v1.0.0` 有 DMG）
  —— **不再靠人肉列 App 清单**：**自动授权**从系统里反推（`Info.plist` 的 usage description → TCC 服务映射
  + 扫 **launchd job** / **包内子组件** / `/Library/Audio/Plug-Ins/HAL` 等组件目录 / 运行中的 App）；
  ★★ **最容易错的一步：要授权的是「真正申请权限的那个 helper / 子组件」，不一定是主 App**
  （例：Loopback 的麦克风权限属于包内的 `Audio Routing Kit (ARK).app`，给 `Loopback.app` 授权没用）⇒ 可钻进 `.app` 内选子组件；
  ★ 写的是 `access` 表（`auth_value=2` / `auth_reason=4` / `indirect_object_identifier='UNUSED'`），
  **`csreq` magic 必须 `fade0c00`**（带 `designated =>` 前缀会变 `fade0c01`，TCC 不认）；
  ★★ **条目不持久**（系统大版本更新 / `tccutil reset` / 清理工具会抹掉，需重跑）
- **Intel 无线网卡** ⇒ `references/intel-wifi.md`：`AirportItlwm` vs `itlwm` 两种形态、
  ★「Sequoia 与 Tahoe 是**两套 ABI 与产物** ⇒ 双系统共用一个配置时必须用 `MinKernel`/`MaxKernel` 分开」、
  macOS 26 的能力与限制（HE 默认关，需 `itlwm_he=1`；不支持 WPA3-only / 强制 PMF / AWDL / AirDrop / MLO）、
  Intel 蓝牙要另装 `IntelBluetoothFirmware` + `IntelBTPatcher`（+ `BlueToolFixup`）、排错与「换网卡后要清理」清单
- **MediaTek 无线网卡（MT7921 / MT7922 / RZ608）** ⇒ `references/mediatek-wifi.md`：
  ★★★ **macOS 26 原生内置 Apple 自己的 MediaTek 驱动** —— `com.apple.AppleSunriseWLAN.dext` +
  `com.apple.AppleSunriseBluetooth.dext`（**自带固件** `BT_RAM_CODE_MT7922_1_1_hdr.bin` 等），
  `IOPCIMatch` = `0x792214c3`(MT7922 Wi-Fi) / **`0x792a14c3`(MT7922 蓝牙，走 PCIe！)** ⇒ **首选「什么都不装」试一遍**；
  ★ **蓝牙有两种形态**：**新的走 PCIe**（`14c3:792a`，Apple 原生管）、**老的走 USB**（`0x0e8d`，靠第三方 `SimpleMtkBtFw`）—— 先判清；
  ★ Sequoia **没有** Sunrise ⇒ 只能走第三方：**蓝牙可用**（`SimpleMtkBtFw` 有 release）；
  ★★ **Wi-Fi 用 `flxxxxddd/SimpleMtkWlan` 这个 fork**（上游 `laobamac` 的 fork，分支 **`mt7921-fixes`**，
  **有 CI release v1.1.0 / v1.2.0**）—— 它修好了 **MT7921 / RZ608「能 attach 但过不了流量」**，并补上
  **802.11n（HT20/40）+ 802.11ac（VHT80）**；实测 RZ608 在 Sequoia 上 5 GHz VHT80 **30–50 Mbit/s**、开机自动加入；
  ★★★ **三条硬限制（先讲清楚）**：**以太网式接口（`enX`）、没有原生 Wi-Fi 菜单**（连网靠 SimpleMTK 客户端）、
  **❌ AirDrop / Handoff / Continuity（设计上不可能）**、**❌ 802.11ax**；
  ★★ **最常踩的安装坑 = 卡被 `SSDT-Disable_Network_*.aml` 藏了**（`vendor-id` 改 `0xFFFF` ⇒ 驱动永远匹配不上）
  ⇒ `ioreg -l | grep -A40 'pci14c3'` 应看到 `vendor-id = <c3140000>`；
  排错用 `./tools/mtklog.sh > mtk.txt`（**常驻 ring buffer、免 root**）；可选 boot-arg `-novht` / `-noht40`；
  ⇒ **要原生菜单 / AirDrop / Wi-Fi 6 就换卡**（Broadcom / Intel），别硬啃；
  第三方蓝牙两个致命坑：**不要**把 USB 产品名改成 `Bluetooth USB Host Controller`（会让 `bluetoothd` 走 Broadcom 内置路径而 abort）、
  **必须**注入 NVRAM 两条 data（`bluetoothExternalDongleFailed` + `bluetoothInternalControllerInfo`，且 `Add`/`Delete` 都要有）
- **博通网卡（BCM943602CDP / BCM43602）** ⇒ `references/broadcom-wifi.md`：
  ★★ **必须按系统分路线** —— Sequoia(15) 用 `IO80211FamilyLegacy` + 其内部 plugin `AirPortBrcmNIC.kext`（`MaxKernel 24.99.99`），
    Tahoe(26) 用 **独立的 `AirPortBrcmNIC-Tahoe.kext`（`MinKernel 25.0.0`）**（OCLP 2.5.1 的条目到 Sequoia 为止 ⇒ 升 26 后 Wi-Fi 会直接消失）；
  两版都要：`Kernel>Block` 屏蔽 `IOSkywalkFamily` + `Kernel>Add` 顺序 IOSkywalkFamily → IO80211FamilyLegacy → 驱动、
  NVRAM 两条蓝牙 data、USB 端口设 Internal(255)、`built-in=<01>`；
  ★ **打 OCLP root patch 前必须先跑保护脚本**（否则 mtime=epoch 的 NVIDIA kext 会被搬到 `Relocated Extensions`）；
  ★ 判 Wi-Fi 死活**看 `ifconfig en1`，别只看 `system_profiler`**；
    ★★ **打完补丁 / 换完卡必须确认「无线 = `en0`」**（补丁会改变驱动挂载顺序，`en0` 可能换人 ⇒ `ROM` / iMessage / Continuity 静默失效）⇒ `references/network-en0-order.md`
- **有线网卡（Intel I225/I226 · I210/I211/I350 · Realtek RTL8125/8126）** ⇒ `references/ethernet-drivers.md`：
  ★★ **本机板载是 Intel `I225-V`**（原生不认，现用 `AppleIGC.kext`）—— 替代方案：
  `SimpleVGBE`（I225/I226，基于 Linux IGC）、`SimpleEthernet`（**Lilu 插件**，i225/226/210/211）、
  `SimpleRTK5`（RTL8125/8126）；★ **一次只换一套**（多套会互相抢设备）；
  ★★ **换完必须复查 `en0` 归属**（换驱动改挂载顺序 ⇒ `references/network-en0-order.md`）
- **换机型 / 三码** ⇒ `references/smbios-and-serials.md`：
  ★★★ **顺序铁律（本机是特例）：先完善 SSDT/ACPI（在【旧机型】下验证通过）→ 再换 SMBIOS → 再重做 CPUFriend 数据**
  —— 不先处理 BIOS 那张 `xh_adls3`，换机型**必循环重启**（铁律 19）
  - **真正让本机进不去系统的是主板 OEM SSDT**：ASUS Z690 的 BIOS 里 `OEM Table ID = xh_adls3`，
    换机型（board-id 变）触发 macOS **重新解析 ACPI 表** ⇒ 该表解析不过（**`HS06 AE_NOT_FOUND`**）
    ⇒ 电源管理/ACPI 层出问题 ⇒ **循环重启**（不是卡死 ⇒「多等一会儿」无效）
    **修法 = `ACPI > Delete` 删原表（`SSDT` + `OemTableId=xh_adls3`）+ `ACPI > Add` 加 `SSDT-XHADLS3.aml`**
  - ★ **已排除的方向**（别白试）：USB 端口图（T3 图验证可用、USB 日志全程正常）· OCLP 根补丁（restore 回滚后仍失败）·
    机型本身（`MacPro7,1` 是官方支持机型）· 15 端口上限 · NVRAM 残留
  - ★ **USB 图那件事是「文档里的一般机制」**（Dortania/USBToolBox 说 macOS 会按「机型 + 控制器名」附加内置 USB 图），
    **但本机实测不是它** ⇒ 知道有这回事，别一上来就重做整张 USB 图
  - **决策**：功能收益 / 成本 / 风险三条摆清楚 —— **能不换就不换**；被新版系统逼的**优先走 boot-arg 绕过**
  - ★★★ **必须连三码一起换**（否则「关于本机」显示旧机型；见铁律 20）
  - **必须同时重做 `CPUFriendDataProvider`**（`MacPro7,1` 强制 `hwp=on` ⇒ 不重做 = 白换）
  - ★ **内存注入也要跟着改**（**槽位数随机型变**：`MacPro7,1`=12 槽、`iMac20,1`=4 槽）⇒ `memory-injection.md`
  - ★ **电脑名 / 主机名 / SMB 名**是独立设置、**不会自动改**（藏在 `preferences.plist` + `com.apple.smb.server.plist` 两处）⇒ §3.2
  - **救援**：备份整个 EFI + **备一个能用的 U 盘 EFI**；进不去就退回「保留原机型 + `-no_compat_check` + `revpatch=sbvmm`」
  - **三码**：官方 `macserial` 生成、**序列号三类判据**（官网「无效」=可用 / 显示保修=必须换 / 「核实购买日期」=最理想）、
    **`ROM` 必须是 `en0` 真实 MAC**、改 ROM 可用 **base64 等长替换**、
    ★ **换码要克制（脏码 + 频繁换号触发风控）**、换完**先 FaceTime 再信息**、
    ★★ **三码 + ROM 不要写进任何会公开的地方**
- **内存定制（`PlatformInfo > Memory`）** ⇒ `references/memory-injection.md`：
  ★★ **先确认机型**：**槽位数随机型变**（`MacPro7,1`=12 槽 / `iMac20,1`=4 槽）—— 换机型要同步重做；
  ★★ **分两层别混** —— **A 层「系统信息 → 内存」= 全机型通用**（就是标准 SMBIOS Type 17 字段，
  `DeviceLocator` 决定显示的名字、`MaxCapacity` 单位是 **bytes**、键名是 **`SerialNumber`**）；
  **B 层「关于本机」的内存图 = MacPro 机型专有**：那张 12 槽图的摆位由 **`Devices` 数组顺序**决定，
  规则是「**数组第 j 项画到固定第 f(j) 个图位**」，`f = [8,7,10,9,12,11,5,6,3,4,1,2]`（= 真机 Type 17 表顺序）；
  ⇒ **槽号用真机编号（1=F1…12=C1）+ 数组按 f 序排**，才能「图位 v = Slot v = 列表第 v 行」；
  校验用 `scripts/mem-check.sh`（算出每条会被画到哪个图位并判定是否错位）；
  ★ 2 条内存的「至少四条」警告**去不掉**（真机也一样）；4 槽消费主板布局下左图**不画编号**
- **CPU 被压在低频（卡顿/掉帧）⇒ Intel 睿频** ⇒ `references/intel-turbo.md`：
  ★★★ **最佳方法（已定案）**：**注入「本机自己那份 profile，只把 `hwp` 删掉」** —— 四点全中才算最佳：
  **1 段**（`FrequencyVectors` 每段恒 7668 B，**多段必崩**）+ **上限尽可能高**（1 段族天花板 4500）+ **`hwp` 已删除**（最关键）+ **`CPUFloor` 匹配**（1300）；
  ★★ **`hwp` 不在 plist 里** —— 它在**向量二进制内偏移 ~7128 的变量名表**里，`plutil`/`PlistBuddy` 搜不到；
  **禁用 = 删除该项**（不是改名），判「有没有作用」必须**逐字节比向量二进制**（只比 plist 键会判错成 no-op）；
  ★★★ **反面结论：注入任何别的机型的 profile 都会压垮睿频**（实测 `iMac19,1` ⇒ **1.97 GHz**、`MacPro7,1` ⇒ **2.3 GHz**）
  ⇒ **别靠换 profile 抬上限，此路不通**；选型照 §5 五族表（**第一分水岭 = 段数**；**所有上限 5000 的 profile 都是 3–5 段** ⇒ 与「结构兼容」不可兼得）；
  ★ **验证用 CPU-S**（看「当前睿频状态」是否「未睿频」+ 频率列表有没有覆盖高倍频），配合 Intel Power Gadget 与 `cpu-freq-probe.sh` 交叉印证（基线单线程 4.28 / 8 线程 4.29–4.35 GHz，**八核一致无振荡比数值更重要**）；
  先排除热降频（`xcpm.cpu_thermal_level=0`）与 XCPM 上限（`hard_plimit_max=49`）；
  ★★ **改完必须重启**（`kern.boottime` 早于改动时间 = 没重启 ⇒ 内存里跑的仍是旧 profile）—— 这是「修了没好」的头号原因；
  修法 = **CPUFriend + CPUFriendDataProvider**（顺序 Lilu → CPUFriend → DataProvider；`ExecutablePath` 必须空；解回必须 7668 B/段）；
  ★ 硬前提：**BIOS `Intel Speed Shift Technology` 必须 Enabled**（否则 `xcpm_hwp_enable` #GP panic）；
  ★ **别混淆**：BIOS 的 HWP 要**开**、macOS 侧**刻意不走 HWP**（传统 XCPM）—— 这个组合是正确解，别去「修」
- **小核（E 核）开 / 关 ⇒ Intel 混合架构** ⇒ `references/e-cores.md`：
  ★ **「关小核」与「开小核」是两种取舍** —— 关掉最稳（macOS 调度 E 核本就是雷区，且**关掉几乎零代价**）；
  开着多 4 核 4 线程，但**必须连 `CpuTopologyRebuild` 一起上**；
  **关 = BIOS `Active Efficient Cores = 0`（配置一行不用改）**；
  **开 = BIOS `= All` + `ProvideCurrentCpuInfo=true`（官方 README 明写必需）+ `CpuTopologyRebuild.kext`（紧跟 Lilu）**；
  ★ **判据**：`hw.nperflevels` **1 = E 核没暴露 / 2 = P+E 都识别**（`perflevel1.physicalcpu` 才是 E 核数）；
  ★★ **别误判「CPU 缺核」** —— `CPUID.1FH` 报 20 逻辑处理器而 macOS 只报 8 核 16 线程是**正常**；
  ★★ **boot-arg 语法分版本**：v2.x 是 **`ctrsmt=off` / `ctrsmt=full`**（等号），v1.x 的 `-ctrsmt` 在 v2.x 上**不生效**；
  `-ctrfixcnt` **必须**配 `AppleMCEReporterDisabler.kext`，否则起不来；
  ★★ **官方已知问题：开小核 + `-v` 可能随机启动失败**（排查时注意，别误判成配置坏）；
  自检用 `scripts/e-cores-check.sh`
- **「关于本机」显示的 CPU 名不对 ⇒ CPU 改名** ⇒ `references/cpu-name.md`：
  ★ **先定性：纯外观问题**（频率 / 核数 / L2L3 全对，只是**显示名按机型映射**）⇒ 不在意就别改；
  **改法 = RestrictEvents 三件套**：**`revpatch=cpuname`（boot-args）+ `revcpu=1`（boot-args）+ `revcpuname=<名>`（NVRAM）**；
  ★★ **最大的坑：NVRAM 的 `rev*` 优先级低于 boot-args**（官方原话 *"but have lower priority"*）
  ⇒ 只在 NVRAM 写 `cpuname` **无效**，**boot-args 的 `revpatch=` 里必须也含 `cpuname`**（本机实测踩过）；
  ★ **`revcpuname` 含空格 ⇒ 只能放 NVRAM**（boot-args 按空格分词会截断）；**Intel 上 `revcpu` 默认 0 ⇒ 必须显式 `revcpu=1`**；
  ★ `revcpuname` 上限 48 字符（建议 ≤20）；★ `NVRAM>Delete` 也要列这些键；
  ★ **`ProcessorType` 必须配核数**（`PlatformInfo>Generic>ProcessorType`，8 核以上 = **`0x0F01`**=3841 / 1-6 核 = `0x0601`）；
  ★ **两条别走错的路**：**`Cpuid1Data` 改不了名字**（品牌串在 CPUID `0x80000002-4`，它改的是 leaf 1）；
  **别去改 `AppleSystemInfo.strings`**（密封系统卷，RestrictEvents 就是替代它）；自检用 `scripts/cpu-name-check.sh`
- **显示不清晰 ⇒ HiDPI** ⇒ `references/hidpi.md`：用 `xzhih/one-key-hidpi` 给非 Retina 屏模拟 HiDPI
  （写 `/Library/Displays/Contents/Resources/Overrides/`，**不动密封系统卷**；两个模式：只注入 `scale-resolutions` /
  连同 patched EDID 一起注入，**先试前者**）；
  ★★ **本机驱动是 NullMoth 的 NVIDIA 驱动，自述未完善** —— 而 HiDPI 正踩在「显示模式/缩放/元数据」这条它出过真 bug 的路径上
  （本机显示器尺寸报错就是这个根因）⇒ **开之前先记录基线、一次只改一项、先确认 `.hidpi-disable` 与 Recovery 恢复路径**；
  ★ 别和**引导期** HiDPI（`UEFI>Output>UIScale`）搞混，两者独立
- **板载声卡（AppleALC）** ⇒ `references/applealc-custom.md`：
  ★★★ **macOS 26 前置（不先做这步，后面全白试）**：Apple 在 DP2 删了 `AppleHDA.kext`
  ⇒ **`AppleALC` 是在 `AppleHDA` 旁边工作的，前者不在，板载音频就整个没了**；
  ★★ **判据**：**HDMI / DisplayPort 数字音频仍然可用**（走别的 kext）⇒「只有 HDMI 有声音、板载没声音」正是这个现象；
  ★★ **主参考 `perez987/AppleHDA-gone-on-macOS-26-Tahoe`** —— 方案按省事排序：
  **① USB 声卡**（很多原生支持，完全不动系统）· **② KDK + `MyKextInstaller`（Mirone，首选，更新频繁、能在 App 里直接下 `AppleHDA.kext`）**
  / `SimpleLoader`（laobamac，已显过时）—— 要求 **KDK** + **`AppleALC ≥ 1.9.5`** + **`csr-active-config = 03080000`**，
  `AppleHDA.kext` 取自 KDK（Sequoia 那份也能用），装完**重启**，用 `kextstat | grep AppleHDA` 验证 ·
  **③ OCLP root patch**（团队仍在早期，暂不适合普通用户）· ④ `SimpleVoodooHDA`（**音质有损**，兜底）；
  ★★ **代价：系统一升级 / 重装就全丢，每次都要重装**（与「OpenCore 注入」类方案根本不同）；
  ★ `SimpleHDA`（此前推荐）**已降为备选**（作者不允许二次开发 + 只有 alpha + 有已知问题）
  ★ **先搜同型号前人经验（推荐路线）**：查官方 `Supported-codecs` 表 → 搜 `repo:acidanthera/AppleALC <codec>` 的 issue/PR →
    搜「主板型号 + layout-id」→ 逐个试 `alcid=N`；
  搜不到才走定制路线：官方 6 步算法、`Resources/<CODEC>/Info.plist` 字段、
  ★ **自定义 layout 只能用 11–99**（1–10 保留给 Mirone/Toleda）、每条都要写机型与作者注释、
  官方 CI 的构建命令、`layout-id` 注入与 `-alcdbg` 调试、**官方禁止把 HDAS 改名成 HDEF**、PR 要带 codec dump + 机型 + 结果
- **启动界面外观（OpenCanopy 主题）** ⇒ `references/theme-opencanopy.md`：
  ★ **必需图标缺一个 OpenCanopy 就不启动** —— 先跑 `scripts/oc-theme-check.sh` 再谈美化；
  `PickerMode` 必须 `External` + `UEFI>Drivers` 里启用 `OpenCanopy.efi`；
  `PickerVariant` 写**相对路径、用反斜杠**（`Acidanthera\GoldenGate`）；
  ★★ **`OCUI: … Not Found` 多数是正常的**（官方图标集**不提供**那批可选图标，**别去「补」**）；
  ★ **不要顺手改主题** —— 用户没要求换外观时 `PickerMode`/`PickerVariant`/`PickerAttributes`/`Resources` 一律不动；
  ★ 改 `Resources/` 也是改 ESP ⇒ 走安全流程；**换坏了会看不到选择器**（留一份能用的图标集 + 逃生口 `PickerMode=Builtin`）

> 装第三方驱动一定会动到安全边界（`SecureBootModel=Disabled`、放宽 SIP、AMFI 参数）——
> **在报告里明确写出来**，并给出「不装时如何恢复」。

### 阶段 9 · 系统大版本升级（如 macOS 15 → 26）⇒ `references/os-upgrade-15-to-26.md`

**升级不是「点一下软件更新」**，它有三件必然发生的事：**Wi-Fi 消失、OCLP root patch 全丢、第三方 kext 可能被搬走**。

- ★★ **核心动作 = 给按版本分构建的 kext 加 `MinKernel`/`MaxKernel`**：
  旧版条目上限钉 `24.99.99`，新版条目写 `MinKernel 25.0.0`
  （博通 `AirPortBrcmNIC-Tahoe.kext`、Intel `AirportItlwm-Tahoe` 都是这么分的；plugin 的 `BundlePath` 要写全路径）
- ★★ **硬约束：升级时不许改机型**（`PlatformInfo` 的 `SystemProductName` / `BoardProduct` / 三码全不动）。
  **机型不在新版白名单里 ⇒ 加 boot-arg 绕过**：`-no_compat_check`（能启动）+ `revpatch=sbvmm`（能收到更新），**两个都要**。
  **绝不**用上游 `nullmoth-setup.sh --update prepare --pkg`（它会自动改机型 + board-id，与约束正面冲突）
- **升级前**：关 FileVault → 跑 OCLP 前置保护脚本（防 1970 时间戳的 NVIDIA kext 被搬走）→ 备份整个 EFI
- **升级后**：补 kext 条目 → 重打 OCLP root patch → 重启验证（`uname -r` / `kmutil showloaded` / **`ifconfig en1`** / `awdl0`）
- **机型白名单**（Tahoe 的 Intel 只剩 `iMac20,1` `iMac20,2` `MacPro7,1` `MacBookPro16,x`，**`iMacPro1,1` 被剔除**）——
  白名单**只用来判断「需不需要绕过」**，不是「要不要换机型」的依据
- **macOS 26 新增环境坑**：EFI 挂载必须提权（`/Volumes` 变 `root:wheel`）、FAT 改 FSKit 实现、在 EFI 上删文件会留 `.Trashes` 需 `diskutil repairVolume`

## 常见坑速查

完整清单见 `references/pitfalls.md`，最容易踩的几条：

| 坑 | 正确做法 |
|---|---|
| 用 `ScanPolicy` 屏蔽启动项 → Windows 启动不了 | 保持 `ScanPolicy=0`；少显示用 `HideAuxiliary`/`Misc>Entries` |
| 按 `disk0/disk1` 认盘 | 按卷 UUID；ESP 现查 |
| 写完 ESP 没卸载重挂 | `sync` → unmount → mount → 复验 sha |
| `NVRAM>Delete` 当数组写 `Delete.0.<GUID>` | 它是 **dict（GUID→数组）**，键路径写 `NVRAM.Delete.<GUID>` |
| 只把键写进 `NVRAM>Add` | 文档规则：**Add 的键必须同时在 `Delete` 里**才会被写入 |
| 用 Bash `grep` 查中文 | 用 Grep 工具（ripgrep），Bash grep 给过假阴性 |
| 用 `log show --start/--end` 查启动日志 | 开机时钟校正会让它返回**整个日志库** ⇒ 改用**流式过滤**（`boot-timeline.md`） |
| 装系统时「找不到任何驱动器」 | 九成是 **BIOS 里 VMD / Intel RST 没关**（macOS 无 VMD 驱动）⇒ `bios-settings.md` |
| 关不掉 CFG Lock 就用 quirk 兜底 | 官方说 `AppleXcpmCfgLock` *"should be avoided whenever possible"* ⇒ 先用 UEFITool 找隐藏选项 |
| 以为 Dortania 清单就是全部 | 它**没写 VMD、没写 Speed Shift** ⇒ 三份清单（官方 / Dortania / 社区）要合起来看 |
| 改了 SSDT 文件名就以为表身份变了 | 表身份**由内容解析决定，不由文件名**；改名安全，只要同步改 `ACPI>Add>Path` |
| 以为 `ocvalidate` 过了就万事大吉 | 它只查 schema；取值是否符合文档要人工逐键比对 |
| **用 U 盘引导一次后，硬盘的 OpenCore 启动项从 BIOS 里消失、只剩 Windows** | `Misc>Boot>LauncherOption=Full` 会按「文件路径后缀」认自己的项（**不看盘**）⇒ 从别的盘引导就把它重指过去；拔盘后固件清理掉 ⇒ **两个 ESP 都改 `Disabled`** + 留 `\EFI\BOOT\BOOTx64.efi` 兜底（`boot-entries.md`） |
| macOS 只看到 8 核 16 线程（`hw.nperflevels=1`），但 CPU 是 12 核 20 线程 | **不是缺核、也不是驱动没加载** ⇒ E 核没喂给 macOS（BIOS 关着，或 `ProvideCurrentCpuInfo=false`）⇒ 见 `e-cores.md`；**关小核是刻意选择时别去「修」** |
| 抄来的 `-ctrsmt` boot-arg 加了没反应 | v1.x 的 `-ctrsmt` 在 **v2.x 上不生效** ⇒ 改写成 **`ctrsmt=full`**（先看 `CFBundleVersion`）⇒ `e-cores.md` §4.2 |
| 开小核后开机偶发失败（尤其带 `-v`） | `CpuTopologyRebuild` 官方已知问题：**与 verbose 启动冲突** ⇒ 排查期先关小核或临时去掉 `-v`（`e-cores.md` §4.3） |
| 想靠「换成 5000 上限的机型 profile」抬睿频 | **实测反而暴跌到 ~1.97 GHz** ⇒ 所有上限 5000 的 profile 都是 **3–5 段**，多段必崩 ⇒ **只注入本机自己的 profile（删 `hwp`）**（`intel-turbo.md` §0.1 / §5） |
| 改完 CPUFriendDataProvider 没效果 / 更慢了 | 先看 **`kern.boottime`** 是否早于改动 ⇒ **没重启**（内存里还是旧 profile）⇒ `intel-turbo.md` §7 |
| 加了 `revcpuname` 但 CPU 名还是没变 | **`rev*` 的 NVRAM 变量优先级低于 boot-args** ⇒ **boot-args 的 `revpatch=` 里也必须含 `cpuname`**；Intel 上还要显式 `revcpu=1`（`cpu-name.md` §3） |
| 语音/摄像头 App「没权限」，**不弹窗、隐私列表里也没这个 App** | 不是 App 坏了 ⇒ **boot-args 关了 AMFI**（`amfi=0x80` / `amfi_get_out_of_my_way=0x1`）导致 macOS **不弹窗也不生成条目** ⇒ 别的驱动可改用 `AMFIPass.kext`；本机不行 ⇒ 用 `GeekAudio/tcc-helper` 注入（`amfi-and-tcc.md`） |
| 授权了主 App 却还是没权限 | ★★ **要授权的是「真正申请权限的那个 helper / 子组件」** —— 例：Loopback 的麦克风权限属于包内 `Audio Routing Kit (ARK).app`，**给 `Loopback.app` 授权没用**（`amfi-and-tcc.md` §4.2） |
| 手写 TCC 条目后 App 还是没权限 | 多半是 **`csreq` 错了**（magic 变 `fade0c01`）或**没重启 `tccd`** ⇒ 必须由 `designated =>` **之后**的文本生成（`amfi-and-tcc.md` §4.5） |
| 以为「黑苹果就该关 AMFI」 | **关 AMFI 是有代价的**（TCC 弹窗全失效 + 安全性下降）⇒ 先查驱动 README 是否**明确要求**；能用 `AMFIPass` 就别关（`amfi-and-tcc.md` §2） |
| 发现 EFI 里 kext 版本号比上游 release **高一位**、上游还查不到该 tag | **不是来路不明** —— `dortania/build-repo` **按 commit 构建**、补丁号自己 +1，且常被厂商安装器钉死 ⇒ **换成上游 release = 降级**（`kext-and-oc-update.md` §0） |
| 想「把所有 kext 统一更新一遍」 | ★ **这个想法本身就是错的** —— 先 grep **厂商自己的安装器 / `mirror.json`**；**厂商钉死的一律不动**（铁律 21） |
| 只换 `OpenCore.efi` 就算升级了 OpenCore | 同版本下 **RELEASE / DEBUG 的所有 Drivers 内容都不同** ⇒ **必须连官方同名 Drivers 一起换**（铁律 14，用 `oc-swap-build.sh`） |
| 开不了机，想「多等一会儿」 | **先分清卡死 vs 循环重启** —— **循环重启 = 引导看门狗超时，「多等」无效**（本机换机型 6 次都是这个形态）；卡死才值得等（`boot-failure-debug.md` §0.1） |
| 看到 `can't perform kext scan: no kext summary` 就去查显卡驱动 | ★ **这是极早期（< 1 s）缓存层故障，与 GPU / 具体某个 kext 无关** ⇒ 别查错方向（`boot-failure-debug.md` §4） |
| 进不去系统时「顺手多改几项」 | ★ 那会让下次复盘**彻底失去线索** ⇒ **一次只改一项**，并先回到「上一份能用的配置」（`boot-failure-debug.md` §7） |
| 想靠改 `Cpuid1Data` 改 CPU 显示名 | **改不了** —— 品牌串在 CPUID `0x80000002-4`，`Cpuid1Data` 只动 leaf 1 ⇒ 用 `revcpuname`（`cpu-name.md` §7） |

## 资源

- `scripts/fetch-opencore-docs.sh` —— 下载同版官方包、抽取校验器与文档、建键库
- `scripts/oc-verify.sh` —— 一键校验（ocvalidate + 引用的文件是否存在 + sha 对照）
- `scripts/oc-swap-build.sh` —— RELEASE ↔ DEBUG 换构建（连官方同名 Drivers 一起换，保留第三方驱动，自动备份/校验/落盘）
- `scripts/oc-edit-safe.sh` —— 安全改 config 的包装（备份/改/lint/sha/镜像/存档/重挂复验）
- `scripts/grab-logs.sh` —— 抓 OC 引导日志与本次开机内核日志（提权）
- `scripts/boot-timeline.sh` —— 启动耗时总览（NVRM 属性 + dmesg + launchd 时间线 + 内核日志，超时保护）
- `scripts/find-boot-gap.sh` —— 启动停顿窗口精查（从 launchd.log 找最大空档 → **流式过滤** log show）
- `scripts/mask-other-disks.sh` —— 按 UUID 写 fstab 屏蔽非 macOS 卷（显式排除 EFI）
- `scripts/cpu-freq-probe.sh` —— CPU 实际频率探针（内联汇编，防编译器折叠）—— 验证睿频 / 对比机型
- `scripts/e-cores-check.sh` —— **小核（E 核）体检**：拓扑（`hw.nperflevels` / `perflevel1` / `CPUID`）+ 频率 + `CpuTopologyRebuild` 加载状态 + 判读；`--topo` / `--freq` 可单跑
- `scripts/kext-inventory.sh` —— **kext 清单体检**：版本 / `DTXcode` / `DTSDKName` / 大小 / sha256（含包内 PlugIns）+ **config 引用核对（0 缺失）** + OpenCore 本体版本；`--tsv` 便于 diff、`--save` 存档改动前证据
- `scripts/cpu-name-check.sh` —— **CPU 显示名体检**：显示名 vs `machdep.cpu.brand_string` 对照 · `rev*` 参数（boot-args + NVRAM）· `RestrictEvents` 加载 · config 里的 `ProcessorType` / `revcpuname` / `NVRAM>Delete` 核对 + 判读
- `scripts/mem-check.sh` —— 校验内存注入摆位（数组序号 → 预测图位，判定是否与「系统信息」错位）
- `scripts/oc-nvram-bootentry.sh` —— **从系统里读/写固件启动项**（官方方法 D 的辅助）：`dump`（解析出名字/设备路径）· `backup` / `restore` · `add`（含 `--dry-run`）· `del`。★ **写操作要提权**；★★ **且只在 `RequestBootVarRouting=false` 时才有意义**（否则是假阳性）
- `scripts/redact-check.sh` —— **发布前脱敏自检（只读）**：扫三码 / MAC / 密钥 / 卷 UUID / 邮箱 / 内网 IP
- `scripts/oc-theme-check.sh` —— **Resources 树合规检查**（必需图标 / 实际像素尺寸 / 标签 / 字体 / 音频）
- `scripts/oc-fetch-iconset.sh` —— 从官方 OcBinaryData 取图标集 / 字体 / 标签 / 音频
- `scripts/bios-audit.ps1` —— **Windows 侧 BIOS 审查（只读）**：判定固件类型/Secure Boot/TPM/VT-x/HT/XMP/**VMD·RST**/串口/内存槽位，判不了的明确标注
- `references/official-docs-method.md` —— 文档取用方法、逐键判定法、成对关系表
- `references/logs-and-debug.md` —— `Target`/`DisplayLevel` 位定义、日志判据、刷屏归因
- `references/boot-entries.md` —— **固件启动项（`Boot####` / `BootOrder`）与 `Misc>Boot>LauncherOption`**：★ **「用 U 盘引导后启动项消失」的根因**、四档取值、取证命令、**ASUS 的 `Boot0000` 坑**；★★ **§7 官方修法（`bcfg` / `OpenControl` / `LauncherOption=Full` / 从系统里写 + `BootKicker`）**、**§8 从 U 盘启动改成硬盘启动**
- `references/boot-timeline.md` —— **启动耗时/时间线分析**：三段拆解、流式过滤、停顿窗口定位、耗时来源与处置
- `references/acpi-ssdt.md` —— 官方 AcpiSamples 逐条适用条件、设备存在性检查、命名规范
- `references/bios-settings.md` —— **BIOS/UEFI 审查**：官方 9 条 + Dortania（Intel/AMD）+ 社区补充（**VMD**/Speed Shift）、**必须关/必须开/看情况**三类、CFG Lock 专题、**厂商命名对照表**、Windows 审查脚本用法
- `references/disks-and-kexts.md` —— 磁盘屏蔽与 kext 精简的判据与「不能删」清单
- `references/nvidia-driver.md` —— NullMoth NVIDIA 驱动：适用范围、安装、必需 OC 设置、恢复、故障对照
- `references/amfi-and-tcc.md` —— **AMFI ↔ TCC 冲突（App 拿不到权限）**：★ 现象三连（**第三条 = 隐私列表里没有条目**才是判据）· 根因（`amfi=0x80`）· **别的机器首选 `AMFIPass`**（本机不行，只能二选一）· ★★ **解法 `GeekAudio/tcc-helper`**（GUI + CLI、**自动授权从系统反推**、109 个服务、任意目标含裸可执行文件）· **要授权的是真正申请的 helper 而不是主 App** · `access` 表字段与 `csreq` magic `fade0c00` · **五个工程坑** · 诊断三分类 · 不持久
- `references/intel-wifi.md` —— Intel 无线网卡驱动（AirportItlwm / itlwm）：版本线、注入、蓝牙配套、排错
- `references/mediatek-wifi.md` —— MediaTek 无线网卡（MT7921 / MT7922 / RZ608）：★★★ **macOS 26 原生 Sunrise 驱动**（`AppleSunriseWLAN/Bluetooth` dext + 自带固件 + PCIe 蓝牙 `14c3:792a`）、★★ **第三方 Wi-Fi 用 `flxxxxddd/SimpleMtkWlan` fork（有 release，802.11n/ac 可用）** · **三条硬限制（无原生菜单 / 无 AirDrop / 无 HE）** · **SSDT 藏卡坑** · `mtklog.sh` 排错 · 三条路线决策树、芯片认型、第三方蓝牙 NVRAM 两坑
- `references/applealc-custom.md` —— 板载声卡（AppleALC）：★★★ **macOS 26 的 `AppleHDA` 恢复（`perez987` 指南：USB 声卡 / **KDK + `MyKextInstaller`** / OCLP / VoodooHDA 方案对照 + 要求与验证）**、先搜前人经验、按 codec 定制、本地构建、测试、提 PR
- `references/broadcom-wifi.md` —— 博通网卡（BCM43602/BCM20703）：**按 Sequoia/Tahoe 分路线**、OCLP root patch、验证判据
- `references/ethernet-drivers.md` —— **有线网卡第三方驱动**（Intel I225/I226 · I210/I211/I350 · Realtek RTL8125/8126）：方案对照、装法、判据
- `references/ecosystem-sources.md` —— ★★ **黑苹果生态：权威来源与工具索引**：Acidanthera / Dortania 官方仓库 · **corpnewt 工具链**（ProperTree / GenSMBIOS / SSDTTime / USBMap / gibMacOS / MountEFI）· `USBToolBox` · `blacktop/ipsw-diffs` · 各硬件驱动作者 · 中文资源（远景 / 黑果小兵 / OC-Little 翻译）· ★ **「做什么事信谁」对照表**
- `references/laobamac-toolkit.md` —— **laobamac 工具与补丁索引（48 仓库全表）**：驱动 · 装机（`SimpleKaruzi`/`PVE-OpenCore`）· ★ **硬件避坑（`SimpleBuyersGuide`）** · 维护工具（`SimpleLoader`）· macOS 26 启动台 · 参考补丁（`OC-little-zh`/`non-metal-frameworks`）· AMD 平台 · fork 说明 · ★ **哪些已存档**
- `references/network-en0-order.md` —— **`en0` 归属与网络接口顺序（通用）**：谁依赖 `en0`（ROM / iMessage / Continuity）、**修补 Wi-Fi 后必须确认无线是 `en0`**、怎么钉住、连带影响、判据纪律
- `references/hidpi.md` —— 非 Retina 屏开 HiDPI（one-key-hidpi）：写入位置、两个模式、恢复路径、**与 NVIDIA 驱动的风险**
- `references/intel-turbo.md` —— Intel 睿频/CPU 限频：★★★ **最佳方法定案（注入「删掉 `hwp` 的本机 profile」四点判据）** · **`hwp` 的真实位置与删法** · **76 份 profile 五族选型表** · CPU-S 验证 · **改完必须重启** · CPUFriend 修法 · BIOS 硬前提
- `references/e-cores.md` —— **开小核 / 关小核（Intel 混合架构 P/E 核）**：★ 两种取舍 · BIOS `Active Efficient Cores`（四家厂商命名）· `ProvideCurrentCpuInfo` · **`CpuTopologyRebuild` 四取值（`ctrsmt=off` / `ctrsmt=full` / `-ctrfixcnt`）** · 判据 `hw.nperflevels` · **官方已知 `-v` 冲突** · 回滚- `references/kext-and-oc-update.md` —— **更新 kext 与 OpenCore**：★★★ **上游 tag 查不到 ≠ 来路不明**（Dortania `build-repo` 按 commit 构建、补丁号 +1）· **判「官方件」四条判据**（只有「厂商安装器钉没钉」能定性）· **DEBUG/RELEASE 用体积对照**· 该更新 / 不该更新的表 · **OC 本体更新（连 Drivers 一起换）** · 安全流程 9 步 · 坑- `references/boot-failure-debug.md` —— **装不上 / 进不去系统的分层 debug 流程**：★ **四段分层**（固件/OC 自身 · OC 引导期 · 内核早期 · 内核中后期）· ★★ **卡死 vs 循环重启** · 各段速查表（含 `no kext summary` / `X86PlatformShim` / `decmpfs` / `element modified after free` 等**本机已定性的失败族**）· 装机期专属（VMD 找不到盘等）· **救援顺序 6 步** · ACPI（`xh_adls3`）· **取证清单**


- `references/cpu-name.md` —— **CPU 显示名（改名）**：★ 纯外观 · RestrictEvents 三件套（`revpatch=cpuname` / `revcpu=1` / `revcpuname`）· ★★ **NVRAM 优先级低于 boot-args** · `revcpuname` 只能放 NVRAM · `ProcessorType` 与核数配对 · **`Cpuid1Data` / `AppleSystemInfo.strings` 两条死路** · 排错
- `references/smbios-and-serials.md` —— **换机型 + 三码**：★★★ **主板 OEM SSDT（`xh_adls3`）与 ACPI 根因**、**顺序铁律（先完善 SSDT）**、检查清单、决策依据、序列号判据、ROM、切换脚本三态、操作教训
- `references/memory-injection.md` —— MacPro 机型内存定制：**12 槽映射表**、**摆位规则 f**、A 层通用字段、踩坑
- `references/rapidefi-first-efi.md` —— 从零开始：在 Windows 上用 RapidEFI 生成基础 EFI，及之后必须做的收尾
- `references/lifecycle.md` —— **六阶段全流程**：Win 生成 → 安装 → 换 DEBUG → 收日志 → 修补 → 日常化
- `references/os-upgrade-15-to-26.md` —— **系统大版本升级**（15 Sequoia → 26 Tahoe）：**`MinKernel`/`MaxKernel` 版本分流**、逐部件清单、升级时序、机型白名单、macOS 26 新坑、OCLP vs BCMC
- `references/pitfalls.md` —— 全部踩过的坑
- `references/theme-opencanopy.md` —— **选择器主题（OpenCanopy）**：开关总表、资源目录、**图标清单（必需/可选/官方不提供）**、Flavour 规则、标签/字体/音频/背景、排错
- `references/machine-facts.md` —— 本机（Z690/Alder Lake/macOS 26）的具体事实
- `USAGE.md` —— **给使用者看的速查**（用户问「怎么用/使用说明/能干什么」时输出这个）
