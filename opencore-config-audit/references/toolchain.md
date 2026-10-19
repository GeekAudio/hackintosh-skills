# 工具链：装什么、从哪来、缺了怎么办

> 本文件只回答三件事：**这套流程要用哪些工具** · **每个从哪来** · **缺了怎么降级**。
> 上游项目 / 作者 / 「做某件事该信谁」⇒ `ecosystem-sources.md`；具体硬件的专用工具 ⇒ 对应硬件文档。
> **先跑 `scripts/toolcheck.sh` 拿到本机现状**，再回来只看缺的那几项。

## 0. ★★ 三层来源（先分层，再谈装）

| 层 | 来源 | 装法 | 典型 |
|---|---|---|---|
| ① 系统自带 | macOS 本体 | 不用装 | `plutil` · `nvram` · `ioreg` · `kmutil` · `diskutil` |
| ② OpenCore 官方包自带 | `OpenCore-<版本>-RELEASE.zip` 的 `Utilities/` | 解压就有 | `ocvalidate` · `macserial` · `ACPIe` · `macrecovery` |
| ③ 需自备 | 上游 release / 包管理器 / 源码编译 | 见 §4 | `iasl` · `gfxutil` · `zlib-flate` · `dot` |

★★ **纪律：能落在 ①② 就不进 ③。** 黑苹果的变量已经够多，**不要为一个可选步骤引入新依赖** ——
新装一个工具就多一个版本、多一处 PATH、多一种失败方式，而这些失败会被误当成「配置改错了」。

★ 判据：**问「这一步不做会怎样」**。不做只是少了「更舒服的取证方式」⇒ 跳过；
不做会**拿不到结论**（比如要改 SSDT 却没 `iasl`）⇒ 才装。

---

## 1. 系统自带（无需安装，但有路径与版本陷阱）

| 工具 | 用在哪 | 陷阱 |
|---|---|---|
| `plutil` | 校验 / 改 plist（保持 XML、改动最小） | `-lint` 只查语法，**不查 schema**（schema 归 `ocvalidate`） |
| **`/usr/libexec/PlistBuddy`** | 读单键、改单键 | ★★ **不在 `PATH` 里**，必须写全路径；ESP 没挂载时它会打 `File Doesn't Exist, Will Create`，**看着像文件损坏，其实是没挂载** |
| `nvram` | 读 OC 版本、`boot-args`、启动项 | ★ `NVRAM>Add` 只在变量**不存在**时写（要生效须同时列进 `Delete`） |
| `ioreg` | 设备树取证（`-l -p IODeviceTree` / `IOService`） | 输出巨大，一律配 `-n` / `-r` / `grep` 收窄 |
| `kmutil` | `showloaded` 看已加载 kext | ★ **无代码 kext（`ExecutablePath` 为空）永不出现**，只能看注入结果 |
| `kextutil` | kext 依赖 / 签名诊断 | 只对**磁盘上的** kext 有意义，不对已注入到 BootKC 的生效 |
| `diskutil` | 列盘、挂载 ESP、`repairVolume` | ★ 挂载**常报 failed 但其实已挂载** ⇒ 用 `mount \| grep -i efi` 判断 |
| `shasum` | sha256 对照 | — |
| `sysctl` | `hw.nperflevels` / `machdep.cpu.*` / `kern.boottime` | ★ `kern.boottime` 早于改动时间 = **没重启**（改 CPUFriend 后必查） |
| `log` | 内核日志 | ★★ 本机 `--start/--end` 整体失效、`--last` 返回整个日志库 ⇒ **只能流式过滤**（`boot-timeline.md`） |
| `pmset` | 睡眠 / 唤醒取证 | `pmset -g log` 才是时间线，`pmset -g` 只是当前设置 |
| `spindump` | 用户态卡顿取证 | 要 root；产物很大 |
| `codesign` / `stapler` | 签名与公证验证 | ★ 本机 `spctl -a` 对第三方公证应用**一律 rejected**（SIP Custom Config ⇒ 联网评估失败）⇒ 改用 `codesign --verify --deep --strict` |
| `spctl` / `csrutil` / `tccutil` | Gatekeeper / SIP / TCC | Gatekeeper 与 TCC **是两件事**（`amfi-and-tcc.md` 附录） |
| `nm` `otool` `size` `lipo` | Mach-O 分析 | ★ 需要 **Xcode CLT 且已同意 license**；被拦时用工作区 `工具/macho_symtab.py` / `macho_deps.py` / `macho_disasm.py` |
| `xxd` | 二进制取证（`configdata`、`MuteGPIO`） | 大端/小端要自己数，别照抄别人结论 |
| `ditto` / `rsync` | 复制（保留元数据 / 资源分支） | ★ `rsync -a --delete` 会让目标与源**完全一致**，别用于「只该多几个文件」的场景 |
| `hdiutil` | 挂载 dmg（KDK、工具包） | macOS 26 上部分 dmg 需先 `hdiutil verify` |
| `defaults` / `launchctl` | 偏好 / 重载守护进程（如 `tccd`） | `launchctl kickstart -k gui/$(id -u)/<label>` 才是重载 |
| `python3` | 本 skill 所有脚本的解析层 | ★ `/usr/bin/python3`（3.9.6）；**本机 bash 3.2 没有 `mapfile`**，脚本一律 `while read` |
| `curl` | 下官方包 / 图标集 | ★ 大文件用 `curl -C -` 续传（官方 zip 常 10 MB 级） |
| `git` | 本仓库与 skill 同步 | Apple Git 2.50+；★ 无 `gh` 时走 API + 钥匙串 token |
| `unzip` / `zip` | 官方包解压 | — |

★ **`PATH` 会在沙箱里被打坏**（`stat`/`strings`/`grep` 突然 command not found）⇒
脚本开头一律 `export PATH=/usr/bin:/bin:/usr/sbin:/sbin`，再按需追加。

---

## 2. OpenCore 官方包自带（`Utilities/`）—— 解压即有，别去别处找

以官方 RELEASE 包实测（1.0.8）为例，`Utilities/` 下与本流程相关的：

| 工具 | 用途 | 注意 |
|---|---|---|
| **`ocvalidate/ocvalidate`** | config.plist 的 **schema / 类型 / 必填 / 顺序**校验 | ★★ **版本必须与机器上的 OpenCore 同版**；不同版会自报 `only compatible with OpenCore version X` |
| **`macserial/macserial`** | 生成 / 解码三码 | ★ **`macserial` 是目录，二进制在 `macserial/macserial`**；`-i <serial>` 能直接给出 `SystemModel`（换码前判产品码就靠它，见 `smbios-and-serials.md`） |
| **`ACPIe/ACPIe`** | **在 ACPI 表里搜路径**（设备存在性判定） | ★★ 见下方专条：**两种结果退出码都是 0** |
| `acdtinfo/acdtinfo` | 显示器的 `DisplayProductID` / `DisplayVendorID` | 配 HiDPI / EDID 用 |
| `macrecovery/macrecovery.py` | 下载 macOS 恢复镜像 | ★ 是 **python 脚本**（`macrecovery.py`），不是二进制；同目录有 `boards.json` |
| `kpdescribe/kpdescribe.sh` | 把 panic 里的地址翻成函数名 | ★ 需要**同版本 dSYM**，否则只能给偏移 |
| `disklabel/disklabel` | 读写磁盘标签（混合分区表场景） | 高危，动之前备份分区表 |
| `icnspack/icnspack` | 打包 `.icns`（OpenCanopy 图标） | 主题相关，见 `theme-opencanopy.md` |
| `CreateVault/` | `vault.plist` / `vault.sig`（`Misc>Security>Vault`） | 开了 Vault 就必须每次改完重签，否则**不启动** |
| `FindSerialPort/` | 找主板串口 | 黑苹果要关串口，用它定位 |
| `ShimUtils/` | shim / SBAT 相关 | 只在 Secure Boot 场景 |
| `LogoutHook/nvramdump` | 关机时 dump NVRAM | 查「NVRAM 写没写进去」 |
| `ocpasswordgen` | 生成 `Misc>Security>Password` 用的哈希 | — |
| `BaseTools/` | `EfiRom` / `GenFfs` 等 EDK2 小工具 | 做驱动时才用 |

> ★ 官方包里**没有** `iasl`，也**没有** `gfxutil` —— 这两个必须自备（§3）。

### 2.1 ★★ `ACPIe` 的正确用法（实测）

```bash
ACPIe -f <表文件.aml> <搜索路径>
```

**三种输出，退出码全是 0**：

| stdout | 含义 |
|---|---|
| `Returned offset: 66` | **找到了**（可信） |
| `EXIT: No entry found in the table.` | 没找到 —— 或表解析到某处就停了 |
| `EXIT: ACPI table is incorrect or not supported by parser!` | 表解析失败 |

★★★ **只有第一种能当结论**。后两种**无法区分「路径真的不存在」和「工具解析不了这张表」**
（实测：同一张 `SSDT-PLUG.aml`，搜 `_SB.PR00` 命中、搜 `_SB.PCI0` / `PR00` / `_SB` 全报
`ACPI table is incorrect or not supported by parser!`）⇒ **否定结论必须回 `iasl -d` 反编译确认**。
★★ 退出码恒 0 ⇒ **不能写 `if ACPIe …; then`**，只能 grep stdout。

用途：**快速初筛「某张表里有没有某个设备路径」**（例如某 OEM SSDT 里有没有 `_SB.PCI0.XHCI`），
比反编译整张表快。官方 `Configuration.pdf` 也点名 "Use `ACPIe` utility to debug"。

### 2.2 官方包里的 UEFI 工具（`EFI/OC/Tools/`）—— 在**选择器里**跑

这批不是 macOS 程序，是**引导期**的 EFI 应用：文件放 `EFI/OC/Tools/`，**还要在 `Misc>Tools` 里注册**
才出现在选择器里。

| 工具 | 用途 | 备注 |
|---|---|---|
| `OpenShell.efi` | UEFI Shell | ★ **`bcfg` 加启动项的官方路线走它**（`boot-entries.md` §7） |
| `OpenControl.efi` | 开关 OpenCore 自身特性 | 配 `Misc>Tools[].FullNvramAccess=true` 才能改 NVRAM |
| `BootKicker.efi` | 直接拉起固件启动项 / 绕过选择器 | 排「选择器看不到某项」 |
| `ControlMsrE2.efi` | 读写 MSR `0xE2` | 判 **CFG Lock 到底锁没锁** |
| `CsrUtil.efi` | **引导期**改 SIP | 与系统里的 `csrutil` 等价，但**不需要进系统** |
| `CleanNvram.efi` | 清空 NVRAM | ★ 高危：连 boot-args / 启动项一起清 |
| `MmapDump.efi` | dump 内存映射 | 查 slide / MMIO 用 |
| `GopStop.efi` | 停止 GOP 图形输出 | 显卡花屏 / 黑屏取证 |
| `ListPartitions.efi` | 列分区 | 「装系统找不到盘」时先看它 |
| `RtcRw.efi` | 读写 RTC | CMOS 相关 |
| `TpmInfo.efi` | TPM 信息 | — |
| `KeyTester.efi` | 测键位 | 键鼠异常 |
| `ChipTune.efi` / `FontTester.efi` | 蜂鸣 / 字体渲染自检 | 排「选择器不显示」时验证输出通道 |

★★ **注册才可见**：`.efi` 文件放进 `Tools/` 但 `Misc>Tools` 里没有条目 ⇒ **选择器里根本不出现**。
★★ **官方 `Sample.plist` 的 `Misc>Tools` 只有 3 条**（`UEFI Shell` / `memtest86` / `Shutdown`），
**且全是 `Enabled=false`** ⇒ 要用 `OpenControl` / `BootKicker` / `ControlMsrE2` 这些，**得自己加条目**
（`Name` / `Path` / `Arguments` / `Enabled` / `Auxiliary` / `FullNvramAccess`）。
★★ **`Auxiliary=true` 的项在 `HideAuxiliary=true` 时被折叠** ⇒ **按空格**进 Extended Mode 才看得到；
换整份 config 后**必须复查** `HideAuxiliary` 与各条 `Auxiliary`（会被覆盖）。

---

## 3. 需自备的工具（按用途分组，只列真会用到的）

### 3.1 ★★★ `iasl` —— ACPI 编译器（最常缺的一个）

**为什么必须有**：`Docs/AcpiSamples/` 里的 `.aml` 是**已编译**的，**只加不改不用 `iasl`**；
但只要你要 **改 SSDT**、**反编译 OEM 表**、**把 `.dsl` 编成 `.aml`**，就绕不过它。

**获取（按推荐度）**：

| 路线 | 命令 / 做法 | 前提 |
|---|---|---|
| **A. 官方 release 的预编译二进制** | ACPICA 的 release 页**直接给 `iasl` 与 `acpidump` 二进制** | ★★ **实测是 Linux ELF**（`/lib64/ld-linux-x86-64.so.2`）⇒ **macOS 跑不了**；只有 Linux / WSL 侧能用 |
| **B. 源码编译（macOS 上唯一可控路线）** | ★ **直接用 `scripts/get-iasl.sh`**（下源码 → 编译 → 装到 `~/bin` → 打出版本与 sha256）。手工做则在源码根目录执行官方 README 的命令：<br>`CFLAGS="-mmacosx-version-min=10.7 -O3" LDFLAGS="-mmacosx-version-min=10.7" make iasl -j $(getconf _NPROCESSORS_ONLN)`<br>产物在 `generate/unix/bin/iasl` | 有 Xcode CLT（`make` / `clang`）；实测十几秒编完 |
| **C. 包管理器** | Homebrew `acpica`（提供 `iasl`）· MacPorts `acpica` | 已装 brew / port |
| **D. 借第三方包内的二进制** | 部分 GUI / 脚本工具自带编译器（见 §3.5 各工具的包内文件） | 只作应急，**版本不可控** |

**验证**：

```bash
iasl -v        # 期望：Intel ACPI Component Architecture … Compiler version YYYYMMDD
```

**判据与坑**：

- ★ 版本看**日期串**（`YYYYMMDD`）。遇到莫名 `syntax error` 先怀疑**编译器太老**（新样例用了新语法），
  而不是「样例写错了」。
- ★ 反编译**整张 OEM 表**（DSDT / 厂商 SSDT）会因外部引用报一堆错 ⇒ 用 `-e` 补外部表，
  或**只编译自己写的 SSDT**（只引用标准命名空间，不需要外部表）。
- ★ 编译完**必须回验**：`iasl -d` 反编译回来，与源码语义对一遍；再看引导日志里这张表有没有真加载。
- ★★ **表身份由内容决定、不由文件名决定** ⇒ 改名安全，只要同步改 `ACPI>Add>Path`。

### 3.2 `gfxutil` —— 设备路径 ↔ `PciRoot(...)/Pci(...)`

**用途**：`DeviceProperties` 里的键是 `PciRoot(0x0)/Pci(0x1f,0x3)` 这种形式，`gfxutil` 能在
「IORegistry 设备」与「UEFI 设备路径」之间互转（找网卡 / 声卡 / 显卡的准确路径）。

**获取**：`acidanthera/gfxutil` 的 release 里直接有 macOS 二进制（`gfxutil-<版本>-RELEASE.zip`）。

**缺了怎么办**：`DeviceProperties` 的路径可以**从官方 Sample / Dortania 的现成值抄**，
或用 `ioreg -l -p IOService -n <设备名>` 拿 `IONameMatched` / `built-in` 位置反推；
但**精确到 function 号**时最省事的仍是 `gfxutil`。

### 3.3 声卡专用：`zlib-flate` / `dot`

| 工具 | 用途 | 获取 |
|---|---|---|
| `zlib-flate` | 解 / 压 AppleALC `configdata` 里的 zlib 数据（`<01000000…>` 那种） | 随 **qpdf** 提供（`brew install qpdf`） |
| `dot` | 画 Codec 拓扑图（`AppleALC-Guides` 的 Codec-Graph） | graphviz（`brew install graphviz` / `port install graphviz`） |

★ 两个都是**「让分析更好看」而非「不做就没结论」** ⇒ 没有就跳过，用十六进制的字段读法硬解（`applealc-custom.md`）。

### 3.4 通用小工具

| 工具 | 用途 | 缺了怎么办 |
|---|---|---|
| `jq` | 解析键库 / JSON | 用 `python3 -m json.tool` |
| `shellcheck` | 脚本静态检查 | 靠 `bash -n` + 实跑 |
| `7z` | 解 `.7z`（部分工具包） | `unzip` 不够时再装 |

### 3.5 GUI 工具（都是可选；命令行能替代的已标注）

| 工具 | 用途 | 命令行替代 |
|---|---|---|
| **ProperTree** | 改 plist 主力（带 OC 快照 / 清理） | `plutil` + `/usr/libexec/PlistBuddy` |
| **OCAT / OCAuxiliaryTools** | 跨平台 config 编辑器 + 版本升级 | `oc-swap-build.sh` + 官方包 |
| **MaciASL** | ACPI IDE（语法着色、树导航、在线补丁库） | `iasl` 命令行；★ MaciASL 需要 `iasl` 二进制（README：编译后放进项目目录作 `iasl-stable` / `iasl-dev`） |
| **Hackintool** | ACPI 表导出、USB、设备树、`layout-id` 速查 | `ioreg` / `ACPIe` / `SysReport` |
| **IORegistryExplorer** | 图形化 IOReg（Apple 官方 Additional Tools for Xcode） | `ioreg -l -p IOService` |
| **UEFITool / IFR-Extractor** | 拆 BIOS、把隐藏选项的 IFR 还原成可读文本 | 无（BIOS 层只能靠它们） |
| **RWEverything**（Windows） | 读 ACPI 表 / EC / PCI 配置空间 | 无 |
| **USBToolBox**（Win/macOS） | USB 端口映射 | `USBMap`（corpnewt） |
| **CPU-S** | 看睿频档位与实测频率 | `scripts/cpu-freq-probe.sh` |

### 3.6 Windows 侧（装机 / 取数阶段）

| 工具 | 用途 | 详见 |
|---|---|---|
| `bios-audit.ps1`（本仓库） | 只读 BIOS 审查 | `bios-settings.md` |
| **HDAU.exe** | 声卡 codec 全量取数（GUI） | `applealc-custom.md` §3.0 |
| **HDAudDev.dll** | 同上，脚本化（`SendVerbLong` 直连，免管理员） | `applealc-custom.md` §3.0.1 |
| `SSDTTime.bat` | 自动生成常用 SSDT（Windows 侧可直接 dump DSDT） | `acpi-ssdt.md` |
| `RWEverything` | 读 ACPI / EC | — |
| `USBToolBox` | USB 映射（Windows 模式） | `disks-and-kexts.md` |

### 3.7 上游脚本类工具（按需取用，别全装）

| 工具 | 用途 | 前提 / 备注 |
|---|---|---|
| `alc-verb` | **运行时**改 AppleALC 节点（调音、验证插孔映射） | 随 AppleALC 源码提供、需自行编译；流程见 `applealc-custom.md` |
| `MountEFI` | 挂 ESP | ★ macOS 26 上需提权（`/Volumes` 归 `root:wheel`） |
| `GenSMBIOS` | 三码生成（封装官方 `macserial`） | 已有官方包里的 `macserial` 时可直接用，不必再装 |
| `gibMacOS` | 下载 macOS 组件（做装机盘） | 也可用官方 `macrecovery` |
| `USBMap` / `USBToolBox` | USB 端口映射 | ★ 本机 UTBMap **缺 SS 端口**（`disks-and-kexts.md`） |
| `OCLP` | 根补丁（Wi-Fi / 声卡 / 老显卡） | ★★ **只服务真 Mac**，黑苹果出问题别指望它 |
| `ipsw` / `ipsw-diffs` | 解析 ipsw、比内核与 kext 版本差异 | ★ 发现「macOS 26 自带 MediaTek 驱动」就靠它 |

> 完整的作者 / 仓库 / ★ 数 / 「做某件事信谁」⇒ `ecosystem-sources.md`。这里只列**会真的调用的**。

---

## 4. 没有包管理器怎么装（**本机实测：无 brew、无 port**）

macOS 上新装工具，按可靠性排：

1. **官方 release 的预编译二进制**（最省事）：解压 → `chmod +x` → 放进 `~/bin`。
2. **源码编译**（`iasl` 走这条）：需要 Xcode CLT，见 §3.1 的官方命令。
3. **借第三方包内的二进制**：应急可以，**但要在报告里写明「来源与版本」**，别让它变成隐形依赖。
4. **换工具 / 换路线**：见 §6 的降级矩阵。

**装在哪**：

```bash
mkdir -p ~/bin
cp <工具> ~/bin/ && chmod +x ~/bin/<工具>
# 只在当前会话生效，避免污染系统
export PATH="$HOME/bin:$PATH"
```

★ **不要往 `/usr/local/bin` 装**：macOS 26 上 `/usr/local` 归 root，装它就要提权；
而且工具散在系统目录里，下次「到底装没装」又要重新查。

★ 验证一律用**版本命令**，不要用 `ls` 看到文件就当装好了：

```bash
iasl -v | head -2
gfxutil -h | head -3
```

---

## 5. 版本对齐纪律（★ 比「有没有装」更容易出错）

| 工具 | 必须对齐到 | 判据 |
|---|---|---|
| `ocvalidate` | **机器上正在用的 OpenCore 版本** | 运行时的 `only compatible with OpenCore version X` 提示；`nvram 4D1FDA02-…:opencore-version` 给的是 `DBG-108`/`REL-108` 这类 |
| `macserial` | 同版本官方包 | 与新机型 / 新系统同期；老版不认新机型的产品码 |
| `iasl` | 与 SSDT 样例同期或更新 | `iasl -v` 的日期串 |
| `ACPIe` / `acdtinfo` | 同版本官方包 | — |
| `kmutil` / `kextutil` | **系统自带，跟着 macOS 走** | 不要从别处拷旧版进来 |

★★ **最常见的假阳性**：拿旧版 `ocvalidate` 校验新配置 ⇒ 报一堆「未知键」，
然后去改本来正确的配置。**校验器版本不对，结论无效**。

---

## 6. 缺失时的降级矩阵

| 缺什么 | 影响 | 降级路线 |
|---|---|---|
| `iasl` | 不能改 / 编译 SSDT | 只加**官方已编译**的 `.aml`（`Docs/AcpiSamples/Binaries/`）；要定制就先用 `SSDTTime` 生成，或临时借 GUI 工具内的编译器 |
| `gfxutil` | `DeviceProperties` 路径靠猜 | 抄 Dortania / 官方 Sample 的现成值；或用 `ioreg` 反推 |
| `acpidump` | —— | ★ **macOS 上本来就没有**（ACPICA 的 `acpidump` 只在 Linux/Windows）⇒ 取表走 **`Misc>Debug>SysReport`（DEBUG 构建）** / `ACPIe` / Hackintool |
| `zlib-flate` | `configdata` 不好解 | 按字段硬解（`applealc-custom.md` 给了字段偏移） |
| `dot` | 画不出拓扑图 | 用文本拓扑表代替 |
| `ProperTree` | 改 plist 麻烦 | `plutil -replace` + `/usr/libexec/PlistBuddy`（本 skill 脚本都这么干） |
| `ocvalidate` | **不能下结论** | 先跑 `scripts/fetch-opencore-docs.sh <版本>`；★ **不许用「看起来差不多」的版本凑** |
| Xcode CLT / license 未同意 | `nm`/`otool`/`size` 被拦 | 用 `工具/macho_symtab.py` / `macho_deps.py` / `macho_disasm.py` |
| 无 `sudo`（沙箱） | 挂 ESP / 写系统库做不了 | 写 `.command` + `open`（走 LaunchServices 提权），见 `pitfalls.md` |

---

## 7. 自检与获取

```bash
scripts/toolcheck.sh                 # 表格输出：工具 / 状态 / 路径 / 版本
scripts/toolcheck.sh --oc-dir <官方包根>   # 顺带核对 ocvalidate / macserial 版本
scripts/toolcheck.sh --strict        # 缺「必需」项时退出码非 0（可接进 CI / 前置检查）
scripts/toolcheck.sh --json          # 机器可读

scripts/get-iasl.sh                  # 取 iasl：下源码 → 编译 → 装 ~/bin → 打版本与 sha256
scripts/get-iasl.sh 20260930 ~/bin   # 指定版本与安装目录
```

输出里的「必需」只包含**核心流程跑不动**的那几项（`plutil` / `PlistBuddy` / `nvram` / `ioreg` /
`diskutil` / `python3` / `ocvalidate`）；其余标「按需」，缺了按 §6 降级，**不要为了全绿去装一堆用不上的东西**。
