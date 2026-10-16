# 主板板载声卡定制（AppleALC）

> 依据：`acidanthera/AppleALC` 的 **README** 与 **官方 wiki**
> （`Installation-and-usage` / `Adding-codec-support` / `Supported-codecs`）+ 官方 CI 的 `.github/workflows/main.yml`
> + ★★ **`5T33Z0/AppleALC-Guides`**（14 章实操指南：dump → 拓扑图 → PathMap → PinConfig → 编译 → 测试 → PR；
> 含 **17 个现成 codec dump** · **`alc-verb` 运行时调音** · **精简到 90 KB** · **文件管理/回滚**）。
> 下文带引号的都是官方原文；标「指南」的是 `5T33Z0` 那份。
> ★ **分工**：**官方 wiki 讲「规则」**（能不能做、编号怎么留、PR 怎么提）· **`5T33Z0` 讲「怎么做」**（逐步操作）⇒ 两本并排看。
>
> ★★★ **macOS 26（Tahoe）请先读 §0.5** —— Apple 在 DP2 删了 `AppleHDA.kext`，
> **不先把它恢复回来，后面所有 layout-id 都是白试**；
> 主参考 `perez987/AppleHDA-gone-on-macOS-26-Tahoe`（KDK + MyKextInstaller / SimpleLoader）。

## 0. 两条路线（先走 A，A 走不通再走 B）

```
确定 codec 型号与 revision
   ├─ A. 先搜「有没有同型号前人做过」 ← 推荐，绝大多数情况够用
   │      找到 ⇒ 抄 layout-id，一次只试一个，重启验证
   └─ B. 没有 ⇒ 按 codec 定制 → 本地构建 → 本机测试 → 提交 PR
```

**为什么要先搜**：AppleALC 的机制是「codec 名 + layout-id」映射到一套 platform/layout 数据，
**同 codec 的不同主板通常能共用同一批 layout**，逐个试过去往往就通了 —— 比从零做 layout 省几个数量级的时间。

## 0.5 ★★★ macOS 26（Tahoe）的前置：先把 `AppleHDA` 弄回来

> 官方 README 写明 *"**macOS 26 dropped AppleHDA.kext in DP2.** AppleALC functioning on macOS 26 may
> require additional actions if AppleHDA.kext is necessary."*
> ⇒ **在 26 上，AppleALC 生效的前提是先把 `AppleHDA` 恢复回来。**
>
> ★★ **主参考：`perez987/AppleHDA-gone-on-macOS-26-Tahoe`** —— 专门讲这件事的完整指南
> （MIT；作者 `perez987` 是黑苹果圈的老手，另有 Fenvi 博通卡 / Intel AX210 / UEFI Secure Boot 等多篇同类指南）。

### 0.5.1 先理解背景（为什么板载没声音、HDMI 却有）

- **`AppleHDA.kext` 的作用**：让 macOS ① 认到板载声卡设备（扬声器 / 耳机）② 从固件读 **`Layout-ID`**
  ③ 按 Layout-ID 加载对应机型的声音映射。
- **`AppleALC` 是「在 `AppleHDA` 旁边工作」的**（通过内核注入，**不改文件系统**）
  ⇒ ★ **`AppleHDA` 一旦不存在，板载音频就整个没了**，AppleALC 也无处附着。
- **Apple 为什么敢删**：能升到 Tahoe 的**最后一批 Intel Mac 都带 T2**，音频由 T2 负责、不需要 `AppleHDA`。
  ⇒ Apple 按老习惯删掉了「受支持机型用不到」的组件。
- ★★ **判据**：**没 `AppleHDA` / `AppleALC` 时，显卡输出的数字音频（HDMI / DisplayPort）仍然可用**
  （走的是别的 kext）⇒ **「只有 HDMI 有声音、板载声卡没声音」正是这个现象**，不是声卡坏了。

### 0.5.2 方案对照

| 方案 | 做法 | 代价 |
|---|---|---|
| **USB 声卡** | 很多 USB 音频设备 **macOS 原生支持**（指南实测 Sound Blaster Play! 3，约 €15） | ★ **最省事、完全不动系统**；代价 = CPU 略高于板载、通常只有「音箱 + 麦克风」两路 |
| **★★ KDK + `MyKextInstaller`** | 用 **KDK** 里的 `AppleHDA.kext` 装回 `/System/Library/Extensions` 并重建内核集合 | **需 KDK**；要放宽 SIP（**`csr-active-config=03080000`**）；★ **系统一升级就要重装** |
| `SimpleLoader`（laobamac） | 同上，SwiftUI 界面，自带 **APFS 快照回滚**保护 | ★ 作者**已有一阵没更新、显得过时**；KDK 依赖同前 |
| **OCLP root patch** | 像根补丁一样把 `AppleHDA` 打回去 | ★ **OCLP 团队仍在早期阶段，目前还不适合普通用户**；★ 专门的实操仓库：**`5T33Z0/OCLP4Hackintosh` 的 `Enable_Features/Audio_Tahoe.md`**（`5T33Z0` 指南推荐） |
| **VoodooHDA 系**（如 `SimpleVoodooHDA`） | **完全替换**音频栈 | ★ **音质有损**（兼容面广） |
| ~~`SimpleHDA`~~（Lilu 插件注入原版 AppleHDA） | 此前本节推荐的做法 | ★ 见 §0.5.6 —— **已降为备选** |

### 0.5.3 两个 App（指南推荐的正是这两个）

| App | 作者 | 评价（指南原意） |
|---|---|---|
| **★★ `MyKextInstaller`** | **Mirone** | **首选**：界面简单易用，**可以直接在 App 里把 `AppleHDA.kext` 一起下回来**；**更新频繁、更跟得上系统**。★ 已在 GitHub，但**源码暂未公开** |
| `SimpleLoader` | laobamac | SwiftUI；**基底语言是中文**（**较新的翻译在 `perez987` 的 fork 里**，上游那份没跟上）；★ **已有一阵没更新、显得过时** |

**两者都能做两件事**：① 把 `AppleHDA.kext`（取自 **Tahoe beta 1** 或 Sequoia）装回去恢复板载音频；
② **把系统恢复到最后一个未修改的密封快照**（= 撤销）。

### 0.5.4 要求（两个 App 通用）

| 项 | 要求 |
|---|---|
| **KDK**（必需） | **同版本存在就用同版本**（例：`Kernel Debug Kit 26.2 build 25C56` 配 `macOS Tahoe 26.2 build 25C56`）；**Apple 还没发就退到最近的旧版本** |
| **`AppleALC`** | **≥ `1.9.5`**，放在 `EFI/OC/Kexts/` **并且**写进 `config.plist`（照常） |
| **`csr-active-config`** | **`03080000`**（SIP **部分**关闭） |
| **`AppleHDA.kext` 来源** | 从 **KDK** 里取，默认路径 `/Library/Developer/KDKs/<KDK 版本-构建>.kdk/System/Library/Extensions/AppleHDA.kext`；★ **macOS 15 Sequoia 安装里的那份也能用** |

> ★ **KDK 镜像**可用 `laobamac/KdkSupportPkg` 下（见 `laobamac-toolkit.md`）。

### 0.5.5 步骤与验证

1. 装好 / 合并 **KDK**（选对版本，见 §0.5.4）
2. 确认 **`AppleALC ≥ 1.9.5`** 在位、**`csr-active-config = 03080000`**
3. 打开 **MyKextInstaller** → 选 KDK → 选 `AppleHDA.kext` → 安装（会**重建内核集合**）
4. **重启** —— 不重启不生效
5. **验证**（指南给的判据）：

```bash
kextstat | grep "AppleHDA"
# 应看到（版本号随系统变）：
#   com.apple.driver.AppleHDAController            (600.2)
#   com.apple.driver.AppleHDA                      (600.2)
#   com.apple.driver.AppleHDAHardwareConfigDriver  (600.2)
```

6. 板载音频应恢复到 Sequoia 及更早的样子 ⇒ **之后才谈 `layout-id`**（从 §1 起）

### 0.5.6 ★★ 边界与提醒（务必看清）

- ★★ **系统一升级 / 重装就全丢** ⇒ **每次都要重装 `AppleHDA.kext`**（指南 Reminder 原话）。
  这与「OpenCore 注入」类方案（`SimpleHDA` / `SimpleMtkWlan`）**根本不同** —— 后者系统更新后不用重打。
- ★ **这是有意放宽系统安全边界**（SIP 部分关闭 + 往 `/System/Library/Extensions` 写）⇒ **在报告里写明**，
  并保留「用 App 里的快照回滚撤销」这条路。
- ★ **`SimpleHDA` 路线（此前本节推荐）已降为备选** —— 它是「OpenCore 注入原版 AppleHDA」的 Lilu 插件，
  好处是**不打补丁 / 不关 SIP / 不动系统卷 / 不用 KDK**；但实际障碍是：
  **作者声明不遵循任何开源协议、不允许任何二次开发**、**至今只有 `v1.0.0-alpha` 无正式版**
  （附件名还带提交短哈希），且有已知问题（Books 登录异常、状态栏重复启动）。
  ⇒ **要省事优先 USB 声卡；要在系统里恢复就按本节走 KDK + MyKextInstaller。**
- ★ **`SimpleVoodooHDA`** 仍是一条兜底（一键、兼容面广），但**音质有损**；与其它方案**二选一，不要同时装**。
  工具索引见 `laobamac-toolkit.md`。

## 1. 先确定 codec 型号、revision 与当前状态

| 环境 | 取 codec 信息的方法 |
|---|---|
| Linux | `cat /proc/asound/card0/codec#0`（**最完整的 dump 来源**） |
| Windows | 设备管理器 → 声音控制器 → 硬件 ID；或 AIDA64 的音频设备页 |
| macOS | `ioreg -l \| grep -i IOHDACodecVendorID`、`ioreg -r -c IOHDACodecDevice` |
| 找设备路径 | `gfxutil -f HDEF`（**注意本机音频设备可能叫 `HDAS`**，那就 `gfxutil -f HDAS`） |

要记下来的四项：**codec 名**（如 `ALC897`）、**`IOHDACodecRevisionID`**、**主板型号**、**目标 macOS 版本**。

## 2. 路线 A：搜前人经验（推荐）

按顺序搜，命中即停：

1. **官方支持表**：AppleALC wiki 的 `Supported-codecs`
   —— 表格列是 `Vendor | Codec | Revisions and layouts | MinKernel | MaxKernel`，
   每个 codec 都链到 `Resources/<CODEC>/Info.plist`，一眼能看出**已经有哪些 layout-id**。
   表由官方 `Tools/wiki_table.command` 生成（当前版本见页面标题，如 `v1.9.8 2026-09-30`）。
2. **搜 AppleALC 仓库的 issue / PR**：
   ```
   repo:acidanthera/AppleALC ALC897
   repo:acidanthera/AppleALC ALC897 Z690
   ```
   很多新 layout 是先以 **PR** 形式存在的，别只看已合并的。
3. **搜「主板型号 + layout-id」**：GitHub 全站（code / issues）、Dortania bugtracker、hackintosh 论坛。
   同主板的帖子通常会直接给出「机型 + macOS 版本 + `alcid=N` + 哪些口能用」。
4. **Dortania 的《Fixing Audio with AppleALC》**：官方认可的上手文档，讲了 `layout-id` 注入与排查顺序。
5. ★ **`5T33Z0/AppleALC-Guides` 的 `Codec_Dumps/`**：**17 个现成 dump**（ALC1220/215/255/257/265/269/292/295/3246/671/887/892/ALCS1200A ·
   Conexant CX20751-2/CX8050 · IDT 92HD99BXX · VIA VT2020），每个都带 **`verbs.txt` + 十进制版 + `.svg` 拓扑图**
   ⇒ **如果你的 codec 正好在里面，直接从它的节点/路由图开始**，省掉装 Linux 那一步。

命中后：**一次只改 `alcid=<N>` 一项**，重启听/看结果，再试下一个 N。别一次改一堆变量。

## 3. 路线 B：按 codec 定制（官方 wiki 的「Adding codec support」）

官方原话：*"This task is fairly simple and requires no programming skills. In short you are meant to edit a few plists, copy the necessary files, and rebuild the kernel extension using Xcode."*

### 3.0 ★★ 实战首选参考：`5T33Z0/AppleALC-Guides`（官方 wiki 讲**规则**，这份讲**怎么做**）

> <https://github.com/5T33Z0/AppleALC-Guides>（★66，**BSD-3-Clause**，2022-07 建、仍在更新）。
> **官方 wiki 是规范，这份是 14 章的完整实操**（从 dump → 拓扑图 → PathMap → PinConfig → 编译 → 测试 → 提 PR）。
> ⇒ **走定制路线时，把这份和官方 wiki 并排看**：先用官方规则判断「能不能做」，再用它的步骤做。

**它的 14 章地图**（与官方 6 步的对应）：

| 章 | 内容 | 对应官方 |
|---|---|---|
| I | Summary（**先自问「确定要做吗」**） | — |
| II | Preparations：**取 codec dump** · 工具 · 准备源码 · **配置 Xcode** | 官方 6 步前置 |
| III | **从 dump 里抽数据**（`Relevant Codec data`：Codec 型号 / Address / Vendor Id(= `CodecID`) / Pin Complex 节点 / 路由能力） | 第 1 步 |
| IV | **读懂拓扑图与信号流**（怎么找可行路径） | 第 2 步 |
| V | **做 PathMap** · `PlatformsXX.xml` 的结构（★ 见 §3.7） | 第 2–3 步 |
| VI–VII | 生成 `PlatformsXX.xml` · **把 PathMap 搬进去** · **Amp 能力（Input/Output 侧）** · 常用 Amp 设置 | 第 3 步 |
| VIII | **改/建 `layoutXX.xml`** · **`MuteGPIO` 计算（见 §3.6）** | 第 4 步 |
| IX | **做 PinConfig**（PinConfigurator 的默认法 / 改法 / 加节点两法 / Edit Node 窗口逐项解释） | 第 5 步 |
| X | **把 PinConfig 并进源码** · **找一个没人用的 Layout-ID 号** | 第 6 步 |
| XI–XII | 把 `Platforms.xml`/`layout.xml` 写进 `info.plist` · **编译 kext** | — |
| XIII | **测试与排错** | — |
| XIV | **把自己的 Layout 提交进 AppleALC 仓库** | §6 |

**★ 仓库里的现成资产（能省最多时间的部分）**：

| 目录 | 有什么 |
|---|---|
| **`Codec_Dumps/`** | ★★ **17 个现成 dump**：ALC1220 · ALC215 · ALC255(3234) · ALC257 · ALC265 · ALC269 · ALC292(ThinkPad X250) · ALC295(Dell G15 5515 / ThinkPad X1 Tablet) · ALC3246 · ALC671 · ALC887 · ALC892 · ALCS1200A · **Conexant CX20751-2 / CX8050** · **IDT 92HD99BXX** · **VIA VT2020**；每个含 `codec_dump.txt` + **十进制版** + **`verbs.txt`** + **`.svg` 拓扑图** |
| `AppleALC_Layout-ID/alc-verb_explained.md` | ★★ **`alc-verb` 运行时调音**（不重编、不重启）⇒ §3.5 |
| `AppleALC_Layout-ID/Tools/` | `Codec-Graph.zip` · `Codec-Info.zip` · `GetDumpXML.zip` · `graphviz-2.40.1.pkg` |
| `Slimming_AppleALC/` | ★ **把 AppleALC 从 3.8 MB 精简到 ~90 KB（-97%）** ⇒ §4.5 |
| `File_Management/` | 多版本备份 / 回滚工作流 ⇒ §4.5 |
| `AppleALC_Layout-ID/Testing_Notes.md` | **测试记录模板**（PinConfig / EAPD / Routing / 各口结果逐次记） |
| `AppleALC_Layout-ID/Dumping_Audio_Codec_OpenCore.md` | **不装 Linux 也能 dump** 的办法 ⇒ 下面 |

**★ 两种取 codec dump 的办法（拓扑图只能用 Linux 那份）**：

| 办法 | 做法 | 限制 |
|---|---|---|
| **① Linux（推荐）** | Ventoy 做启动盘 → 启动任意发行版「Try」→ 一条命令收集：<br>`cd ~/Desktop && mkdir CodecDump && for c in /proc/asound/card*/codec#*; do f="${c/\/*card/card}"; cat "$c" > CodecDump/${f//\//-}.txt; done && zip -r CodecDump.zip CodecDump` | ★ **只有 Linux 的 dump 能生成拓扑图**（Clover / OpenCore 的不行） |
| **② OpenCore** | 换 **DEBUG** 版 OpenCore（含同名 Drivers）→ `Misc>Debug>SysReport=true` · `UEFI>ConnectDrivers=true` · `UEFI>Drivers` 加 **`AudioDXE.efi`** → 重启（会慢些）→ ESP 根出现 `SysReport/Audio/` → **改回 RELEASE 并把那两个开关关掉** | 拿不到拓扑图，但应急可用 |

★ **两个必看的坑**：
1. **必须把文件改名成 `codec_dump.txt`**，否则转换脚本会失败；
2. 系统有 HDMI/DP 数字音频时会有**多个 dump** —— **`Codec0.txt` 才是声卡**，其余是显卡的（开头写了是 AMD/NVIDIA/Intel 的就不是）。

**★ 生成拓扑图（Codec-Graph）**：装 graphviz（`sudo port install graphviz` 或 `brew install graphviz`）→
用 **Core-i99 的 Python3 版带 GUI** 的 `Codec-Graph`（`python3 Codec-Graph.py`）→ 选 `codec_dump.txt` →
产出 **十进制版 + `.svg` 拓扑图**（★ **之后要一直用十进制版**，因为 AppleALC 的 `.xml` 里填的是十进制）。

### 3.1 要动的文件（都在 `Resources/`）

| 文件 | 作用 | 通常要不要改 |
|---|---|---|
| `Vendors.plist` | 厂商名 + id 的关联数组 | 一般不用 |
| `Kexts.plist` | 要打补丁的 kext（`Id` = CFBundleIdentifier，`Paths` = 可能的位置） | 需要时才加 |
| `CodecLookup.plist` | **靠 IORegistry 路径探测 codec**：`Tree`（从 `IOService:/PCI/AppleACPIPlatformExpert` 起，**最后一项**含 `IOHDACodecVendorID` / `IOHDACodecRevisionID`）、`controllerNum`（含 controller 属性如 `layout-id` 的路径索引）、`Detect`（是否在最后一项找 codec；**模拟控制器如 Realtek 设 YES**） | 路径对不上时才加 |
| `Controllers.plist` | 全局改音频控制器（含 HDMI）：`Vendor` / `Device` / `Name` / `Platform` / `Revisions` / `Patches[]` | 需要时才加 |
| `Resources/<CODEC>/` | **每个 codec 一个目录**，放 `Info.plist` + layout/platform 文件 | ★ 主要工作在这里 |

### 3.2 codec 目录里 `Info.plist` 的字段（官方清单）

- `Vendor`（取自 `Vendors.plist`）
- `CodecID` —— **`IOHDACodecVendorID` 的低 2 字节**
- `CodecName` —— 给人看的名字（用于日志）
- `Revisions` —— 支持的 `IOHDACodecRevisionID` 数组（可选；不填 = 不校验 revision）
- `Author` —— 修改者（可选）
- `Files`
  - `Platforms[]`：`Id`（= layout-id）、`Path`、`MinKernel` / `MaxKernel`（可选）
  - `Layouts[]`：同上
- `Patches[]`：`Count` / `Find` / `Replace` / `Name`（取自 `Kexts.plist`）/ `MinKernel` / `MaxKernel`

### 3.3 官方 6 步算法（需要 Xcode）

1. 看 `Vendors.plist` 有没有你的厂商，没有就加
2. 看 `Kexts.plist` 里要打补丁的 kext 在不在，没有就加
3. **在 IORegistry 里核对 `IOHDACodecVendorID` / `IOHDACodecRevisionID` / `layout-id` 的路径**，需要就加进 `CodecLookup.plist`
4. 在 `Resources/` 建 codec 目录，把 layout/platform 文件拷进去
5. 按 §3.2 写 `Info.plist`
6. **重建 kext**（见 §4）

### 3.4 ★ 资源编号与注释规则（官方硬规则，PR 会被照这个审）

- **Layout 1–10 保留给 Mirone / Toleda 的基础补丁**，别占：
  - 台式机 codec：Layout **1, 2, 3** = Toleda；Layout **5, 7** = Mirone
  - 笔记本 codec：Layout **1–8** = Mirone
- **自定义用户 layout = 11–99**
- **不要把 Toleda/Mirone 的资源当自定义资源塞进 11–99**（官方理由：避免重复、减小 kext 体积）
- **每条新增的 platform / layout 都要写注释**（在 codec 的 `Info.plist` 与 `PinConfigs` 里）：
  人类可读的 codec 名 + 作者（Mirone / Toleda / Custom）；**是 Custom 的必须写明机型（笔记本或主板型号）和你的名字**

### 3.5 ★★ `alc-verb`：运行时调音（**不重编、不重启**）

> 出处：`AppleALC_Layout-ID/alc-verb_explained.md`。**这是整份指南里最省时间的工具** ——
> 把「改 XML → 重编 kext → 重启 → 试听」这个循环压成「敲一行命令 → 立刻试听」。

**前提**：

1. `AppleALC.kext` + `Lilu.kext` **确实加载了**：`kextstat | grep -v com.apple` 里应能看到它们；
2. ★ **移除冲突件** —— **`VoodooHDA` 会让 AppleALC 完全失效**（老 `CodecCommander` 同理）；
3. **打开 verb 支持**（二选一）：
   - **boot-arg**：`alcverbs=1`（连同 `alcid=XX` 一起写）
   - **DeviceProperties**（更干净）：给 HDEF 路径加 **`alc-verbs = 1`**（如 `PciRoot(0x0)/Pci(0x1f,0x3)`）
4. **手上有 codec dump**（要知道目标节点的 NID、Amp-In/Out 能力、`Pin-ctls` 当前值）

**语法与常用 verb**：

```bash
alc-verb <NID> <verb> <parameter>      # 例：alc-verb 0x19 0x707 0x40
```

| verb | 作用 |
|---|---|
| **`0x707`** | **Set Pin Widget Control**（使能引脚 / 设方向） |
| `0x708` | Set Unsolicited Response（插孔检测） |
| **`0xF07`** | **Get Pin Widget Control**（读当前状态） |
| `0x500` | Set Coefficient Index（寻址处理系数） |
| `0x4XX` | Set Processing Coefficient（写系数值） |

选项：`-d <int>` 选 codec 序号（默认 0，多 codec 时用）· `-l` / `-L` 列 verb · `-q` 静默。

**四步工作流**：

1. **读现状**：`alc-verb 0x19 0xF07 0x00`
2. **试**：`alc-verb 0x19 0x707 0x40` ⇒ **立刻**在「声音设置」或发声器 App 里听（**无需重启**）
3. **迭代**：把每一条「有效」的命令**逐字记下来**（后面要用）
4. **固化**（二选一）：
   - ★ **推荐**：把 verb 序列写进 `PinConfigs.kext` 里对应条目的 **`WakeConfigData`** —— 这才是 AppleALC 的正规做法，**天然能扛重启**
   - **组合口专用**（ALC255/256/295/298）：`WakeConfigData` **管不了插拔事件** ⇒ 用 **`ALCPlugFix-Swift`** 装一个守护进程，在插孔检测事件上重发 verb

**★ 真实例子：ALC255（Layout 66）耳麦插进去没声音**

```bash
alc-verb 0x20 0x500 0x45   # 选系数索引 0x45
alc-verb 0x20 0x4d4 0x89   # 写系数：启用耳麦模式
alc-verb 0x20 0x500 0x1b   # 选系数索引 0x1b
alc-verb 0x20 0x40c 0x2b   # 写系数：配置 mic bias
alc-verb 0x57 0x500 0x03   # 节点 0x57 选系数索引 0x03
alc-verb 0x57 0x48e 0xa6   # 写系数：启用耳麦检测
```

确认「声音设置 → 输入」里有信号 ⇒ 就按上面第 4 步固化。

**★ 更硬的对照法：`dump_coeff.sh`**（AppleALC 源码 `Scripts/` 里自带）

```bash
./dump_coeff.sh 0 0x20 80      # codec 0、节点 0x20、读 80 个系数
```

**在能工作的系统（Linux / Windows）跑一次、在有问题的 macOS 再跑一次，然后 diff** ——
**差在哪几个系数，就是你要发的 verb**。这比猜快得多。

**★ 三个坑**：
1. **`alc-verb` 不在 release zip 里** —— 它跟 kext 一起编出来，产物在 `AppleALC/build/Release/`；
2. ★★ **`-alcdbg` / `-liludbg` 只在 DEBUG 构建下有效**，**release 二进制完全忽略这些参数**（想拿调试输出必须自己编 Debug 版）；
3. 命令没反应 ⇒ 先查 `alcverbs=1` 是否生效、kext 是否真加载、有没有 VoodooHDA 之类的冲突件。

### 3.6 ★ `MuteGPIO` 速查表（直接抄十进制值）

`layoutXX.xml` 里的 `MuteGPIO` 要按 codec 的 **IN VREF** 方式（50% / 80%）选值：

| NodeID | VREF=50%（Dec） | VREF=80%（Dec） | VREF=?%（Dec） |
|---|---|---|---|
| 20 | **838926356** | **1342242836** | **1677787156** |
| 21 | **838926357** | **1342242837** | **1677787157** |
| 22 | **838926358** | **1342242838** | **1677787158** |
| 23 | **838926359** | **1342242839** | **1677787159** |
| 24 | **838926360** | **1342242840** | **1677787160** |
| 25 | **838926361** | **1342242841** | **1677787161** |
| 26 | **838926362** | **1342242842** | **1677787162** |
| 27 | **838926363** | **1342242843** | **1677787163** |
| 28 | **838926364** | **1342242844** | **1677787164** |
| 29 | **838926365** | **1342242845** | **1677787165** |
| 30 | **838926366** | **1342242846** | **1677787166** |
| 31 | **838926367** | **1342242847** | **1677787167** |

规律：`50% = 0x32010000 + NID` · `80% = 0x50010000 + NID` · 第三列 = `0x64010000 + NID`（十六进制见原表）。

### 3.7 ★ `PlatformsXX.xml` 的自动切换要点

**输入 / 输出在 PathMap 层级里的分组方式，决定「插上就自动切」还是「要在系统设置里手动切」**：

- ★★ **要自动切换，它们必须在同一个 group / array 里**；
- 惯例做法：**输入建一组、输出建一组**；
- 否则就会像 VoodooHDA 那样 —— **必须手动选**。

## 4. 本地构建（照搬官方 CI 的做法）

```bash
git clone https://github.com/acidanthera/AppleALC && cd AppleALC
git clone https://github.com/acidanthera/MacKernelSDK MacKernelSDK      # 必须放到 MacKernelSDK/

# 官方 CI 的两个 bootstrap（取构建工具链）
src=$(curl -Lfs https://raw.githubusercontent.com/acidanthera/ocbuild/master/ci-bootstrap.sh) && eval "$src"
src=$(curl -Lfs https://raw.githubusercontent.com/acidanthera/Lilu/master/Lilu/Scripts/bootstrap.sh) && eval "$src"

xcodebuild -jobs 1 -configuration Release -arch x86_64
# 产物：build/Release/*.zip（内含 AppleALC.kext）
```

> 官方 CI 还会编 `-arch ACID32`（32 位），现代机器不需要；
> 官方两条命令是 `-configuration Debug` 与 `-configuration Release` 各编一次。

## 4.5 ★ 精简 AppleALC（3.8 MB → ~90 KB）与文件管理

> 出处：`Slimming_AppleALC/` 与 `File_Management/`。**官方 CI 编出来的包里有全部 640+ 个 layout、全部 codec**，
> 自己用的机器只需要**一个 codec + 自己的 layout**。

### 4.5.1 精简（-97%）

1. **删掉用不到的 codec 目录**（`Resources/` 下只留自己那个，如只留 `ALC269`）
2. **删掉用不到的 layout / Platforms**（codec 目录里只留自己在用的，如只留 18 与 39）
3. 改同目录 `Info.plist`，**把不用的 Layout / Platforms 条目删掉**（要在条目里看，或用搜索找自己那个）
4. ★★ **还要改 `PinConfig.kext`**：`Contents/Info.plist` →
   `IOKitPersonalities/as.vit.9696.AppleALC/HDAConfigDefault` 是个**数组，里面有 640+ 条** ⇒
   **只留下含自己 Layout-ID 的那几条**
5. `xcodebuild` ⇒ 产物在 `AppleALC/build/Release` ⇒ 替换 `EFI/OC/Kexts/`

> ★★ **必读警告（指南原话）**：**只有你保留下来的 layout 才可用** ——
> 如果你只留了 17，而 `config.plist` 里的 `alcid` 填的不是 17，**就是没声音**。

> ★ 附带：`Slimming_Xcode_for_Kexts.md` 教**把 Xcode 删到只剩 1/5 体积**（删掉用不到的平台 SDK）。

### 4.5.2 文件管理：让每次实验都能回滚

自己调 layout 会试很多组合，很容易记混。**指南给的工作流**（每编一次就存一档）：

1. 进 `AppleALC/build/Release`，解压出 `AppleALC-x.y.z-RELEASE.zip`
2. **给目录加序号**：`AppleALC-1.7.2-RELEASE 1`
3. 把**这次编进 kext 的四个源文件**拷进去留档：
   `PinConfigs.kext`（在 `Resources/`）· `PlatformsXX.xml` · `layoutXX.xml`（都在 `Resources/ALCXXX/`）· 同目录 `Info.plist`
4. 改源码 → 重编 → 测；不行就**序号 +1 再来一轮**
5. **回滚** = 把某个序号目录里的四个文件拷回原位 ⇒ 立刻回到那一版

★ 好处不只是回滚：**提 PR 时也不再靠猜**（哪一版有效、参数是什么，都在目录里）。
★ 配合 `AppleALC_Layout-ID/Testing_Notes.md` 的**测试记录模板**（PinConfig / EAPD / Routing / 各口结果逐次记）一起用。

## 5. 装到本机测试

1. 把编出来的 `AppleALC.kext` 放进 `EFI/OC/Kexts/`，在 `Kernel → Add` 里加条目
2. ★ **必须让 AppleALC 比 AppleHDA 先加载**（官方原话：*"remember to load AppleALC earlier than AppleHDA"*）；
   注入顺序：**Lilu → AppleALC**；`sudo kextstat` 可看实际顺序
3. ★ **Lilu 必须存在**（AppleALC 是 Lilu 插件）
4. **`layout-id` 必须自己设**：`alcid=<N>` boot-arg，或 `DeviceProperties` 注入到音频设备路径
   （位置用 `gfxutil -f HDEF` / `-f HDAS` 查）
5. ★ **官方明确禁止改名**：*"Do not use renaming HDAS to HDEF, B0D3 to HDAU, etc."* —— 直接用设备路径，别做 ACPI 改名
6. 逐个 layout 试：改 `alcid=N` → 重启 → 看结果。**一次只试一个**
7. 调试日志：
   ```bash
   # 最省事：60 秒后把 Lilu/AppleALC 日志落到 /var/log/Lilu_<版本>_<内核主>.<次>.txt
   # boot-args: -alcdbg -liludbg liludump=60
   log show --predicate 'process == "kernel" AND (eventMessage CONTAINS "AppleALC" OR eventMessage CONTAINS "Lilu")' --style syslog --source
   ```
8. 其它控制用 boot-arg：`-alcoff`（禁用）、`-alcbeta`（在未支持的系统上启用）、`alcverbs=1`（开 `alc-verb`，或 `alc-verbs` 设备属性）；
   `-x` / `-s` 也会禁用 AppleALC

> ★★ **macOS 26 特别注意**：官方 README 写明 *"macOS 26 dropped AppleHDA.kext in DP2."*
> ⇒ **在 26 上折腾板载音频，先按 §0.5 把 `AppleHDA` 恢复回来**（见 §0.5：`perez987/AppleHDA-gone-on-macOS-26-Tahoe`）。

## 6. 提交 PR

官方 README 原话：*"To support more audio codecs in the binary packages you are asked to submit your configurations. Please read the wiki for more details."*

PR 里应当包含：

- 新增/修改的 `Resources/<CODEC>/` 目录（`Info.plist` + layout / platform 文件）
- **原始 codec dump**（便于维护者复核，Linux 的 `/proc/asound/card0/codec#0` 最标准）
- **测试过的机型（主板/笔记本型号）+ macOS 版本 + 结果**（哪些端口/功能可用、哪些不行）
- layout 编号符合 **11–99**，且注释里写明**机型与作者**（见 §3.4）
- 如果动了 `Vendors.plist` / `Kexts.plist` / `CodecLookup.plist` / `Controllers.plist`，说明**为什么**
- 支持表由官方 `Tools/wiki_table.command` 生成 ⇒ 提交前确认你的 codec 条目能被正确生成

**提交纪律**（与其它上游一致）：
- **一 PR 一改动**；描述要短；用自己的话写
- 不要贴大段自动生成的内容；不要写「说一声我就改」式的空话
- 讨论渠道：README 给的 InsaneMac 主题（英文）/ AppleLife 主题（俄文）

## 7. 排错：`alc-verb` 与常见坑

| 现象 | 检查 |
|---|---|
| **`alc-verb` 命令没反应** | ① `alcverbs=1` 有没有生效（或 DeviceProperties 的 `alc-verbs=1`）；② `kextstat \| grep -v com.apple` 里 AppleALC / Lilu 在不在；③ **有没有 `VoodooHDA`（会让 AppleALC 完全失效）**；④ 用的 `alc-verb` 是不是跟当前 AppleALC 版本一起编出来的 |
| **加了 `-alcdbg` / `-liludbg` 却没有任何调试输出** | ★★ **这两个参数只在 DEBUG 构建下有效**，release 二进制**完全忽略** ⇒ 必须自己编 Debug 版 AppleALC / Lilu |
| **改了 layout 后某些口好了、另一些口坏了** | 正常过程 ⇒ 按 **§4.5.2 的文件管理工作流**每轮存一档（四个源文件），**可随时回到上一版**；配合 `Testing_Notes.md` 模板逐次记录 |
| **精简后没声音了** | ★★ **只有你保留下来的 layout 可用** —— 检查 `config.plist` 的 `alcid` 是否正是你留下的那个号 |
| **同一 codec 但插上不自动切** | PathMap 里**输入/输出没放在同一个 group/array** ⇒ §3.7 |
| **组合口（耳麦）插拔后没声音 / 麦克风不出声** | `WakeConfigData` **管不了插拔事件** ⇒ 用 **`ALCPlugFix-Swift`**；先用 `alc-verb` 试出正确序列（§3.5） |

## 8. 本机相关（避坑）

- 本机音频设备 ACPI 名是 **`HDAS`**（ASUS 命名，不是 `HDEF`），PCI 位置 `PciRoot(0x0)/Pci(0x1f,0x3)`
  ⇒ 查路径用 `gfxutil -f HDAS`；**绝不要**把 HDAS 改名成 HDEF（官方禁止）
- 本机**当前没有用板载音频**：`AppleALC.kext` 已从 `EFI/OC/Kexts` 移除（备份在工作区 `_kexts-removed-20261014/`），音频走外置声卡
  ⇒ 要用板载音频就得把它加回来（Lilu 在前、注入 `layout-id`、`alcid=N` 试）；
  ★ 本机是 **macOS 26.7.1** ⇒ **先按 §0.5 处理 AppleHDA**（§0.5），再谈 `layout-id`
- 加/删这个 kext 属于改 ESP ⇒ 一样走安全流程（备份 → 改 → 校验 → `sync`/卸载重挂 → 复验 sha）
