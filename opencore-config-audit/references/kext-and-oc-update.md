# 更新 kext 与 OpenCore —— 什么时候该更新、什么时候**千万别动**

> 依据：一次**完整踩坑与回滚**（把 Dortania 构建误判成「第三方重编译」→ 换成上游 release →
> 逐字节核对后发现是**降级** → 全部回滚）+ OpenCore 官方文档 + 上游驱动安装脚本逐行核对。
> ★★ **一句话**：**「更新」在黑苹果里不是好事** —— 先证明「该更新」，再动手；
> **判「这个文件是不是官方件」的最后一步，是去 grep 厂商自己的安装脚本，而不是查上游 tag。**

## 0. ★★★ 先记住这条（付过学费）

**上游 tag 查不到 ≠ 来路不明。**

实测见过一份 EFI 里有 8 个 kext 的版本号**比上游 release 高一个补丁号**，上游**逐个 404**：

| kext | EFI 里的版本 | 上游最新 release | 上游有该 tag？ |
|---|---|---|---|
| `Lilu` | **1.7.3** | 1.7.2 | ❌ 404 |
| `VirtualSMC` / `SMCProcessor` / `SMCSuperIO` | **1.3.9** | 1.3.8 | ❌ 404 |
| `WhateverGreen` | **1.7.2** | 1.7.1 | ❌ 404 |
| `RestrictEvents` | **1.1.7** | 1.1.6 | ❌ |
| `NVMeFix` | **1.1.4** | 1.1.3 | ❌ |
| `BlueToolFixup` | **2.7.3** | 2.7.2 | ❌ |

**它们全都是 Dortania `build-repo` 的构建产物** —— 该仓库**按具体 commit 构建**，
上游在最后一次 release 之后又有提交时，就把**补丁号自己 +1**。

⇒ **把它们「更新」成上游 release = 降级**（做过一次，已回滚）。

### 0.1 谁是「官方源」？—— **厂商自己的安装器说了算**

以 NullMoth（NVIDIA 驱动）为例，其安装脚本 `app/Resources/nullmoth-setup.sh` 第 100–105 行有一张 `kurl()` 表，
把驱动需要的 kext **固定到具体文件并校验 SHA-256**：

| kext | 安装器钉的源 | 包内版本 |
|---|---|---|
| `Lilu.kext` | `dortania/build-repo/releases/download/**Lilu-0515f40**/` | **1.7.3** |
| `RestrictEvents.kext` | `dortania/build-repo/releases/download/**RestrictEvents-9265e78**/` | **1.1.7** |
| `AMFIPass.kext` | `dortania/OpenCore-Legacy-Patcher/raw/main/payloads/Kexts/Acidanthera/` | 1.4.1 |
| `USBToolBox.kext` | `USBToolBox/kext/releases/download/1.2.0/` | 1.2.0 |

注释原话：

> *"Kexts the driver's OpenCore setup needs, **pinned to the same files 1401 builds with** (p1401/mirror.json)."*

**其余映射（已逐个下载比对，逐字节一致）**：

| EFI 里的版本 | Dortania tag |
|---|---|
| `VirtualSMC` / `SMCProcessor` / `SMCSuperIO` **1.3.9** | `VirtualSMC-b5c62c2` |
| `WhateverGreen` **1.7.2** | `WhateverGreen-093e76f` |
| `BlueToolFixup` **2.7.3** | `BrcmPatchRAM-6538902` |
| `NVMeFix` **1.1.4** | （同族构建） |

Lilu 那支的 zip SHA = `261aebb9dc83adb6515c96405653f53c3c50b09c89babdb91fb41f7b33a1cd2a`，
**与安装器里钉的值一字不差**。

⇒ ★★ **纪律**：判定「该不该更新某个 kext」之前，**先 grep 厂商的安装脚本 / 文档 / `mirror.json`**：
它们才是「官方源」的定义。**厂商钉死的东西一律不动。**

## 1. 判「这个 kext 是不是官方件」的四条判据（**必须一起看**）

| # | 判据 | 能证明什么 | 会怎么误判 |
|---|---|---|---|
| 1 | **上游有没有这个 tag**（`git/ref/tags/<v>`） | 是否来自上游 release | ★ **会误判** —— Dortania build-repo 的 tag 在上游查不到 |
| 2 | **构建元数据**（`DTXcode` / `DTSDKName` / `BuildMachineOSBuild`） | 是不是同一批、同一工具链 | ★ **会误判** —— Dortania 的构建机就是**老工具链**（本机这批是 `DTXcode 1420 / macosx13.1 / 21G320`，2022 年） |
| 3 | **二进制 sha256** | 与官方是否同一份 | 只能证明「不同」，**不能证明「不可信」** |
| 4 | ★★★ **厂商安装器 / 文档 / `mirror.json` 有没有钉它** | **权威答案** | —— |

**结论**：1–3 只能给出「可疑」，**只有第 4 条能定性**。
★ 反之：**若第 4 条钉了，即使 1–3 全「异常」，也不要动**。

> ★ **`DTXcode` 老 ≠ 可疑**；**版本号比官方高 ≠ 可疑**。
> 反例记牢：本机这批「可疑件」全部是**厂商指定的 Dortania 构建**，对应的是**比官方 release 更新的 commit**。

## 2. 判 DEBUG / RELEASE —— 用**体积对照**，别找字符串

下载**同版本**官方 RELEASE + DEBUG 双包，逐个比体积（**DEBUG 通常 1.2–1.9×**）：

| kext | 你手上那份 | 官方 REL | 官方 DBG | 判定 |
|---|---|---|---|---|
| `Lilu` | 543,840 | 527,456 | **978,324** | REL |
| `WhateverGreen` | 531,800 | 527,896 | 752,368 | REL |
| `RestrictEvents` | 52,848 | 52,768 | 62,408 | REL |
| `NVMeFix` | 51,312 | **51,312** | 91,320 | REL |
| `BlueToolFixup` | 41,336 | 41,296 | 42,592 | REL |

★ 比「在二进制里找 `DEBUG` 字符串」可靠得多（Release 构建里也可能残留字样）。
★ **OpenCore 本体**的 DEBUG/RELEASE 是**另一回事**（看 `opencore-version` 前缀 `DBG-` / `REL-`，见 §4）。

## 3. ★ 什么情况下**才**该更新

| 情况 | 该更新吗 |
|---|---|
| 上游发了新 release，**且厂商安装器没钉死这个 kext** | ✅ 可以（走 §5 流程） |
| 升级 macOS 大版本，需要 `MinKernel` / `MaxKernel` 版本分流的新构建 | ✅ **必须**（见 `os-upgrade-15-to-26.md`） |
| 有明确 bug fix / CVE **正对着你的症状** | ✅ 可以 |
| **厂商安装器钉死了** | ❌ **不要动**（§0.1） |
| 只是「版本号看着旧」/「习惯性全部更新」 | ❌ **不要动** |
| 驱动本体（如 NullMoth）由 App 自己管版本 | ❌ 交给 App（`/Library/NullMoth/driver-version`），**别手工换 kext** |

> ★ 教训：**「统一更新一遍」这种想法本身就是错的** ——
> 黑苹果的 kext 生态里，「厂商钉死的组合」比「最新版」重要得多。

## 4. OpenCore 本体的更新

### 4.1 先看现在是什么

```bash
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version
# 例：DBG-108-2026-09-27  ⇒ 1.0.8 的 DEBUG 构建
```

`DBG-` = DEBUG / `REL-` = RELEASE；数字是版本（`108` = 1.0.8）；后面是构建日期。

### 4.2 ★★ 换构建必须**连官方同名 Drivers 一起换**（铁律 14）

同版本下 **RELEASE 与 DEBUG 的所有 Drivers 内容都不同**（例 1.0.8：`OpenRuntime.efi` 24,576 → 36,864）。
只换 `OpenCore.efi` = **构建混搭的引导器**。
★ **第三方驱动**（如 `NullMothLogo.efi`）**保持不动**。

用 `scripts/oc-swap-build.sh`（它连 Drivers 一起换、保留第三方驱动、自动备份/校验/落盘）。

### 4.3 升级到**新版本** OpenCore 时还要做

1. **先取同版本的官方包**：`scripts/fetch-opencore-docs.sh`（拿 `ocvalidate` / `Configuration.tex` / `Sample.plist` / `AcpiSamples`）
2. ★ **`ocvalidate` 必须与机器上的 OpenCore 同版本** —— 否则校验结论无效（铁律 10）
3. **读官方 `Differences.pdf` / Release notes** 看有没有 breaking change（`Sample.plist` 的语义 diff 是最快的检查）
4. 换完跑 `scripts/oc-verify.sh`（`plutil` + `ocvalidate` + 引用完整性 + sha）
5. ★ **别忘 BIOS 侧**：新版本可能对 `ResizeGpuBars` / `ResizeAppleGpuBars` / `Kernel>Block` 有不同要求

## 5. 更新流程（安全版，一次只动一类）

1. **备份**：整个 EFI（`tgz`）+ kext 目录（**含一份版本清单 `VERSIONS-before.txt`**）
2. **记录现状**：`scripts/kext-inventory.sh` 导出每个 kext 的 `CFBundleVersion` / `DTXcode` / sha256
3. **判断该不该动**：§1 四条判据 + §3 该更新表
4. ★ **一次只动一类**：**先 kext 或先 OpenCore 本体，不要同时**
5. **改**：`rsync -a --delete` 同步 kext 目录（★ 注意它会删掉目标里不在源里的文件）
6. **自检三条**：
   - `ocvalidate` = No issues found
   - **config 里所有 `BundlePath` 都能在 `Kexts/` 找到**（引用 0 缺失）
   - **只有被改动的 kext** 的 `Info.plist` + 二进制发生变化
7. **落盘**：`sync` → **卸载** → **重挂** → 复验版本/sha 一致（FAT 有写缓存）
8. **重启后验证**：`kmutil showloaded --list-only` 对照版本；跑 `scripts/oc-verify.sh`
9. **写清回滚路径**（备份在哪、怎么还原）

## 6. 自检与坑

| 项 | 做法 |
|---|---|
| **kext 版本清单** | `scripts/kext-inventory.sh <EFI 挂载点或 Kexts 目录>` —— 版本 / `DTXcode` / 大小 / sha256 / config 引用核对 |
| ★ **shell `PATH` 会被沙箱搞坏** | 脚本里先 `export PATH=/usr/bin:/bin:/usr/sbin:/sbin`（否则 `stat` / `strings` / `grep` 会莫名 `command not found`） |
| ★ **盘号会漂** | 一律 `diskutil list \| grep "EFI EFI"` 认盘（铁律 1） |
| ★ **卸载重挂才算落盘** | FAT 写缓存（铁律 4） |
| ★ **`rsync --delete` 是双刃剑** | 它会让目标与源**完全一致** —— 别拿它同步「只应该多几个文件」的场景 |
| ★ **别在没备份时试** | 尤其 OC 本体：混搭构建 = 可能进不去选择器 |

## 7. 出处

- Dortania `build-repo`（<https://github.com/dortania/build-repo>）—— 按 commit 构建、补丁号 +1 的机制。
- 厂商安装脚本 `nullmoth-setup.sh` 的 `kurl()` 表 + `p1401/mirror.json` —— **「官方源」的实际定义**。
- OpenCore `Configuration.pdf`（`Misc>Debug` 版本号语义）+ 官方 `Differences.pdf`。
- 相关：`official-docs-method.md`（逐键对照）· `os-upgrade-15-to-26.md`（版本分流）·
  `nvidia-driver.md`（驱动本体版本由 App 管）· `disks-and-kexts.md`（kext 精简与「不能删」清单）。
