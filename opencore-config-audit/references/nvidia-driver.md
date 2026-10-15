# NVIDIA 驱动安装方法（NullMoth nvidia-macos-driver）

> ★ **相关补丁仓库**：`laobamac/non-metal-frameworks` —— **非 Metal 框架补丁**（基于 Moraea 已删除的仓库）
> ⇒ 老显卡在 Metal 化系统上的补丁。索引见 `laobamac-toolkit.md`。

> 依据：官方仓库 `nullmoth/nvidia-macos-driver` 的 `README.md` / `docs/HOW-IT-WORKS.md` /
> `docs/TROUBLESHOOTING.md` / `docs/CARD-SUPPORT.md` / `gpu-port/README.md`（逐条摘录），
> 外加本机（ASUS Z690 + RTX 3080 + macOS 26.7.1）的实测补充，实测部分已标注。

## 0. 先确认「这张卡 + 这个系统」在不在范围内

| 项 | 官方口径 |
|---|---|
| 卡 | **Turing 及更新**：GTX 16、RTX 20/30/40/50、TITAN RTX、Quadro RTX、T 系列（T400/T600/T1000、T500/T550/T600/T1200 laptop）。Pascal / Maxwell / Kepler 及更早 **不支持**（那需要另一套内核/固件实现） |
| 系统 | macOS **15 Sequoia**（测试 15.7.x 与 15.8.1）与 **macOS 26 Tahoe**（2.0.0 起），x86_64 |
| 笔记本 | 屏幕接在核显上的机型，内屏不会被加速；接受 PCI ID ≠ 实现 Optimus 显示 mux |
| macOS 26 | ★ **2.0.0 起官方支持 Tahoe**（changelog：「Tahoe: ship the macOS 26 accelerator built from this release」；包内 `kexts/26` 与 `kexts/15` 分开构建）。1.15.0 时代属越界使用（当时官方只声明 macOS 15）。**本机实测**：**2.0.1** 在 macOS 26.7.1 上 4 个 kext 正常加载、桌面可用 |

## 1. 两条安装路线

### A. 官方预编译包（推荐）

```bash
tar -xzf nullmoth-nvidia-*.tar.gz && cd pkgroot
shasum -a 256 -c SHA256SUMS          # 每一行都必须 OK
sudo ./install.sh                    # 拷贝文件 + 重建 Auxiliary Kernel Collection
sudo shutdown -r now                 # 必须重启：注销不会加载驱动
```

首次加载后，系统设置 → 隐私与安全性 里**允许这些扩展**，然后再重启一次。

### B. 1401 Mac App（最省事，会顺带改 OpenCore）

下载 `1401-Mac-<version>.dmg` → 打开运行 1401（驱动包就在镜像里）。它会：

1. 用 NVRAM `boot-path` 找到**启动本机的那个 OpenCore**（找不到就逐分区搜，只认 SMBIOS 匹配的，避免误改救援盘）
2. **先试建 AuxKC**，通不过就什么都不改
3. 备份 `config.plist`，只补第 2 节里缺的项，`plutil` 校验（失败就还原备份）
4. 往选择器加 **`1401: Remove NVIDIA driver`**（`Misc>Tools` + `NullMothSafe.efi`）
5. 跑包里的 `install.sh`，写安装记录到 `/Library/NullMoth/state`

**App 运行期间要一直插着启动 macOS 的那个 OpenCore 盘**（它改的是那份 config）。
App 有「Turn verbose on/off」按钮（= 加/删 boot-args 的 `-v`）。

## 2. ★ 核心概念：kext 装在哪、从哪加载

- 四个 kext（`NVRM` / `NVAccel` / `NVRMFB` / `NVRMAGDC`）装到 **`/Library/Extensions`**，从 **Auxiliary Kernel Collection** 加载
- ⇒ **绝对不要**同时从 `EFI/OC/Kexts` 注入它们（会冲突）。OpenCore 只需要设 SIP 和 boot-args
- 它们链接 Apple 的 `IOGraphicsFamily` / `IOAcceleratorFamily2`，这些只存在于 macOS 自己的 kernel collection 里，所以不能靠 OpenCore 注入

## 3. OpenCore 必需设置（官方表格）

**`NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82`**

| 键 | 值 | 为什么 |
|---|---|---|
| `csr-active-config` | `<430A0000>` | 驱动测试用的 SIP 值（kext 非 Apple 签名） |
| `boot-args` | `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0` | 开 framebuffer + 加速器、4 个显示头；AMFI 参数让 WindowServer 能加载驱动 bundle |

**其他设置**

| 位置 | 值 | 为什么 |
|---|---|---|
| `UEFI → Quirks → ResizeGpuBars` | 保持现值（官方 HOW-IT-WORKS 用 `13` = 8 GB） | 强制改尺寸可能让固件在进入选择器前就停住 |
| `Booter → Quirks → ResizeAppleGpuBars` | 保持现值（HOW-IT-WORKS 用 `-1`） | 大 BAR 可能卡在 PCI configuration |
| `Kernel → Add` | `Lilu.kext` 与 `AMFIPass.kext` **必须启用**（Lilu 在前、AMFIPass 在后） | ★★ **AMFIPass 才是让 WindowServer（platform binary）加载 ad-hoc 签名驱动的那一环**；缺了它 = 没有 Metal 设备 + 黑屏只剩鼠标（上游安装脚本有实测日志）。安装器会自动下载并校验 SHA |
| `Kernel → Block` | `com.apple.iokit.IONDRVSupport`，`Exclude` | 否则固件 framebuffer 会抢走 display index 0 |
| `Misc → Security → SecureBootModel` | `Disabled` | Apple 安全启动拒绝非 Apple 签名的 kext |
| BIOS | Above 4G Decoding **ON**、CSM **OFF** | 卡要映射 4 GB 以上的内存 |
| SMBIOS | 能跑 macOS 15 且带独显的机型（1401 用 `MacPro7,1`；测试过 `iMacPro1,1`） | macOS 26 会拒绝 `iMacPro1,1`，`MacPro7,1` 两个版本都能跑 |

**必须去掉**：任何 `nv_disable=1`、`-wegnoegpu`（这两个会把 N 卡藏起来）、WhateverGreen 的 NVIDIA 补丁、`agdpmod=pikera`。
**显卡不需要任何 `DeviceProperties`**。

**可选 boot-args（排障用）**

| boot-arg | 作用 |
|---|---|
| `-nvrmnoflip` | 让 NVRM 不启用零拷贝直扫，显示器读的是已完成的拷贝。**桌面闪烁/撕裂时第一个试它** |
| `-nvrmnogo` | 驱动待机，等 `nvrmctl go <pass>` 再启动 GPU |
| `-nvrmnobootscreen` | 不截取开机画面 |
| `-nvoff` | 让 NVRM 完全不碰这张卡（选择器的「Start once without NVIDIA driver」就是用这个） |
| `nvrmsettle=<ms>` | 覆盖 GPU 上电后的等待时间（官方在 Turing 上给过 `10000`） |

**装完验证**

```bash
kmutil showloaded --list-only | grep nullmoth     # 应为 4 行
system_profiler SPDisplaysDataType | head -20     # 应显示你的 GeForce、Metal: supported
```

## 4. 恢复路径（进不去系统时）

1. 选择器选 **`1401: Remove NVIDIA driver`**（按 Y 确认，再选 macOS）—— 它会加 `-nvoff` + 写 NVRAM 标志 `nullmoth-remove=1`，macOS 起来后 LaunchDaemon `com.nullmoth.recover` 执行 `--remove` 并自动重启
2. 或选择器选 **`1401: Start once without NVIDIA driver`**（`-nvoff`，只影响这一次启动）
3. 或从别的系统里，把 `EFI/OC/config.plist` 的 boot-args 加上 `-nvoff`，并在 `Kernel>Block` 里屏蔽 `com.apple.NVRM*`
4. 开机 logo（`NullMothLogo.efi`）默认关闭；**它可能让固件到不了选择器**，若选择器不出现，从别的系统里把 `NullMothLogo.efi` 关掉（boot-args 救不了「选择器之前就挂住」的情况）

## 5. 常见故障对照（官方 TROUBLESHOOTING 摘要）

| 现象 | 原因 | 处理 |
|---|---|---|
| 桌面亮约一分钟，然后黑屏只剩鼠标 | 一分钟时驱动切到「直接从显存扫描输出」，而桌面画在核显或小 BAR 窗口上 | 1.14 已修；更早版本加 `-nvrmnoflip` |
| 100–240 Hz 黑屏/闪，或改分辨率/刷新率后出现 | DisplayPort 1.4 带宽不够需要 DSC，而没告诉 macOS | 1.14 已发压缩设置；仍出现就 Send logs |
| macOS 26 黑桌面 | 包里那个 26 版加速器过期 | 1.14 已修 |
| 换显示器输入再切回来没画面 | 驱动只点亮「没见过」的显示器 | 1.14 已修；更早版本拔插线缆 |
| 老 Intel 板（无 ReBAR）约 100 s 后黑屏，日志有 `cannot hold … not placing` | 固件没列 64 位 PCI range | 1.14 已修 |
| 装驱动后约 19 分钟卡死（Ryzen 7000/8000/9000） | 这些板在安装器写固件设置时挂住 | `Booter → Quirks → DisableVariableWrite = true` |
| Turing 卡装完开机循环在 `AppleKeyStore` | 固件需要更多时间 | 1.13 起 Setup 会自动加 `nvrmsettle=10000` |
| 开机提示 `This version of Mac OS X is not supported on this platform!` + `Mac-…` | 机型不被该 macOS 版本接受 | 用 `MacPro7,1`（macOS 15/26 都能跑）；自建 EFI 用 1401 的「Check your EFI」查 |
| `Quadro T1200 / T 系列 … is older than the driver supports` | 安装器的白名单没覆盖 | 1.14 已修（Turing 及更新全接受） |
| 桌面闪、窗口黑块、Preview 显示块 | 图像内容在 GPU 画完前被标成最新 / 双重释放 | 1.14 已修；仍出现就 Send logs |
| 网页显示不支持 WebGL | 部分 shader 翻译失败 | 1.14 已修 |

## 6. 本机实测补充（ASUS Z690 + RTX 3080 + macOS 26.7.1）

- 包版本 **1.15.0**；`/Library/NullMoth/os-major` = 26，但驱动走 **`kexts/15`** 那份构建（作者注释：NV* 三件套在 15/26 上是同一份二进制）
- boot-args 实配：`nvrmsettle=1500 nvfbsample=1 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth -no_compat_check revpatch=sbvmm,cpuname revcpu=1`
- `ResizeGpuBars=13` + `ResizeAppleGpuBars=-1`；代价 = **开机黑屏 ~21 s**（改 `-1` 约 10 s）
- 开机到 WindowServer **15 s**（无回归）；`NVAccel: configureDevice 10de:2206 — RM owns the card (NVRM.kext)` 是正常行
- 核显要用 `-wegnoigpu` 屏蔽（WhateverGreen），否则核显会留在 PCI 树里参与 AGDC 判定
- 曾经踩过的显示问题：显示器被报成 **30.5"** —— 真因是驱动没填 `IODisplayModeInformation.imageWidth/imageHeight`（已修，PR #199）
- 已知未解决：无 HDMI/DP 音频、雷电 eGPU 无显示、笔记本内屏不加速

## 7. 上报纪律（Send logs）

- **先 Send logs 拿到 report ID，再开 issue**（官方 bug 模板把 report ID 标为必填，且禁用了空白 issue）
- 上报前**先读本机回执**（如 `~/Library/Logs/NullMoth/Reports/report-*/upload-receipt.json`），核对 `confirmed[]` 的条数与 sha —— App 给的扁平 ID 列表可能混进**陈旧条目**
- **ID 重复先怀疑「内容相同」**：服务端按内容寻址，相同内容返回同一 ID，那是去重正常工作
- 采集器可能报 `System log collection did not complete (status 124)` —— 通常只影响**系统日志**那一路，`driver-kernel-log.txt` 照样会传上去
- issue 正文：**一 issue 一问题**、用自己的话写几句、**不粘贴大段日志**（把日志留在 report ID 里）

## 8. 安全提示

装这个驱动必须放宽系统安全边界：`SecureBootModel=Disabled` + `csr-active-config` 放宽 SIP + AMFI 参数（`amfi_get_out_of_my_way`），
且 `Lilu.kext` / `AMFIPass.kext` 必须启用。
这是**有意降低系统安全性**换图形加速，只在明确需要时做；不装驱动时把这几项恢复原值。

> ★★ **关 AMFI 有一个隐性代价**：**TCC 权限弹窗会全部失效** ——
> 语音 / 摄像头类 App 会「报没权限 + 不弹窗 + 隐私列表里也没有它」。
> 这不是驱动 bug，而是「AMFI 关闭」本身的性质；**用之前先想清楚这台机器要不要用麦克风/摄像头**。
