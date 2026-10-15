# hackintosh-skills

黑苹果（OpenCore）相关的 **Skill** 集合，适用于 WorkBuddy / CodeBuddy。

把「改黑苹果配置」从**凭经验试**，变成**有文档依据、可回滚、可复验**的流程。

目录 `opencore-config-audit/` 就是 skill 本体：把它整个复制到你的 skills 目录即可（或按下面用插件市场安装）。

> **不知道怎么用？**
> ① 在对话里直接问 **「opencore-config-audit 怎么用」** —— 技能会输出它自己的使用说明；
> ② 或看 [`opencore-config-audit/USAGE.md`](opencore-config-audit/USAGE.md)；
> ③ 调用机制与「怎么改技能」见 [`USAGE.md`](USAGE.md)。

**目录**

- [包含的 Skill](#包含的-skill)
- [安装](#安装)
- [目录结构](#目录结构)
- [`opencore-config-audit` — 配置审查与维护](#opencore-config-audit--opencore-配置审查与维护)
- [适用性与边界](#适用性与边界)

---

## 包含的 Skill

| Skill | 一句话 | 规模 |
|---|---|---|
| **`opencore-config-audit`** | 审查 / 修改 / 维护 OpenCore EFI 配置 —— 覆盖从装机到日常化、再到系统大版本升级的全生命周期，并含**启动选择器（OpenCanopy）主题**与**换机型 / 三码** | 20 条铁律 · 28 份参考 · 17 个脚本 |

技能目录里有一份 `USAGE.md`（**随安装一起复制**），在对话里问「使用说明」即可拿到。

---

## 安装

**方式一：作为插件市场安装（推荐）**

本仓库已配好市场清单，直接添加即可：

```bash
# ① 添加市场
/plugin marketplace add GeekAudio/hackintosh-skills

# ② 安装插件（<插件名>@<市场名>）
/plugin install opencore-config-audit@hackintosh-skills
```

**方式二：手动复制（离线 / 只装一个）**

```bash
# 用户级（所有项目都能用）
cp -R opencore-config-audit ~/.workbuddy-ai/skills/

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
├── .codebuddy-plugin/
│   └── marketplace.json         # ← 插件市场清单（加市场时读它）
├── opencore-config-audit/
│   ├── .codebuddy-plugin/
│   │   └── plugin.json          # ← 插件元数据
│   ├── SKILL.md                 # 主流程 + 20 条铁律 + 资源表
│   ├── USAGE.md                 # ← 使用说明（随安装一起复制）
│   ├── references/              # 28 份专题文档（见下表）
│   └── scripts/                 # 17 个脚本（见下表）
```

---

## `opencore-config-audit` — OpenCore 配置审查与维护

### 它解决什么

先用**官方文档 + 官方 `ocvalidate`** 判定配置对不对，再用**官方发布包里的样例**判定 SSDT 该不该加，
最后用**引导期日志**判定现状，按安全流程落盘 —— 每一步都有依据、都能回滚。

### 能力

**⓪ 硬件避坑 + BIOS / UEFI 审查（装机前先做）**

- ★ **更早一步**：`laobamac/SimpleBuyersGuide`《黑苹果硬件避坑指南》—— 明确列出**不应购买**的 CPU / GPU / 主板芯片组 / SSD / 网卡 / 无线卡等

- **三份清单合起来看**：OpenCore 官方文档（9 条检查清单）+ Dortania（Intel / AMD 分开）+ 社区实战补充
- ★ **官方与 Dortania 都没写、但踩到就装不上的两项**：**VMD 必须关**（否则装系统「找不到任何驱动器」）、
  **Intel Speed Shift 必须开**（否则 `wrmsr(0x770,1)` #GP）
- ★ **区分三类**：**必须关**（Fast Boot / Secure Boot / CSM / CFG Lock / VMD / RST / SGX / PTT / 串口）·
  **必须开**（VT-x·SVM / Above 4G / HT / XD / XHCI Hand-off / OS Type=Windows UEFI / AHCI / DVMT≥64MB）·
  **看情况**（Re-BAR / XMP / iGPU / Thunderbolt / ErP / **E 核数量**）—— **不是一律关或一律开**
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
- ★ **固件启动项（`Boot####`）**：**「用 U 盘引导一次后，硬盘的 OpenCore 启动项从 BIOS 里消失、只剩 Windows」**
  的根因与修法 —— `LauncherOption=Full` 会**按文件路径后缀认自己的项（不看盘）**，从别的盘引导就把它重指过去；
  ⇒ **定案组合 = 目标盘 `Full`（自建+自愈）/ 另一份 `Disabled`**（★ 两个都 `Disabled` 就没人建项了）
- ★★ **加回来：官方方法**（`Configuration.pdf`）—— **B** OpenShell 里 `bcfg boot add 0 FSx:\EFI\OC\OpenCore.efi "OpenCore"`
  （★ **官方推荐**，纯 U 盘、不要 Windows）· **C** `bcfg` 写不进去 ⇒ 先跑 `\EFI\OC\Tools\OpenControl.efi disable`（+ `FullNvramAccess=true`）再重试，**之后必须重启** ·
  **A** `LauncherOption=Full` 让 OpenCore 自己建（**解决不了「鸡生蛋」**）·
  **D** 从系统里写（macOS `nvram` / Linux `efibootmgr` / Windows EasyUEFI）—— ★★ **前提：该次启动的 `RequestBootVarRouting=false`**，
  否则「写成功、读回一致」全是假阳性 ⇒ **判据只看重启后的 BIOS**；附 `BootKicker`（黑苹果通常不可用）
- ★ **从 U 盘启动改成硬盘启动**：完整迁移步骤 + 三步验收（BIOS 有且第一 / `boot-path` 指向硬盘 / **拔掉 U 盘再重启**）

**④ 系统大版本升级（如 macOS 15 → 26）**

- ★★ **硬约束 ①：给按版本分构建的 kext 加 `MinKernel` / `MaxKernel`** —— 旧版条目上限钉 `24.99.99`，
  新版条目写 `MinKernel 25.0.0`（博通 `AirPortBrcmNIC-Tahoe.kext`、Intel `AirportItlwm-Tahoe` 都是这么分的）
- **升级会必然打断**：Wi-Fi 消失、OCLP root patch 全丢、第三方 kext 可能被搬走 —— 这是设计使然，不是配置坏了
- **时序**：升级前**备份整个 EFI** + 关 FileVault + 保护第三方 kext → 升级 → 补 kext 条目 → 重打 OCLP root patch → 重启验证
- ★★ **硬约束 ②：升级时不许改机型** —— `PlatformInfo` 的 `SystemProductName` / `BoardProduct` / 三码全不动。
  白名单**只用来判断「需不需要绕过」**，不是「要不要换机型」的依据：
  Tahoe 的 Intel 只剩 `iMac20,1` `iMac20,2` `MacPro7,1` `MacBookPro16,x`（`iMacPro1,1` 被剔除）；
  **不在名单里 ⇒ 加 boot-arg 绕过**：`-no_compat_check`（能启动）+ `revpatch=sbvmm`（能收到更新），**两个都要**
- **换机型是独立的一件事，不要塞进升级那一次** —— 它连带 **board-id 变化触发 ACPI 重新解析**（本机真因是**主板 OEM SSDT**，见 §⑤）、系统卷重建、XCPM profile 变化（`smbios-and-serials.md` §2）
- **macOS 26 新增环境坑**：EFI 挂载必须提权、FAT 改 FSKit、EFI 上删文件会留 `.Trashes`

**⑤ 驱动与硬件特性**

| 主题 | 要点 |
|---|---|
| **NVIDIA 独显**（NullMoth） | 适用卡范围、两条安装路线、★「装 `/Library/Extensions` 从 AuxKC 加载 ⇒ 不要再从 `EFI/OC/Kexts` 注入」、必需 OC 设置、恢复路径、上报纪律 |
| **Intel 无线**（AirportItlwm / itlwm） | 两种形态、★「Sequoia 与 Tahoe 是两套 ABI 与产物 ⇒ 双系统共用配置必须用 `MinKernel`/`MaxKernel` 分开」、蓝牙配套、macOS 26 的能力与限制 |
| **MediaTek 无线**（MT7921 / MT7922 / RZ608） | ★★★ **macOS 26 原生 Sunrise 驱动**（`AppleSunriseWLAN/Bluetooth`，自带固件）⇒ 先「什么都不装」试一遍；**蓝牙（USB）走 `SimpleMtkBtFw`**；★★ **第三方 Wi-Fi 认准 `flxxxxddd/SimpleMtkWlan` fork（有 CI release v1.2.0）** —— 修好了 MT7921/RZ608「能 attach 但过不了流量」，补上 **802.11n + 802.11ac（VHT80）**，实测 30–50 Mbit/s 且开机自动加入；★★★ **三条硬限制**：**以太网式接口、没有原生 Wi-Fi 菜单、AirDrop/Handoff/Continuity 设计上不可能**、不支持 802.11ax ⇒ 要这些就换卡；★ 最常踩的坑 = **卡被 `SSDT-Disable_Network` 藏了**（`vendor-id` 改 `0xFFFF`）；排错用 `mtklog.sh`（常驻日志、免 root） |
| **有线网卡**（Intel / Realtek） | ★★ **本机是 Intel `I225-V`**；`SimpleVGBE`（I225/I226）· `SimpleEthernet`（Lilu 插件，i225/226/210/211）· `SimpleRTK5`（RTL8125/8126）；★ **一次只换一套**、**换完复查 `en0` 归属** |
| **博通网卡**（BCM943602CDP / BCM43602） | ★ **按系统分路线**：Sequoia 用 `IO80211FamilyLegacy`，Tahoe 用独立 `AirPortBrcmNIC-Tahoe.kext`；OCLP root patch 前置保护；★ 判死活看 `ifconfig en1` |
| **板载声卡**（AppleALC） | ★★★ **macOS 26 前置：先用 `SimpleHDA` 恢复原版 `AppleHDA`**（OpenCore 注入，**不打补丁 / 不关 SIP / 不用 KDK**，音质无损耗）；然后先搜同型号前人 layout-id（推荐路线）→ 搜不到再按 codec 定制 → 本地构建 → 提 PR；自定义 layout 只能用 11–99 |
| **HiDPI**（one-key-hidpi） | 非 Retina 屏清晰度；★ NVIDIA 驱动未完善，含风险与恢复路径；★ 别和引导期 `UIScale` 混 |
| **Intel 睿频** | ★★★ **最佳方法定案：注入「本机自己的 profile，只把 `hwp` 删掉」** —— 四点判据（**1 段** / 上限尽可能高 / **`hwp` 已删** / `CPUFloor` 匹配）；★ `hwp` **不在 plist 里**（在 7668 B 向量二进制偏移 ~7128 的变量名表内）⇒ 判「有没有作用」要**逐字节比**；★★ **反面结论：注入别的机型 profile 会压垮睿频**（实测 `iMac19,1` ⇒ 1.97 GHz、`MacPro7,1` ⇒ 2.3 GHz）；含 **76 份 profile 五族选型表**（分水岭 = 段数，**上限 5000 的全是 3–5 段** ⇒ 与结构兼容不可兼得）；★ CPU-S 验证 · **改完必须重启** · BIOS `Speed Shift` 必须 Enabled |
| **开小核 / 关小核**（E 核） | Intel 12 代+ 混合架构的两种取舍：**关 = 稳**（BIOS `Active Efficient Cores = 0`，**配置一行不用改**）· **开 = 快**（`= All` + `ProvideCurrentCpuInfo=true` + `CpuTopologyRebuild.kext`）；★ 判据 `hw.nperflevels`（**1 = E 核没暴露 / 2 = P+E 都识别**）；★★ 「只看到 8 核 16 线程」**不是缺核**；★ `ctrsmt=off` / `ctrsmt=full` 的 **v2 语法与 v1 的 `-ctrsmt` 不通用**；★ 官方已知**开小核 + `-v` 可能随机启动失败** |
| **CPU 显示名不对** | 「关于本机显示 Xeon W 但我是 i7」—— **纯外观问题**（频率/核数全对，只是名字按机型映射）；**RestrictEvents 三件套**：`revpatch=cpuname`（boot-args）+ `revcpu=1`（boot-args）+ `revcpuname=<名>`（NVRAM）；★★ **最大的坑：NVRAM 的 `rev*` 优先级低于 boot-args** ⇒ boot-args 里必须也含 `cpuname`；★ `revcpuname` 含空格**只能放 NVRAM**；★ Intel 上 `revcpu` **默认 0**；★ `ProcessorType` 必须配核数（8 核+ = `0x0F01`）；★ **`Cpuid1Data` 改不了名字**、**别去改 `AppleSystemInfo.strings`** |
| **内存定制** | ★★ **槽位数随机型变**（`MacPro7,1`=**12 槽** / `iMac20,1`=**4 槽**）⇒ 换机型要同步重做；★ **分两层**：「系统信息」= 全机型通用（SMBIOS Type 17）；「关于本机」内存图 = **MacPro 专有**（**摆位规则 + 12 槽映射表**） |
| **SMBIOS 机型切换 + 三码** | ★★★ **换机型必须连三码一起换** —— 「关于本机」的机型名是**序列号产品码**的函数，不换码就永远显示旧机型（`macserial -i` 可先解码核对）；**连带项一次做全**：三码 · ACPI/SSDT 前置 · `CPUFriend` · **内存注入槽位数**（MacPro7,1=12 / iMac20,1=4）· `ROM` · **电脑名/主机名/SMB 名**；★★★ **顺序：先完善 SSDT/ACPI（旧机型下验证）→ 再换 SMBIOS → 再重做 CPUFriend**；★ 真正让本机进不去系统的是**主板 OEM SSDT**（ASUS Z690 的 `xh_adls3` ⇒ `HS06 AE_NOT_FOUND`），修法 = `ACPI>Delete` 删原表 + 加 `SSDT-XHADLS3.aml`；已排除 USB 图/OCLP/机型本身/15 口/NVRAM；序列号三类判据、ROM 用真实 en0 MAC、换码风控纪律。★ **与系统升级解耦**（升级时不动机型） |
| **首次生成 EFI**（RapidEFI） | Windows 上生成基础 EFI，及之后必须做的收尾 |
| **选择器主题**（OpenCanopy） | 图标集、`PickerAttributes` 位表、Flavour 规则、标签/字体/音频/背景、HiDPI；★ **必需图标缺一个就不启动**、**官方图标集不提供哪些可选图标**（解释日志里的 `Not Found` 为什么正常） |

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
| `e-cores-check.sh` | **小核（E 核）体检**：拓扑（`hw.nperflevels` / `perflevel1` / `CPUID`）+ 频率 + `CpuTopologyRebuild` 加载状态 + 判读 |
| `cpu-name-check.sh` | **CPU 显示名体检**：显示名 vs `machdep.cpu.brand_string` · `rev*` 参数（boot-args + NVRAM）· `RestrictEvents` 加载 · config 的 `ProcessorType` / `revcpuname` / `NVRAM>Delete` 核对 |
| `mem-check.sh` | 校验内存注入摆位（数组序号 → 预测图位，判定是否与「系统信息」错位） |
| `bios-audit.ps1` | **Windows 侧 BIOS 审查（只读）**：判定固件类型/Secure Boot/TPM/VT-x/HT/XMP/**VMD·RST**/串口/内存槽位 |
| `oc-nvram-bootentry.sh` | **从系统里读/写固件启动项**（官方方法 D 的辅助）：`dump`（解析名字/设备路径）· `backup` / `restore` · `add`（含 `--dry-run`）· `del`。★ 写操作要提权；★★ **且只在 `RequestBootVarRouting=false` 时才有意义** |
| `redact-check.sh` | **发布前脱敏自检（只读）**：扫三码 / MAC / 密钥 / 卷 UUID / 邮箱 / 内网 IP |
| `oc-theme-check.sh` | **Resources 树合规检查**（必需图标 / 真实像素尺寸 / 标签 / 字体 / 音频） |
| `oc-fetch-iconset.sh` | 从官方 OcBinaryData 取图标集 / 字体 / 标签 / 音频 |

### 参考文档

| 文档 | 内容 |
|---|---|
| `lifecycle.md` | **六阶段全流程**：Win 生成 → 安装 → 换 DEBUG → 收日志 → 修补 → 日常化（另有 ⑦ 指向系统大版本升级） |
| `os-upgrade-15-to-26.md` | **系统大版本升级**（15 Sequoia → 26 Tahoe）：★★ **两条硬约束**（kext 版本分流 · **不改机型**）、逐部件清单、升级时序、macOS 26 新坑、OCLP vs BCMC |
| `official-docs-method.md` | 官方文档取用方法、逐键判定法、**成对关系表** |
| `logs-and-debug.md` | `Target` / `DisplayLevel` 位定义、日志判据、刷屏归因 |
| `boot-timeline.md` | **启动耗时 / 时间线分析**：三段拆解、流式过滤、停顿窗口定位 |
| `boot-entries.md` | **固件启动项（`Boot####` / `BootOrder`）与 `LauncherOption`**：★ **「用 U 盘引导后启动项消失」的根因**、四档取值、取证命令、**ASUS 的 `Boot0000` 坑**；★★ **§7 官方修法**（`bcfg` / `OpenControl` 解锁 NVRAM / `LauncherOption=Full` 自愈 / 从系统里写 / `BootKicker`）、**§8 从 U 盘启动改成硬盘启动（含三步验收）** |
| `acpi-ssdt.md` | 官方 AcpiSamples 逐条适用条件、设备存在性检查、命名规范 |
| `bios-settings.md` | **BIOS/UEFI 审查**：官方 9 条 + Dortania + 社区补充（**VMD**/Speed Shift）、**必须关/必须开/看情况**三类、CFG Lock 专题、**厂商命名对照表** |
| `disks-and-kexts.md` | 磁盘屏蔽与 kext 精简的判据与「不能删」清单 |
| `rapidefi-first-efi.md` | 从零：Windows 上用 RapidEFI 生成基础 EFI 及收尾 |
| `nvidia-driver.md` | NullMoth NVIDIA 驱动：适用范围、安装、必需 OC 设置、恢复、故障对照 |
| `intel-wifi.md` | Intel 无线网卡：版本线、注入、蓝牙配套、排错 |
| `mediatek-wifi.md` | MediaTek 无线网卡：★★★ **macOS 26 原生 Sunrise 驱动**；★★ **第三方 Wi-Fi 用 `flxxxxddd/SimpleMtkWlan` fork（有 release、802.11n/ac 可用）** · **三条硬限制** · **SSDT 藏卡坑** · `mtklog.sh` 排错 · 蓝牙 `SimpleMtkBtFw` 两坑 · 芯片认型 · 决策树 |
| `broadcom-wifi.md` | 博通网卡：**按 Sequoia / Tahoe 分路线**、OCLP root patch、验证判据 |
| `network-en0-order.md` | **`en0` 归属与网络接口顺序**：谁依赖 `en0`、**修补 Wi-Fi 后必须确认无线是 `en0`**、怎么钉住、连带影响 |
| `ethernet-drivers.md` | **有线网卡第三方驱动**：Intel I225/I226 · I210/I211/I350 · Realtek RTL8125/8126 的方案对照与判据 |
| `ecosystem-sources.md` | ★★ **黑苹果生态权威来源索引**：Acidanthera / Dortania 官方 · **corpnewt 工具链**（ProperTree / GenSMBIOS / SSDTTime / USBMap）· `USBToolBox` · `blacktop/ipsw-diffs` · 驱动作者 · 中文资源 · ★ **「做什么事信谁」对照表** |
| `laobamac-toolkit.md` | **laobamac 工具与补丁索引（48 仓库全表）**：驱动 · 装机 · ★ **硬件避坑（`SimpleBuyersGuide`）** · 维护工具（`SimpleLoader`）· macOS 26 启动台 · 参考补丁（`OC-little-zh`）· AMD · fork 说明 · ★ **哪些已存档** |
| `applealc-custom.md` | 板载声卡：★★★ **macOS 26 的 `AppleHDA` 恢复（`SimpleHDA`，无需补丁）**、先搜前人经验、按 codec 定制、本地构建、提 PR |
| `hidpi.md` | 非 Retina 屏开 HiDPI：写入位置、两个模式、恢复路径、与 NVIDIA 驱动的风险 |
| `intel-turbo.md` | Intel 睿频 / 限频：★★★ **最佳方法定案（注入「删掉 `hwp` 的本机 profile」四点判据）** · **`hwp` 的真实位置与删法** · **76 份 profile 五族选型表** · CPU-S 验证 · **改完必须重启** · CPUFriend 修法 · BIOS 硬前提 |
| `e-cores.md` | **开小核 / 关小核（Intel 混合架构 P/E 核）**：★ 两种取舍 · BIOS `Active Efficient Cores`（四家厂商命名）· `ProvideCurrentCpuInfo` · **`CpuTopologyRebuild` 四取值**（`ctrsmt=off` / `ctrsmt=full` / `-ctrfixcnt`）· 判据 `hw.nperflevels` · **官方已知 `-v` 冲突** · 回滚 |
| `cpu-name.md` | **CPU 显示名（改名）**：★ 纯外观 · RestrictEvents 三件套（`revpatch=cpuname` / `revcpu=1` / `revcpuname`）· ★★ **NVRAM 优先级低于 boot-args** · `revcpuname` 只能放 NVRAM · `ProcessorType` 与核数配对 · **`Cpuid1Data` / `AppleSystemInfo.strings` 两条死路** · 排错 |
| `memory-injection.md` | 内存定制：★★ **槽位数随机型**（`MacPro7,1`=12 / `iMac20,1`=4）、**MacPro 12 槽映射表**、**摆位规则 f**、A 层通用字段 |
| `smbios-and-serials.md` | **换机型 + 三码**：★★★ **换机型必须连三码一起换**（机型名 = 序列号产品码的函数）、**连带项清单 7 项**（三码 · SSDT 前置 · CPUFriend · 内存槽位数 · ROM · **电脑名/主机名/SMB 名** · 显示名缓存）、★★★ 主板 OEM SSDT（`xh_adls3`）与 ACPI 根因、**顺序铁律（先完善 SSDT）**、检查清单、序列号判据、ROM、切换脚本三态、操作教训 |
| `theme-opencanopy.md` | **选择器主题（OpenCanopy）**：开关总表、资源目录、**图标清单（必需/可选/官方不提供）**、Flavour 规则、标签/字体/音频/背景、排错 |
| `pitfalls.md` | 全部踩过的坑 |
| `machine-facts.md` | 参考机器（Z690 / Alder Lake / macOS 26）的具体事实 |

---

## 适用性与边界

- **流程通用**：文档、校验器、样例、资源都来自官方发布包 / 官方仓库，对任何 OpenCore 机器适用。
- **参考机器事实隔离**：`opencore-config-audit/references/machine-facts.md` 记录的是**某一台机器**的事实
  （Z690 / Alder Lake / RTX 3080 / macOS 26）。换机器时按 `SKILL.md` 的**阶段 0**重新核实即可，
  不要把那份事实当成通用配置。
- **第三方工具不是权威**：RapidEFI 等工具生成的结果适合作为**起点**，仍需回到官方文档 + `ocvalidate` 复核。

## 说明

本仓库内容由作者编写，可自由用于个人与研究用途。
