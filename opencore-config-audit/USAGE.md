# opencore-config-audit —— 使用说明

> 给**使用者**看的速查。技术细节在 `SKILL.md` 与 `references/` 里，不用管。

## 怎么用

**直接用自然语言说需求就行**，不用记技能名、不用记命令。系统会自己挑到它。

也可以手动指定：输入框打 **`/`** → 选 `opencore-config-audit`；或点输入框左下角 **`+` → 技能**。

## 说这些话就会触发

| 你想做什么 | 直接这么说 |
|---|---|
| **查 BIOS** | 「帮我审一下 BIOS 设置」「装系统找不到硬盘」「CFG Lock 要不要关」 |
| 审配置 | 「审一下我的 OpenCore 配置」「校验一下 config.plist」 |
| 补 SSDT | 「看日志还有没有要补的 SSDT」 |
| 查开机慢 | 「开机很慢，分析一下时间线」「卡在苹果 logo」 |
| **启动项没了** | 「BIOS 里看不到 OpenCore 了」「只剩 Windows」「用 U 盘引导后启动项消失」 |
| 精简 | 「kext 精简一下，不用的删掉」「屏蔽一下其它磁盘」 |
| 装驱动 | 「装 NVIDIA 驱动」「Intel 无线网卡怎么配」「我这块 MT7922 能用吗」「博通网卡怎么配」「有线网卡/2.5G 网卡怎么驱动」 |
| 调 CPU | 「CPU 频率被压住了」「睿频怎么开」 |
| **换机型 / 三码** | 「换一下 SMBIOS 机型」「三码怎么配」「序列号怎么生成」「ROM 填什么」「换了机型开不了机」 |
| 升系统 | 「从 15 升到 26 要改什么」「升级后 Wi-Fi 没了」 |
| 换构建 | 「从 release 换成 debug 版 OpenCore 并开日志」 |
| **换主题** | 「换个 OpenCore 主题」「图标集怎么装」「选择器界面不出现」「图标显示不对/变形」「启动没有声音」「PickerAttributes 怎么配」 |
| 首次装机 | 「第一次装黑苹果，EFI 怎么生成」 |

## 你会拿到什么

- **审查报告**：每个结论都对着官方文档 / 官方校验器，不是「经验之谈」
- **可回滚的改动**：改之前备份、改完算 sha、卸载重挂复验 —— 出问题能退回
- **校验过的清单**：SSDT 该加哪个、kext 该删哪个，逐条给依据
- **分析文档**：启动耗时、日志取证这类会落成文件

## 配套脚本（14 个）

| 脚本 | 作用 |
|---|---|
| `bios-audit.ps1` | **Windows 侧 BIOS 审查（只读）** —— 在 Windows 里先跑这个 |
| `fetch-opencore-docs.sh` | 取同版官方包 + 建配置键库 |
| `oc-verify.sh` | 一键校验（`plutil` + `ocvalidate` + 引用完整性 + sha） |
| `oc-swap-build.sh` | RELEASE ↔ DEBUG 换构建 |
| `oc-edit-safe.sh` | 安全改 config（备份 / 校验 / 存档 / 重挂复验） |
| `grab-logs.sh` | 抓引导日志与内核日志 |
| `boot-timeline.sh` | 启动耗时总览 |
| `find-boot-gap.sh` | 启动停顿窗口精查 |
| `mask-other-disks.sh` | 按 UUID 屏蔽非系统卷 |
| `cpu-freq-probe.sh` | CPU 实际频率探针 |
| `mem-check.sh` | 校验内存注入摆位 |
| `redact-check.sh` | **发布前脱敏自检**（扫三码 / MAC / 密钥等） |
| `oc-theme-check.sh` | **Resources 树合规检查**（必需图标 / 真实像素尺寸 / 标签 / 字体 / 音频） |
| `oc-fetch-iconset.sh` | 从官方 OcBinaryData 取图标集 / 字体 / 标签 / 音频 |

## 参考文档（26 份）

按主题挑：`bios-settings.md`（BIOS）· `lifecycle.md`（全流程）· `os-upgrade-15-to-26.md`（升系统）·
`nvidia-driver.md` · `intel-wifi.md` · `mediatek-wifi.md` · `broadcom-wifi.md`（四类网卡/显卡）·
`applealc-custom.md`（声卡）· `hidpi.md`（显示）· `intel-turbo.md`（CPU）· `memory-injection.md`（内存）· `boot-timeline.md` / `logs-and-debug.md`（日志）· `boot-entries.md`（启动项）·
`acpi-ssdt.md` · `disks-and-kexts.md` · `official-docs-method.md` · `rapidefi-first-efi.md` ·
`smbios-and-serials.md`（换机型 + 三码）· `network-en0-order.md`（`en0` 归属）· `ethernet-drivers.md`（有线网卡）· `ecosystem-sources.md`（**权威来源与工具索引**）· `laobamac-toolkit.md`（工具索引）· `pitfalls.md`（踩过的坑）· `theme-opencanopy.md`（选择器主题）· `machine-facts.md`（参考机器事实）

## 注意

- 这个技能会**改你的 EFI**。改动都走安全流程（备份 → 校验 → 复验），但**请自己留一份 EFI 备份**。
- 涉及安全边界的改动（放宽 SIP、`SecureBootModel=Disabled`、AMFI 参数）会在报告里明确写出来。
- `-v` 要不要开、选择器主题这类**你能看见的偏好**，会先问你，不会替你决定。
