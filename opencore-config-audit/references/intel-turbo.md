# Intel 睿频（Turbo Boost）诊断与 CPUFriend 数据检查

依据：[CPUFriend 使用说明](https://github.com/acidanthera/CPUFriend/blob/master/Instructions.md)、
[FrequencyVectors 结构定义](https://github.com/acidanthera/CPUFriend/blob/master/Tools/FrequencyVectors.bt)
与 [iMac20,x XCPM QoS 的作者讨论](https://github.com/dortania/bugtracker/issues/190)。
CPUFriend 负责注入数据，不保证某份数据适合目标 CPU；没有明确的电源管理异常时不新增它。

## 1. 先确认现象

记录 CPU 型号、当前 SMBIOS、P/E 核与超线程设置、macOS / Darwin 版本，以及是否已注入 CPUFriend 数据。
使用目标系统支持的工具，在相同负载和散热条件下比较频率、耗时、温度与功耗。

| 检查 | 用途与限制 |
|---|---|
| CPU-S / Intel Power Gadget（可用时） | 对照频率、温度与功耗；先确认工具支持当前 CPU 与系统 |
| `scripts/cpu-freq-probe.sh` | 辅助采样；它是基准推算，不是硬件频率计，不能单独证明限频根因 |
| `sysctl machdep.xcpm.cpu_thermal_level` | 结合温度和负载排查热限制；键不可用时记录限制，不补造读数 |
| `machdep.xcpm.hard_plimit_max_100mhz_ratio` 等 | 仅在键存在且含义适用于目标 CPU 时解释，不能把一台机器的值当默认 |
| `uptime`、`iostat`、`vm_stat` | 辅助核实后台负载、存储与内存压力 |
| `sysctl -n kern.boottime` | 确认是否已在上次修改后重启 |

例如 i7-12700K 的历史记录里有约 2.3 GHz 与约 4.3 GHz 两组测量。
它们只描述当时的机器、负载及工具输出，不能据此认定其它机器的正常频率或性能比例。
先排除散热、功耗、后台任务、BIOS 和拓扑因素，再评估 profile。

## 2. 确认 profile 与注入来源

系统数据位于 `IOPlatformPluginFamily.kext/Contents/PlugIns/X86PlatformPlugin.kext/Contents/Resources/Mac-<board-id>.plist`。
按目标系统版本与当前 board-id 取原始文件，在工作区保存原件和 sha256；不要修改系统自带的 profile。

- `FrequencyVectors` 是数据数组，不是单个 bytes；逐段检查，不只比较最外层键或段数。
- `Frequencies`、`CPUFloor`、`pmspFile` 的差异不足以证明某份 profile 更快或兼容。
- 已有 DataProvider 时，解出 `cf-frequency-data`，确认其来源及与原始 profile 的实际差异。
- 切换 SMBIOS 后重新核对数据适用性；原本未使用 CPUFriend 的机器不因此自动新增它。

## 3. 固定布局：不能删除字节来“去掉 hwp”

CPUFriend 的 `FrequencyVectors.bt` 对 version 2 的 `xcpmio_vectors_t` 定义为固定布局：

| 字段 | 数量 | packed 大小 |
|---|---|---|
| `version` | 1 | 4 B |
| `vector` | 32 | 每项 180 B |
| `qos` | 16 | 每项 83 B |
| `vars` | 16 | 每项 36 B |

合计 **7668 B**，`vars` 从偏移 **7092** 开始。`hwp` 若存在，是 `vars` 中某个定长记录的名字；
每条记录含 16 B 名称、4 B 类型与 16 B 值，并不是可任意删除的文本片段。
其它格式或版本应按对应结构解析，不能靠字符串搜索和猜偏移改写。

**不要删除 `hwp` 字符串、删掉一段字节或让后续数据整体前移。**
旧记录中“缩短 165 B”的描述无法满足该布局，不能作为修法或可复用的已验证 profile；
旧备份名中的“已去 hwp”也不能证明其中数据正确。

作者讨论中出现过把 `hwp` 的值由 `on` 改为 `off` 的实验，同时提醒可能降低响应性。
这是有适用条件的实验，不是通用调优步骤。只有已明确字段类型、目标值含义和当前问题时才考虑修改：

1. 用对应版本的结构定义解码原始向量，确认版本、每个字段与数组边界。
2. 修改确认过的字段值，**保持结构总长、记录大小与其它字段偏移不变**；不按固定字符串偏移批量替换。
3. 重新解码候选，逐字段 / 逐字节对照原件，证明差异仅限计划项；无法做到时保留原始数据。

长度正确只是必要条件，不能证明字段值或电源管理行为正确。

## 4. 需要注入时使用官方转换器

在工作区对完整的机型 plist 操作，按官方工具生成 DataProvider：

```bash
/path/to/CPUFriend/Tools/ResourceConverter.sh --kext /path/to/candidate-profile.plist
```

转换器在当前工作目录产生 `CPUFriendDataProvider.kext`。`cf-frequency-data` 应是**完整 plist**，
不是裸 `FrequencyVectors`。使用生成的属性和目录结构，不手工拼装缺字段的 Info.plist。

- `Kernel > Add` 保持依赖顺序：`Lilu` → `CPUFriend` → `CPUFriendDataProvider`。
- DataProvider 是无代码 kext，`ExecutablePath` 为空；不要要求它出现在已加载可执行 kext 的列表中。
- `Comment` 使用可打印 ASCII；具体限制以同版本官方文档 / `ocvalidate` 为准。
- 改前备份原 DataProvider 和 config；新文件与 `Kernel > Add` 引用一起检查。
- `plutil -lint`、同版 `ocvalidate`、启用文件引用检查、语义 diff 均通过后，再按
  [技能入口](../SKILL.md#修改与复验) 的流程同步和复验。

`ocvalidate` 不解读 `cf-frequency-data` 内的电源管理语义，不能替代第 3 节的结构与差异检查。

## 5. 重启后验收与回退

数据在启动时读取。写入后必须重启，再确认实际 CPUFriend 加载、目标机型及当前注入状态。
重复修改前的同机负载，比较耗时、频率、温度、功耗和稳定性；不把历史 4.3 GHz 或跨平台跑分当验收线。
结果变差或出现新 panic 时回退完整的已知可用配置和 DataProvider，不继续叠加变量。

若无法启动，用预先准备的已知可用 EFI 恢复备份；写盘失败或复验失败不意味着原盘从未被改变。

## 6. BIOS 与拓扑线索

对于支持 HWP 的目标 CPU，若 panic 明确涉及 `xcpm_hwp_enable` / MSR `0x770`，
核对 BIOS 的 Intel Speed Shift 设置与实际 HWP 能力；不能把该线索推广为所有 Intel CPU 的前提。
禁用某个 profile 字段也不能证明内核从此不会访问 HWP。

混合架构的核心暴露与 CTR 拓扑属于另一组变量，见 [小核专题](e-cores.md)。
该项目记录了 CTR 与 verbose `-v` 的随机启动失败问题；确认是否命中该已知问题后再归因到 profile。
