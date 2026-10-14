# hackintosh-skills

黑苹果（OpenCore）相关的 WorkBuddy / CodeBuddy **Skill** 集合。

每个子目录就是一个可直接使用的 skill：把整个目录复制到你的 skills 目录即可。

## 安装

```bash
# 用户级（所有项目都能用）
cp -R opencore-config-audit ~/.workbuddy-ai/skills/
cp -R opencore-picker-theme ~/.workbuddy-ai/skills/

# 或项目级（只在该项目里可用）
cp -R <skill> <项目目录>/.workbuddy-ai/skills/
```

---

## 1. `opencore-config-audit` — OpenCore 配置审查与维护

把「改黑苹果 OpenCore 配置」从「凭经验试」变成**有文档依据、可回滚、可复验**的流程。

**能力**

- **全流程生命周期**：Windows 上用 RapidEFI 生成基础 EFI → 安装 macOS → **换成 DEBUG OpenCore** →
  收集引导期日志 → 按官方文档逐项修补 → **日常化（换回 RELEASE + 关掉 debug 日志，`-v` 询问客户）**
- **逐键对照官方文档**：按机器上的 OpenCore 版本取官方发布包，用官方 `ocvalidate` 校验，
  并把 `Configuration.tex` 里**全部 420 个配置键**的 `Type / Failsafe / Description` 抽成键库，
  逐键判定「本机取值 vs 官方默认」，分成三类：有依据的正确偏离 / 与文档相反 / 冗余残留
- **引导期取证**：读 OpenCore 自己的 `opencore-*.txt`（`Target` 位定义、`OCABC:` 判据、
  ACPI 表清单、启动项注册、APFS 驱动门槛）与 macOS 内核日志（ACPI 报错、平台设备挂载）
- **启动耗时 / 时间线分析**：把启动拆成 **OC 段 / 内核驱动段 / 用户态段**三段分开量，
  用「停顿窗口」定位卡顿（`launchd.log` 找最大空档 → **流式过滤** `log show`，绕过其时间过滤失效），
  并给出耗时来源处置表（含驱动侧 `nvrmsettle` / `-wegnoigpu` 两类已知固定延迟）
- **ACPI / SSDT 巡检**：用官方 `Docs/AcpiSamples/`（18 个样例）逐条对照本机实际设备
- **磁盘屏蔽**：`/etc/fstab` + `noauto`（按卷 UUID），**显式排除 EFI 分区**并做挂载验证
- **kext 精简**：找禁用项与孤儿文件，含「不能删」清单
- **驱动安装**：NVIDIA（NullMoth）、Intel 无线（AirportItlwm / itlwm）、
  **博通网卡**（BCM943602CDP / BCM43602 —— ★ 按 Sequoia / Tahoe 分路线，含 OCLP root patch 与前置保护）、
  从零生成基础 EFI（RapidEFI）、**HiDPI**（非 Retina 屏清晰度；★ 本机 NVIDIA 驱动未完善，含风险与恢复路径）、
  **Intel 睿频**（CPU 被压低频 → 用 CPU-S 验证 → CPUFriend 修法，含 BIOS 硬前提）、
  **MacPro 机型内存定制**（★ 分两层：「系统信息」全机型通用 /「关于本机」内存图是 MacPro 专有的**摆位规则 + 12 槽映射表**）、
  **SMBIOS 机型切换 + 三码**（★ 换机型会连带换掉内置 USB 图 ⇒ 与 UTBMap 冲突；序列号三类判据；ROM 用真实 en0 MAC；换码风控纪律）、
  **板载声卡 AppleALC**（先搜同型号前人 layout-id → 搜不到再按 codec 定制 → 本地构建 → 提 PR）

**内置的安全流程（最重要的一部分）**

改 ESP 前备份 → 先读 live 再对 diff → `plutil` 改 → `plutil -lint` → 官方 `ocvalidate` →
算 sha → 同步工作区镜像 + 版本存档 → `sync` → 卸载 → 重新挂载 → **复验 sha 一致**。

| 脚本 | 作用 |
|---|---|
| `scripts/fetch-opencore-docs.sh` | 取同版官方包（`ocvalidate` + `Sample.plist` + `AcpiSamples`）并建 420 键键库 |
| `scripts/oc-verify.sh` | 一键校验：`plutil` + `ocvalidate` + ACPI/Kexts 引用完整性 + 孤儿文件 + sha |
| `scripts/oc-swap-build.sh` | RELEASE ↔ DEBUG 换构建（连官方同名 Drivers 一起换，保留第三方驱动） |
| `scripts/oc-edit-safe.sh` | 安全改 config 的包装（`begin` 备份 / `finish` 校验存档落盘复验） |
| `scripts/grab-logs.sh` | 抓 OC 引导日志与本次开机内核日志（提权，可 `--oc-only`） |
| `scripts/boot-timeline.sh` | 启动耗时总览（NVRM 属性 + `dmesg` + launchd 时间线 + 内核日志，带超时保护） |
| `scripts/find-boot-gap.sh` | 启动停顿窗口精查（从 `launchd.log` 找最大空档 → **流式过滤** `log show`，不落大文件） |
| `scripts/mask-other-disks.sh` | 按 UUID 写 fstab 屏蔽非系统卷（默认 dry-run，永不碰 EFI） |
| `scripts/cpu-freq-probe.sh` | CPU 实际频率探针（内联汇编，防编译器折叠）—— 验证睿频 / 对比机型 |
| `scripts/mem-check.sh` | 校验内存注入摆位（数组序号 → 预测图位，判定是否与「系统信息」错位） |

参考文档：`official-docs-method.md`（含**成对关系表**）、`logs-and-debug.md`、`boot-timeline.md`（**启动耗时/时间线**）、`acpi-ssdt.md`、
`disks-and-kexts.md`、`lifecycle.md`（**六阶段全流程**）、`nvidia-driver.md`、`intel-wifi.md`、
`rapidefi-first-efi.md`、`applealc-custom.md`、`broadcom-wifi.md`、`hidpi.md`、`intel-turbo.md`、`memory-injection.md`、`smbios-and-serials.md`、`pitfalls.md`、`machine-facts.md`

---

## 2. `opencore-picker-theme` — 选择器主题（OpenCanopy）

配置、制作与排错图形启动界面：图标集、属性位、Flavour、标签、字体、音频辅助、背景、HiDPI。

**能力**

- **权威对照**：必需图标清单与尺寸（**缺一个 OpenCanopy 就不启动**）、官方图标集**不提供**哪些可选图标
  （解释了日志里那些 `OCUI: … Not Found` 为什么是正常的）、标签 / 字体 / 音频的格式要求
- **Flavour 系统**：图标选择与回退链、`Ext` 前缀的安全规则、`.contentFlavour`、`.VolumeIcon.icns` 优先级
- **PickerAttributes 全位表** + 依赖关系（如 `0x0008` 必须搭 `0x0001`）
- **排错顺序**：界面不出现 / 图标不对 / 变形 / 没有声音 / 字体异常

| 脚本 | 作用 |
|---|---|
| `scripts/oc-theme-check.sh` | Resources 树合规检查（必需图标、**真实像素尺寸**、Selector/SetDefault 同宽、标签/字体/音频） |
| `scripts/oc-fetch-iconset.sh` | 从官方 OcBinaryData 取图标集 / 字体 / 标签 / 音频 |

参考文档：`opencanopy-resources.md`、`picker-attributes.md`、`flavours.md`、`theme-troubleshooting.md`

---

## 适用性

流程本身对任何 OpenCore 机器通用（文档、校验器、样例、资源都来自官方发布包 / 官方仓库）。
`opencore-config-audit/references/machine-facts.md` 是**那一台机器**的事实，换机器时按 SKILL.md 的阶段 0 重新核实即可。

## 说明

本仓库内容由作者编写，可自由用于个人与研究用途。
