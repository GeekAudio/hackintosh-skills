# OpenCore 与 Windows 共存：审查、验证与回滚

用于双系统配置审查、经 OpenCore 启动 Windows 后蓝屏 / 设备异常、身份或启动顺序变化。完整 EFI 构建仍优先 [1401](1401-efi-workflow.md)；本专题是候选配置的兼容性复核，不是一套所有机器必须照抄的参数。

本次依据为 OpenCore **1.0.8** 官方文档与实现（2026-11-01 核对）；实际操作取目标引导器同版资料。先区分**固件直接启动 Windows Boot Manager**与**经 OpenCore 启动 Windows**，保存完整 EFI、目标分区标识、原始 ACPI、BIOS 与启动项基线。直接启动可用于对照，但不会撤销先前已写入的 NVRAM、BIOS 或磁盘改动。

## 1. 哪些改动会跨系统

| 配置 / 操作 | 审查边界 |
|---|---|
| `ACPI > Delete / Quirks / Patch / Add` | 对经 OC 引导的各系统全局生效，新增 SSDT 也不例外；顺序为 Delete → Quirks → Patch → Add，`RebaseRegions` / `SyncTableIds` 在其后处理 |
| `PlatformInfo` | 普通 SMBIOS 更新可能改变 Windows 所见硬件身份；`Custom` 模式有单独 GUID 的隔离路径，见 §3 |
| NVRAM、UEFI 驱动 / 硬件设置、BIOS | 可能影响后续系统或持续留在固件中；不能把 `boot-args` 只由 macOS 解析推广成整节 NVRAM 无影响 |
| `Kernel` 注入 / 补丁、`DeviceProperties` | 面向 XNU / macOS，通常不是 Windows 蓝屏的直接配置来源；不据此放行同次操作附带的 ACPI、固件或安全设置改动 |
| `Booter > Quirks` | 逐项核对作用对象与实际平台分支，不能把所有内存相关项都视为 Windows 开关；`SyncRuntimePermissions` 可能是受影响固件启动 Windows 所需的修正，不能反读为默认应关闭 |

例如 `Booter > Quirks > ResizeAppleGpuBars` 与 `UEFI > Quirks > ResizeGpuBars` 作用范围不同；`DisableIoMapper` 属于 **Kernel > Quirks**，`DisableVariableWrite` 属于 **Booter > Quirks**。1.0.8 的 `RebuildAppleMemoryMap`、`ProtectMemoryRegions`、`DevirtualiseMmio` 等走 Apple 启动分支，不能直接解释成 Windows 收到了重建的内存图。不因排查 Windows 而将 1401 按目标机器生成的 quirk 整组关闭。

依据：[ACPI 顺序](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L846-L869)、[运行时权限修正](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L1900-L1930)、[实际 Apple / 通用内存分支](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Library/OcAfterBootCompatLib/ServiceOverrides.c#L617-L666)、[Windows 支持边界](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L9700-L9725)。

## 2. ACPI：检查实际对象与非 macOS 行为

- **Add 不等于无害**。按实际 AML、命名空间、操作区和方法依赖检查，不能仅凭 `SSDT-EC` / `PLUG` / `AWAC` 等文件名判断风险。新增虚拟设备可按需要在非 Darwin 下隐藏；修改原有设备时则要保留该系统需要的原行为。
- `_OSI("Darwin")` 可让 AML 在运行时分支，但不撤销全局重命名、删表、顶层副作用或已改变的硬件状态。不是每份 SSDT 都必须加它，也不是加了就完成隔离。
- 若确需包装已有 `_STA`，先核实它原本是方法、整数对象还是不存在，再决定是否重命名与透传。仅当原方法已正确保留为 `XSTA` 时，非 Darwin 分支才可调用 `XSTA()`；不能给所有设备直接补这一行，也不能统一返回 `Zero` 或 `0x0F`。
- `ACPI > Patch > Base` 是查找起点，不是作用域沙箱；填写时用实际的绝对 ACPI 路径。结合目标表、唯一字节上下文、`Count` / `Limit` 等约束，并验证真实匹配次数。空 Base 是合法配置，`Count=1` 只改一次但可能命中错误对象；不能声称空 Base 必然改遍整表。
- Find / Replace 长度须相同。表头过滤也不能代替对象级定位；不要给每条现有补丁机械补上同一 Base、Count 或 OEM ID。`RebaseRegions` 是启发式区域重定位，不是只修注入表的无害开关。
- `_OSI → XOSI` 可能改变其它系统的调用；先核实 wrapper 是否在非 Darwin 下委托原 `_OSI`，以及目标硬件是否仍需要。官方建议尽量避免这类补丁，不代表现代平台全部无需它或应直接删除。
- `SSDT-UIAC + USBInjectAll` 的常见方案是向 macOS 驱动提供映射数据，不能等同于直接改 `_UPC` / `_PLD`；若实际 AML 确实修改这些对象，再按跨系统影响审查。USBMap / USBToolBox 是可选的 macOS 映射路线，不能仅凭文件名判 Windows USB 故障。
- `ACPI > Delete` 会影响其它系统。针对 macOS IOMapper 冲突，优先评估 `Kernel > Quirks > DisableIoMapper`，而非删除 DMAR 或关闭整机 VT-d。确需替换表时，精确匹配并验证完整替代表及各系统行为。

具体取表、反编译和编译见 [ACPI / SSDT](acpi-ssdt.md)。ACPI_BIOS_ERROR、设备丢失是现象；先比对直接启动与经 OC 启动的差异，不预设根因就是缺 Base、NVMeFix 或某个 SSDT 文件名。

机制示例：[USBInjectAll 的 UIAC 数据表](https://github.com/RehabMan/OS-X-USB-Inject-All/blob/master/SSDT-UIAC-ALL.dsl)、[SSDTTime 的 XOSI 生成逻辑](https://github.com/corpnewt/SSDTTime/blob/master/SSDTTime.py#L2225-L2277)。这些不是目标机器的替代输入，按实际所用版本和 AML 复核。

## 3. SMBIOS 与 Windows 身份

正确键路径为 **`PlatformInfo > UpdateSMBIOSMode`**，不在 Generic 下。需要保留 Windows 原 SMBIOS、避免 OEM 软件或激活冲突时，可评估这组同版选项：

```text
PlatformInfo > UpdateSMBIOSMode = Custom
Kernel > Quirks > CustomSMBIOSGuid = true
```

前者将新表放到自定义 GUID，后者修补 AppleSMBIOS / AppleACPIPlatform 的读取 GUID；官方说明其副作用是将 SMBIOS 更新限定于 macOS。不能把 Custom 和 Create 一起描述为必然替换 Windows 所见表，也不因发现双系统就自动启用这组设置；还要考虑现有固件与 Apple 工具的兼容性。

官方也建议在适用时考虑原固件 `SystemUUID`，但原值可能无效，且改变现有 macOS UUID 会影响已有身份。先比较直接启动 / 经 OC 的 SMBIOS 与当前配置，保留稳定 UUID、ROM、serial / MLB；不用“必须改回原 UUID”作为通用清单，也不保证改 UUID 一定解决激活。真实标识只保存在本地脱敏记录中。迁移详见 [SMBIOS 与身份](smbios-and-serials.md)。

`PlatformInfo > Generic > AdviseFeatures` 是补充 FirmwareFeatures 的选项，其中含 Windows 重启切换所需的功能位；这些位可能已经存在。按实际功能与现值判断，不把它当成 Windows 启动或激活的万能开关。

依据：[Custom 模式](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L5582-L5614)、[配套 GUID quirk](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L2723-L2730)、[AdviseFeatures](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L5833-L5863)。

## 4. Windows 入口：扫描与固件启动项分开查

**OC 菜单缺 Windows**时，先确认实际 ESP 中 `\EFI\Microsoft\Boot\bootmgfw.efi` 存在、原生 Windows Boot Manager 可用，再检查扫描策略与存储驱动。普通 UEFI Windows 从 ESP 加载，不要求 OC 先加载 NTFS 驱动。

`Misc > Security > ScanPolicy` 同时含文件系统与设备类型过滤。保留原策略，以按位 OR 放行本次确需的类型，不为隐藏条目收紧安全策略，也不默认统一清零。以下只演示 **1.0.8 Failsafe / Sample 的基值**，不是每台机器的当前值：

| 表达式 | 结果 | 含义 |
|---|---|---|
| `0x10F0103` | `0x10F0103` | 启用两类锁，文件系统仅放行 APFS；不含 HFS、ESP 或 NTFS |
| 基值 OR `0x400` | `0x10F0503` | 增加 ESP；还须匹配实际存储设备类型 |
| 基值 OR `0x400` OR `0x800` | `0x10F0D03` | 同时增加 ESP 与 NTFS；不是 `0x10F0903` |
| `0` | `0` | 不限制扫描，不代表文件或启动项必然有效 |

`Misc > BlessOverride` 添加 bless 搜索路径，不能绕过扫描过滤或修复 BCD；`Misc > Entries` 也要按同版定义提供正确设备路径等字段，不能把一个文件路径当成完整条目。辅助项按空格展开、`.contentVisibility` 等显示机制核对。

**BIOS 中 OC 启动项消失 / 优先级变化**则按 [固件启动项](boot-entries.md)调查，不和菜单扫描混为一谈。`RequestBootVarRouting` 依赖 OpenRuntime，将 Boot 前缀变量访问导向 OC 命名空间；它不是所有启动路径下都能阻止固件或 Windows 改动的保证。从该环境回读一致也不证明写到了真实固件入口。`LauncherOption=Disabled` 只停止 Launcher 自动维护，不禁止全部 NVRAM 写入；NVRAM Add/Delete、工具和驱动仍须单独检查。

依据：[扫描算法](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L3196-L3258)、[ScanPolicy 位定义](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L4525-L4617)、[Boot 变量路由](https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Docs/Configuration.tex#L9276-L9301)。

## 5. 验证与回滚要覆盖 Windows

1. 先保存可启动基线、完整 EFI 与本轮配置差异。按实际平台做语法 / 引用检查，并记录同版官方 ocvalidate 是否真正执行；1401 的 4551 降级检查另行标记，不能写成官方通过。
2. 对候选逐组测试：直接启动 Windows 与经 OC 启动 Windows，记录设备、显卡 / USB、网络、激活状态和实际症状；涉及睡眠时与该机器原有支持状态比较。`powercfg /a` 只是查询能力，不能要求所有机器都有 S3 + S4，也不证明睡眠恢复已通过。
3. 修改过 BIOS、启动项、身份或安全配置时分别复核；不要默认关闭 TPM、VT-d 或固件 Secure Boot。固件 Secure Boot 与 OC 的 Apple `SecureBootModel` 分开判断。只审查文档不授权修改这些设置。
4. 菜单里选择 Windows 启动即可完成一次路径测试；`Ctrl+Enter` 涉及更改默认项，仅在有此需求时使用。成功进桌面不能代替设备、功能和后续重启验收。
5. 失败时恢复本轮实际改动的成对配置 / AML / 二进制并复验；只有纯配置变动才可能只恢复 config。BIOS、NVRAM 与磁盘写入按各自备份处理，不假设完整 EFI 副本能自动还原全部状态，也不默认运行 `bootrec /rebuildbcd`。

1401 候选的现场状态仍是 `build_bound_live_unverified`；手工修改会破坏文件绑定。按工具重建或走已审查的离线备选，不能伪造 profile 或把构建成功报告成双系统已经验收。
