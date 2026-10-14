# hackintosh-skills

黑苹果（OpenCore）相关的 WorkBuddy / CodeBuddy **Skill** 集合。

每个子目录就是一个可直接使用的 skill：把整个目录复制到你的 skills 目录即可。

## 安装

```bash
# 用户级（所有项目都能用）
cp -R opencore-config-audit ~/.workbuddy-ai/skills/

# 或项目级（只在该项目里可用）
cp -R opencore-config-audit <项目目录>/.workbuddy-ai/skills/
```

## 包含的 skill

### `opencore-config-audit` — OpenCore 配置审查与维护

把「改黑苹果 OpenCore 配置」从「凭经验试」变成**有文档依据、可回滚、可复验**的流程。

**能力**

- **逐键对照官方文档**：按机器上的 OpenCore 版本取官方发布包，用官方 `ocvalidate` 校验，
  并把 `Configuration.tex` 里**全部 420 个配置键**的 `Type / Failsafe / Description` 抽成键库，
  逐键判定「本机取值 vs 官方默认」，把偏离分成三类：有依据的正确偏离 / 与文档相反 / 冗余残留
- **引导期取证**：读 OpenCore 自己的 `opencore-*.txt`（`Target` 位定义、`OCABC:` 判据、
  ACPI 表清单、启动项注册、APFS 驱动门槛）与 macOS 内核日志（ACPI 报错、平台设备挂载）
- **ACPI / SSDT 巡检**：用官方 `Docs/AcpiSamples/`（18 个样例）逐条对照本机实际设备，
  判定"还需要补哪张 SSDT"；含命名规范与设备存在性检查
- **磁盘屏蔽**：`/etc/fstab` + `noauto`（按卷 UUID），让 macOS 里只看到系统盘；
  **显式排除 EFI 分区**并做挂载验证
- **kext 精简**：找禁用项与孤儿文件，含「不能删」清单（无线三件套等）
- **调试开关**：OC 段刷屏（`Target` 的 `0x02`）与 macOS 段刷屏（`-v`）的区分与取值建议

**内置的安全流程（最重要的一部分）**

改 ESP 前备份 → 先读 live 再对 diff → `plutil` 改 → `plutil -lint` → 官方 `ocvalidate` →
算 sha → 同步工作区镜像 + 版本存档 → `sync` → 卸载 → 重新挂载 → **复验 sha 一致**。
配套 `scripts/oc-edit-safe.sh` 把这一串变成两条命令（`begin` / `finish`）。

**脚本**

| 脚本 | 作用 |
|---|---|
| `scripts/fetch-opencore-docs.sh` | 取同版官方包（`ocvalidate` + `Sample.plist` + `AcpiSamples`）并建 420 键键库 |
| `scripts/oc-verify.sh` | 一键校验：`plutil` + `ocvalidate` + ACPI/Kexts 引用完整性 + 孤儿文件 + sha |
| `scripts/oc-edit-safe.sh` | 安全改 config 的包装（`begin` 备份 / `finish` 校验存档落盘复验） |
| `scripts/grab-logs.sh` | 抓 OC 引导日志与本次开机内核日志（提权，可 `--oc-only`） |
| `scripts/mask-other-disks.sh` | 按 UUID 写 fstab 屏蔽非系统卷（默认 dry-run，`--apply` 才写，永不碰 EFI） |

**参考文档**（按需加载）

| 文件 | 内容 |
|---|---|
| `references/official-docs-method.md` | 文档取用方法、逐键判定法、**成对关系表**（别拆散） |
| `references/logs-and-debug.md` | `Target`/`DisplayLevel` 位定义、日志判据清单、刷屏归因 |
| `references/acpi-ssdt.md` | 官方 AcpiSamples 逐条适用条件、设备存在性检查、命名规范 |
| `references/disks-and-kexts.md` | 磁盘屏蔽与 kext 精简判据、「不能删」清单、主题保留 |
| `references/pitfalls.md` | 踩过的坑（症状 → 原因 → 正确做法） |
| `references/machine-facts.md` | 一台实机（ASUS Z690 / i7-12700K / RTX 3080 / macOS 26）的实测事实 |

## 适用性

流程本身对任何 OpenCore 机器通用（文档、校验器、样例都来自官方发布包）。
`references/machine-facts.md` 是**那一台机器**的事实，换机器时按 SKILL.md 的阶段 0 重新核实即可。

## 说明

本仓库内容由作者编写，可自由用于个人与研究用途。
