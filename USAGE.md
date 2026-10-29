# 使用与维护说明

本仓库目前提供一个技能：[opencore-config-audit](opencore-config-audit/USAGE.md)。使用者说明放在技能目录内，复制整个目录安装时会一起带上。

## 调用

安装后直接描述 OpenCore / 黑苹果任务，或使用客户端提供的手动技能入口。可用「opencore-config-audit 怎么用」查看能力说明。

安装位置、手动调用菜单、自动发现及重新加载方式由客户端决定。本仓库不把某个客户端的内部设置字段当作通用技能协议。安装与分发入口见 [README.md](README.md) 和 [PUBLISHING.md](PUBLISHING.md)。

## 维护入口

[SKILL.md](opencore-config-audit/SKILL.md) 保留任务边界、共用约束和路由；专项命令与硬件细节放在 `references/`，需要重复、确定执行的逻辑放在 `scripts/`。

- 描述写清用途与触发条件，避免把全部专题与症状堆进 `description`。
- 一个结论在对应专题维护，README 与使用说明只描述能力或链接到来源。
- 参考机器事实集中在 `references/machine-facts.md`；案例写清证据与适用范围，不当成通用默认配置。
- 只修改已请求的范围，保留用户已有授权与偏好；增加排障步骤应由当前证据支持。

## Frontmatter 与版本

技能入口使用 `name`、`description` 和 `metadata`，版本及英文说明保存在 `metadata` 中：

```yaml
---
name: opencore-config-audit
description: 审查与维护黑苹果 OpenCore EFI 配置。
metadata:
  version: "0.44.0"
  description_en: Audit and maintain hackintosh OpenCore EFI configurations.
  agent_created: "true"
---
```

`description` 是发现技能时的用途说明；`metadata.description_en` 是补充元信息，不保证客户端用它做英文路由。插件市场保留自身的 `description_en` 字段。

修改发布版本时同步：

1. `opencore-config-audit/SKILL.md` → `metadata.version`
2. `opencore-config-audit/.codebuddy-plugin/plugin.json` → `version`
3. `.codebuddy-plugin/marketplace.json` → 对应插件的 `version`

## 验证

在仓库根目录执行：

```bash
bash tools/doc-lint.sh
python3 tools/test-doc-lint.py
python3 -m unittest discover -s tools -p 'test_*.py'
```

可用 skill-creator 时，再运行其校验器：

```text
python3 <skill-creator>/scripts/quick_validate.py opencore-config-audit
```

该校验器需要 PyYAML。静态校验不能证明硬件适配正确；修改脚本后，应以临时文件和 mocks 验证成功、失败与副作用边界，不要为验证文档去挂载或改动真实 EFI。

发布前可运行 `bash tools/doc-lint.sh --with-redact`。若报告命中，逐项核实是否为身份信息或明确的教学示例；不能仅为消除报告而删除必要的通用字段说明。
