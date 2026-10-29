# hackintosh-skills

黑苹果 OpenCore 配置审查与维护技能，适用于支持 `SKILL.md` 的代理环境；仓库同时提供 WorkBuddy / CodeBuddy 插件市场清单。

以目标机器的配置、同版本官方文档与日志为依据，完成可回滚、可复验的维护。当前技能为 `opencore-config-audit`，版本 **0.44.0**。

## 能力与使用

直接描述任务，例如「审一下我的 OpenCore 配置」「开机循环重启」「这块 MT7922 怎么驱动」，或在支持的客户端中手动选择技能。

| 范围 | 支持的任务 |
|---|---|
| 配置与装机 | BIOS / UEFI、基础 EFI、config.plist 逐键审查、同版本 ocvalidate、ACPI / SSDT |
| 启动诊断 | 装不上 / 进不去、日志取证、启动耗时、固件启动项与引导盘迁移 |
| 维护与升级 | kext 清理及更新判断、OpenCore 构建切换、macOS 大版本升级、磁盘屏蔽 |
| 硬件 | NVIDIA、Intel / MediaTek / 博通无线、有线网卡、USB、AppleALC、Intel 睿频与小核 |
| 功能与外观 | AirDrop / 接力、黑苹果相关 AMFI / TCC、HiDPI、CPU 名称、内存显示、SMBIOS 与 OpenCanopy |

- [技能使用说明](opencore-config-audit/USAGE.md)：常见提问、交付结果与脚本说明。
- [技能入口](opencore-config-audit/SKILL.md)：基线、修改约束，以及全部专题和脚本的按需索引。
- [调用与维护说明](USAGE.md)：目录、frontmatter 与验证方式。
- [发布说明](PUBLISHING.md)：现有插件市场与 SkillHub 分发流程。

普通 macOS 应用问题先核实是否与 OpenCore、驱动或 AMFI 有关。参考机器的记录只作为案例，不能代替目标机器的实时检查。

## 安装

支持本仓库市场格式的 WorkBuddy / CodeBuddy 环境：

```text
/plugin marketplace add GeekAudio/hackintosh-skills
/plugin install opencore-config-audit@hackintosh-skills
```

手动安装时，复制整个 `opencore-config-audit/` 到客户端支持的技能目录，保留 `USAGE.md`、`references/` 与 `scripts/`。例如 WorkBuddy 用户目录：

```bash
mkdir -p ~/.workbuddy-ai/skills
cp -R opencore-config-audit ~/.workbuddy-ai/skills/
```

不同客户端的目录、手动调用入口及重新加载方式以各自文档为准。

## 目录与维护

```text
hackintosh-skills/
├── README.md / USAGE.md / PUBLISHING.md
├── .codebuddy-plugin/marketplace.json
├── tools/                      # 仓库维护与校验工具，不随技能安装
└── opencore-config-audit/
    ├── .codebuddy-plugin/plugin.json
    ├── SKILL.md                # 精简入口、共用约束、按需索引
    ├── USAGE.md                # 使用者说明，随技能安装
    ├── references/             # 按任务读取的专题，详见技能入口
    └── scripts/                # 检查、取证与维护脚本
```

提交前执行：

```bash
bash tools/doc-lint.sh
python3 tools/test-doc-lint.py
python3 -m unittest discover -s tools -p 'test_*.py'
```

该检查覆盖元数据一致性、文档和脚本的可发现性、本地引用及已记录的内容冲突。脚本变更还应检查 Bash 语法，并在临时目录用夹具验证相应行为；维护技能本身不需要修改真实 EFI。

维护原则：通用判据写在对应专题，入口只保留共用约束和路由；硬件案例须标明适用条件。发布版本同步 `SKILL.md` 的 `metadata.version`、插件 `version` 与市场条目的 `version`。
