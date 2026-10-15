# 装不上 / 进不去系统 —— 分层 debug 流程

> 依据：本机 10-08 ~ 10-16 的**全部失败复盘**（换机型循环重启 ×6、卡 USB/HID ×3、`decmpfs` panic ×2、
> `X86PlatformShim` panic、`no kext summary` 极早期失败、ReBAR 黑屏、VMD 找不到盘…）+ OpenCore 官方文档。
> ★★ **一句话**：**先分层定位「挂在哪一段」，再查那一段的日志** ——
> **不要一上来就改配置**（改了就没法复盘，本机踩过）。

## 0. ★★ 第一步永远是分层

把启动拆成四段，**先判在哪一段挂的**：

| 段 | 表现 | 去哪查 |
|---|---|---|
| **① 固件 / OpenCore 自身** | **连选择器都不出现**；或出现后一选就回 BIOS / 黑屏 | §2 |
| **② OpenCore 引导期** | 选择器出来了，选了 macOS 后**卡在 OpenCore 自己的输出** | §3（OC 日志） |
| **③ 内核早期**（< 1–2 s） | 苹果 logo / `-v` 刚开始就停；或**立刻重启** | §4 |
| **④ 内核中后期 / 用户态** | **走到很后面**（驱动都加载了）才卡 / panic | §5、§6 |

### 0.1 ★★ 先分清「卡死」还是「循环重启」

- **循环重启 = 引导看门狗超时自动重启 ⇒ 「多等一会儿」无效**（本机 10-12 换机型 6 次全是这个形态）。
- **卡死才值得等** —— 本机也踩过反例：看着像卡死，其实是在**回滚 11 GB 的系统卷快照，很慢但不是死**。
- ★ 判据：屏幕**有没有闪一下重启**；BIOS/开机自检是不是重新走了一遍。

## 1. 三条铁律（先记住，能省一半折腾）

1. ★ **没有 `-v` 就没有信息** —— 排查期**必须开 `-v`**（日常态才关）。
   日志完整性两边一样，但**屏幕上的信息只有 `-v` 给**（`-v` 是**偏好项，要问客户**，铁律 13）。
2. ★★ **进不去 ≠ 一定要重装** —— 先按 §7 把**上一份能用的配置**拿回来，再慢慢查。
3. ★★ **备一个能用的 U 盘 EFI**（那份用 `Misc>Boot>LauncherOption=Disabled`，**不改写 NVRAM**）——
   它是**所有救援路径的前提**（`boot-entries.md`）。

## 2. ① 固件 / OpenCore 自身（连选择器都进不去）

| 症状 | 查什么 |
|---|---|
| **黑屏，连 logo 都没有** | ★ 本机已知：`UEFI>Quirks>ResizeGpuBars=13`（8 GB）会让**开机黑屏 ~21 s** ⇒ **先等够 2 分钟**；真超时再改 `12` 或关 BIOS ReBAR（`nvidia-driver.md`） |
| **选择器不出现** | ★ 第三方开机 logo（如 `NullMothLogo.efi`）**可能让固件到不了选择器** ⇒ 从别的系统里关掉它。★ **boot-args 救不了「选择器之前」挂住的情况** |
| **改过主题后选择器全黑 / 不启动** | ★ **必需图标缺一个 OpenCanopy 就不启动** ⇒ 跑 `scripts/oc-theme-check.sh`；逃生口 `PickerMode=Builtin`（`theme-opencanopy.md`） |
| **怀疑构建混搭** | ★ **只换 `OpenCore.efi` 没换 Drivers** = 构建混搭的引导器 ⇒ **连官方同名 Drivers 一起换**（铁律 14） |
| **BIOS 里看不到 OpenCore 项** | 那是启动项问题，不是引导问题 ⇒ `boot-entries.md`（`LauncherOption` / `bcfg` / `OpenControl`） |

## 3. ② OpenCore 引导期

**拿日志**（三条路径，见 `logs-and-debug.md` §4）：

- ① **文件**：ESP 根目录 `opencore-*.txt`（需 `Misc>Debug>Target` 含 **`0x40`**；**256 KB 上限**）
- ② **DataHub**（`Target` 含 **`0x04`**；控制台关掉也能读）
- ③ **UEFI 变量**（`Target` 含 **`0x10`**，日志上限 32 KB）

**判据清单**：`OCABC: MAT support` / `slide` / APFS 驱动门槛 / ACPI 表清单 / 启动项注册 ⇒ `logs-and-debug.md` §5。

> ★★ **进不去系统时怎么读日志**：用 **U 盘 EFI 或 Recovery 启动** → 挂载**内置** EFI → 读 `opencore-*.txt`。

## 4. ③ 内核早期（< 1–2 s）

| 症状 | 含义 / 查什么 |
|---|---|
| **`can't perform kext scan: no kext summary`** | ★★ **极早期（< 1 s）的启动缓存层故障** —— **与 GPU、与「某个具体 kext」无关**，别往显卡驱动上查（本机踩过） |
| **立刻重启、什么都看不到** | ★ 引导看门狗 ⇒ 回到 §0.1 先确认形态 |
| **`X86PlatformShim` / `xcpm_hwp_enable` panic（type 13）** | ★★ **第一件事查 BIOS 的 `Intel(R) Speed Shift Technology` 是否 `Enabled`**（**`Auto` 也可能等效关闭**）—— `wrmsr(0x770,1)` #GP（`intel-turbo.md` §10） |
| **刚改完 kext 就挂** | 用 `scripts/kext-inventory.sh` 对照改动前清单；★ 查 `Kernel>Add` **引用缺失** / **顺序**（`Lilu` 必须最前） |

## 5. ④ 内核中后期 / 用户态

| 症状 | 查什么 |
|---|---|
| **走到很后面（驱动都加载了）才卡** | 多半是**用户态服务没起来**。本机实例：`AppleUSBHostHIDDevice` 都建好了，但在等 **DriverKit dext `com.apple.AppleUSBHostHIDDrivers`** ⇒ **没有键鼠输入**（看着像卡死，其实是等不到服务） |
| **panic 了** | ★ **首选证据在 `/Library/Logs/DiagnosticReports/`**；带 `keepsyms=1` 的 panic 回溯**直接给帧名**（所以排查期值得开 `keepsyms=1`） |
| **`decmpfs_pagein_compressed: couldn't ubc_upl_map a single page`**（`apfs_vnops.c`） | ★ 本机**已知族**：APFS **透明解压路径**的内核断言，**与 GPU / 机型 / 内存压力无关**（panic 里 `Compressor Info: 0% … 0 swapfiles` 已排除内存不足）；特征是**开机几十分钟后、新进程启动时**、**不同机型不同进程同一行代码** |
| **开机 ~2 s 的 `element modified after free`** | ★ 本机实测是 **`NVMeFix.kext`** 造成的（**不是 GPU、不是网卡驱动**）⇒ 先**禁用 `NVMeFix` 做 A/B** |
| **`SIGABRT` 在 `MPSLibrary::MPSKey_Compile`**（**应用**崩溃，不是 boot 失败） | ★ NVIDIA Metal 驱动建不出 MPS 计算管线 ⇒ **系统级、与 EFI / 三码 / 内存注入无关**（`nvidia-driver.md`、`pitfalls.md`） |

## 6. 装机期专属：装不上 / 找不到盘

| 症状 | 查什么 |
|---|---|
| ★★ **安装器「找不到任何驱动器」** | 九成是 **BIOS 里 VMD / Intel RST 没关**（macOS 没有 VMD 驱动）⇒ `bios-settings.md` |
| **安装期键鼠没反应 / 卡 USB** | `XHCI Hand-off` / `Legacy USB Support`；★ **`UTBMap` 是否把安装盘或键鼠映射掉了** |
| **装到一半重启** | 先按 §0.1 判形态；**循环重启** ⇒ 查 ACPI（§8） |
| **装完第一次开机进不去** | 常见是 **`MinKernel`/`MaxKernel` 分流不对**（`os-upgrade-15-to-26.md`）或 **kext 顺序** |
| **刚装完就 panic 在电源管理** | 查 BIOS `Speed Shift`（§4） |

## 7. ★★ 救援顺序（进不去系统时按这个来）

1. **先回到「上一份能用的配置」** —— 每次改 ESP 都该留备份（铁律 2/3）；
   `scripts/oc-edit-safe.sh` 的版本存档就是干这个的
2. **U 盘 EFI 启动**（前提是它存在且 `LauncherOption=Disabled`，不会改写 NVRAM）
3. **Recovery / 单用户模式** 挂载**内置** EFI，把配置换回去
4. **二分**：拔掉可疑硬件 / 关掉可疑开关
   - 例：核显相关（`-wegnoigpu`）、ReBAR、某个可疑 kext
   - ★ **一次只改一项**（铁律 5）—— 否则下次复盘无法定位
5. **从别的系统直接改 ESP**（Windows / 另一份 macOS 都能挂 FAT）
6. ★ **不要**在进不去的时候「顺手多改几项」—— 那会让下次复盘彻底失去线索

## 8. ACPI 相关（本机特例，换机型必看）

★★★ **本机（ASUS Z690）换机型 ⇒ 循环重启**，真因是**主板 OEM SSDT `xh_adls3`**：
board-id 变了 ⇒ macOS **重新解析 ACPI 表** ⇒ 该表解析不过（**`HS06 AE_NOT_FOUND`**）
⇒ 电源管理 / ACPI 层出问题 ⇒ **循环重启**（不是卡死）。

- **修法 = `ACPI>Delete` 删原表（`SSDT` + `OemTableId=xh_adls3`）+ `ACPI>Add` 加 `SSDT-XHADLS3.aml`**
- **顺序：先完善 SSDT（在【旧机型】下验证通过）→ 再换 SMBIOS → 再重做 CPUFriend**（铁律 19）
- 已排除的方向（别白试）：USB 端口图 · OCLP 根补丁 · 机型本身 · 15 端口上限 · NVRAM 残留
- 详见 `smbios-and-serials.md` §2

## 9. 取证清单（照着抄）

```bash
# ① 本次开机的 OC 日志（进不去系统时：U 盘 EFI / Recovery 启动后挂内置 EFI 再读）
ls -l /Volumes/EFI/opencore-*.txt

# ② panic 报告（首选证据）
ls -lt /Library/Logs/DiagnosticReports/*.panic 2>/dev/null | head

# ③ 本次开机的内核日志（需提权）
scripts/grab-logs.sh

# ④ 卡在哪一段（时间线三段拆解 + 停顿窗口）
scripts/boot-timeline.sh
scripts/find-boot-gap.sh

# ⑤ 现状快照：OC 版本 / kext 清单（含 config 引用核对）
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version
scripts/kext-inventory.sh /Volumes/EFI

# ⑥ 配置整体校验
scripts/oc-verify.sh
```

## 10. 出处

- OpenCore `Configuration.pdf` / `Differences.pdf`（`Misc>Debug>Target` 位定义、版本语义）。
- 本机失败族复盘：换机型循环重启（`smbios-and-serials.md` §2）· `decmpfs` panic（APFS 透明解压）·
  `no kext summary`（极早期缓存层）· `X86PlatformShim` panic（BIOS Speed Shift）·
  `element modified after free`（`NVMeFix`）· `MPSKey_Compile`（NVIDIA Metal）。
- 相关：`logs-and-debug.md` · `boot-timeline.md` · `boot-entries.md` · `bios-settings.md` ·
  `pitfalls.md` · `kext-and-oc-update.md` · `lifecycle.md`。
