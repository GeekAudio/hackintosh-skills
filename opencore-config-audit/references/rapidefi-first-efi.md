# 从零开始：在 Windows 上生成一份基础 EFI（RapidEFI）

> ★ **另一个从零生成 EFI 的选择**：`laobamac/SimpleKaruzi` —— *"一款专门用于简化 OpenCore EFI 创建过程的工具，
> 通过自动化基本设置流程并提供标准化配置"*（**AGPL-3.0**）。
> ⚠️ **2026-06-18 已存档**，不再更新。索引见 `laobamac-toolkit.md` §2。

> 工具：**`JeoJay127/RapidEFI-Tool`** —— 「一个面向普通用户的 OpenCore EFI 配置、自动生成与后期维护工具」。
> 官方自述：配置逻辑**遵循 OpenCore 官方文档与 Dortania OpenCore 安装指南**。
> 下文带引号的是 README 原文，其余是把它接进本 skill 工作流的做法。

## 0. 什么时候用这份

- 手上**还没有**任何能启动的 OpenCore EFI，要从零装黑苹果
- 手上只有 Windows（或 Linux/macOS），想在装机前先做出一份**能引导安装盘**的基础 EFI
- 已经有 EFI 只是想重做一份对照 ⇒ 也可以，但**不要直接覆盖在用的那份**

## 1. 官方定位与边界（务必先读）

- 「自动配置 EFI 依赖硬件信息、ACPI 表和内置规则判断，**生成结果适合作为基础配置，不等于最终免调试配置**。」
- 「输出 EFI 后建议**先使用备用 U 盘测试启动，不要直接覆盖正在稳定使用的 EFI**。」
- 「黑苹果安装和调试存在硬件差异，请务必**提前备份重要数据**。」
- 工具**完全免费、离线、无广告**；核心能力内置，不依赖网络（连不上 GitHub 也能跑完）
- ⇒ 结论：**它产出的是一份「可用的起点」，不是终点**。收尾仍然按本 skill 的阶段 1–2 用官方文档逐键复核

## 2. 平台与版本要求

| 运行环境 | 支持情况（README 原文要点） |
|---|---|
| **Windows** | **仅 Windows 10 及以上**（含虚拟机）；推荐，因为「硬件信息采集和自动配置流程最完整」 |
| macOS | Catalina 10.15 及以上；**运行设备显卡需支持 Metal**，不建议在 macOS 虚拟机里跑 |
| Linux | Debian 10+、Ubuntu 20.04 LTS ~ 24.04 LTS；硬件采集能力与 Windows 不同 |

- 目标 macOS 覆盖 **High Sierra 10.13 ~ Tahoe 26**
- 平台模板：Intel 台式机 0–15 代；笔记本 0–10 代（**11 代及以上核显无法驱动**）；NUC；HEDT（X58/X79/X99/X299/X599）；AMD（Bulldozer/Jaguar、Ryzen、Threadripper）
- ⚠️ README 明确建议：**在 Windows 上运行前先关掉 360、腾讯电脑管家、火绒等安全软件**，否则生成/复制文件可能被拦截
  —— 这等于**临时降低系统防护**，属于「知道自己在做什么」的操作：只在运行工具期间关，做完立刻恢复

## 3. 新手推荐流程（README 原文 6 步）

1. 打开 **配置 EFI → 自动配置 EFI**
2. 在 Windows 下点击 **刷新硬件信息**，等硬件信息加载完成；也可以导入其他电脑导出的硬件资料
3. 查看**硬件兼容性提示**，必要时进入 **EFI 设置** 调整 macOS 版本、声卡布局、SSDT 方案等
4. 点击 **输出 EFI**，等待工具生成 EFI
5. **使用备用 U 盘测试启动**
6. 需要继续调整时，用 **加工 EFI** 导入生成目录里的 `configModel`（**无需手动编辑 `config.plist`**）

> 输出 EFI 时会保存 `configModel`，后续「加工 EFI」靠它再次调整；每次成功生成还会留**历史记录**便于对比与重新导出。

**给别的电脑做 EFI**：先在目标机导出**硬件报告 + ACPI 表**，再在本工具里用 **导入硬件资料** 导入。
「没有 ACPI 表时仍可生成基础配置，但**定制 SSDT 能力会受限**」——所以尽量把 ACPI 表一起带过来。

## 4. 运行前的硬件侧准备（不在工具里，但决定成败）

- **BIOS**：Above 4G Decoding **ON**、CSM **OFF**；SATA 模式 AHCI；关闭 Secure Boot；
  视平台处理 CFG Lock / VT-d（记下当前值，后面按文档决定要不要 `AppleXcpmCfgLock` / `DisableIoMapper`）
- **目标机硬件信息要准**：CPU 型号、显卡（含 PCI ID）、有线/无线网卡型号、声卡 codec、磁盘接口
- **准备一个备用 U 盘**（测试启动专用），以及在用系统的完整备份
- 三码（Serial / MLB / UUID / ROM）**必须自己生成**（如 `macserial`），不要照抄别人的

## 5. 生成之后必须做的四件事

工具给的是基础配置，下面这些**一定要自己过一遍**（本 skill 的脚本正好干这个）：

1. **官方校验 + 逐键复核**（阶段 1–2）
   ```bash
   scripts/fetch-opencore-docs.sh <机器上的 OpenCore 版本>   # 取同版官方文档与 ocvalidate
   scripts/oc-verify.sh <EFI/OC/config.plist> ./_oc-docs-audit
   ```
   重点核对：`Kernel>Block IOPCIFamily/IONDRVSupport`、`SecureBootModel`、`csr-active-config`、
   `ResizeGpuBars`/`ResizeAppleGpuBars`、`NVRAM>Add` 的键是否都在 `Delete` 里
2. **USB 端口映射**：不要靠 `Kernel>Quirks>XhciPortLimit`（文档明确「should be avoided」）——
   用 USB 端口图（如 USBToolBox + `UTBMap.kext`）把端口限制在 15 个以内
3. **平台相关 SSDT**：按官方 `Docs/AcpiSamples/` 逐条对照本机设备再决定加不加（见 `acpi-ssdt.md`）
4. **显卡**：
   - NVIDIA **Turing 及更新** ⇒ 按 `nvidia-driver.md` 补它要求的设置（`nvfb/nvaccel` boot-args、`ResizeGpuBars`、`IONDRVSupport` 屏蔽等）
   - AMD/Intel 核显 ⇒ 按 Dortania 对应页面处理（本 skill 不覆盖）
   - 要屏蔽核显 ⇒ `-wegnoigpu`（WhateverGreen）

## 6. 接进本 skill 的安全流程

```
Windows 上生成基础 EFI（本文档）
      ↓ 拷到 U 盘，先在备用 U 盘上试启动（不要覆盖在用 EFI）
      ↓ 能进安装器 / 能进系统
挂载 ESP → scripts/oc-verify.sh 校验 → 阶段 2 逐键对照官方文档
      ↓ 每改一项：scripts/oc-edit-safe.sh begin / finish（备份 + 语义 diff + sha + 重挂复验）
      ↓ 日志取证（scripts/grab-logs.sh）：0 ACPI 报错、选择器项正确、无 OC WARN/ERROR
完成
```

## 7. 免责与信任边界

- RapidEFI **不在 OpenCore 官方项目内**，是第三方（个人）工具 ⇒ 生成结果**必须**按官方文档复核，不要因为"工具说 OK"就跳过 `ocvalidate` 与逐键比对
- 工具本身声明「仅供学习、研究和个人维护使用」，并提示生成/修改 EFI 可能导致无法启动、功能异常或数据风险
- 与所有第三方 EFI 工具一样：**先 U 盘、后内置盘；先备份、后覆盖**
