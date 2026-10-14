# 全流程：从 Windows 生成 EFI 到修补完成

黑苹果不是「一次配好」，而是**六个阶段**。按这个顺序走，每一步都有明确的产出和判据。

```
① Windows 上生成基础 EFI ──► ② 用它安装 macOS ──► ③ 进系统后换成 DEBUG OpenCore
                                                          │
                                          ⑤ 按官方文档逐项修补 ◄── ④ 收集引导期日志
                                                          │
                                          ⑥ 日常化：换回 RELEASE + 关掉 debug 日志
```

| 阶段 | 在哪做 | 产出 | 对应本 skill |
|---|---|---|---|
| ① 生成基础 EFI | Windows | 一份能引导安装盘的 EFI | `rapidefi-first-efi.md` |
| ② 安装 macOS | 目标机 | 能进桌面的系统 | —（安装本身不在本 skill 范围） |
| ③ 换 DEBUG OpenCore | macOS 里（改 ESP） | 能产出完整日志的引导器 | `scripts/oc-swap-build.sh` + 本文 §3 |
| ④ 收集日志 | macOS 里 | OC 引导日志 + 内核日志 | `scripts/grab-logs.sh` + `logs-and-debug.md` |
| ⑤ 修补 | macOS 里（改 ESP） | 逐项修正后的 config/SSDT/kext | SKILL.md 阶段 1–8 |
| ⑥ 日常化 | macOS 里（改 ESP） | 快启动 + 安静屏幕的成品 | 本文 §6 + `scripts/oc-swap-build.sh release` |

---

## ① 在 Windows 上生成基础 EFI

见 `rapidefi-first-efi.md`。要点复述：

- 用 **RapidEFI-Tool**：「刷新硬件信息 → 自动配置 EFI → 输出 EFI」，拿到**基础配置**
- ★ 官方自述边界：**「适合作为基础配置，不等于最终免调试配置」**、**「先用备用 U 盘测试启动，不要直接覆盖正在稳定使用的 EFI」**
- 阶段①**不要**追求完美：先能进安装器、能进桌面。剩下的都留到阶段⑤

## ② 用它安装 macOS

- 装机阶段用**安装器安全设置**：`ResizeAppleGpuBars = 0`、`ResizeGpuBars = -1`、**不**屏蔽 `com.apple.iokit.IONDRVSupport`
  （安装器跑在固件 framebuffer 上，大 BAR 会让它卡在 PCI configuration）
- 装完、能进桌面之后，才切到「驱动/日常」那套设置（大 BAR、屏蔽 IONDRVSupport 等）

## ③ 换成 DEBUG OpenCore（本阶段的关键动作）

### 为什么必须换

| | RELEASE | DEBUG |
|---|---|---|
| `OpenCore.efi` 大小（1.0.8 实测） | 626,688 B | **868,352 B** |
| `BOOTx64.efi` | 24,576 B | **53,248 B** |
| `Drivers/*.efi`（同一版本，实测） | 小 | **全部更大**（例：`OpenRuntime.efi` 24,576 → 36,864；`OpenCanopy.efi` 114,688 → 151,552） |
| 日志量 | 少 | **多得多**（一次开机可写满 ESP 上 256 KB 的 `opencore-*.txt`） |
| `Misc>Debug>SysReport` | **不可用**（文档明确：RELEASE 构建不提供） | **可用** —— 会在 ESP 上生成 `SysReport/`，含 ACPI / SMBIOS / 音频 codec 转储 |
| 启动速度 | 快 | 慢一点（日志生成开销） |

⇒ **要「收集日志再修补」，就得先换 DEBUG**；`SysReport` 更是在阶段⑤里用来拿到 DSDT/SSDT 原件的唯一省事途径。

### 怎么换（`scripts/oc-swap-build.sh` 已封装）

1. **确认当前版本**：`nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version`
   - `DBG-108-2026-09-27` → 版本 **1.0.8**、构建 **DEBUG**（`DBG-` 前缀）
   - `1.0.8-2026-09-27` → 版本 1.0.8、构建 RELEASE
2. **下载同版本**的官方 `OpenCore-<ver>-DEBUG.zip`（或 `-RELEASE.zip`）
3. **备份**现有的 `EFI/OC/OpenCore.efi`、`EFI/BOOT/BOOTx64.efi`、`EFI/OC/Drivers/`
4. **替换三处**：
   - `EFI/OC/OpenCore.efi`
   - `EFI/BOOT/BOOTx64.efi`
   - `EFI/OC/Drivers/` 里**与官方同名的那些**（★ **保留第三方驱动**，例如驱动安装 App 放的 `NullMothLogo.efi`）
   - ⚠️ **两边的驱动内容是不一样的**（上面表格已实测），所以换构建**必须**连驱动一起换，否则会版本/构建混搭
5. **校验**：新文件的 sha 必须与官方包里的同名文件一致
6. **重启**（换引导器必须重启才生效）
7. **重启后验证**：
   ```bash
   nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version   # 应变成 DBG-<ver>-<日期>
   shasum -a 256 /Volumes/EFI/EFI/OC/OpenCore.efi                 # 应与官方 DEBUG 包一致
   ```

### 换完之后顺手做的两件事

- **打开 `Misc>Debug>SysReport`（一次性）**：重启后 ESP 上会出现 `SysReport/`，里面有 **ACPI 表（DSDT/SSDT）、SMBIOS、音频 codec** 转储 —— 阶段⑤ 要判断「该补哪张 SSDT」时，这些就是一手材料。**拿完就关掉**（它只在 DEBUG 下可用，且会占空间）
- **配好日志去向**：`Misc>Debug>Target` 建议 `69 (0x45)` = 记录 + DataHub + **文件**（不上屏，见 `logs-and-debug.md`）
  —— 想在屏幕上看就把 `0x02` 加回去（`71`），但那是**另一件事**，和日志是否完整无关

### 什么时候换回 RELEASE

**修补完成、机器稳定之后**就换回去（这就是阶段⑥）：启动更快、日志更少。
换之前先确认：`Misc>Debug>SysReport` 已关（RELEASE 下它本来就无效），且不再需要每次开机的完整日志。
（本机实测：DEBUG 的 `OpenCore.efi` 与官方 DEBUG 包**逐字节一致**，所以这个换动是干净、可回滚的。）

## ④ 收集日志

跑 `scripts/grab-logs.sh`（`--oc-only` 可先只看 OC 那部分）。产出：

- `oc-boot-log-summary.txt` —— 从 ESP 根 `opencore-*.txt` 里筛出的关键行（`OCABC:` 判据、ACPI 表清单、启动项注册、`OCJS: APFS` 门槛、`OC:` 错误）
- `kernel-log-acpi.txt` —— 本次开机内核日志里的 ACPI 报错、macOS 解析到的表、平台设备挂载、ACPI 平面设备存在性

**判读方法见 `logs-and-debug.md`**。三条最快的判据：

1. **ACPI 报错 0 命中** ⇒ 没有"坏掉的 ACPI"，不用急着补 SSDT
2. `OCB: Registering entry <名字>` ⇒ 选择器里**实际**有哪些启动项（"屏蔽"效果的唯一可靠依据）
3. `OCABC: MAT support is 1` / `Only N/M slide values are usable!` ⇒ 直接决定 `EnableWriteUnprotector`、`ProvideCustomSlide` 该怎么设

## ⑤ 修补

回到 SKILL.md 的 **阶段 1–8**，按这个顺序：

1. **阶段 1–2**：取同版官方文档 + `ocvalidate` 校验 + 逐键对照（找出「与文档相反」的项）
2. **阶段 3**：日志取证（上面 ④ 的产出）
3. **阶段 5**：ACPI/SSDT 巡检（用 `SysReport/` 里的 DSDT/SSDT 对照官方 `AcpiSamples`）
4. **阶段 4**：每改一项走 `oc-edit-safe.sh begin/finish`
5. **阶段 6–7**：磁盘屏蔽、kext 精简（收尾整洁）
6. **阶段 8**：装/调驱动（NVIDIA、Intel 无线）

### 修补的节奏（重要）

- **一次只改一项**，改完重启验证，再改下一项 —— 否则出问题无法归因
- 每一项都在报告里写清：**改了什么 / 文档依据 / 怎么回滚**
- 保留「**明确不动**」清单（含理由），避免下次有人把这些"改回默认"改坏
- 引导期的问题（`EXITBS:START` 卡住、选择器不出现）**先看 ESP 根的 `opencore-*.txt`**，别猜

---

## ⑥ 日常化：换回 RELEASE + 关掉 debug 日志

修补完成后，把机器从「排障态」切回「日常态」：**换引导器构建** + **关日志** + **确认 `-v` 偏好**。

### 6.1 换回 RELEASE

```bash
scripts/oc-swap-build.sh release     # 自动从 NVRAM 推断版本；备份 + 替换 OpenCore.efi/BOOTx64.efi/官方同名 Drivers + 校验 sha
# 重启后确认：
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version    # 期望 1.0.8-2026-09-27（没有 DBG- 前缀）
```

### 6.2 关掉 debug 日志（配置侧）

把 `Misc>Debug` 回到**官方 `Sample.plist` 的默认值**——这就是「日常态」：

| 键 | 日常值 | 说明 |
|---|---|---|
| `Target` | **`3`** = `0x01`+`0x02` | 只留「记录 + 控制台」⇒ **不再往 ESP 写 `opencore-*.txt`**（关键：去掉 `0x40`） |
| `DisplayLevel` | `2147483650` = `0x80000002` | ERROR + WARN（去掉 INFO） |
| `AppleDebug` | `false` | 不再把 boot.efi 调试日志并入 OC 日志 |
| `ApplePanic` | `false` | 不落 panic 文件；**想保留 panic 现场就设 `true`**（会往 ESP 写文件） |
| `DisableWatchDog` | `false` | 只有 DEBUG 构建启动慢时才需要 |
| `SysReport` | `false` | RELEASE 下本来就无效 |
| `LogModules` | `*` | 官方默认 |

> 想**完全静默**可以把 `Target` 设 `0`（文档：不设 `0x01` = 全部日志丢弃）；
> 但那样屏幕上连 OC 的错误提示都没有，排障会很被动 ⇒ 日常建议保持 `3`。

### 6.3 `-v`：**必须问客户，不要自己决定**

`-v`（macOS verbose）是**偏好项**，不是技术默认值。切日常态时**明确问用户**要哪种，并把差别讲清楚：

| | 开 `-v` | 关 `-v` |
|---|---|---|
| 屏幕 | 内核/kext 全文滚动，看不到苹果 logo | 苹果 logo + 进度条 |
| 开机速度 | 慢一点（每行都要经控制台渲染） | 快一点 |
| 现场排障 | 一眼看到卡在哪 | 需按 **CMD+V** 临时开（`PollAppleHotKeys=true` 时可用） |
| 日志完整性 | **不受影响** | **不受影响**（`log show` / Send logs / OC 日志都还在） |

- 关掉 = boot-args 去掉 `-v`（等同驱动安装 App 的 "Turn verbose off"）
- 换的时候**只动这一个 token**，并在报告里写明「客户选择了哪种」

### 6.4 日常态收尾清单

- [ ] `oc-swap-build.sh release` 已执行，重启后 `opencore-version` 无 `DBG-` 前缀
- [ ] `Misc>Debug` 已回到 §6.2 的值（或按客户意愿保留 panic 落盘）
- [ ] `-v` 已**问过客户**并按选择设置
- [ ] ESP 上排障期攒下的 `opencore-*.txt` 按需清理（可留最近几份备查）
- [ ] 再跑一次 `scripts/oc-verify.sh` 确认仍是 `No issues found`
- [ ] 报告里记录：本次生命周期各阶段做了什么、最终 sha、以及「明确不动」清单

---

## ⑦ 之后：系统大版本升级（不是装机的第七阶段，是另一件事）

装好、稳定运行之后，如果要从 **macOS 15 (Sequoia)** 升到 **26 (Tahoe)**，
那是**另一套流程**（升级会必然打断 Wi-Fi 与 OCLP root patch）⇒ 见 **`os-upgrade-15-to-26.md`**。

一句话：**核心动作是给按版本分构建的 kext 加 `MinKernel`/`MaxKernel`**（旧版上限 `24.99.99`、新版 `MinKernel 25.0.0`），
升级前关 FileVault + 保护第三方 kext，升级后补条目 + 重打 root patch。
