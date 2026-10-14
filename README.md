# hackintosh-skills

黑苹果（OpenCore）相关的 **Skill** 集合，适用于 WorkBuddy / CodeBuddy。

把「改黑苹果配置」从**凭经验试**，变成**有文档依据、可回滚、可复验**的流程。

每个子目录就是一个可直接使用的 skill：把整个目录复制到你的 skills 目录即可。

> **不知道怎么用？**
> ① 在对话里直接问 **「opencore-config-audit 怎么用」** —— 技能会输出它自己的使用说明；
> ② 或看 [`opencore-config-audit/USAGE.md`](opencore-config-audit/USAGE.md) / [`opencore-picker-theme/USAGE.md`](opencore-picker-theme/USAGE.md)；
> ③ 调用机制与「怎么改技能」见 [`USAGE.md`](USAGE.md)。

**目录**

- [包含的 Skill](#包含的-skill)
- [安装](#安装)
- [目录结构](#目录结构)
- [1. `opencore-config-audit` — 配置审查与维护](#1-opencore-config-audit--opencore-配置审查与维护)
- [2. `opencore-picker-theme` — 选择器主题](#2-opencore-picker-theme--选择器主题opencanopy)
- [适用性与边界](#适用性与边界)

---

## 包含的 Skill

| Skill | 一句话 | 规模 |
|---|---|---|
| **`opencore-config-audit`** | 审查 / 修改 / 维护 OpenCore EFI 配置，并覆盖从装机到日常化、再到系统大版本升级的全生命周期 | 17 条铁律 · 20 份参考 · 11 个脚本 |

每个技能目录里都有一份 `USAGE.md`（**随安装一起复制**），在对话里问「使用说明」即可拿到。
| **`opencore-picker-theme`** | 配置、制作与排错图形启动选择器（OpenCanopy）主题 | 4 份参考 · 2 个脚本 |

---

## 安装

```bash
# 用户级（所有项目都能用）
cp -R opencore-config-audit ~/.workbuddy-ai/skills/
cp -R opencore-picker-theme  ~/.workbuddy-ai/skills/

# 或项目级（只在该项目里可用）
cp -R <skill> <项目目录>/.workbuddy-ai/skills/
```

装好后，新建一个对话，用自然语言说一句需求（例如「审一下我的 OpenCore 配置」）验证是否生效。
不知道怎么用、或没被触发，见 **[`USAGE.md`](USAGE.md)**。

---

## 目录结构

```
hackintosh-skills/
├── README.md
├── USAGE.md                     # 怎么调用 + 索引（给人看）
├── opencore-config-audit/
│   ├── SKILL.md                 # 主流程 + 17 条铁律 + 资源表
│   ├── USAGE.md                 # ← 本技能的使用说明（随安装一起复制）
│   ├── references/              # 20 份专题文档（见下表）
│   └── scripts/                 # 11 个脚本（见下表）
└── opencore-picker-theme/
    ├── SKILL.md
    ├── USAGE.md                 # ← 本技能的使用说明（随安装一起复制）
    ├── references/              # 4 份
    └── scripts/                 # 2 个
```

---

## 1. `opencore-config-audit` — OpenCore 配置审查与维护

### 它解决什么

先用**官方文档 + 官方 `ocvalidate`** 判定配置对不对，再用**官方发布包里的样例**判定 SSDT 该不该加，
最后用**引导期日志**判定现状，按安全流程落盘 —— 每一步都有依据、都能回滚。

### 能力

**⓪ BIOS / UEFI 审查（装机前先做）**

- **三份清单合起来看**：OpenCore 官方文档（9 条检查清单）+ Dortania（Intel / AMD 分开）+ 社区实战补充
- ★ **官方与 Dortania 都没写、但踩到就装不上的两项**：**VMD 必须关**（否则装系统「找不到任何驱动器」）、
  **Intel Speed Shift 必须开**（否则 `wrmsr(0x770,1)` #GP）
- ★ **区分三类**：**必须关**（Fast Boot / Secure Boot / CSM / CFG Lock / VMD / RST / SGX / PTT / 串口）·
  **必须开**（VT-x·SVM / Above 4G / HT / XD / XHCI Hand-off / OS Type=Windows UEFI / AHCI / DVMT≥64MB）·
  **看情况**（Re-BAR / XMP / iGPU / Thunderbolt / ErP）—— **不是一律关或一律开**
- **厂商命名对照表**（ASUS / MSI / Gigabyte / ASRock 同一设置不同叫法）+ **CFG Lock 专题**（三种查法 + 隐藏选项路线）
- **Windows 只读审查脚本**：直接判定固件类型 / Secure Boot / TPM / VT-x / HT / XMP / VMD·RST / 串口 / 内存槽位，
  判不了的明确标成「需人工核」

**① 全流程生命周期**

```
① Windows 上用 RapidEFI 生成基础 EFI → ② 用它安装 macOS → ③ 进系统后换成 DEBUG OpenCore
        → ④ 收集引导期日志 → ⑤ 按官方文档逐项修补 → ⑥ 日常化（换回 RELEASE + 关 debug 日志）
```

> 阶段 ③④ 是关键：**没有 DEBUG 构建就拿不到完整日志，拿不到日志就只能靠猜。**

**② 配置审查**

- **逐键对照官方文档**：按机器上的 OpenCore 版本取官方发布包，用官方 `ocvalidate` 校验，并把
  `Configuration.tex` 里**全部配置条目**（**420 个**，其中带 `Type` 的配置项 **401 个**）的
  `Type / Failsafe / Description` 抽成键库，
  逐键判定「你的取值 vs 官方默认」，分成三类：**有依据的正确偏离 / 与文档相反 / 冗余残留**
- **ACPI / SSDT 巡检**：用官方 `Docs/AcpiSamples/`（18 个样例）逐条对照你的实际设备
- **kext 精简**：找禁用项与孤儿文件，含「不能删」清单
- **磁盘屏蔽**：`/etc/fstab` + `noauto`（按卷 UUID），**显式排除 EFI 分区**并做挂载验证

**③ 日志与耗时取证**

- **引导期取证**：读 OpenCore 自己的 `opencore-*.txt`（`Target` 位定义、`OCABC:` 判据、ACPI 表清单、
  启动项注册、APFS 驱动门槛）与 macOS 内核日志（ACPI 报错、平台设备挂载）
- **启动耗时 / 时间线分析**：把启动拆成 **OC 段 / 内核驱动段 / 用户态段** 三段分开量，
  用「停顿窗口」定位卡顿（`launchd.log` 找最大空档 → **流式过滤** `log show`，绕过其时间过滤失效），
  并给出耗时来源处置表（含驱动侧 `nvrmsettle` / `-wegnoigpu` 两类已知固定延迟）

**④ 系统大版本升级（如 macOS 15 → 26）**

- ★★ **硬约束 ①：给按版本分构建的 kext 加 `MinKernel` / `MaxKernel`** —— 旧版条目上限钉 `24.99.99`，
  新版条目写 `MinKernel 25.0.0`（博通 `AirPortBrcmNIC-Tahoe.kext`、Intel `AirportItlwm-Tahoe` 都是这么分的）
- **升级会必然打断**：Wi-Fi 消失、OCLP root patch 全丢、第三方 kext 可能被搬走 —— 这是设计使然，不是配置坏了
- **时序**：升级前**备份整个 EFI** + 关 FileVault + 保护第三方 kext → 升级 → 补 kext 条目 → 重打 OCLP root patch → 重启验证
- ★★ **硬约束 ②：升级时不许改机型** —— `PlatformInfo` 的 `SystemProductName` / `BoardProduct` / 三码全不动。
  白名单**只用来判断「需不需要绕过」**，不是「要不要换机型」的依据：
  Tahoe 的 Intel 只剩 `iMac20,1` `iMac20,2` `MacPro7,1` `MacBookPro16,x`（`iMacPro1,1` 被剔除）；
  **不在名单里 ⇒ 加 boot-arg 绕过**：`-no_compat_check`（能启动）+ `revpatch=sbvmm`（能收到更新），**两个都要**
- **换机型是独立的一件事，不要塞进升级那一次** —— 它连带内置 USB 图冲突、board-id 触发系统卷重建、XCPM profile 变化（见 §⑤ 与 `smbios-and-serials.md`）
- **macOS 26 新增环境坑**：EFI 挂载必须提权、FAT 改 FSKit、EFI 上删文件会留 `.Trashes`

**⑤ 驱动与硬件特性**

| 主题 | 要点 |
|---|---|
| **NVIDIA 独显**（NullMoth） | 适用卡范围、两条安装路线、★「装 `/Library/Extensions` 从 AuxKC 加载 ⇒ 不要再从 `EFI/OC/Kexts` 注入」、必需 OC 设置、恢复路径、上报纪律 |
| **Intel 无线**（AirportItlwm / itlwm） | 两种形态、★「Sequoia 与 Tahoe 是两套 ABI 与产物 ⇒ 双系统共用配置必须用 `MinKernel`/`MaxKernel` 分开」、蓝牙配套、macOS 26 的能力与限制 |
| **MediaTek 无线**（MT7921 / MT7922 / RZ608） | ★★ **分两条线**：**蓝牙（USB）可用**（`SimpleMtkBtFw` 有 release）；**Wi-Fi（PCIe）是实验性**（`SimpleMtkWlan` 无 release、能扫描但关联/连接仍在修）⇒ **要稳定就换卡**；含蓝牙两个致命坑（别改 USB 产品名 + NVRAM 两条 data） |
| **博通网卡**（BCM943602CDP / BCM43602） | ★ **按系统分路线**：Sequoia 用 `IO80211FamilyLegacy`，Tahoe 用独立 `AirPortBrcmNIC-Tahoe.kext`；OCLP root patch 前置保护；★ 判死活看 `ifconfig en1` |
| **板载声卡**（AppleALC） | 先搜同型号前人 layout-id（推荐路线）→ 搜不到再按 codec 定制 → 本地构建 → 提 PR；自定义 layout 只能用 11–99 |
| **HiDPI**（one-key-hidpi） | 非 Retina 屏清晰度；★ NVIDIA 驱动未完善，含风险与恢复路径；★ 别和引导期 `UIScale` 混 |
| **Intel 睿频** | CPU 被压低频 → **CPU-S 验证** → CPUFriend 修法；★ BIOS `Speed Shift` 必须 Enabled |
| **MacPro 机型内存定制** | ★ **分两层**：「系统信息」= 全机型通用（SMBIOS Type 17）；「关于本机」内存图 = MacPro 专有（**摆位规则 + 12 槽映射表**） |
| **SMBIOS 机型切换 + 三码** | ★ 换机型会连带换掉内置 USB 图 ⇒ 与 UTBMap 冲突；序列号三类判据；ROM 用真实 en0 MAC；换码风控纪律。★ **与系统升级解耦** —— 升级时不动机型（见 §④） |
| **首次生成 EFI**（RapidEFI） | Windows 上生成基础 EFI，及之后必须做的收尾 |

### 内置的安全流程（最重要的一部分）

改 ESP 前备份 → 先读 live 再对 diff → `plutil` 改 → `plutil -lint` → 官方 `ocvalidate` → 算 sha →
同步工作区镜像 + 版本存档 → `sync` → 卸载 → 重新挂载 → **复验 sha 一致**。

### 脚本

| 脚本 | 作用 |
|---|---|
| `fetch-opencore-docs.sh` | 取同版官方包（`ocvalidate` + `Sample.plist` + `AcpiSamples`）并建键库（420 条目 / 401 项带 `Type`） |
| `oc-verify.sh` | 一键校验：`plutil` + `ocvalidate` + ACPI/Kexts 引用完整性 + 孤儿文件 + sha |
| `oc-swap-build.sh` | RELEASE ↔ DEBUG 换构建（连官方同名 Drivers 一起换，保留第三方驱动） |
| `oc-edit-safe.sh` | 安全改 config 的包装（`begin` 备份 / `finish` 校验存档落盘复验） |
| `grab-logs.sh` | 抓 OC 引导日志与本次开机内核日志（提权，可 `--oc-only`） |
| `boot-timeline.sh` | 启动耗时总览（NVRM 属性 + `dmesg` + launchd 时间线 + 内核日志，带超时保护） |
| `find-boot-gap.sh` | 启动停顿窗口精查（从 `launchd.log` 找最大空档 → **流式过滤** `log show`，不落大文件） |
| `mask-other-disks.sh` | 按 UUID 写 fstab 屏蔽非系统卷（默认 dry-run，永不碰 EFI） |
| `cpu-freq-probe.sh` | CPU 实际频率探针（内联汇编，防编译器折叠）—— 验证睿频 / 对比机型 |
| `mem-check.sh` | 校验内存注入摆位（数组序号 → 预测图位，判定是否与「系统信息」错位） |
| `bios-audit.ps1` | **Windows 侧 BIOS 审查（只读）**：判定固件类型/Secure Boot/TPM/VT-x/HT/XMP/**VMD·RST**/串口/内存槽位 |

### 参考文档

| 文档 | 内容 |
|---|---|
| `lifecycle.md` | **六阶段全流程**：Win 生成 → 安装 → 换 DEBUG → 收日志 → 修补 → 日常化（另有 ⑦ 指向系统大版本升级） |
| `os-upgrade-15-to-26.md` | **系统大版本升级**（15 Sequoia → 26 Tahoe）：★★ **两条硬约束**（kext 版本分流 · **不改机型**）、逐部件清单、升级时序、macOS 26 新坑、OCLP vs BCMC |
| `official-docs-method.md` | 官方文档取用方法、逐键判定法、**成对关系表** |
| `logs-and-debug.md` | `Target` / `DisplayLevel` 位定义、日志判据、刷屏归因 |
| `boot-timeline.md` | **启动耗时 / 时间线分析**：三段拆解、流式过滤、停顿窗口定位 |
| `acpi-ssdt.md` | 官方 AcpiSamples 逐条适用条件、设备存在性检查、命名规范 |
| `bios-settings.md` | **BIOS/UEFI 审查**：官方 9 条 + Dortania + 社区补充（**VMD**/Speed Shift）、**必须关/必须开/看情况**三类、CFG Lock 专题、**厂商命名对照表** |
| `disks-and-kexts.md` | 磁盘屏蔽与 kext 精简的判据与「不能删」清单 |
| `rapidefi-first-efi.md` | 从零：Windows 上用 RapidEFI 生成基础 EFI 及收尾 |
| `nvidia-driver.md` | NullMoth NVIDIA 驱动：适用范围、安装、必需 OC 设置、恢复、故障对照 |
| `intel-wifi.md` | Intel 无线网卡：版本线、注入、蓝牙配套、排错 |
| `mediatek-wifi.md` | MediaTek 无线网卡：**蓝牙可用 / Wi-Fi 实验性**两条线、芯片认型、NVRAM 两坑、自编译流程、决策树 |
| `broadcom-wifi.md` | 博通网卡：**按 Sequoia / Tahoe 分路线**、OCLP root patch、验证判据 |
| `applealc-custom.md` | 板载声卡：先搜前人经验、按 codec 定制、本地构建、提 PR |
| `hidpi.md` | 非 Retina 屏开 HiDPI：写入位置、两个模式、恢复路径、与 NVIDIA 驱动的风险 |
| `intel-turbo.md` | Intel 睿频 / 限频：CPU-S 验证、根因定位、CPUFriend 修法、BIOS 硬前提 |
| `memory-injection.md` | MacPro 内存定制：**12 槽映射表**、**摆位规则 f**、A 层通用字段 |
| `smbios-and-serials.md` | 机型切换 + 三码：机型↔USB 图冲突、序列号判据、ROM、风控纪律 |
| `pitfalls.md` | 全部踩过的坑 |
| `machine-facts.md` | 参考机器（Z690 / Alder Lake / macOS 26）的具体事实 |

---

## 2. `opencore-picker-theme` — 选择器主题（OpenCanopy）

配置、制作与排错图形启动界面：图标集、属性位、Flavour、标签、字体、音频辅助、背景、HiDPI。

### 能力

- **权威对照**：必需图标清单与尺寸（**缺一个 OpenCanopy 就不启动**）、官方图标集**不提供**哪些可选图标
  （解释了日志里那些 `OCUI: … Not Found` 为什么是正常的）、标签 / 字体 / 音频的格式要求
- **Flavour 系统**：图标选择与回退链、`Ext` 前缀的安全规则、`.contentFlavour`、`.VolumeIcon.icns` 优先级
- **`PickerAttributes` 全位表** + 依赖关系（如 `0x0008` 必须搭 `0x0001`）
- **排错顺序**：界面不出现 / 图标不对 / 变形 / 没有声音 / 字体异常

### 脚本

| 脚本 | 作用 |
|---|---|
| `oc-theme-check.sh` | Resources 树合规检查（必需图标、**真实像素尺寸**、Selector/SetDefault 同宽、标签/字体/音频） |
| `oc-fetch-iconset.sh` | 从官方 OcBinaryData 取图标集 / 字体 / 标签 / 音频 |

### 参考文档

| 文档 | 内容 |
|---|---|
| `opencanopy-resources.md` | 目录结构、必需/可选图标清单、尺寸与格式要求 |
| `picker-attributes.md` | `PickerAttributes` 位定义与依赖关系 |
| `flavours.md` | Flavour 命名、解析与回退链 |
| `theme-troubleshooting.md` | 界面不出现 / 图标不对 / 变形 / 无声 / 字体异常的排查顺序 |

---

## 适用性与边界

- **流程通用**：文档、校验器、样例、资源都来自官方发布包 / 官方仓库，对任何 OpenCore 机器适用。
- **参考机器事实隔离**：`opencore-config-audit/references/machine-facts.md` 记录的是**某一台机器**的事实
  （Z690 / Alder Lake / RTX 3080 / macOS 26）。换机器时按 `SKILL.md` 的**阶段 0**重新核实即可，
  不要把那份事实当成通用配置。
- **第三方工具不是权威**：RapidEFI 等工具生成的结果适合作为**起点**，仍需回到官方文档 + `ocvalidate` 复核。

## 说明

本仓库内容由作者编写，可自由用于个人与研究用途。
