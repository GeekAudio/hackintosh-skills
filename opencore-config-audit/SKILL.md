---
name: opencore-config-audit
description: 审查、修改与维护黑苹果的 OpenCore（OpenCorePkg）EFI 配置与驱动安装：**BIOS/UEFI 设置审查（官方 9 条清单 + Dortania Intel/AMD + 社区补充的 VMD / Speed Shift；区分「必须关 / 必须开 / 看情况」；含 Windows 只读审查脚本）**、逐键对照官方文档并用官方 ocvalidate 校验 config.plist、巡检 ACPI/SSDT（对照官方 AcpiSamples）、精简注入的 kext、读取 OpenCore 引导日志与内核日志取证、**启动耗时/时间线分析（OC 段 / 内核驱动段 / 用户态段三段拆解，定位卡顿与停顿窗口）**、**系统大版本升级（macOS 15 Sequoia → 26 Tahoe：按 Darwin 版本用 MinKernel/MaxKernel 给网卡等 kext 做版本分流、OCLP root patch、机型白名单、升级时序）**、用 /etc/fstab 屏蔽磁盘、调整 boot-args 与调试开关；并含从零生成基础 EFI（Windows 上用 RapidEFI）、NVIDIA 驱动（NullMoth nvidia-macos-driver）、Intel 无线网卡驱动（AirportItlwm / itlwm）、**MediaTek 无线网卡（MT7921 / MT7922 / RZ608 —— 蓝牙可用、Wi-Fi 实验性）**、博通网卡（BCM943602CDP / BCM43602，按 Sequoia/Tahoe 分路线）、板载声卡 AppleALC、HiDPI（非 Retina 屏清晰度）、Intel 睿频/CPU 限频（CPU-S 验证 + CPUFriend 修法）、MacPro 机型内存定制（摆位规则 + 映射表）与 **SMBIOS 机型切换/三码**（★ **先完善 SSDT → 再换机型 → 再重做 CPUFriend**；主板 OEM SSDT `xh_adls3` 与 `AE_NOT_FOUND` 根因、序列号三类判据、ROM、风控纪律）（先搜前人 layout-id、搜不到再按 codec 定制并提 PR）的完整方法；**并含启动界面外观（OpenCanopy 主题）：图标集、PickerAttributes、Flavour 系统、标签/字体/音频/背景、HiDPI，以及「官方图标集不提供哪些可选图标」的权威对照**。当任务涉及 OpenCore、config.plist、EFI/OC、ocvalidate、SSDT/ACPI、boot-args、kext 注入、启动选择器、开机刷屏或日志、**开机慢/启动耗时/启动卡顿/时间线分析**、**BIOS 设置/UEFI 设置/BIOS 审查/CFG Lock/VMD/Intel RST/Above 4G/Re-Size BAR/CSM/Secure Boot/VT-d/Speed Shift/装系统找不到硬盘**、**OpenCore 主题/启动界面外观/选择器/OpenCanopy/图标集 icon pack/PickerAttributes/PickerVariant/Flavour/.icns/启动声音/开机提示音/选择器字体或背景**、**升级系统/升到 macOS 26/Sequoia 升 Tahoe/升级后 Wi-Fi 没了/kext 版本限制 MinKernel MaxKernel/Darwin 版本分流/机型不被新系统支持/-no_compat_check/收不到系统更新**、屏蔽磁盘/隐藏磁盘、首次生成 EFI、装 NVIDIA 驱动、装 Intel 无线驱动、**装 MediaTek 无线网卡/MT7922/MT7921/RZ608 驱动或蓝牙**、板载声卡/AppleALC/layout-id、博通网卡/BCM943602CDP/OCLP root patch、HiDPI/显示不清晰/缩放、CPU 睿频/限频/卡顿（CPU-S）、内存定制/关于本机内存图/插槽映射、换机型/SMBIOS/三码/序列号/ROM/iMessage 登录时使用。内置「改 ESP 的安全流程」（备份 → 语义 diff → lint → sha 校验 → 镜像/存档 → 卸载重挂复验）。另外，**用户问「这个技能怎么用 / 使用说明 / 有哪些能力 / 能干什么」时也适用**（此时输出技能目录下的 `USAGE.md`，不要输出内部流程）。
description_en: Audit, edit and maintain a hackintosh OpenCore (OpenCorePkg) EFI configuration and its driver installs — audit BIOS/UEFI firmware settings (OpenCore's official checklist plus Dortania's Intel/AMD lists plus community-only items such as VMD and Intel Speed Shift, split into must-disable / must-enable / conditional, with a read-only Windows audit script), verify every config.plist switch against the official documentation and ocvalidate, review ACPI/SSDT tables against the official AcpiSamples, trim injected kexts, read OpenCore boot logs and kernel logs for evidence, analyse boot time / startup timeline in three independent phases (OpenCore, kernel/driver, userspace) to locate stalls and gaps, plan a major macOS upgrade (15 Sequoia to 26 Tahoe: per-Darwin-version kext gating with MinKernel/MaxKernel for WiFi cards, OCLP root patching, supported SMBIOS whitelist, upgrade ordering), mask disks with /etc/fstab, and follow the NullMoth NVIDIA driver, Intel WiFi (AirportItlwm), MediaTek WiFi (MT7921 / MT7922 / RZ608 — Bluetooth works, Wi-Fi experimental), Broadcom WiFi (BCM943602CDP, Sequoia vs Tahoe routes), onboard audio (AppleALC layout-id / codec customisation), HiDPI scaling on non-Retina displays, Intel Turbo Boost / CPU frequency capping (verified with CPU-S, fixed with CPUFriend), MacPro memory injection (slot layout mapping), SMBIOS model switching and serials/MLB/UUID/ROM (iMessage; board OEM SSDT / AE_NOT_FOUND root cause; order: finish SSDT first, then SMBIOS, then CPUFriend) and first-time base-EFI generation (RapidEFI on Windows) workflows, plus OpenCanopy boot-picker theming (icon sets, PickerAttributes, the flavour system, labels/fonts/audio/background, HiDPI, and the authoritative list of optional icons the official icon sets do NOT ship). Includes a mandatory safe-edit protocol for the EFI system partition. Also applies when the user asks how to use this skill, for its usage guide, or for a list of its capabilities — in that case output the skill's USAGE.md rather than the internal workflow.
version: 0.12.0
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

## 工作流

### 阶段 0 · 摸清基线

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

### 阶段 7 · kext 精简

对照 `Kernel>Add` 与 `EFI/OC/Kexts/`：找**禁用项**与**孤儿文件**，逐个判断是否真的不用
（换了硬件的驱动、功能已被其它开关覆盖的补丁）。删除前先把原件备份到工作区，再删文件 + 删条目。
判据与「不能删」清单见 `references/disks-and-kexts.md`。

### 阶段 8 · 驱动与硬件特性（NVIDIA / Intel 无线 / 博通网卡 / 板载声卡 / HiDPI / Intel 睿频 / **内存定制 / SMBIOS+三码**）

- **NVIDIA 独显** ⇒ `references/nvidia-driver.md`：适用卡范围（Turing+）、两条安装路线（官方包 / 1401 App）、
  ★「kext 装 `/Library/Extensions` 从 AuxKC 加载 ⇒ **不要**再从 `EFI/OC/Kexts` 注入」、
  官方要求的 OpenCore 设置表（`csr-active-config` / boot-args / `ResizeGpuBars` / `Kernel>Block IONDRVSupport` / `SecureBootModel` / BIOS）、
  恢复路径（选择器里的 1401 项、`-nvoff`）、官方 TROUBLESHOOTING 摘要、Send logs 上报纪律
- **Intel 无线网卡** ⇒ `references/intel-wifi.md`：`AirportItlwm` vs `itlwm` 两种形态、
  ★「Sequoia 与 Tahoe 是**两套 ABI 与产物** ⇒ 双系统共用一个配置时必须用 `MinKernel`/`MaxKernel` 分开」、
  macOS 26 的能力与限制（HE 默认关，需 `itlwm_he=1`；不支持 WPA3-only / 强制 PMF / AWDL / AirDrop / MLO）、
  Intel 蓝牙要另装 `IntelBluetoothFirmware` + `IntelBTPatcher`（+ `BlueToolFixup`）、排错与「换网卡后要清理」清单
- **MediaTek 无线网卡（MT7921 / MT7922 / RZ608）** ⇒ `references/mediatek-wifi.md`：
  ★★★ **macOS 26 原生内置 Apple 自己的 MediaTek 驱动** —— `com.apple.AppleSunriseWLAN.dext` +
  `com.apple.AppleSunriseBluetooth.dext`（**自带固件** `BT_RAM_CODE_MT7922_1_1_hdr.bin` 等），
  `IOPCIMatch` = `0x792214c3`(MT7922 Wi-Fi) / **`0x792a14c3`(MT7922 蓝牙，走 PCIe！)** ⇒ **首选「什么都不装」试一遍**；
  ★ **蓝牙有两种形态**：**新的走 PCIe**（`14c3:792a`，Apple 原生管）、**老的走 USB**（`0x0e8d`，靠第三方 `SimpleMtkBtFw`）—— 先判清；
  ★ Sequoia **没有** Sunrise ⇒ 只能走第三方：**蓝牙可用**（`SimpleMtkBtFw` 有 release），
  **Wi-Fi 实验性**（`SimpleMtkWlan` **无 release**、能扫描但关联/连接仍在修、实机有「一连接就 panic」）；
  ⇒ **要能日常用的 Wi-Fi 就换卡**（Broadcom / Intel），别硬啃；
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
  - **必须同时重做 `CPUFriendDataProvider`**（`MacPro7,1` 强制 `hwp=on` ⇒ 不重做 = 白换）
  - **救援**：备份整个 EFI + **备一个能用的 U 盘 EFI**；进不去就退回「保留原机型 + `-no_compat_check` + `revpatch=sbvmm`」
  - **三码**：官方 `macserial` 生成、**序列号三类判据**（官网「无效」=可用 / 显示保修=必须换 / 「核实购买日期」=最理想）、
    **`ROM` 必须是 `en0` 真实 MAC**、改 ROM 可用 **base64 等长替换**、
    ★ **换码要克制（脏码 + 频繁换号触发风控）**、换完**先 FaceTime 再信息**、
    ★★ **三码 + ROM 不要写进任何会公开的地方**
- **内存定制（`PlatformInfo > Memory`）** ⇒ `references/memory-injection.md`：
  ★★ **分两层别混** —— **A 层「系统信息 → 内存」= 全机型通用**（就是标准 SMBIOS Type 17 字段，
  `DeviceLocator` 决定显示的名字、`MaxCapacity` 单位是 **bytes**、键名是 **`SerialNumber`**）；
  **B 层「关于本机」的内存图 = MacPro 机型专有**：那张 12 槽图的摆位由 **`Devices` 数组顺序**决定，
  规则是「**数组第 j 项画到固定第 f(j) 个图位**」，`f = [8,7,10,9,12,11,5,6,3,4,1,2]`（= 真机 Type 17 表顺序）；
  ⇒ **槽号用真机编号（1=F1…12=C1）+ 数组按 f 序排**，才能「图位 v = Slot v = 列表第 v 行」；
  校验用 `scripts/mem-check.sh`（算出每条会被画到哪个图位并判定是否错位）；
  ★ 2 条内存的「至少四条」警告**去不掉**（真机也一样）；4 槽消费主板布局下左图**不画编号**
- **CPU 被压在低频（卡顿/掉帧）⇒ Intel 睿频** ⇒ `references/intel-turbo.md`：
  ★ **验证用 CPU-S**（看「当前睿频状态」是否「未睿频」+ 频率列表有没有覆盖高倍频），配合 Intel Power Gadget 与本机 `cpu-freq-probe.sh` 交叉印证；
  先排除热降频（`xcpm.cpu_thermal_level=0`）与 XCPM 上限（`hard_plimit_max=49`）；
  根因多为**机型 profile 的 `FrequencyVectors` + `hwp`**（本机 `MacPro7,1` 强制 `hwp=on` ⇒ 卡 2.3 GHz；`iMacPro1,1` 不用 HWP ⇒ 流畅）；
  修法 = **CPUFriend + CPUFriendDataProvider**（顺序 Lilu → CPUFriend → DataProvider；`ExecutablePath` 必须空；`FrequencyVectors` 解回必须 7668 B）；
  ★ 硬前提：**BIOS `Intel Speed Shift Technology` 必须 Enabled**（否则 `xcpm_hwp_enable` #GP panic）；
  ★ 官方警告「不确定就别用 CPUFriend，能改 SMBIOS 解决更合理」
- **显示不清晰 ⇒ HiDPI** ⇒ `references/hidpi.md`：用 `xzhih/one-key-hidpi` 给非 Retina 屏模拟 HiDPI
  （写 `/Library/Displays/Contents/Resources/Overrides/`，**不动密封系统卷**；两个模式：只注入 `scale-resolutions` /
  连同 patched EDID 一起注入，**先试前者**）；
  ★★ **本机驱动是 NullMoth 的 NVIDIA 驱动，自述未完善** —— 而 HiDPI 正踩在「显示模式/缩放/元数据」这条它出过真 bug 的路径上
  （本机显示器尺寸报错就是这个根因）⇒ **开之前先记录基线、一次只改一项、先确认 `.hidpi-disable` 与 Recovery 恢复路径**；
  ★ 别和**引导期** HiDPI（`UEFI>Output>UIScale`）搞混，两者独立
- **板载声卡（AppleALC）** ⇒ `references/applealc-custom.md`：
  ★★★ **macOS 26 前置**：Apple 在 DP2 删了 `AppleHDA.kext` ⇒ 先用 **`SimpleHDA`**（Lilu 插件，**OpenCore 注入原版 AppleHDA**，
  **不打补丁 / 不关 SIP / 不动系统卷 / 不用 KDK**，音质无损耗）把它恢复回来，再谈 `layout-id`；
  顺序 `Lilu → AppleALC → SimpleHDA` + **必需 `keepsyms=1`**；★ 用前先卸掉其它 AppleHDA 恢复方案或根补丁
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
- `scripts/mem-check.sh` —— 校验内存注入摆位（数组序号 → 预测图位，判定是否与「系统信息」错位）
- `scripts/redact-check.sh` —— **发布前脱敏自检（只读）**：扫三码 / MAC / 密钥 / 卷 UUID / 邮箱 / 内网 IP
- `scripts/oc-theme-check.sh` —— **Resources 树合规检查**（必需图标 / 实际像素尺寸 / 标签 / 字体 / 音频）
- `scripts/oc-fetch-iconset.sh` —— 从官方 OcBinaryData 取图标集 / 字体 / 标签 / 音频
- `scripts/bios-audit.ps1` —— **Windows 侧 BIOS 审查（只读）**：判定固件类型/Secure Boot/TPM/VT-x/HT/XMP/**VMD·RST**/串口/内存槽位，判不了的明确标注
- `references/official-docs-method.md` —— 文档取用方法、逐键判定法、成对关系表
- `references/logs-and-debug.md` —— `Target`/`DisplayLevel` 位定义、日志判据、刷屏归因
- `references/boot-timeline.md` —— **启动耗时/时间线分析**：三段拆解、流式过滤、停顿窗口定位、耗时来源与处置
- `references/acpi-ssdt.md` —— 官方 AcpiSamples 逐条适用条件、设备存在性检查、命名规范
- `references/bios-settings.md` —— **BIOS/UEFI 审查**：官方 9 条 + Dortania（Intel/AMD）+ 社区补充（**VMD**/Speed Shift）、**必须关/必须开/看情况**三类、CFG Lock 专题、**厂商命名对照表**、Windows 审查脚本用法
- `references/disks-and-kexts.md` —— 磁盘屏蔽与 kext 精简的判据与「不能删」清单
- `references/nvidia-driver.md` —— NullMoth NVIDIA 驱动：适用范围、安装、必需 OC 设置、恢复、故障对照
- `references/intel-wifi.md` —— Intel 无线网卡驱动（AirportItlwm / itlwm）：版本线、注入、蓝牙配套、排错
- `references/mediatek-wifi.md` —— MediaTek 无线网卡（MT7921 / MT7922 / RZ608）：★★★ **macOS 26 原生 Sunrise 驱动**（`AppleSunriseWLAN/Bluetooth` dext + 自带固件 + PCIe 蓝牙 `14c3:792a`）、三条路线决策树、芯片认型、第三方 NVRAM 两坑、自编译流程
- `references/applealc-custom.md` —— 板载声卡（AppleALC）：★★★ **macOS 26 的 `AppleHDA` 恢复（`SimpleHDA`，无需补丁）**、先搜前人经验、按 codec 定制、本地构建、测试、提 PR
- `references/broadcom-wifi.md` —— 博通网卡（BCM43602/BCM20703）：**按 Sequoia/Tahoe 分路线**、OCLP root patch、验证判据
- `references/ethernet-drivers.md` —— **有线网卡第三方驱动**（Intel I225/I226 · I210/I211/I350 · Realtek RTL8125/8126）：方案对照、装法、判据
- `references/laobamac-toolkit.md` —— **laobamac 工具与补丁索引（48 仓库全表）**：驱动 · 装机（`SimpleKaruzi`/`PVE-OpenCore`）· ★ **硬件避坑（`SimpleBuyersGuide`）** · 维护工具（`SimpleLoader`）· macOS 26 启动台 · 参考补丁（`OC-little-zh`/`non-metal-frameworks`）· AMD 平台 · fork 说明 · ★ **哪些已存档**
- `references/network-en0-order.md` —— **`en0` 归属与网络接口顺序（通用）**：谁依赖 `en0`（ROM / iMessage / Continuity）、**修补 Wi-Fi 后必须确认无线是 `en0`**、怎么钉住、连带影响、判据纪律
- `references/hidpi.md` —— 非 Retina 屏开 HiDPI（one-key-hidpi）：写入位置、两个模式、恢复路径、**与 NVIDIA 驱动的风险**
- `references/intel-turbo.md` —— Intel 睿频/CPU 限频：**CPU-S 验证**、根因定位（机型 profile + hwp）、CPUFriend 修法、BIOS 硬前提
- `references/smbios-and-serials.md` —— **换机型 + 三码**：★★★ **主板 OEM SSDT（`xh_adls3`）与 ACPI 根因**、**顺序铁律（先完善 SSDT）**、检查清单、决策依据、序列号判据、ROM、切换脚本三态、操作教训
- `references/memory-injection.md` —— MacPro 机型内存定制：**12 槽映射表**、**摆位规则 f**、A 层通用字段、踩坑
- `references/rapidefi-first-efi.md` —— 从零开始：在 Windows 上用 RapidEFI 生成基础 EFI，及之后必须做的收尾
- `references/lifecycle.md` —— **六阶段全流程**：Win 生成 → 安装 → 换 DEBUG → 收日志 → 修补 → 日常化
- `references/os-upgrade-15-to-26.md` —— **系统大版本升级**（15 Sequoia → 26 Tahoe）：**`MinKernel`/`MaxKernel` 版本分流**、逐部件清单、升级时序、机型白名单、macOS 26 新坑、OCLP vs BCMC
- `references/pitfalls.md` —— 全部踩过的坑
- `references/theme-opencanopy.md` —— **选择器主题（OpenCanopy）**：开关总表、资源目录、**图标清单（必需/可选/官方不提供）**、Flavour 规则、标签/字体/音频/背景、排错
- `references/machine-facts.md` —— 本机（Z690/Alder Lake/macOS 26）的具体事实
- `USAGE.md` —— **给使用者看的速查**（用户问「怎么用/使用说明/能干什么」时输出这个）
