---
name: opencore-config-audit
description: 审查、修改与维护黑苹果 OpenCore（OpenCorePkg）EFI：BIOS/UEFI 设置审查、config.plist 逐键对照官方文档并用 ocvalidate 校验、ACPI/SSDT 巡检、kext 精简与更新判断、引导与内核日志取证、装不上或进不去系统的分层 debug、启动耗时分析、系统大版本升级（15→26 的版本分流）、磁盘屏蔽、从零生成基础 EFI、换机型与三码。硬件侧覆盖 NVIDIA 独显、Intel / MediaTek / 博通无线网卡、有线网卡、板载声卡 AppleALC、HiDPI、Intel 睿频与小核、内存定制、AMFI/TCC 权限修复、Gatekeeper、AirDrop / 接力、OpenCanopy 主题。触发场景：开机卡 EB、卡 ExitBootServices、卡代码、循环重启、黑屏、启动项丢失、选择器不显示、只有 HDMI 有声音、板载声卡没声音、AppleHDA 装不回来、layout-id 填多少、麦克风没权限、隐私列表里没有这个软件、双击 App 打不开、AirDrop 用不了、隔空投送找不到设备、接力不工作、Wi-Fi 连不上、网卡驱动、蓝牙不可用、睿频上不去、CPU 被限频、小核要不要关、关于本机 CPU 名不对、内存显示不对、显示不清晰、改机型、三码、序列号、ROM、iMessage 登录不了、iasl 怎么装、找不到工具、缺工具、ocvalidate 版本不对、macserial 在哪、没有 brew。内置「改 ESP 的安全流程」（备份 → 语义 diff → lint → sha 校验 → 镜像/存档 → 卸载重挂复验）。用户问「这个技能怎么用 / 使用说明 / 有哪些能力 / 能干什么」时也适用（此时输出技能目录下的 USAGE.md，不要输出内部流程）。
description_en: Audit, edit and maintain a hackintosh OpenCore (OpenCorePkg) EFI configuration — BIOS/UEFI firmware settings, per-key verification of config.plist against the official docs plus ocvalidate, ACPI/SSDT inspection, kext trimming and update decisions, boot and kernel log forensics, layered debug for installs that fail or never reach the desktop, boot-time analysis, major OS upgrades (15 → 26 with MinKernel/MaxKernel routing), disk masking, generating a first EFI from Windows, SMBIOS model change and serials. Hardware coverage — NVIDIA GPUs, Intel / MediaTek / Broadcom WiFi, Ethernet, onboard audio via AppleALC, HiDPI, Intel Turbo and E-cores, memory injection, AMFI/TCC permission repair, Gatekeeper, AirDrop / Handoff, OpenCanopy themes. Triggers — stuck at EB, stuck at ExitBootServices, boot loop, black screen, lost boot entry, picker not showing, audio only over HDMI, no onboard audio, AppleHDA missing on macOS 26, which layout-id to use, app has no microphone permission, app missing from Privacy list, app won't open on double-click, AirDrop not working, Handoff not working, WiFi not connecting, network driver, Bluetooth unavailable, Turbo stuck low, CPU frequency capped, should I disable E-cores, wrong CPU name in About This Mac, wrong memory display, blurry display, change SMBIOS model, serials, ROM, iMessage sign-in fails, how to install iasl, missing tools, ocvalidate version mismatch. Includes the safe ESP editing flow (backup → semantic diff → lint → sha check → mirror/archive → remount and re-verify). Also applies when the user asks how to use this skill, what it can do, or for usage instructions — in that case output USAGE.md from the skill directory instead of internal workflow details.
version: 0.38.0
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

### 阶段 0.1 · 工具链自检（**先确认工具在不在，再谈排查**）

跑 `scripts/toolcheck.sh`：一条命令给出「① 系统自带 · ② OpenCore 官方包自带 · ③ 需自备」三层工具的现状
（工具 / 状态 / 路径 / 版本）。

- **必需项缺失 = 流程跑不完整** —— 尤其 `ocvalidate` 没有就**不能下结论**（先 `fetch-opencore-docs.sh`）
- **按需项缺失不必全补** —— 缺 `iasl` 只影响「改 / 编译 SSDT」，**只加官方已编译的 `.aml` 不需要它**；
  缺 `gfxutil` 可以抄现成 `DeviceProperties` 路径
- ★★ **比「没装」更容易错的是「装错版本」**：`ocvalidate` 必须与机器上的 OpenCore 同版
  （`nvram 4D1FDA02-…:opencore-version`）—— **校验器版本不对，结论无效**
- ★ 官方包里**没有** `iasl` / `gfxutil`；**`acpidump` 在 macOS 上本来就没有**
  （取表走 `Misc>Debug>SysReport` / `ACPIe` / Hackintool）
- 获取方式（含**无 brew / 无 port 时怎么装**）、版本对齐、**缺失降级矩阵** ⇒ `references/toolchain.md`

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
对照表、设备存在性检查命令、SSDT 命名规范见 `references/acpi-ssdt.md`；
★ 要**改 / 编译** SSDT ⇒ 同文件 **§6 编译与验证**（`iasl` 三个动作 · 反编译报错是正常的 · 四项验证 · 报错对照）。
★ 只加官方 `Binaries/*.aml` 的话**不需要 `iasl`** —— 别为一个用不上的步骤去装工具。

> ★★★ **热补丁样例库主参考：`5T33Z0/OC-Little-Translated`**（★745，**仍在更新**）——
> 起于 `daliansky/OC-little` 的英译，**已远超原作**（新增第 7–20 章 + 完整附录 A–Z）；
> **只用 ACPI 热补丁、不做 DSDT patch**（与本 skill 的判据同源）。
> 覆盖：ACPI 基础/**删表/改名** · 加/禁设备 · CPU 电源 · 显卡（含 **GPU-BAR**）· USB（含 **用 ACPI 做端口映射**）·
> 睡眠唤醒 · 笔记本 · CMOS · **MMIO 白名单 / AppleVTD** · 雷雳 · **boot-args / Quirks 逐项解释** · kext 顺序 ·
> **OCLP on Wintel** · 多系统 · 虚拟机 · **自己做 ALC Layout-ID** · 排错（SysReport / **Preboot** / spindump）。
> ⇒ **按需求找哪一章的索引表**（含**本机 Z690 的落点**）见 `references/acpi-ssdt.md` §0。
> ★ 诚实提醒：英译是 AI + 人工校对、**译者不懂中文** ⇒ 关键结论仍回官方文档核。

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

### 阶段 8 · 驱动与硬件特性

> 本节**只做路由**：症状 → 读哪个文件。命令、参数值、根因分析都在 references 里，别在这里重复。
> ★ 标「★★★」的是**顺序前提**（不先做，后面的都白试）。

- **NVIDIA 独显** ⇒ `references/nvidia-driver.md`：适用卡范围（Turing+）、官方包 / 1401 App 两条路线、
  ★「kext 装 `/Library/Extensions` 从 AuxKC 加载 ⇒ **不要**再从 `EFI/OC/Kexts` 注入」、
  必需 OC 设置表、恢复路径、Send logs 上报纪律
- **AMFI ↔ TCC（App 拿不到麦克风 / 摄像头 / 屏幕录制）** ⇒ `references/amfi-and-tcc.md`：
  ★★ 判据 = 报没权限 + 不弹窗 + **隐私列表里压根没这个 App 的条目**（第三条才是判据）；
  根因 = boot-args `amfi=0x80`；★ 别的机器首选 `AMFIPass.kext`，**本机不行**（NullMoth 要求关 AMFI）
  ⇒ 只能二选一、走注入 TCC 条目；★★ 解法 `GeekAudio/tcc-helper`；
  **最容易错：要授权的是真正申请权限的 helper / 子组件，不是主 App**；
  ★ 与 Gatekeeper 是两回事（双击打不开 = Gatekeeper，见该文档附录）
- **Intel 无线网卡** ⇒ `references/intel-wifi.md`：`AirportItlwm` vs `itlwm` 两种形态、
  ★「Sequoia 与 Tahoe 是两套 ABI 与产物 ⇒ 双系统共用配置必须用 `MinKernel`/`MaxKernel` 分开」、
  macOS 26 能力限制（**无 AWDL ⇒ 无 AirDrop**）、Intel 蓝牙要另装三件套、换卡后清理清单
- **MediaTek 无线（MT7921 / MT7922 / RZ608 / RZ717）** ⇒ `references/mediatek-wifi.md`：
  ★★★ **macOS 26 原生内置 Apple 的 MediaTek 驱动**（`AppleSunriseWLAN/Bluetooth.dext`）⇒ **首选「什么都不装」试一遍**；
  ★★ **26.7.1「自带」什么要按芯片分**（别信「升级就自带全部固件」）：蓝牙 MT7922/7923 已内置 ·
  MT7932/RZ717 的 Wi-Fi 已内置 · **MT7922/RZ616 的 Wi-Fi 仍缺**；
  ★★ 原生路线要动手 ⇒ 用 `GeekAudio/mediatek-sunrise-hackintosh`（含 `AppleSunrise.kext` —— **内核态 HAL，必需项**）；
  ★★★ **三条硬限制**：以太网式接口无原生菜单 · **❌ AirDrop / Handoff / Continuity（设计上不可能）** · ❌ 802.11ax
  ⇒ **要原生菜单 / AirDrop / Wi-Fi 6 就换卡，别硬啃**；
  ★★ **最常踩的坑 = 卡被 `SSDT-Disable_Network_*.aml` 藏了**（`vendor-id=0xFFFF` ⇒ 驱动永远匹配不上）
- **博通网卡（BCM943602CDP / BCM43602）** ⇒ `references/broadcom-wifi.md`：
  ★★ **必须按系统分路线** —— Sequoia 用 `IO80211FamilyLegacy`（`MaxKernel 24.99.99`）、
  Tahoe 用独立的 `AirPortBrcmNIC-Tahoe.kext`（`MinKernel 25.0.0`）⇒ **升 26 后不换会直接没 Wi-Fi**；
  ★ **打 OCLP root patch 前必须先跑保护脚本**（否则 mtime=epoch 的 NVIDIA kext 会被搬走）；
  ★ 判死活**看 `ifconfig en1`，别只看 `system_profiler`**；
  ★★ 打完补丁必须确认「无线 = `en0`」⇒ `references/network-en0-order.md`
- **AirDrop / 接力 / Handoff / 连续互通（隔空投送用不了）** ⇒ `references/airdrop-handoff.md`：
  ★★★ **只取决于一件事：无线是否跑在 Broadcom 原生 `IO80211Family` 栈上、从而产生 `awdl0`**；
  `itlwm.kext` ⇒ 永远没有 `awdl0` ⇒ 必然不可用（**驱动设计层面的限制，改 config 救不回来**）；
  ★★★ **`ROM` / `en0` 归属 / 机型 / 序列号 / `SystemUUID` 与 AirDrop 无关** —— 那是 iServices（iMessage）的要求
- **有线网卡（I225/I226 · I210/I211/I350 · RTL8125/8126）** ⇒ `references/ethernet-drivers.md`：
  ★★ 本机板载 `I225-V` 原生不认（现用 `AppleIGC`）—— 替代 `SimpleVGBE` / `SimpleEthernet` / `SimpleRTK5`；
  ★ **一次只换一套**（多套会互相抢设备）；★★ 换完必须复查 `en0` 归属
- **换机型 / 三码** ⇒ `references/smbios-and-serials.md`：
  ★★★ **顺序铁律：先完善 SSDT/ACPI（在【旧机型】下验证通过）→ 再换 SMBIOS → 再重做 CPUFriend**
  —— 不先处理 ASUS 的 `xh_adls3` OEM SSDT，换机型**必循环重启**（不是卡死 ⇒「多等一会儿」无效）；
  ★★★ **必须连三码一起换**（否则「关于本机」显示旧机型）+ **必须重做 `CPUFriendDataProvider`**
  （`MacPro7,1` 强制 `hwp=on`）+ **内存注入跟着改**（槽位数随机型变）；
  ★ 电脑名 / 主机名 / SMB 名是独立设置、不会自动改；
  ★ 救援：备份整个 EFI + **备一个能用的 U 盘 EFI**；★★ 三码 + ROM **不要写进任何会公开的地方**
- **内存定制（`PlatformInfo > Memory`）** ⇒ `references/memory-injection.md`：
  ★★ 先确认机型（**槽位数随机型变**：`MacPro7,1`=12 / `iMac20,1`=4）；
  ★★ **分两层别混** ——「系统信息 → 内存」全机型通用（标准 Type 17 字段）；
  「关于本机」那张 12 槽图是 **MacPro 专有**，摆位由 `Devices` 数组顺序决定
  ⇒ 校验用 `scripts/mem-check.sh`
- **CPU 被压在低频（卡顿 / 掉帧）⇒ Intel 睿频** ⇒ `references/intel-turbo.md`：
  ★★★ **最佳方法（已定案）：注入「本机自己那份 profile，只把 `hwp` 删掉」** —— 四点判据见文档；
  ★★ **`hwp` 不在 plist 里**（在向量二进制内的变量名表），禁用 = **删除该项**，判有没有作用必须逐字节比向量；
  ★★★ **反面结论：注入任何别的机型的 profile 都会压垮睿频**（实测 1.97 / 2.3 GHz）⇒ **别靠换 profile 抬上限**；
  ★★ **改完必须重启**（`kern.boottime` 早于改动时间 = 没重启 ⇒ 跑的仍是旧 profile），这是「修了没好」的头号原因；
  ★ 硬前提：BIOS `Intel Speed Shift Technology` 必须 Enabled；验证用 CPU-S + `scripts/cpu-freq-probe.sh`
- **小核（E 核）开 / 关 ⇒ Intel 混合架构** ⇒ `references/e-cores.md`：
  ★ **关掉最稳、几乎零代价**（macOS 调度 E 核本就是雷区）；
  开 = BIOS `All` + `ProvideCurrentCpuInfo=true` + `CpuTopologyRebuild`；
  ★ **判据 `hw.nperflevels`**（1 = E 核没暴露 / 2 = 都识别）；
  ★★ `CPUID.1FH` 报 20 逻辑处理器而 macOS 只报 8 核 16 线程是**正常**；
  ★★ **boot-arg 语法分版本**（v2.x `ctrsmt=off`；v1.x 的 `-ctrsmt` 在 v2.x 不生效）；自检 `scripts/e-cores-check.sh`
- **「关于本机」CPU 名不对 ⇒ CPU 改名** ⇒ `references/cpu-name.md`：
  ★ **先定性：纯外观问题**，不在意就别改；改法 = RestrictEvents 三件套（`revpatch=cpuname` + `revcpu=1` + `revcpuname`）；
  ★★ **最大的坑：NVRAM 的 `rev*` 优先级低于 boot-args** ⇒ 只在 NVRAM 写 `cpuname` **无效**；
  ★ `revcpuname` 含空格只能放 NVRAM；`ProcessorType` 必须配核数（8 核以上 = `0x0F01`）；
  自检 `scripts/cpu-name-check.sh`
- **显示不清晰 ⇒ HiDPI** ⇒ `references/hidpi.md`：用 `xzhih/one-key-hidpi`（**不动密封系统卷**），
  两个模式**先试只注入 `scale-resolutions`**；★ 别和**引导期** HiDPI（`UEFI>Output>UIScale`）搞混
- **板载声卡（AppleALC）** ⇒ `references/applealc-custom.md`：
  ★★★ **macOS 26 前置（不先做这步，后面全白试）**：Apple 在 DP2 删了 `AppleHDA.kext`
  ⇒ 判据「**只有 HDMI 有声、板载没声**」；★★ **26 的 KDK 里根本没有 AppleHDA** ⇒ 直接回退 `KDK 15.8.1 build 24H32`；
  ★★ **代价：系统一升级 / 重装就全丢**；
  ★★ **定制前先问用户能不能提供 Windows 侧取数**（能提供就直接进流程，不能才讲硬约束并给
  HDAU / `HDAudDev.dll` 两条取数路线）；
  ★★ **AppleHDA 三条实测根因**（PathMap 同组多路径只留最后一条 / 插孔型 Mic 引脚建不出设备 /
  插孔检测可能整体是死的）；★ **不用耳朵验证**（播放中读 `0xF07`/`0xF06`）
- **启动界面外观（OpenCanopy）** ⇒ `references/theme-opencanopy.md`：
  ★ **必需图标缺一个就不启动** —— 先跑 `scripts/oc-theme-check.sh` 再谈美化；
  ★★ **`OCUI: … Not Found` 多数是正常的**（官方图标集不提供那批可选图标，别去「补」）；
  ★ **不要顺手改主题**（用户没要求换外观时一律不动）；**换坏了会看不到选择器**（留 `PickerMode=Builtin` 逃生口）

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

> 脚本统一 `set -euo pipefail`（**失败即停**，不会把半成品当成品继续跑）。
> ★ 会改 ESP / 系统卷的三个（`oc-edit-safe.sh` · `oc-swap-build.sh` · `mask-other-disks.sh`）先 dry-run 再执行。
> ★★ **开工先跑 `scripts/toolcheck.sh`**：缺什么、缺了怎么降级，见 `references/toolchain.md`。

- `scripts/toolcheck.sh` —— **工具链自检**：三层来源（系统自带 / 官方包自带 / 需自备）逐个查「状态 · 路径 · 版本」，`--oc-dir` 顺带核对官方包、`--strict` 缺必需项即非零、`--json` 机器可读
- `scripts/get-iasl.sh` —— **取 iasl**（ACPICA 源码 → 编译 → 装 `~/bin` → 打出版本与 sha256）；★ 官方 release 里的预编译 `iasl` 是 **Linux ELF**，macOS 用不了
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
- `references/toolchain.md` —— **工具链（装什么 / 从哪来 / 缺了怎么办）**：★ **三层来源**（① 系统自带 · ② **OpenCore 官方包 `Utilities/`** · ③ 需自备）· **每个工具的用途与陷阱**（`PlistBuddy` 不在 `PATH` · `macserial` 是目录 · **`ACPIe` 只有 `Returned offset` 能当结论**（三种输出退出码全是 0））· ★★ **`iasl` 三条获取路线（含 ACPICA 官方编译命令）** · **`acpidump` 在 macOS 上没有** · ★★ **`EFI/OC/Tools/` 那批 UEFI 工具**（`Sample.plist` 只注册 3 条、且全 `Enabled=false` ⇒ 要用得自己加条目） · **无 brew / 无 port 时怎么装** · **版本对齐纪律** · **缺失降级矩阵**
- `references/official-docs-method.md` —— 文档取用方法、逐键判定法、成对关系表
- `references/logs-and-debug.md` —— `Target`/`DisplayLevel` 位定义、日志判据、刷屏归因
- `references/boot-entries.md` —— **固件启动项（`Boot####` / `BootOrder`）与 `Misc>Boot>LauncherOption`**：★ **「用 U 盘引导后启动项消失」的根因**、四档取值、取证命令、**ASUS 的 `Boot0000` 坑**；★★ **§7 官方修法（`bcfg` / `OpenControl` / `LauncherOption=Full` / 从系统里写 + `BootKicker`）**、**§8 从 U 盘启动改成硬盘启动**
- `references/boot-timeline.md` —— **启动耗时/时间线分析**：三段拆解、流式过滤、停顿窗口定位、耗时来源与处置
- `references/acpi-ssdt.md` —— ACPI/SSDT 巡检：官方 AcpiSamples 逐条适用条件 · 设备存在性检查 · 命名规范 · ★ **§6 编译与验证（`iasl` 三个动作 / 反编译报错是正常的 / 四项验证 / 报错对照表）** · ★★ **`5T33Z0/OC-Little-Translated` 按需求索引表**（含本机落点）· **官方/Dortania 没有的那些**（`SSDT-ALL` 合并表 · **用 ACPI 做 USB 端口映射** · `SSDT-I225V` · `SSDT-PMCR` · `ACPIDebug` · `Fixing_Preboot`）
- `references/bios-settings.md` —— **BIOS/UEFI 审查**：官方 9 条 + Dortania（Intel/AMD）+ 社区补充（**VMD**/Speed Shift）、**必须关/必须开/看情况**三类、CFG Lock 专题、**厂商命名对照表**、Windows 审查脚本用法
- `references/disks-and-kexts.md` —— 磁盘屏蔽与 kext 精简的判据与「不能删」清单
- `references/nvidia-driver.md` —— NullMoth NVIDIA 驱动：适用范围、安装、必需 OC 设置、恢复、故障对照
- `references/amfi-and-tcc.md` —— **AMFI ↔ TCC 冲突（App 拿不到权限）**：★ 现象三连（**第三条 = 隐私列表里没有条目**才是判据）· 根因（`amfi=0x80`）· **别的机器首选 `AMFIPass`**（本机不行，只能二选一）· ★★ **解法 `GeekAudio/tcc-helper`**（GUI + CLI、**自动授权从系统反推**、109 个服务、任意目标含裸可执行文件）· **要授权的是真正申请的 helper 而不是主 App** · `access` 表字段与 `csreq` magic `fade0c00` · **五个工程坑** · 诊断三分类 · 不持久 · **附录：Gatekeeper /「任何来源」/「无法验证开发者」（`sudo spctl --global-disable`，`--master-disable` 在 macOS 15+ 已过时；与 TCC 是两回事）**
- `references/intel-wifi.md` —— Intel 无线网卡驱动（AirportItlwm / itlwm）：版本线、注入、蓝牙配套、排错
- `references/mediatek-wifi.md` —— MediaTek 无线网卡（MT7921 / MT7922 / RZ608 / RZ717）：★★★ **macOS 26 原生 Sunrise 驱动**（`AppleSunriseWLAN/Bluetooth` dext + 自带固件 + PCIe 蓝牙 `14c3:792a`）· ★★★ **原生路线用 `GeekAudio/mediatek-sunrise-hackintosh`（MT7922 Sunrise Pack，含固件/HAL kext/免编译 device-id 伪装）** · **26.7.1 按芯片分的固件现状** · **`AppleSunrise.kext` = 内核态 HAL（必需）** · **日志判读表 / boot-args 表** · ★★ **第三方 Wi-Fi 用 `flxxxxddd/SimpleMtkWlan` fork（有 release，802.11n/ac 可用）** · **三条硬限制（无原生菜单 / 无 AirDrop / 无 HE）** · **SSDT 藏卡坑** · `mtklog.sh` 排错 · 三条路线决策树、芯片认型、第三方蓝牙 NVRAM 两坑
- `references/applealc-custom.md` —— 板载声卡（AppleALC）：★★★ **macOS 26 的 `AppleHDA` 恢复（`perez987` 指南：USB 声卡 / **KDK + `MyKextInstaller`** / OCLP / VoodooHDA 方案对照 + 要求与验证）** · ★★ **定制走 `5T33Z0/AppleALC-Guides`**（14 章流程 · 17 个现成 dump · **`alc-verb` 运行时调音** · `MuteGPIO` 表 · **精简到 90 KB** · 回滚工作流） · ★★★ **硬约束：写 layout 前必须已有 Windows 侧取数**（用户能提供则直接进定制流程，不能才让他去取；**GUI 走 HDAU，脚本走 `HDAudDev.dll` 直连** —— 免管理员、可脚本化、产出 Linux 风格 `codec_dump.txt/.json`；dump 完用 **Windows 端点反证插孔映射**）· **AppleHDA 三条实测根因**（PathMap 同组多路径只留最后一条 / 插孔型 Mic 引脚建不出设备 / 插孔检测可能整体是死的）· **不用耳朵验证**（播放中读 `0xF07`/`0xF06` 寄存器）· Pin Config Default 字段读法 · 先搜前人经验、按 codec 定制、本地构建、测试、提 PR
- `references/broadcom-wifi.md` —— 博通网卡（BCM43602/BCM20703）：**按 Sequoia/Tahoe 分路线**、OCLP root patch、验证判据
- `references/ethernet-drivers.md` —— **有线网卡第三方驱动**（Intel I225/I226 · I210/I211/I350 · Realtek RTL8125/8126）：方案对照、装法、判据
- `references/ecosystem-sources.md` —— ★★ **黑苹果生态：权威来源与工具索引**：Acidanthera / Dortania 官方仓库 · **corpnewt 工具链**（ProperTree / GenSMBIOS / SSDTTime / USBMap / gibMacOS / MountEFI）· `USBToolBox` · `blacktop/ipsw-diffs` · 各硬件驱动作者 · 中文资源（远景 / 黑果小兵 / OC-Little 翻译）· ★ **「做什么事信谁」对照表**
- `references/laobamac-toolkit.md` —— **laobamac 工具与补丁索引（48 仓库全表）**：驱动 · 装机（`SimpleKaruzi`/`PVE-OpenCore`）· ★ **硬件避坑（`SimpleBuyersGuide`）** · 维护工具（`SimpleLoader`）· macOS 26 启动台 · 参考补丁（`OC-little-zh`/`non-metal-frameworks`）· AMD 平台 · fork 说明 · ★ **哪些已存档**
- `references/network-en0-order.md` —— **`en0` 归属与网络接口顺序（通用）**：谁依赖 `en0`（ROM / iMessage / FaceTime / App Store）、**修补 Wi-Fi 后必须确认无线是 `en0`**、怎么钉住、连带影响、判据纪律。★ **AirDrop / 接力不依赖 `en0`**（见 `airdrop-handoff.md`）
- `references/airdrop-handoff.md` —— **AirDrop / 接力 / Handoff / 连续互通**：★★★ **根因只看 `awdl0`（= Broadcom 原生 `IO80211Family` 栈）** · **`itlwm.kext` 必然不可用（官方 FAQ 原文）** · **四个误判（`ROM` / `en0` / `SystemUUID` / 序列号）** · **8 步排查顺序** · 选卡原则 · 本机实测（含「U 盘 EFI 为什么坏」反例）
- `references/hidpi.md` —— 非 Retina 屏开 HiDPI（one-key-hidpi）：写入位置、两个模式、恢复路径、**与 NVIDIA 驱动的风险**
- `references/intel-turbo.md` —— Intel 睿频/CPU 限频：★★★ **最佳方法定案（注入「删掉 `hwp` 的本机 profile」四点判据）** · **`hwp` 的真实位置与删法** · **76 份 profile 五族选型表** · CPU-S 验证 · **改完必须重启** · CPUFriend 修法 · BIOS 硬前提
- `references/e-cores.md` —— **开小核 / 关小核（Intel 混合架构 P/E 核）**：★ 两种取舍 · BIOS `Active Efficient Cores`（四家厂商命名）· `ProvideCurrentCpuInfo` · **`CpuTopologyRebuild` 四取值（`ctrsmt=off` / `ctrsmt=full` / `-ctrfixcnt`）** · 判据 `hw.nperflevels` · **官方已知 `-v` 冲突** · 回滚
- `references/kext-and-oc-update.md` —— **更新 kext 与 OpenCore**：★★★ **上游 tag 查不到 ≠ 来路不明**（Dortania `build-repo` 按 commit 构建、补丁号 +1）· **判「官方件」四条判据**（只有「厂商安装器钉没钉」能定性）· **DEBUG/RELEASE 用体积对照**· 该更新 / 不该更新的表 · **OC 本体更新（连 Drivers 一起换）** · 安全流程 9 步 · 坑
- `references/boot-failure-debug.md` —— **装不上 / 进不去系统的分层 debug 流程**：★ **四段分层**（固件/OC 自身 · OC 引导期 · 内核早期 · 内核中后期）· ★★ **卡死 vs 循环重启** · 各段速查表（含 `no kext summary` / `X86PlatformShim` / `decmpfs` / `element modified after free` 等**本机已定性的失败族**）· 装机期专属（VMD 找不到盘等）· **救援顺序 6 步** · ACPI（`xh_adls3`）· **取证清单**


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
