# 官方文档取用与逐键判定法

## 1. 先确定「用哪一版文档」

```bash
nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version
# DBG-108-2026-09-27 → OpenCore 1.0.8 的 DEBUG 构建（DBG- 前缀 = DEBUG）
# 形如 1.0.8-2026-09-27 → RELEASE
```

**必须用同版本**：`ocvalidate` 会拒绝校验不同版本的 config；文档里键的 Failsafe 也可能随版本变。

判断本机 OpenCore.efi 到底是 DEBUG 还是 RELEASE（逐字节）：

```bash
shasum -a 256 /Volumes/EFI/EFI/OC/OpenCore.efi
# 与官方包同名文件比：RELEASE 与 DEBUG 大小差别明显（1.0.8：626,688 B vs 868,352 B）
```

## 2. 取包与建键库

跑 `scripts/fetch-opencore-docs.sh`，它做三件事：

1. 下载官方 `<ver>` 的 **RELEASE** 包并解压（含 `Utilities/ocvalidate/`、`Docs/`、`X64/`）
2. 另取该版本的 `Docs/Configuration.tex`（LaTeX 源，比 PDF 好检索）
3. 从 `Configuration.tex` 抽取**每个键**的 `Type / Failsafe / Description` → `oc-doc-keys.json`

`Configuration.tex` 里每个键长这样，抽取就是按这个模式切块：

```latex
\item
  \texttt{ResetLogoStatus}\\
  \textbf{Type}: \texttt{plist\ boolean}\\
  \textbf{Failsafe}: \texttt{false}\\
  \textbf{Description}: Reset \texttt{BGRT} table \texttt{Displayed} status field ...
```

用 `\section{}/\subsection{}` 跟踪键所属的段（ACPI / Booter / Kernel / Misc / NVRAM / PlatformInfo / UEFI）。

## 3. 三份输入做三角对照

| 输入 | 作用 |
|---|---|
| 官方 `Sample.plist` | 官方默认值（Failsafe 的实例）；与 live config 做**语义 diff** |
| `oc-doc-keys.json` | 每个键的**官方说明**，用来判定「这个偏离是有意为之还是错的」 |
| live `config.plist` | 机器实际配置 |

语义 diff 要按 plist 结构递归（dict 按 key、list 比长度/元素），不要按文本 diff —— `plutil`/手工编辑会重排格式。

## 4. 判定分类（把偏离分成三类）

1. **有依据的正确偏离** —— 文档里有明确适用条件，本机正好符合。例：
   - `Kernel>Emulate>Cpuid1Data = 55 06 0A 00…`：文档原文给出的「Alder Lake (0x090672) → Comet Lake (0x0A0655)」推荐值
   - `FixupAppleEfiImages=true`：文档说 `SecureBootModel=Disabled` 时对较新 macOS **必需**
   - `ProvideCustomSlide=true`：文档说必要性由日志 `OCABC: Only N/256 slide values are usable!` 判定
2. **与文档明确指引相反** —— 文档用了 "strongly discouraged" / "Please use X instead" / "required" 这类措辞。例：
   - `UEFI>APFS>MinDate/MinVersion = -1`（文档：strongly discouraged）
   - `Booter>Quirks>EnableWriteUnprotector=true` 而 `OCABC: MAT support is 1`（文档：MAT 支持时应改用 `RebuildAppleMemoryMap`）
   - `Kernel>Quirks>PanicNoKextDump=true`（文档：会隐藏 panic 里的 kext 信息）
3. **冗余/失效残留** —— 无害但不生效。例：
   - `UEFI>Input>PointerSupportMode='ASUS'` 但 `PointerSupport=false`（文档：该值只对 Z87/Z97 ASUS 板有效）
   - `PointerPollMin/Max` 显式写的就是实现默认值（写 `0` 等价）
   - 同时开 `DisableLinkeditJettison` 与 `keepsyms=1`（文档说前者就是为免去后者）

## 5. ★ 文档里的「成对关系」—— 别拆散

| 成对 | 文档依据 |
|---|---|
| `PlatformInfo>UpdateSMBIOSMode=Custom` ↔ `Kernel>Quirks>CustomSMBIOSGuid=true` | Custom「Requires patching AppleSmbios.kext and AppleACPIPlatform.kext… done automatically by CustomSMBIOSGuid quirk」 |
| `Misc>Boot>LauncherOption=Full` ↔ `UEFI>Quirks>RequestBootVarRouting=true` | 「For this option to work, RequestBootVarRouting is required to be enabled」 |
| `Misc>Security>SecureBootModel=Disabled` ↔ `Booter>Quirks>FixupAppleEfiImages=true` | 「required for all newer macOS when SecureBootModel is set to Disabled」 |
| `UEFI>Output>TextRenderer=System*` ↔ `ClearScreenOnModeSwitch` / `IgnoreTextInGraphics` | 这两个开关「only applies to System renderer」—— 换 Builtin 就失效 |
| `UEFI>Output>ProvideConsoleGop=true` ↔ `Resolution=Max` | Builtin 渲染器「necessary to enable ProvideConsoleGop and set Resolution to Max」 |
| `Kernel>Block` 的 `com.apple.iokit.IONDRVSupport` | 否则固件 framebuffer 会抢走 display index 0 |
| `NVRAM>Add` 的每个键 ↔ 同名 `NVRAM>Delete` 条目 | 「Variables will only be set if not present or deleted」 |

## 6. 报告格式建议

- 开头给「**ocvalidate 结论**」+「**与 Failsafe 的偏离总数/分类计数**」
- 逐键表：`键 | 本机值 | 文档 Failsafe | 判定 | 文档原话(截断)`
- 「建议修改」按风险排序，每条注明**依据 + 回滚方式**
- 附一节「**明确不动**」并写理由 —— 避免下次有人把这些"改回默认"改坏
