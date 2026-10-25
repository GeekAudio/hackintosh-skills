# AirDrop / 接力（Handoff / 连续互通）排障

先区分用户要恢复的功能：AirDrop、Handoff、通用剪贴板的支持范围不能互相代替。不要因某一功能失败就改 ROM、三码、UUID 或网络接口顺序。

## 1. 官方依据与能力边界

[Apple 连续互通要求](https://support.apple.com/en-us/108046) 按功能列出设备与系统条件，应选择目标功能核对账号、开关及无线连接要求，不能将所有功能简化为一个接口判据。

[OpenIntelWireless FAQ](https://openintelwireless.github.io/itlwm/FAQ.html) 说明：`AirportItlwm` 支持的连续互通功能限于 Handoff 与通用剪贴板；AirDrop 不在支持范围。`itlwm.kext` 使用 `IOEthernetController`，与 `AirportItlwm` 的能力不同。因此，「没有 Broadcom / AWDL 就一定没有 Handoff」不是通用结论。

[Dortania iServices 指南](https://dortania.github.io/OpenCore-Post-Install/universal/iservices.html#fixing-en0) 检查 `en0` 的存在与 built-in 标记，并允许不同接口类型。无线为 `en1` 不构成需要重排接口的证据，见 [接口顺序](network-en0-order.md)。

## 2. 排查顺序

1. 明确故障功能、两端设备 / 系统版本、是否曾经可用，以及最近改过的驱动或补丁。
2. 对照 Apple 的该功能要求检查开关、发现范围、账号和连接条件；AirDrop 的发现范围与 Handoff 的账号条件分别判断。
3. 确认无线芯片及实际驱动。先查作者的当前支持范围，驱动不支持的功能应说明限制，不以反复改 EFI 尝试补出能力。
4. 对已支持 AirDrop 的驱动检查点对点接口，例如 `ifconfig awdl0`，再结合蓝牙状态、日志与两端实际传输测试。接口存在只是证据之一，不能单独证明 AirDrop 可用，也不能据此推断所有连续互通功能正常。
5. 检查多个无线 / 蓝牙控制器、旧驱动残留或补丁失配时，先确定设备归属与加载来源，再选择单项验证。不要仅因存在第二个控制器就禁用它。
6. 仅在证据指向 EFI、kext 或系统补丁时修改对应项；记录回滚并在重启后重新测试目标功能。

可按需采集：

```bash
networksetup -listallhardwareports
ifconfig awdl0
system_profiler SPAirPortDataType
system_profiler SPBluetoothDataType
kmutil showloaded --list-only
```

重启后等驱动初始化，再按实际 `enX` 检查连接。`system_profiler`、接口 flags 与 kext 加载记录均需结合功能验证，避免把某个输出当成唯一成功判据。

## 3. 选择驱动时

| 方案 | 如何判断 |
|---|---|
| `AirportItlwm` | 按官方 FAQ 区分 Handoff / 通用剪贴板与不支持的 AirDrop |
| `itlwm.kext` | 不套用 `AirportItlwm` 的支持列表，查该产物自己的限制 |
| 博通原生栈 / 补丁方案 | 核对目标 macOS、驱动与补丁兼容性，再实测 AirDrop / Handoff |
| MediaTek 原生或第三方方案 | 按芯片、具体驱动版本和实现路线核实，见 MediaTek 专题 |

不要仅为 Handoff 一项功能要求用户更换 Broadcom 网卡。需要购置硬件时，先核实当前系统的兼容范围及用户需求。

## 4. 案例与相关专题

参考机器曾在有线为 `en0`、无线为 `en1` 时正常使用 AirDrop。这只是否定「无线必须为 en0」的案例，不能据此推出任意身份字段变化都无影响。机器历史见 [machine-facts.md](machine-facts.md)。

- [博通无线](broadcom-wifi.md)
- [Intel 无线](intel-wifi.md)
- [MediaTek 无线](mediatek-wifi.md)
- [SMBIOS 与身份信息](smbios-and-serials.md)
