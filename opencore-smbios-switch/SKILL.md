---
name: opencore-smbios-switch
description: 黑苹果（OpenCore）**机型切换与三码**的完整流程：判断该不该换机型（功能收益 / 成本 / 风险）、换机型与**内置 USB 图的耦合冲突**（`AppleUSBHostMergeProperties` 合并冲突会直接开不了机）、board-id 变化带来的系统卷重建与 AGDC/AGDP 路径变化、`CPUFriendDataProvider` 数据必须同步重做、序列号（serial/MLB/UUID）生成与**三类判据**、`ROM` 必须是 `en0` 真实 MAC、换码风控纪律、以及「先换 UTBMap → 再换 SMBIOS → 再重做 CPUFriend」的正确顺序与救援路径。当任务涉及**换机型 / 改 SMBIOS / SystemProductName / BoardProduct / board-id / MacPro7,1 / iMacPro1,1 / 序列号 / serial / MLB / UUID / ROM / en0 MAC / GenSMBIOS / macserial / 三码 / iMessage 登录不了**时使用。另外，**用户问「这个技能怎么用 / 使用说明 / 有哪些能力 / 能干什么」时也适用**（此时输出技能目录下的 `USAGE.md`，不要输出内部流程）。
description_en: Full workflow for switching the SMBIOS model and regenerating board serials on a hackintosh OpenCore setup — deciding whether to switch at all, the coupling conflict between the SMBIOS model and Apple's built-in USB maps (an AppleUSBHostMergeProperties merge conflict that prevents booting), the system-volume rebuild and AGDC/AGDP path changes caused by a new board-id, why CPUFriendDataProvider data must be rebuilt in the same change, generating serial/MLB/UUID with the three-class validity check, why ROM must be the real en0 MAC, account-flagging discipline, and the correct order (UTBMap first, then SMBIOS, then CPUFriend) with a rescue path. Also applies when the user asks how to use this skill, for its usage guide, or for a list of its capabilities — in that case output the skill's USAGE.md rather than the internal workflow.
version: 1.0.0
agent_created: true
---

# OpenCore 机型切换 + 三码

## 用途

把「换机型」这件事**安全地**做掉：先判断该不该换，再把耦合在一起的三样东西
（**USB 图 / SMBIOS / CPU 电源 profile**）按正确顺序一起换，最后把三码配好并验证。

> **官方依据**：Dortania《Choosing the right SMBIOS》· USBToolBox 官方 README · 官方 `macserial`。
> 参考机器的实际台账见 `references/smbios-and-serials.md`（**已脱敏，不含真实三码**）。

> ★★ **用户问「这个技能怎么用 / 使用说明 / 有哪些能力 / 能干什么」时**：
> **直接输出同目录下的 `USAGE.md`**，**不要**把本文件的内部流程（铁律、阶段编号）原样倒给用户。

## ★★ 与「审配置 / 升系统」那个技能的分工（先说清楚，免得打架）

| | 本技能（`opencore-smbios-switch`） | `opencore-config-audit` |
|---|---|---|
| 管什么 | **换机型 + 三码**（主动去改） | 审配置 / 补 SSDT / 装驱动 / **升级系统** |
| 对机型的立场 | 换机型是**本技能的主职** | ★ **不动机型**（硬约束）—— 升级时机型一个字段都不动，不支持就加 boot-arg 绕过 |

> ⇒ 两边的说法**不矛盾**：`opencore-config-audit` 里的「不许改机型」是**它的约束**；
> 真要换机型，**换到这里来做**，而且是**独立的一次操作**，不要塞进系统升级那一次。

## ★ 铁律

0. ★★★ **改机型之前，必须先把 SSDT 完善** —— **本机是特例**：
   本机（ASUS Z690）的 BIOS 有一张 `xh_adls3` SSDT，**不先处理掉它，换机型必失败**。
   ⇒ **顺序是「先把 ACPI/SSDT 层做干净 → 再换机型」**，不是「换完再补」。
   ★ **通用化**：换机型前先审一遍 ACPI/SSDT（有没有厂商 OEM SSDT、有没有 `AE_NOT_FOUND`、
   该补的补丁表补齐），**在旧机型下就把 ACPI 层验证通过**，再动 board-id。
1. ★★ **换机型会不会「进不去系统」，先看本机有没有厂商 OEM SSDT** ——
   本机（**ASUS Z690**）的 BIOS 里有一张 `OEM Table ID = xh_adls3` 的 SSDT；换机型（board-id 变）会触发
   macOS **重新解析 ACPI 表**，而这张表在新机型下解析不过（**`HS06 AE_NOT_FOUND`**）
   ⇒ 电源管理 / ACPI 层面出问题 ⇒ **循环重启，进不去系统**（10-12 连败 6 次）。
   **修法（实测有效）= `ACPI > Delete` 删掉 BIOS 原表（`SSDT` + `OemTableId=xh_adls3`）+ `ACPI > Add` 加载打补丁的替换表**
   ★ **这是「主板特有」现象，不是普遍规律** ⇒ 先查（见 `references/smbios-and-serials.md` §2.7），别当公式背
2. **USB 端口图是「文档里的一般机制」，但本机实测不是它** ——
   Dortania 与 USBToolBox 确实说 macOS 会按「机型 + 控制器名」附加**内置 USB 图**，理论上换机型可能冲突；
   **但本机换机型失败与 USB 图无关**（USB 驱动日志全程正常、T3 图验证可用）。
   ⇒ **知道有这回事，作为排查方向之一保留；别一上来就重做整张 USB 图**（那是大工程，且不是这里的问题）
3. **必须同时重做 `CPUFriendDataProvider`** —— 机型 ↔ CPU 电源 profile 是强耦合
   （`MacPro7,1` 强制 `hwp=on` ⇒ CPU 被压在低频；换机型不重做数据 = 白换）
4. **换机型要单独一次做，不要塞进系统升级那一次** —— 升级本身已是高风险，别叠加第二个耦合改动
5. **改之前必须有救援路径**：备份整个 EFI + **备一个能用的 U 盘 EFI**（否则改坏就进不去系统）
6. **board-id 变了会触发系统卷重建 / 校验** —— 若 OCLP 已破封印，**可能卡住**
7. **三码（serial / MLB / UUID）+ `ROM` 等同于这台机器的 Apple 身份** ——
   ★★ **一律不要写进任何会公开的地方**（仓库、issue、截图、日志）。`ROM` 必须是 **`en0` 的真实 MAC**
8. **换码要克制** —— 社区风控警告：**「脏三码 + 频繁换号」是最典型的触发组合**
9. **换完视为「新硬件」** ⇒ 需重新认证，顺序：**先 FaceTime → 再信息**

## 工作流

### 阶段 1 · 决策：到底该不该换

先问三个问题（详见 `references/smbios-and-serials.md` §1）：

1. **功能收益是什么？** 若只是「想换个机型」—— Sequoia 下 `iMacPro1,1` 与 `MacPro7,1` 功能**等价**，收益为零
2. **是不是被新版系统逼的？** 若机型不在新版白名单里 —— ★ **优先考虑「保留机型 + boot-arg 绕过」**
   （`-no_compat_check` + `revpatch=sbvmm`），**不是**顺便换机型
3. **现在的基线干净吗？** 若正在跑别的实验（BAR / 重影 / 频率），**别在这时候换** —— 会污染 A/B 基线

> ★ **能不换就不换。** 换机型只在「收益明确 > 成本与风险」时才做。

### 阶段 2 · 准备（缺一样都别动手）

- [ ] ★★★ **先把 SSDT 完善（第一位，本机是特例）** ——
      ① 审一遍 ACPI 表：找**非 Apple 的厂商 OEM SSDT**（从 `SysReport/` 或 ioreg 的 ACPI 表清单里，
      `OEM Table ID` 带厂商特征，如 `xh_adls3`）；② 看日志有没有 **`AE_NOT_FOUND`**；
      ③ 该补的补丁表补齐（本机 = `ACPI>Delete` 删厂商原表 + `ACPI>Add` 加 `SSDT-XHADLS3.aml`）；
      ④ **在旧机型下先把 ACPI 层验证通过**，再往下走
- [ ] **备份整个 EFI**
- [ ] **准备可引导的 U 盘 EFI**（改坏后的唯一救援路径）
- [ ] USB 图**只有在日志明确指向它时**才动（见 `references/smbios-and-serials.md` §2.6）
- [ ] **生成新三码候选池**（官方 `macserial -m <机型>` 或等价算法；**年/周/MLB 校验位要自检通过**）
- [ ] **按三类判据筛序列号**（拿序列号去 Apple 官网查）
- [ ] **取 `en0` 的真实 MAC** 作为 `ROM`
- [ ] **生成新的 `CPUFriendDataProvider`**（用**目标机型**的 profile plist 作数据源）
- [ ] 记下**旧值**（否则回退时不知道退到哪一套）

### 阶段 3 · 换（**顺序不能变**）

```
① 先完善 SSDT / ACPI（在旧机型下做完并验证）
        ↓
② SMBIOS / PlatformInfo 换机型   →   ③ CPUFriendDataProvider 换数据
```
> ★★ **① 必须在 ② 之前完成** —— 本机（ASUS Z690）就是特例：不先处理 BIOS 的 `xh_adls3`，
> 换机型**必循环重启**（10-12 连败 6 次）。**先把 ACPI 层做干净，再动 board-id。**

- `PlatformInfo` 三处都要改：`Generic` / `SMBIOS` / `DataHub` 的 `SystemProductName`
  （用 `UpdateSMBIOSMode = Custom` 时只有 `Generic` 段生效，另两段可留空）
- `BoardProduct`（board-id）要跟着换
- 改 ESP 走**安全流程**：备份 → 改 → `plutil -lint` → `ocvalidate` → `sync` → 卸载重挂 → 复验 sha

### 阶段 4 · 验证

- **换机型前先在旧机型下确认 ACPI 层干净**（无 `AE_NOT_FOUND`、厂商 OEM SSDT 已处理）—— 这是能不能换过去的前提
- 换完**先 `-v` 开机**：若**循环重启** ⇒ 回到 ACPI 层查（厂商 OEM SSDT 没处理，见铁律 0/1）
- 起来后确认：机型（`system_profiler SPHardwareDataType`）、CPU 频率是否正常（换机型后 hwp 可能变）、USB 端口是否齐全
- 三码：`iMessage` / `FaceTime` 能否登录（**先 FaceTime → 再信息**）

### 阶段 5 · 回退

- 仍进不去 ⇒ 走备选：**保留原机型 + `-no_compat_check` + `revpatch=sbvmm`**（唯一不碰 board-id 的路）
- 彻底回退：用备份的 EFI 覆盖回去（**这就是阶段 2 必须备份的原因**）

## 资源

- `references/smbios-and-serials.md` —— **决策依据 + USB 图冲突机制 + 三码生成与判据 + 切换脚本形态 + 操作教训**
- `USAGE.md` —— **给使用者看的速查**（用户问「怎么用/使用说明/能干什么」时输出这个）

## 与其它技能的关系

- **机型 ↔ 内存图**：`PlatformInfo > Memory` 的 12 槽图**只在 MacPro 机型上**画得出来
  ⇒ 换机型后内存图的摆位规则要重新对照（见 `opencore-config-audit` 的 `references/memory-injection.md`）
- **机型 ↔ CPU 频率**：换机型后要重做 CPUFriend 数据（同上技能的 `references/intel-turbo.md`）
- **升级系统时不动机型**：那是 `opencore-config-audit` 的硬约束，见其 `references/os-upgrade-15-to-26.md` §5
