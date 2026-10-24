# CPU 显示名（「关于本机」的处理器名称）—— 改名方法

> 依据：**RestrictEvents 官方 `README.md`**（逐条引用，见 §9）+ 一次完整实操闭环
> （现象 → 定位 → 修复 → 重启验证）。
> ★ **先定性**：这是**纯外观问题**，不影响性能 / 功能 / 指令集。
> ⇒ **改之前先想清楚值不值得**：名字不对通常只是「机型映射的名字 ≠ 真实型号」。

## 0. 一句话

「关于本机 → 处理器」与「系统信息 → 硬件 → 处理器名称」显示的名字，
**不是从 CPUID 直接读出来的，而是 macOS 按机型（SMBIOS）映射出来的**
⇒ 机型选错就会出现「i7-12700K 显示成 Intel Xeon W」这类错名。

**改法 = RestrictEvents 的三件套：`revpatch=cpuname` + `revcpu=1` + `revcpuname=<自定义名>`。**

## 1. 先看现状（三条命令）

```bash
system_profiler SPHardwareDataType | grep -E "Processor Name|Chip|Total Number of Cores"
sysctl -n machdep.cpu.brand_string      # 真实 CPU 自报的品牌串（来自 CPUID）
sysctl -n hw.model                      # 当前机型
```

**判据**：`Processor Name` 与 `machdep.cpu.brand_string` **不一致** ⇒ 就是本文档的问题。

> 实例：`Processor Name: 8-Core Intel Xeon W`（`MacPro7,1` 的映射），
> 而真实 CPU 是 `12th Gen Intel(R) Core(TM) i7-12700K`；
> 其余项（3.6 GHz / 8 核 / L2 1.3 MB / L3 25 MB）**全对** ⇒ 只有显示名错。

## 2. 三个键各管什么（官方 README 原话）

| 键 | 官方描述 | 说明 |
|---|---|---|
| **`revpatch=cpuname`** | *"`cpuname` - custom CPU name in System Information"* | **总开关** —— 不加它，下面两个都不生效 |
| **`revcpu=1`** | *"`revcpu=value` to enable (`1`, non-Intel default)/disable (`0`, Intel default) CPU brand string patching"* | ★★ **Intel CPU 上默认是 `0`（关）** ⇒ **必须显式写 `revcpu=1`** |
| **`revcpuname=value`** | *"custom CPU brand string (max **48 characters**, **20 or less recommended**, taken from CPUID otherwise)"* | 自定义名字；**上限 48 字符，建议 ≤20** |

★ `revpatch` 是**逗号分隔**的多选项：
`memtab` · `pci` · `cpuname` · `diskread` · `asset` · `sbvmm` · `f16c` · `none` · `auto`
（`auto` = `memtab,pci,cpuname`，且**真实 Mac 上不套用 `memtab` / `pci`**）。

## 3. ★★ 最大的坑：NVRAM 优先级**低于** boot-args

官方 README 的 Note 原话：

> *"`4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:revpatch`, `…:revcpu`, `…:revcpuname` and `…:revblock`
> NVRAM variables work the same as the boot arguments, **but have lower priority**."*

⇒ **只在 NVRAM 里写 `cpuname` 是没用的** —— 只要 boot-args 里也有 `revpatch=...`，就**以 boot-args 为准**。

**踩过**：NVRAM 里 `revpatch='sbvmm,cpuname'`、boot-args 里 `revpatch=sbvmm`
⇒ 生效的是 boot-args（**没有 `cpuname`**）⇒ **名字一直没改过来**。
**修法 = boot-args 里的 `revpatch=` 也要带上 `cpuname`**（如 `revpatch=sbvmm,cpuname`）。

### 3.1 ★ `revcpuname` 只能放 NVRAM（因为它含空格）

boot-args **按空格分词** ⇒ `revcpuname=8-Core Intel Core i7-12700K` 会被切成多个参数而**截断**。

⇒ **分工**：**`revcpuname` 写 NVRAM**（`NVRAM > Add > 4D1FDA02-…`），**`revpatch` / `revcpu` 写 boot-args**。

## 4. 完整改法（已验证）

1. **`NVRAM > Add > 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102`**
   - `revcpuname` = 字符串，如 `8-Core Intel Core i7-12700K`
   - （可选，保险）`revcpu` = `1`、`revpatch` = `cpuname`
2. **`NVRAM > Add > 7C436110-…:boot-args`** 里确保有 **`revpatch=cpuname`** 与 **`revcpu=1`**
   （★ 原来是 `revpatch=sbvmm` 的，改成 **`revpatch=sbvmm,cpuname`**）
3. ★ **`NVRAM > Delete` 里这些键也要出现** —— OpenCore 规则：`Add` 的键**必须同时在 `Delete` 里**才生效
4. 确认 **`RestrictEvents.kext` 已加载**（Lilu 插件 ⇒ **必须排在 Lilu 之后**）
5. `ocvalidate` → **重启** → 复查 §1 的三条命令

## 5. ★ `ProcessorType` 必须与核数配对

官方 README 的 Note 原话：

> *"Apple CPU identifier must be `0x0F01` for 8 core CPUs or higher and `0x0601` for 1, 2, 4, or 6 cores.
> This is the default in OpenCore for non-natively supported CPUs."*

- **位置：`PlatformInfo > Generic > ProcessorType`**（★ 在 `Generic` 里，**不是** `PlatformInfo` 顶层）
- 8 核及以上 ⇒ **`0x0F01`**（十进制 `3841`）✓ **不要动**；1/2/4/6 核 ⇒ `0x0601`
- 写错的症状：**CPU 图标不对 / 核数显示异常**（不是名字问题）

## 6. 名字怎么起（经验）

- **Apple 风格**：`<N>-Core Intel Core i7-12700K`（27 字符）
- 上限 **48**、建议 **≤20** ⇒ 名字太长可能被截断
- ★ **不要**把带空格的 `revcpuname` 写进 boot-args（§3.1）
- 想更保险：`revcpuname` 只写型号（`Intel Core i7-12700K`），核数让系统自己拼

## 7. 常见误解（别走错路）

| 想法 | 事实 |
|---|---|
| 「改 `Kernel > Emulate > Cpuid1Data` 就能改名字」 | **不能**。CPU 品牌串在 **CPUID `0x80000002–0x80000004`** 叶子，而 `Cpuid1Data` 改的是 **leaf 1**（机型 / 步进 / 特性位）⇒ **不影响品牌串**。本机 `Cpuid1Data = 0x000A0655`（ADL→Comet Lake）是给**内核**看的，与显示名无关 |
| 「直接改 `AppleSystemInfo.strings` / 本地化字符串」 | **老方法，别用**。现代 macOS 是**密封系统卷（SSV）** ⇒ 要关 SIP + 破坏系统卷签名；**RestrictEvents 就是为替代它而生的** |
| 「换个机型名字就对了」 | 有时有效（映射对了名字就对），但**换机型是连带改动**（三码 / SSDT / CPUFriend / 内存槽位，见 `smbios-and-serials.md`）⇒ **为改名字换机型不值得**；`revcpuname` 才是零耦合做法 |
| 「名字不对说明 CPU 被认错了」 | 不一定 —— 频率、核数、L2/L3、指令集**全对**，只是**显示名**按机型映射 |
| 「`revpatch=auto` 就够了」 | `auto` **确实含 `cpuname`**，但① 你原有的 `revpatch` 可能被写成了 `sbvmm` 而覆盖它（§3）；② `revcpu=1` 在 Intel 上**仍需显式加** |

## 8. 排错

| 现象 | 检查 |
|---|---|
| 加了 `revcpuname` 但名字没变 | ① **boot-args 里有没有 `cpuname`**（§3 优先级坑 —— **最常见**）；② 有没有 **`revcpu=1`**（Intel 默认 0）；③ `RestrictEvents.kext` 加载了没；④ **重启了没** |
| 名字乱码 / 被截断 | `revcpuname` 超 48 字符，或**被写进 boot-args 遭空格切碎**（§3.1） |
| 「关于本机」变了但「系统信息」没变（或反之） | 两者取自不同路径；`cpuname` 补丁主要作用于 **System Information** ⇒ **以「系统信息 → 硬件」为准** |
| CPU 图标 / 核数不对 | `ProcessorType` 与核数不配（§5） |
| 想撤销 | 去掉 `cpuname` 与 `revcpuname`（或加 `revpatch=none`）→ 重启 |

## 9. 出处

- `acidanthera/RestrictEvents` → `README.md`：
  `revpatch` 选项表 · `revcpu` · `revcpuname`（48 字符上限）· **NVRAM 优先级 Note** · **CPU identifier Note**。
- 相关：`smbios-and-serials.md`（机型名由序列号产品码决定 —— **那是另一件事**，别混）·
  `intel-turbo.md`（CPU 频率 / 机型 profile）· `bios-settings.md`（BIOS 侧）。
- 自检工具：`scripts/cpu-name-check.sh`。
