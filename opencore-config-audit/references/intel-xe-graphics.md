# Intel Xe-LP 核显：WhateverXe

用于 Tiger Lake、Alder Lake、Raptor Lake 等平台的**特定 Xe-LP 核显**适配。先核对 PCI ID、系统构建和实际显示接线，再判断是否适用；不能仅凭“11 / 12 / 13 / 14 代”或“Iris Xe”名称判断支持。

核对日期：2026-11-01。作者当前发布为 [WhateverXe 0.6.1](https://github.com/b00t0x/WhateverXe/releases/tag/0.6.1) 与 [WhateverXe Graphics 0.3.2](https://github.com/b00t0x/WhateverXe-Graphics/releases/tag/v0.3.2)，两者版本独立。后续操作前重查作者发布说明。

一手入口：[WEX README](https://github.com/b00t0x/WhateverXe/blob/0.6.1/README.md)、[设备选择与接口限制](https://github.com/b00t0x/WhateverXe/blob/0.6.1/docs/device-selection.md)、[图形包安装与卸载](https://github.com/b00t0x/WhateverXe-Graphics/blob/v0.3.2/README.md)。本专题整理作者的覆盖范围，本技能没有新增实机验收结果。

## 1. 先判支持范围

| GPU / 平台 | 作者当前证据与边界 |
|---|---|
| Tiger Lake-U | 48 / 80 EU 有实机记录，含桌面式接线与笔记本内屏；其它 U / H35、96 EU 尚待实机验证 |
| Tiger Lake-H45 | `9A60` / `9A68` / `9A70` 接受，尚待实机验证 |
| Alder Lake-N / Twin Lake | ADL-N 16 / 24 EU 双 HDMI 有实机记录；其它配置及 Twin Lake 尚待验证 |
| Alder Lake-H / P / U、Raptor Lake-H / P / U | ADL-H `46A6` 有固定 TC HDMI、DP 转 HDMI 适配器实机记录；其它型号及直连 DP 不因此获得验收。移动 eDP 是 0.6.1 的实验实现，未有实机结果 |
| Alder Lake-S / HX、Raptor Lake-S / HX | ADL-S UHD 770 `4690` 有 HDMI / DP / 固定 DP 接线 USB-C 记录；`4680` 等其它接受 ID 与 HX / RPL-S 仍需分别验证 |
| Rocket Lake-S | 当前版本不支持，不能按 Xe-LP 名称套用 |
| Meteor Lake Xe-LPG、Xe2 及以后架构、Arc 独显 | 不在本项目当前核显路线内；作者对 Xe-LPG / Xe2+ 无支持计划 |

完整 ID 表与资源限制以作者 device-selection 为准。**ID 被接受、后端已实现、特定机器已测试是三个不同层次**。

接口也要分开判断：

- Tiger Lake 已有 eDP、HDMI、USB-C DP Alt Mode 测试；TC3 / TC4 固定 DP 等新增接线未全部实机验证。
- ADL-N / Twin Lake 与 ADL / RPL 移动平台：固定 HDMI、匹配 VBT AUX 的实验性固定 TC1–4 SST DP；外部 Combo DP、MST、USB-C DP Alt Mode、Thunderbolt 管理输出仍不支持。移动 eDP 仅限作者描述的单面板 Combo A/B、PPS0 / PCH PWM 路径，不能保证笔记本内屏可用。
- ADL-S / HX、RPL-S / HX：实现 Combo PHY A–C；PHY D/E、Type-C / TBT 管理路线不支持。**USB-C 插座接成固定 DP，不等于支持 USB-C DP Alt Mode**。

## 2. 系统版本与内核分流

| macOS | 作者要求 |
|---|---|
| Big Sur | 11.7.11 |
| Monterey | 12.7.6 |
| Ventura | 13.7.8 |
| Sonoma | 14.8.9 |
| Sequoia | 15.8.x |
| Tahoe | 26.7 及以后同系统系列的维护更新 |

图形包当前对应的基准 build 是 `20G1443`、`21H1320`、`22H730`、`23J631`、`24H32`、`25G241`。11–14 还要求经过限定的 kernel identity；15 / 26 接受范围内的维护更新，但保留指令与 ABI 检查，**未来更新未预验证**。

一个 WEX 二进制配一个图形 pkg 按当前 OS 选择载荷，通常无需像无线驱动那样为每个系统复制一份 WEX。共用 EFI 的双系统仍须**分别启动每个目标 macOS 安装图形 pkg，各自更新 AuxKC**；在一个系统安装不会自动覆盖另一个系统卷。
`Kernel>Add>MinKernel` / `MaxKernel` 只是 Darwin 粗筛，不能替代上述版本、kernel identity 或运行时 ABI 检查。
例如只供 macOS 26 使用的条目可限定 `25.0.0–25.99.99`，但这**不代表 26.0–26.6 可用**，也不放行下一代 Darwin。

## 3. 必需组件与安装顺序

| 组件 | 放置 / 用途 |
|---|---|
| Lilu | EFI 注入；必须先于 WhateverXe 加载，选兼容目标系统的版本 |
| WhateverXe.kext | 从作者 RELEASE ZIP 解压至 `EFI/OC/Kexts`，在 `Kernel>Add` 启用；DEBUG 仅排障 |
| AMFIPass 1.4.1 **Mod** | 用图形包仓库链接的 [Mod 归档](https://github.com/b00t0x/WhateverXe-Graphics/blob/v0.3.2/extras/AMFIPass-v1.4.1-Mod-RELEASE.zip)；替换已有同名组件，不能同时加载两份。普通上游 AMFIPass 不支持此签名链 |
| WhateverXe Graphics pkg | 在目标 macOS 中安装图形驱动、编译组件和 AppleIntelTGLCompat 至 `/Library`，重建 AuxKC；WEX 的 ZIP 不含这些载荷 |

**WhateverGreen 与 WhateverXe 禁止同时启用，混合显卡机器也不例外。** 禁用 WEG 或替换 AMFIPass 之前，先核对 NVIDIA 等现有独显的驱动版本、WEG 相关功能、AMFIPass / OCLP 签名链、GPU 禁用属性和显示接线；作者未给出与这些独显驱动的共存保证。证据不足时先保留现有工作配置并准备可回滚候选，不能为了加 Xe 支持顺手停掉用户仍需使用的独显，也不能同时保留两套插件。已有 `-wegnoigpu`、BIOS 关闭核显或针对目标 iGPU 的 `disable-gpu` 等设置时，先按用户目标解除相应禁用条件，不改其它 GPU 的保留设置。

仅对这条作者安装路线：

- `NVRAM>Add>7C436110-AB2A-4BBB-A880-FE41995C9F82>csr-active-config` 使用 **Data `03080000`**（数值 `0x803`），作者不支持完整 SIP。需要覆盖已有同名变量时才配对应 Delete；pkg 不会替你改 SIP。
- `boot-args` 添加 **`-allow3d -disablegfxfirmware`**。使用匹配的签名载荷与 Mod AMFIPass 时，不需要额外加入 `amfi=0x80` 或 `ipc_control_port_options=0`；其它组件已有参数先核对依赖，不直接批量删除。
- 不从“第三方 kext”推导额外关闭 `SecureBootModel`。安全设置变化按已授权任务记录原值与恢复方式，见 [权限与安全专题](amfi-and-tcc.md)。
- 仍需 OCLP 为其它设备打 root patch 时，作者要求使用其[同签名链的 OCLP 分支](https://github.com/b00t0x/OpenCore-Legacy-Patcher)。上游 OCLP 与 Xe 的信任链不能靠混装两份 AMFIPass 解决；Xe 本身不依赖 OCLP root patch。

准备好 EFI 后，先从该 EFI **启动目标 OS**，再安装最新匹配图形 pkg。旧 Xe 系统卷补丁须先按原恢复流程撤销；新 pkg 不会替你修复旧补丁。安装器报告成功后重启，失败时先处理错误，不能把文件落盘视为安装完成。图形包不修改 EFI、System 文件或快照；Tahoe 的 `CoreMedia / AllowOnePassMetalScaling` 禁用项由安装器处理。

WEX 条目核对值（完整 config 仍由同版 Sample 与 ocvalidate 校验）：

| `Kernel>Add` 字段 | 值 |
|---|---|
| `Arch` / `Enabled` | `x86_64` / `true` |
| `BundlePath` | `WhateverXe.kext` |
| `ExecutablePath` | `Contents/MacOS/WhateverXe` |
| `PlistPath` | `Contents/Info.plist` |
| `MinKernel` / `MaxKernel` | 多系统共用时可留空；仅部署某 OS 时按 §2 限定 |

包内标识符为 `org.b00t0x.WhateverXe`。[构建源码](https://github.com/b00t0x/WhateverXe/blob/0.6.1/tools/build.py) 的 Lilu 依赖下限为 1.2.0；这不表示该老版本适合 Tahoe，作者构建 CI 使用 1.7.2。以当前系统兼容性选 Lilu，不把 CI 版本误写成运行下限。

## 4. 属性、DVMT 与内屏

默认用**物理 PCI ID 自动选择后端**，从 VBT 读取支持的连接器接线。TGL GT1、ADL-S / HX、RPL-S / HX 的 Display12 小 GT 后端要求物理 ID，不能设置 override；尤其不能把 `4680` 仿冒成 `4690` 来声称属于已测硬件。不要照搬旧 Ice Lake `device-id` / framebuffer 伪装，或只为改名字而仿冒设备。确需 override 时按作者 device-selection 处理四字节小端 Data；接受目标 ID 不会伪造 EU 数量或让未知接线受支持。

- BIOS 的 **DVMT Pre-Allocated 优先设为 96 MB**。若固件固定为 **60 MB**，才按作者方案添加 `-igfxdvmt`，并在目标 iGPU 的 `DeviceProperties>Add` 中设 Data：`framebuffer-patch-enable=01000000`、`framebuffer-stolenmem=0000C003`。常见路径是 `PciRoot(0x0)/Pci(0x2,0x0)`，先核对实际路径。两项仅适配 / 限定内存池，不能增加固件预留内存；96 MB 时不需要这些 DVMT 特例。
- 支持的内屏亮度需加入适配目标 ACPI 的 `SSDT-PNLF`；亮度补丁不能补齐未实现的内屏后端。ADL-P / N 及对应移动后端的实验 eDP 路径，还要求固件已提供单个线性、8-bpc RGB GOP 于 pipe A；内屏伴随多个活动固件显示会在启动接管前被拒绝。该启动前提不表示后续原生 pipe 分配只能用 A，详见作者设备说明。
- WEX 会在支持设备上处理 MEI / HECI 到 IMEI 的命名，无需额外照抄 ACPI rename。
- 当前版本已不需要 `-wex-nopanel`、ADL-N 的家族选择参数或手动 `AAPL,GfxYTile`。已有属性先核对来源；相关 Display13 GPU 不使用 `-yTileDisable`。
- `-wex-noaccel` 仅用于 framebuffer 排障，不能据此声称 Metal / 硬解可用，也不能启用未支持的显示后端。更多开发参数按作者 README 按需取用。

## 5. 验证、限制与回退

先在离线 EFI / 备用引导中完成 [配置与引用校验](../scripts/oc-verify.sh)，实际维护按[技能入口的备份与复验流程](../SKILL.md#修改与复验)。图形包容器未签名、未公证，修改后的载荷使用 Mod 代码签名；WEX ZIP 与图形 pkg 从各自作者发布页取得并核对 `SHA256SUMS`；Mod AMFIPass 使用作者指定归档。不能用全局关闭 Gatekeeper 代替来源检查。

重启后分层验收：

1. `sw_vers` / `uname -r` 与目标 build、物理 PCI ID、VBT 接线符合预期；`kmutil showloaded --list-only` 核对 Lilu、WhateverXe、Mod AMFIPass、图形驱动和 AppleIntelTGLCompat。
2. `system_profiler SPDisplaysDataType`、IORegistry 和实际输出核对 framebuffer / Metal；显示了 GPU 名称不等于加速成功。
3. 实测所需 Metal / MPS / OpenGL / OpenCL，以及 H.264 / HEVC 会话与驱动归属；作者部分硬件有 H.264 编解码、HEVC 解码记录，不能扩展为所有 codec 均可用。
4. 每个实际接口分别验证点亮、亮度、热插拔、显示睡眠和系统睡眠；结果注明 GPU、系统 build、接口和适配器。

作者当前列明：DP / USB-C 重连可能黑屏或卡死，Sequoia App Store 视频可能挂 GPU，部分图像转换可能崩溃；FairPlay 不支持。最多同时三屏，已测分辨率不是硬性上限；更高分辨率和完整系统睡眠 / 唤醒尚未验证。不要把显示器睡眠通过当成系统睡眠通过。

回退使用图形包仓库当前的 [uninstall.sh](https://github.com/b00t0x/WhateverXe-Graphics/blob/main/uninstall.sh)，先审阅来源和移除范围再执行：它清理本项目图形载荷与 scaling 覆写、重建 AuxKC、清除对应 receipts，成功后重启；**不会恢复旧图形栈，也不会删除 EFI 中的 WEX / Lilu / AMFIPass 或恢复 SIP**。EFI 从已验证备份恢复；其它设备仍需的 Lilu / AMFIPass 先核对依赖。`-wexoff` 可临时停用插件作诊断，不等于卸载图形包或完整回退。
