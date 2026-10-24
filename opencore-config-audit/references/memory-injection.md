# MacPro 机型内存定制

> ★★ **先确认机型再动手 —— 槽位数随机型变**：
> **`MacPro7,1` = 12 槽**（本文的「12 槽映射表」只适用于它）；
> **`iMac20,1` 这类消费级机型 = 4 槽**，按普通 SMBIOS Type 17 摆即可（Slot 1–4）。
> 换机型时必须**同步重做 `PlatformInfo>Memory>Devices`**，否则「关于本机」的内存图会错位
> ⇒ 见 `smbios-and-serials.md` §3.1 连带项 ④。（`PlatformInfo > Memory`）

> 依据：**一次完整破案链（配置版本 v19 → v38）** + 真机取证
> （`khronokernel/DarwinDumped` 的 MacPro7,1 dmidecode Type 17 / system_profiler 输出 + Apple 官方槽位图与配置图，
> 全部存于工作区 `内存弹窗-官方参考-20261013/`）。
>
> ★★ **本流程分两层，别混**：
> - **A 层｜系统信息（系统报告 → 内存）** —— **全机型通用**：就是标准 SMBIOS Type 17 字段，macOS 照抄
> - **B 层｜「关于本机」的内存图** —— **MacPro 机型专有**：那张 12 槽图（左图）的摆位由 **`Devices` 数组顺序**决定，
>   下面那张映射表 `f` 就是这一层的核心

---

## 1. MacPro7,1 真机 12 槽映射表（★ B 层的基础，很值得存）

| 槽号 | 真机 DeviceLocator | 通道/DIMM |
|---|---|---|
| **1** | `Slot 1 (Channel F / DIMM 1)` | F1 |
| **2** | `Slot 2 (Channel F / DIMM 2)` | F2 |
| **3** | `Slot 3 (Channel E / DIMM 1)` | E1 |
| **4** | `Slot 4 (Channel E / DIMM 2)` | E2 |
| **5** | `Slot 5 (Channel D / DIMM 1)` | D1 |
| **6** | `Slot 6 (Channel D / DIMM 2)` | D2 |
| **7** | `Slot 7 (Channel A / DIMM 2)` | **A2** |
| **8** | `Slot 8 (Channel A / DIMM 1)` | A1 |
| **9** | `Slot 9 (Channel B / DIMM 2)` | **B2** |
| **10** | `Slot 10 (Channel B / DIMM 1)` | B1 |
| **11** | `Slot 11 (Channel C / DIMM 2)` | C2 |
| **12** | `Slot 12 (Channel C / DIMM 1)` | C1 |

- 12 槽 = **6 通道 × 2 DIMM**；上组 1–6 = 通道 F/E/D，下组 7–12 = 通道 A/B/C
- ★ 下组每对里 **DIMM2 在前、DIMM1 在后**（7=A2、8=A1），这是最容易记反的地方
- 真机（8 核型）Type 16：`Number Of Devices = 12`、`Maximum Capacity 4606 GB`、ECC Single-bit
- **Apple 官方只支持 4 / 6 / 8 / 10 / 12 条**；**4 条 = 槽 3, 5, 8, 10**（每通道一条，官方 x4 图深色槽）
  ⇒ **2 条属非官方配置**，macOS 会弹「建议成对、至少四条」+ 顾问 `!` 标记 —— **这是真机行为，改位置去不掉**（要完全干净只能上 4 条官方配置）

## 2. ★★ B 层规则：摆位 = 数组序号 → 固定图位

「关于本机 → 内存」图把 `PlatformInfo/Memory/Devices` 的**第 j 个条目画到固定的第 f(j) 个图位**：

```
f = [8, 7, 10, 9, 12, 11, 5, 6, 3, 4, 1, 2]      ← 与真机 SMBIOS Type 17 的表顺序完全一致
```

| 数组第 j 项 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **画到图位** | 8 | 7 | 10 | 9 | 12 | 11 | 5 | 6 | 3 | 4 | 1 | 2 |

- **为什么真机正常**：真机固件的 Type 17 表**本来就是 f 序** ⇒ 图位 v 恰好显示 `Slot v` ⇒ 图与「系统信息」列表**天然一致**
- **为什么按 1..12 排会错位**：图位 v 显示的是数组第 `f⁻¹(v)` 项 ⇒ 图与列表对不上
  （实测：实装在第 2/8 项时，图上出现在 6/7）
- **正确做法（三步）**：
  1. 槽号用**真机编号**（1=F1 2=F2 3=E1 4=E2 5=D1 6=D2 7=A2 8=A1 9=B2 10=B1 11=C2 12=C1），**不是** 1..12 顺序号
  2. **`Devices` 数组按 f 序排列**（第 1 项 = `Slot 8`、第 2 项 = `Slot 7`、…、第 12 项 = `Slot 2`）
  3. 于是「图位 v = `Slot v` = 列表第 v 行」，**两处永远一致**，任何实装位置都能一致
- **副证**：Apple 官方 6-DIMM 截图（槽 1,3,5,8,10,12 有内存）在 f 序下占数组第 11,9,7,1,3,5 项 → 图位 1,3,5,8,10,12，**与官方截图逐位吻合**
- **一个反例（省得白试）**：**4 槽消费主板布局下「关于本机」左图不画编号、也不标占用**（三轮配置验证）
  ⇒ **要让左图标出「哪几条装了内存」，就必须用 Mac Pro 的 12 槽结构**

> 校验工具：`scripts/mem-check.sh <config.plist>` —— 读 `Devices` 数组，按 f 算出**每个条目会被画到哪个图位**，
> 并直接告出「数组顺序对不对」（槽号与预测图位不一致 = 会错位）。

## 3. A 层：系统信息（全机型通用）的字段

`PlatformInfo > Memory` 的字段就是标准 SMBIOS Type 16/17，**与机型无关**：

| 层级 | 字段 | 注意 |
|---|---|---|
| 顶层 | `Devices[]` | 一条内存 = 一个 dict；**空槽也要列**（官方 Sample 结构） |
| 顶层 | `MaxCapacity` | ★ **单位是 bytes** |
| 顶层 | `Type` / `FormFactor` / `DataWidth` / `TotalWidth` / `ErrorCorrection` | 见 OpenCore 文档 `PlatformInfo → Memory Properties` |
| 每条 | `DeviceLocator` | ★ **系统报告里显示的就是这个字符串** |
| 每条 | `BankLocator` | 为空 ⇒ 无前缀；**非空** ⇒ 显示成 `BankLocator/DeviceLocator` |
| 每条 | `Size` / `Speed` / `Manufacturer` / `SerialNumber` / `PartNumber` / `AssetTag` | ★ 键名是 **`SerialNumber`**（不是 `Serial`） |

**命名规则（真机实测）**：系统报告显示的名字 = **`DeviceLocator` 本身**（如 `Slot 7 (Channel A / DIMM 2)`）；
真机空槽的四项是 `Size: Empty / Type: Empty / Speed: Empty / Status: Empty`，
`Manufacturer / Serial Number / Part Number` 全是 **`NO DIMM`**。

> ★ **两层可以独立调**：B 层（摆位）只影响「关于本机」那张图；A 层列表**照数组写什么就显示什么**。

## 4. 示例：4 槽消费板 + MacPro 图的最终配置（★ 只作对照，别照抄）

- 参考机物理：ASUS TUF Z690-PLUS D4，**4 槽（A1/A2/B1/B2）**，SPD 实读 **两条 16GB Kingston KHX2666C16/16G 在 A2 / B2**
  （通道 A 第 2 槽、通道 B 第 2 槽）
- **物理最忠实的映射** = **Slot 7 (Channel A / DIMM 2) + Slot 9 (Channel B / DIMM 2)**（即 A2 + B2）
- **用户最终选** = **Slot 8 + Slot 2**（上组第 2 根 + 下组第 2 根，两个内存仓各一条、视觉对称）
- **现行 = v38**：12 条 `Devices`，**数组按 f 序**；实装 `Slot 8` + `Slot 2`（各自填**该内存条的真实序列号**），
  其余 10 槽 `NO DIMM`；`MaxCapacity = 68719476736`（64 GB，单位 bytes）
- **回退** = `config.plist.v16-MacPro71-CPUFriend`（**无** `PlatformInfo/Memory` 段）

## 5. 踩过的坑（都写下来，别再试）

| 坑 | 事实 |
|---|---|
| 以为「槽号 = 数组顺序号」 | **数组序号决定图位**（见 §2），槽号必须用真机编号 |
| v32 崩 `SPMemoryReporter`（显示「收集此信息时出错」） | 当时是「**空 `BankLocator` + 纯 `Slot N` 命名**」；真机可用组合是「**空 `BankLocator` + 完整 Locator 串**」（v34 起验证 OK） |
| 想靠改位置去掉「至少四条」警告 | **去不掉** —— 那是 macOS 对「2 条」这种非官方配置的固定行为，真机也一样 |
| 用户看到「两处位置不一致」 | 真相是 **顾问动画**（不是配置问题）；稳态下两处一致 |
| 用 4 槽消费主板布局 | 左图**不画编号、不标占用** ⇒ 拿不到「哪条装了内存」的可视化 |
| `MaxCapacity` 写成 GB | **单位是 bytes** |
| 键名写 `Serial` | 是 **`SerialNumber`** |

## 6. 验证方法

```bash
# A 层：系统信息列表（应为 12 行，实装两条有容量、其余 Empty）
system_profiler SPMemoryDataType | head -60

# B 层：拿 config 里的数组算出「会被画到哪个图位」，并与槽号比对
scripts/mem-check.sh /Volumes/EFI/EFI/OC/config.plist
```

然后**肉眼对照**：「关于本机 → 内存」左图里哪几个槽有内存，应与 `Slot v` 一致、且与系统信息列表逐行一致。
