# 日志取证与调试开关

## 1. 两个「刷屏」来源，互相独立

| 刷屏发生在 | 由什么控制 | 关掉的方法 |
|---|---|---|
| **进入选择器 → 交给 macOS 之间** | `Misc>Debug>Target` 的 **`0x02`（Enable basic console logging）** 位 | `Target` 去掉 `0x02`（例：`71 (0x47)` → `69 (0x45)`） |
| **交给 macOS 之后** | boot-args 的 **`-v`** | 去掉 `-v`（= 1401 App 的 "Turn verbose off"）；临时要看就开机按 **CMD+V**（需 `PollAppleHotKeys=true`） |

文档原话：*"Unless Target enables console (onscreen) printing, onscreen debug output will not be visible."*

## 2. `Misc>Debug>Target` 位定义（文档）

| 位 | 含义 |
|---|---|
| `0x01` | 记录（否则全部丢弃） |
| `0x02` | **控制台（屏幕）** 日志 |
| `0x04` | Data Hub |
| `0x08` | 串口 |
| `0x10` | UEFI 变量 |
| `0x20` | **非易失** UEFI 变量（文档带 Warning：固件 NVRAM 回收缺陷时会出问题） |
| `0x40` | 写入文件（ESP 根 `opencore-YYYY-MM-DD-HHMMSS.txt`） |
| `0x80` | 配合 `0x40`，更快但不安全的文件日志 |

## 3. `Misc>Debug>DisplayLevel` 位定义（文档）

| 位 | 含义 |
|---|---|
| `0x02` | DEBUG_WARN |
| `0x40` | DEBUG_INFO |
| `0x00400000` | DEBUG_VERBOSE |
| `0x80000000` | DEBUG_ERROR |

**「常规 debug」的合理取值**：`Target = 0x45 (69)`（记录 + DataHub + 文件，不上屏）、
`DisplayLevel = 0x80000042`（ERROR + INFO）、`AppleDebug=true`、`ApplePanic=true`、`DisableWatchDog=true`。
**「完整 debug」= 再往 Target 加 `0x08/0x10/0x20`、往 DisplayLevel 加 `0x00400000`** —— 除非在查引导问题，否则不需要。

## 4. 三种读 OpenCore 日志的方法

```bash
# ① 文件（Target 含 0x40 才有；ESP 根目录，256 KB 上限）
ls -lt /Volumes/EFI/opencore-*.txt | head
# ② DataHub（Target 含 0x04；控制台关掉也能读，文档给的方法）
ioreg -lw0 -p IODeviceTree | grep boot-log | sort | sed 's/.*<\(.*\)>.*/\1/' | xxd -r -p
# ③ UEFI 变量（Target 含 0x10，日志上限 32 KB）
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:boot-log | awk '{gsub(/%0d%0a%00/,"");gsub(/%0d%0a/,"")1}'
```

日志行格式：`mm:sss 间隔 OC模块: 消息`。第一列是**相对启动的秒数**，用它做阶段耗时分析。

> **「开机很慢」请配合 `references/boot-timeline.md`** —— 那里把启动拆成 **OC 段 / 内核驱动段 / 用户态段** 三段分开量，
> 并给出停顿窗口定位法与耗时来源处置表（含 `log show` 时间过滤失效时改用**流式过滤**的做法）。

## 5. OC 日志里的关键判据

| 日志行 | 用途 |
|---|---|
| `OCABC: MAT support is 1/0` | 决定 `EnableWriteUnprotector` 该不该关（文档指名看这一行） |
| `OCABC: Only N/256 slide values are usable!` | 决定 `ProvideCustomSlide` 是否必要 |
| `OCABC: ALRBL 1 RTDFRG 1 … WRUNPROT 1 CLRTS 0` | 各 Booter quirk 的实际生效值（ALRBL=AllowRelocationBlock、RTDFRG=AvoidRuntimeDefrag、SMSLIDE=EnableSafeModeSlide、WRUNPROT=EnableWriteUnprotector…） |
| `OCABC: … CSLIDE 1 MSLIDE 0 … RBMAP 1 VMAP 1 RTPERMS 1 ARBAR -1` | ProvideCustomSlide / ProvideMaxSlide / RebuildAppleMemoryMap / SetupVirtualMap / SyncRuntimePermissions / ResizeAppleGpuBars |
| `OCA: Found N ACPI tables` + 每张表的 `Detected table SIG (OEM ID) … at index N` | 固件 ACPI 全清单；OEM ID 是 8 字节十六进制（小端 ASCII） |
| `OCA: Deleting table … with <ID> ID at index N` | `ACPI>Delete` 是否命中（本机 `xh_adls3` 就是靠这个确认的） |
| `OCA: Inserted table SSDT (OEM …) of N bytes into ACPI at index M` | `ACPI>Add` 的注入结果（能核对表身份与大小） |
| `OCJS: APFS driver <ver>/<date> found …, required >= X/Y, allow|refuse` | `UEFI>APFS>MinDate/MinVersion` 的门槛判定 —— 改成非 `-1` 后**必须**看这一行 |
| `OCB: Registering entry <名字> [<类型>]` | 选择器里**实际有哪些启动项**（判断"屏蔽"效果的唯一可靠依据） |
| `OCB: Not adding hidden auxiliary entry …` | 被 `HideAuxiliary=true` 隐藏的项 |
| `OCUI: Failed to load image … - Not Found` | OpenCanopy 探测**可选图标**后的正常回退；官方三套图标集都只有 25 个文件，别去"补" |
| `OC: WARN/ERROR` / `OCB: ERROR` | 引导期错误（应清零） |

## 6. macOS 侧内核日志（需要提权）

沙箱里 `log show` 不可用；用**提权 AppleScript** 跑（`scripts/grab-logs.sh` 已封装）：

```bash
osascript -e 'do shell script "/bin/bash <脚本>" with administrator privileges'
```

脚本内把输出写到文件再 `chmod 644`，普通用户才能读。

**判据清单（ACPI / 平台）**

| 抓什么 | 说明 |
|---|---|
| `grep -aiE "acpi error\|ae_not_found\|ae_already\|namespace lookup\|Error evaluating"` | **0 命中 = ACPI 没坏**，这是「还要不要补 SSDT」的第一判据 |
| `(AppleACPIPlatform) FACP/FACS/DSDT/XSDT …` | macOS 侧实际解析到的表清单（与 OC 日志对照；能证明某张表"到底在不在"） |
| `(AppleACPIPlatform)` 里**没有** DMAR | 说明固件未暴露 VT-d |
| `(AppleAHCIPort) … COMRESET did not proceed` + `PxSSTS 0x4` | 该端口 **PHY offline**（空端口）；先看 `ioreg -r -c IOAHCIDevice` 有没有子设备再下结论 |
| `(AppleUSBXHCI) createPorts: speed index N has inconsistent speed IDs` | 常见无害 |
| `Previous shutdown cause:` | 上次关机是否正常 |
| `AppleIGC (isOpen(forClient) == 1)` | I225-V 网卡驱动是否真的打开了设备 |

**命令要点**：`log show` 是**旧→新**输出，`| head -N` 会只留最早一批 ⇒ 必须 `--start "<开机时间>"` 或改用 `tail`。
开机时间取 `sysctl -n kern.boottime`。

## 7. 常见「误判」提醒

- 日志里 `Not Found` 满天飞 ≠ 有问题：NVRAM 变量、APFS preboot 分区、OpenCanopy 可选图标都会打这个。
- 「OC 日志里某张表没出现」要先确认 `Target` 是否含 `0x40`（本机曾出现「今天几次开机都没生成日志」的怪象）。
- 看到 `X: no driver attached` 之类的驱动侧消息，先分清是 **OC 阶段** 还是 **kext 阶段**（后者在 `log show` 里，带 `(KextName)` 前缀）。
