---
name: opencore-config-audit
description: 审查、修改与维护黑苹果的 OpenCore（OpenCorePkg）EFI 配置与驱动安装：逐键对照官方文档并用官方 ocvalidate 校验 config.plist、巡检 ACPI/SSDT（对照官方 AcpiSamples）、精简注入的 kext、读取 OpenCore 引导日志与内核日志取证、用 /etc/fstab 屏蔽磁盘、调整 boot-args 与调试开关；并含从零生成基础 EFI（Windows 上用 RapidEFI）、NVIDIA 驱动（NullMoth nvidia-macos-driver）与 Intel 无线网卡驱动（AirportItlwm / itlwm）的完整安装方法。当任务涉及 OpenCore、config.plist、EFI/OC、ocvalidate、SSDT/ACPI、boot-args、kext 注入、启动选择器、开机刷屏或日志、屏蔽磁盘/隐藏磁盘、首次生成 EFI、装 NVIDIA 驱动、装 Intel 无线驱动时使用。内置「改 ESP 的安全流程」（备份 → 语义 diff → lint → sha 校验 → 镜像/存档 → 卸载重挂复验）。
description_en: Audit, edit and maintain a hackintosh OpenCore (OpenCorePkg) EFI configuration and its driver installs — verify every config.plist switch against the official documentation and ocvalidate, review ACPI/SSDT tables against the official AcpiSamples, trim injected kexts, read OpenCore boot logs and kernel logs for evidence, mask disks with /etc/fstab, and follow the NullMoth NVIDIA driver, Intel WiFi (AirportItlwm) and first-time base-EFI generation (RapidEFI on Windows) workflows. Includes a mandatory safe-edit protocol for the EFI system partition.
version: 0.2.0
agent_created: true
---

# OpenCore 配置审查与维护

## 用途

把「改黑苹果 OpenCore 配置」从「凭经验试」变成「有文档依据、可回滚、可复验」的流程：
先用**官方文档 + 官方 ocvalidate** 判定配置对不对，再用**官方发布包里的样例**判定 SSDT 该不该加，
用**引导期日志**（OpenCore 自己的 `opencore-*.txt` + macOS 内核日志）判定现状，最后按安全流程落盘。

适用于任何 OpenCore 机器；本机（ASUS Z690 / Alder Lake / macOS 26）的具体事实见
`references/machine-facts.md`，可直接引用。

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

### 阶段 8 · 驱动安装（NVIDIA / Intel 无线）

- **NVIDIA 独显** ⇒ `references/nvidia-driver.md`：适用卡范围（Turing+）、两条安装路线（官方包 / 1401 App）、
  ★「kext 装 `/Library/Extensions` 从 AuxKC 加载 ⇒ **不要**再从 `EFI/OC/Kexts` 注入」、
  官方要求的 OpenCore 设置表（`csr-active-config` / boot-args / `ResizeGpuBars` / `Kernel>Block IONDRVSupport` / `SecureBootModel` / BIOS）、
  恢复路径（选择器里的 1401 项、`-nvoff`）、官方 TROUBLESHOOTING 摘要、Send logs 上报纪律
- **Intel 无线网卡** ⇒ `references/intel-wifi.md`：`AirportItlwm` vs `itlwm` 两种形态、
  ★「Sequoia 与 Tahoe 是**两套 ABI 与产物** ⇒ 双系统共用一个配置时必须用 `MinKernel`/`MaxKernel` 分开」、
  macOS 26 的能力与限制（HE 默认关，需 `itlwm_he=1`；不支持 WPA3-only / 强制 PMF / AWDL / AirDrop / MLO）、
  Intel 蓝牙要另装 `IntelBluetoothFirmware` + `IntelBTPatcher`（+ `BlueToolFixup`）、排错与「换网卡后要清理」清单

> 装第三方驱动一定会动到安全边界（`SecureBootModel=Disabled`、放宽 SIP、AMFI 参数）——
> **在报告里明确写出来**，并给出「不装时如何恢复」。

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
| 改了 SSDT 文件名就以为表身份变了 | 表身份**由内容解析决定，不由文件名**；改名安全，只要同步改 `ACPI>Add>Path` |
| 以为 `ocvalidate` 过了就万事大吉 | 它只查 schema；取值是否符合文档要人工逐键比对 |

## 资源

- `scripts/fetch-opencore-docs.sh` —— 下载同版官方包、抽取校验器与文档、建键库
- `scripts/oc-verify.sh` —— 一键校验（ocvalidate + 引用的文件是否存在 + sha 对照）
- `scripts/oc-swap-build.sh` —— RELEASE ↔ DEBUG 换构建（连官方同名 Drivers 一起换，保留第三方驱动，自动备份/校验/落盘）
- `scripts/oc-edit-safe.sh` —— 安全改 config 的包装（备份/改/lint/sha/镜像/存档/重挂复验）
- `scripts/grab-logs.sh` —— 抓 OC 引导日志与本次开机内核日志（提权）
- `scripts/mask-other-disks.sh` —— 按 UUID 写 fstab 屏蔽非 macOS 卷（显式排除 EFI）
- `references/official-docs-method.md` —— 文档取用方法、逐键判定法、成对关系表
- `references/logs-and-debug.md` —— `Target`/`DisplayLevel` 位定义、日志判据、刷屏归因
- `references/acpi-ssdt.md` —— 官方 AcpiSamples 逐条适用条件、设备存在性检查、命名规范
- `references/disks-and-kexts.md` —— 磁盘屏蔽与 kext 精简的判据与「不能删」清单
- `references/nvidia-driver.md` —— NullMoth NVIDIA 驱动：适用范围、安装、必需 OC 设置、恢复、故障对照
- `references/intel-wifi.md` —— Intel 无线网卡驱动（AirportItlwm / itlwm）：版本线、注入、蓝牙配套、排错
- `references/rapidefi-first-efi.md` —— 从零开始：在 Windows 上用 RapidEFI 生成基础 EFI，及之后必须做的收尾
- `references/lifecycle.md` —— **六阶段全流程**：Win 生成 → 安装 → 换 DEBUG → 收日志 → 修补 → 日常化
- `references/pitfalls.md` —— 全部踩过的坑
- `references/machine-facts.md` —— 本机（Z690/Alder Lake/macOS 26）的具体事实
