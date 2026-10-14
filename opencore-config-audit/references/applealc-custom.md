# 主板板载声卡定制（AppleALC）

> 依据：`acidanthera/AppleALC` 的 **README** 与 **官方 wiki**
> （`Installation-and-usage` / `Adding-codec-support` / `Supported-codecs`）+ 官方 CI 的 `.github/workflows/main.yml`。
> 下文带引号的都是官方原文。

## 0. 两条路线（先走 A，A 走不通再走 B）

```
确定 codec 型号与 revision
   ├─ A. 先搜「有没有同型号前人做过」 ← 推荐，绝大多数情况够用
   │      找到 ⇒ 抄 layout-id，一次只试一个，重启验证
   └─ B. 没有 ⇒ 按 codec 定制 → 本地构建 → 本机测试 → 提交 PR
```

**为什么要先搜**：AppleALC 的机制是「codec 名 + layout-id」映射到一套 platform/layout 数据，
**同 codec 的不同主板通常能共用同一批 layout**，逐个试过去往往就通了 —— 比从零做 layout 省几个数量级的时间。

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

命中后：**一次只改 `alcid=<N>` 一项**，重启听/看结果，再试下一个 N。别一次改一堆变量。

## 3. 路线 B：按 codec 定制（官方 wiki 的「Adding codec support」）

官方原话：*"This task is fairly simple and requires no programming skills. In short you are meant to edit a few plists, copy the necessary files, and rebuild the kernel extension using Xcode."*

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

> ★ **macOS 26 特别注意**：官方 README 写明 *"macOS 26 dropped AppleHDA.kext in DP2. AppleALC functioning on macOS 26 may require additional actions if AppleHDA.kext is necessary."*
> ⇒ 在 26 上折腾板载音频前，先确认 AppleHDA 这条链路是否存在（本机就是没有用板载音频）。

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

## 7. 本机相关（避坑）

- 本机音频设备 ACPI 名是 **`HDAS`**（ASUS 命名，不是 `HDEF`），PCI 位置 `PciRoot(0x0)/Pci(0x1f,0x3)`
  ⇒ 查路径用 `gfxutil -f HDAS`；**绝不要**把 HDAS 改名成 HDEF（官方禁止）
- 本机**当前没有用板载音频**：`AppleALC.kext` 已从 `EFI/OC/Kexts` 移除（备份在工作区 `_kexts-removed-20261014/`），音频走外置声卡
  ⇒ 要用板载音频就得把它加回来（Lilu 在前、注入 `layout-id`、`alcid=N` 试）
- 加/删这个 kext 属于改 ESP ⇒ 一样走安全流程（备份 → 改 → 校验 → `sync`/卸载重挂 → 复验 sha）
