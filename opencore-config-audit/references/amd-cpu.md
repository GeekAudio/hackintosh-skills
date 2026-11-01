# AMD Zen CPU：电源管理、监控与 AMD Power Gadget

用于 Ryzen / Threadripper 等 AMD Zen 平台的温度、功耗、频率读数，AMD Power Gadget，以及按需评估 P-State / 风扇控制。先核对实际 CPU、macOS build、驱动与现有电源设置。

上游：[trulyspinach/SMCAMDProcessor](https://github.com/trulyspinach/SMCAMDProcessor)。核对日期 2026-11-01，最新正式发布为 [0.7.2f1](https://github.com/trulyspinach/SMCAMDProcessor/releases/tag/0.7.2f1)（2024-03-31）。Actions 构建是独立的开发候选，不能只凭较新时间替换已工作的发行包。

## 1. 三个组件各做什么

| 组件 | 用途与依赖 |
|---|---|
| `AMDRyzenCPUPowerManagement.kext` | 电源管理、CPU 读数及控制接口；**AMD Power Gadget 必需**。依赖 Lilu，不依赖 VirtualSMC 数据桥 |
| `SMCAMDProcessor.kext` | **VirtualSMC 传感器插件**，把前者的数据导出给 iStat 等应用；同时依赖 AMDRyzenCPUPowerManagement、VirtualSMC 和 Lilu |
| `AMD Power Gadget.app` | 上游图形监控 / Power Tool / P-State 编辑入口；只装 App 不能替代内核组件，也不必为了使用它额外安装 SMCAMDProcessor 数据桥 |

两份 kext 是同项目拆分后的不同组件，不能把 `AMDRyzenCPUPowerManagement` 当作可以删除的旧名称。优先使用同一 release 的配套文件；发行 tag、App 版本、两份 kext 的版本字段不必相同。

它们不替代 AMD 安装 macOS 所需的 `AMD_Vanilla` 内核兼容补丁，也不负责 AMD 核显加速。Intel 的 CPUFriend、SMCProcessor、HWP / E 核方案不能直接套用到 AMD；不要为了补温度读数换掉现有能启动的内核补丁或平台配置。

依据：[上游 README](https://github.com/trulyspinach/SMCAMDProcessor/blob/0.7.2f1/README.md)、[主驱动依赖](https://github.com/trulyspinach/SMCAMDProcessor/blob/0.7.2f1/AMDRyzenCPUPowerManagement/Info.plist)、[VirtualSMC 桥依赖](https://github.com/trulyspinach/SMCAMDProcessor/blob/0.7.2f1/SMCAMDProcessor/Info.plist)。

## 2. 支持范围与系统

| 范围 | 已知依据与核对方式 |
|---|---|
| AMD Zen | 作者定位为 Zen 电源管理与监控；核对实际 CPU Family / Model、核心拓扑和传感器，而非只看 Ryzen 商标或 SMBIOS 显示名 |
| Family `17h` / `19h` | 0.7.2f1 源码将这两个家族标记为受支持；这不是每个具体型号、主板和功能均已验收的清单 |
| 其它家族 / 新型号 | 依据具体实现与机器结果判断；源码的支持标志不是保证其它家族安全拒绝加载的保护，不能为 Family `1Ah` 等新家族照抄旧寄存器调节值 |
| **macOS 26 Tahoe** | **本次维护中用户已确认可以支持**。该反馈未附具体 CPU / build / 组件版本与功能测试范围；在目标机记录这些信息，分别验证监控、电源管理和风扇功能 |
| 其它 macOS / 后续维护更新 | 上游未给出完整的逐 OS / build 验收矩阵；编译部署目标、版本号留空或驱动已加载都不能单独证明全部功能可用 |

[主驱动源码](https://github.com/trulyspinach/SMCAMDProcessor/blob/0.7.2f1/AMDRyzenCPUPowerManagement/AMDRyzenCPUPowerManagement.cpp) 会解析内核符号并访问 MSR / PCI，加载后也参与电源管理，**不能把它描述成完全无副作用的温度读取器**。新系统要结合实际服务启动、读数与负载 / 休眠行为验证；不因发行日期较早就断言 Tahoe 不支持。

## 3. OpenCore 配置与加载顺序

先备份目标 EFI，按现有 [配置校验与复验流程](../SKILL.md#修改与复验) 操作。把作者 release 解压得到的完整 bundle 放进 `EFI/OC/Kexts`，同步 `Kernel>Add`；不把 App 放进 Kexts，也不把安装 EFI 等同于热加载到当前系统。

满足下面的依赖顺序即可，不要求所有无关 kext 都重排：

```text
Lilu → AMDRyzenCPUPowerManagement → SMCAMDProcessor
Lilu → VirtualSMC                → SMCAMDProcessor
```

只使用 AMD Power Gadget 时，不必新增最后的 SMCAMDProcessor；需要向 VirtualSMC 应用发布 CPU 读数时才加。系统已有其它 SMC 仿真路线时，不为这个可选桥同时加载 FakeSMC 与 VirtualSMC。

| 条目 | `BundlePath` | `ExecutablePath` | `PlistPath` |
|---|---|---|---|
| 主驱动 | `AMDRyzenCPUPowerManagement.kext` | `Contents/MacOS/AMDRyzenCPUPowerManagement` | `Contents/Info.plist` |
| 可选传感器桥 | `SMCAMDProcessor.kext` | `Contents/MacOS/SMCAMDProcessor` | `Contents/Info.plist` |

启用条目设 `Enabled=true`，架构按 x86_64；核对实际包内可执行文件和 plist。0.7.2f1 的元数据要求 Lilu ≥1.3.9；桥还声明 VirtualSMC ≥1.0.0 与主驱动兼容版本 ≥0.6。这些是依赖门槛，不等于推荐使用旧 Lilu / VirtualSMC，实际版本还须兼容目标 macOS。

`MinKernel` / `MaxKernel` 按当前 EFI 的已验证部署范围填写，可共用的构建不因系统不同就复制两份。只在 Tahoe 目标上使用时可限制 Darwin `25.0.0–25.99.99`；它只筛选系统家族，不证明所有 25.x / CPU 型号均已验证，也不应借留空或 beta 参数强行绕过未知 ABI。

上游安装流程没有把关闭 SIP / AMFI、全局 Gatekeeper 或增加核显用的 CSR 值作为本项目默认要求。若 App 被拦，先核对来源 / 签名和单应用例外，见[权限与安全专题](amfi-and-tcc.md)，不照抄其它驱动的安全参数。

## 4. 先读数，再按目标评估控制

目标只是查温度、功耗或频率时，先采样，保留 BIOS 与 App 的原有设置，不操作 P-State、Boost 或风扇覆盖开关。驱动本身已参与电源管理，安装前后的基线也要保留。

| 要验证什么 | 方法与判据 |
|---|---|
| 主驱动 / 桥是否加载 | `kmutil showloaded --list-only` 查 `AMDRyzenCPUPowerManagement`、`SMCAMDProcessor`、Lilu / VirtualSMC；旧系统用 `kextstat` |
| IOKit 服务是否启动 | `ioreg -r -c AMDRyzenCPUPowerManagement -l`；需要桥时再查 `ioreg -r -c SMCAMDProcessor -l`。磁盘文件存在不代表已运行 |
| CPU 拓扑 | 实际型号、`sysctl -n hw.physicalcpu hw.logicalcpu` 与 BIOS 活动核数 / SMT 相符；不把显示机型当物理 CPU 证据 |
| 温度 / 功耗 / 频率 | AMD Power Gadget 中按空闲、短单核、短多核负载比较曲线与有效频率，并交叉核对其它可用传感器。单个读数非零、软件显示最高频率，都不等于所有核心持续运行在该频率 |
| iStat 等没有 CPU 数据 | 先核对主驱动，再查可选桥、VirtualSMC 及其加载顺序；App 可读取而 iStat 不行时不先重做 AMD 内核补丁 |
| 新增后 panic / 卡顿 / 睡醒失败 | 保留对应启动与 panic 日志，先用已验证备用 EFI 回退新增组件，对照控制设置和内核符号；不只凭症状认定 BIOS 或 CPU 已损坏 |

需要新增采集工具时按具体任务准备；本技能未附带自动 AMD 压测、调频或写 MSR 脚本。

## 5. P-State 与风扇控制

作者 README 的 P-State 入口是 App 内 **Power Tool → Speed → Advanced Options**，并列有手动速度 / P-State 编辑功能。这些操作会改变硬件状态，不能当作只读监控或“修温度显示”的默认步骤。编辑器行为见[上游源码](https://github.com/trulyspinach/SMCAMDProcessor/blob/0.7.2f1/AMD%20Power%20Gadget/Power%20Tool/PStateEditorViewController.swift)。

- 保留当前 P-State / Boost / App 设定和恢复方法；P-State 编辑器的 **Revert 用 App 当前缓存的 PStateDef 重置尚未应用的编辑内容**，不会写回硬件，也不恢复改动前或出厂值。仅在用户明确要求调节的范围内，以目标 CPU 的资料和可归因的小步改动验证。不提供跨 CPU 通用电压、频率或 MSR 写值。
- **保留权限检查**。`-amdpnopchk` 会绕过作者的权限检查，不是提高性能或让监控可用的必需参数；不为方便默认添加。README 的早期 root 描述与具体版本授权实现可能不同，按当前 App / 驱动实际提示处理，不批量修改系统权限。
- 风扇入口为 **Open → SMC Fans** 或 Power Tool 按钮；这是有限 Super I/O 芯片支持的实验功能。0.7.2f1 的发布说明新增 NCT6799D，不代表任意同品牌主板都能控风扇。
- 主驱动自带 Super I/O 探测 / 控制实现，不以额外安装 SMCSuperIO 为前提。先核对芯片、风扇通道映射与已有控制工具；多个读数导出插件不等于可以同时让多个工具写同一个风扇控制器。
- 转速读数有效不证明 PWM / 自动模式恢复正确；验证控制时同时观察实际风扇与温度，结束后显式恢复原自动控制。不要假定退出 App、删除 kext 或热卸载就恢复全部寄存器状态。

依据：[README 功能与权限说明](https://github.com/trulyspinach/SMCAMDProcessor/blob/0.7.2f1/README.md)、[实际控制接口](https://github.com/trulyspinach/SMCAMDProcessor/blob/0.7.2f1/AMDRyzenCPUPowerManagement/AMDRyzenCPUPMUserClient.cpp)。

## 6. 回退

先在 App 中恢复自己改过的 P-State / 风扇设置并关闭相关自动启动项；EFI 从已校验备份恢复，或停用本次新增的条目。移除主驱动时同时停用依赖它的 SMCAMDProcessor；只移除传感器桥则不必为了它删除仍需使用的 Lilu / VirtualSMC。随后重启，验证主驱动 / 桥的实际加载状态、频率、温度与风扇行为。BIOS 中改过的项目按原记录单独恢复，不能声称 EFI 回滚会自动恢复 BIOS 或所有运行态控制值。
