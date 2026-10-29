# 磁盘屏蔽与 kext 精简

> ★ **装 kext 到系统目录 / 合并 KDK / 重建缓存** 时，可用 `laobamac/SimpleLoader`（SwiftUI 图形界面，
> **自带 APFS 快照保护**，比手工 `kmutil` 安全）。
> **KDK 镜像**见 `laobamac/KdkSupportPkg`；**MetalLib 补丁工具**见 `laobamac/MetallibSupportPkg`。
> 索引见 `laobamac-toolkit.md` §4。

## 一、磁盘屏蔽：先分清是「选择器」还是「macOS 里」

| 目标 | 正确做法 | 千万不要 |
|---|---|---|
| 启动选择器里少显示 | `Misc>Boot>HideAuxiliary=true`（隐藏 recovery / Time Machine / 系统项）；要隐藏具体项用 `Misc>Entries` 给该卷加条目并标 `Auxiliary` | ❌ 用 `Misc>Security>ScanPolicy` —— 它是**安全策略**，屏蔽后 OpenCore **看不到其它 OS**，Windows 就启动不了 |
| macOS 里不出现其它盘 | `/etc/fstab` + `noauto`（见下） | ❌ 直接删分区/改分区表 |

**判断选择器里实际显示什么**，只看 OC 日志里的 `OCB: Registering entry <名字>` 行 —— 这是唯一可靠依据。

### 1.1 macOS 侧屏蔽（`/etc/fstab` + `noauto`）

原理：给目标卷写 `noauto` ⇒ 系统启动时**不自动挂载** ⇒ 桌面 / 访达 / Spotlight 都不出现。

```
# 屏蔽非 macOS 卷 —— 只自动挂载 Macintosh HD
# ★★ EFI 分区不在此列！引导在它上面，安装 App 要靠它读写 config.plist ⇒ 永不屏蔽
UUID=<卷UUID> none ntfs noauto   # 卷名
```

要点：

- **一律用卷 UUID**，不要用 `/dev/diskXsY`（盘号会漂）。取 UUID：`diskutil info <dev> | awk -F': *' '/Volume UUID/{print $2}'`
- `fstab` 第 3 字段是 vfstype（NTFS 写 `ntfs`，exFAT 写 `exfat`），第 4 字段是挂载选项（这里是 `noauto`）；按实际文件系统填写并检查字段
- **同盘的其它分区互不影响**（fstab 按卷 UUID 匹配）⇒ 屏蔽同一块盘上的 Windows 卷不会影响该盘的 EFI 分区
- 撤销：只删除自己新增的行；用脚本添加时运行 `scripts/mask-other-disks.sh --undo`，它只删除自身标记区块，保留用户的其他规则。临时访问：`sudo diskutil mount /dev/diskXsY`（或把该行注释掉再重启）
- 写完**立即生效**：按 UUID 找到设备后逐个 `diskutil unmount`；确认 `/Volumes` 只剩 `Macintosh HD`
- 写入前后核对目标 UUID 与分区类型，确认没有 EFI 分区或用户要求保留的卷；已挂载的 ESP 可只读检查。磁盘屏蔽本身无需额外挂卸载 ESP。

脚本：`scripts/mask-other-disks.sh`（自动排除 EFI，可重复执行）。

### 1.2 排查 fstab 相关疑问

```bash
cat /etc/fstab
diskutil info <dev> | grep -E "Volume Name|Volume UUID|File System"
ls -1 /Volumes            # 屏蔽生效后应只剩 Macintosh HD（+ 需要时的 EFI）
```

## 二、kext 精简

### 2.1 先做三张表

1. `Kernel>Add` 全部条目（`BundlePath` / `Enabled` / `Comment`）
2. `EFI/OC/Kexts/` 目录实际文件
3. 两者的差集：
   - **未直接引用的文件** ⇒ 先核对完整 `BundlePath`、嵌套插件、依赖和备用 EFI 用途；确认未被使用后才列为清理候选
   - **引用但文件不存在** ⇒ 死条目，要么补文件要么删条目
   - **`Enabled=false` 的条目** ⇒ 候选删除对象，逐个判断

### 2.2 删除判据（满足其一才删）

- 驱动对应的**硬件已经换了**（例：Intel 无线/蓝牙驱动，但机器已换成 Broadcom 网卡）
- 功能**已由另一组件提供且有作者说明与目标机器验证**。`CpuTopologyRebuild` 与 `ProvideCurrentCpuInfo` 职责不同，不能把后者当成前者的通用替代
- 相关功能**你的配置不用**（例：`AppleALC` 但用外置声卡、且没注入 layout-id）
- 长期 `Enabled=false` 且注释写着"for isolation / for comparison"的临时项

### 2.3 依赖核对清单（按实际功能保留）

| kext | 需要核对的功能 / 依赖 |
|---|---|
| `Lilu` | 所有插件的宿主 |
| `VirtualSMC` + `SMCProcessor`/`SMCSuperIO` | SMC 模拟与传感器 |
| `WhateverGreen` | 显卡修正；`-wegnoigpu` 也靠它 |
| `USBToolBox` + `UTBMap` | USB 端口映射（替代 `XhciPortLimit`） |
| `RestrictEvents` | 配合 `revpatch=` 改机型/CPU 显示 |
| `NVMeFix` | NVMe 电源管理/兼容性 |
| `AMFIPass` | 配合 AMFI boot-args |
| 无线三件套（`IOSkywalkFamily` + `IO80211FamilyLegacy` + 对应 `AirPortBrcmNIC*`） | Broadcom 卡在新版 macOS 上的必需组合（OCLP 路线），**删了就没 WiFi** |
| `XHCI-unsupported` | 是否命中目标控制器的 PCI ID；RehabMan 版本包含多种 Intel 芯片组，见 USB 专题 |
| `BlueToolFixup` | 部分 Broadcom 蓝牙 |
| `CPUFriend` + DataProvider | 定制 CPU 电源数据 |

> ★ **Intel 无线/蓝牙三件套**（`itlwm` 或 `AirportItlwm` + `IntelBluetoothFirmware` / `IntelBTPatcher`，新版系统还要 `BlueToolFixup`）
> 只在**机器上确实是 Intel 网卡**时才需要：
> 换成 Broadcom 等原生卡之后，它们属于「已换硬件的驱动」，可以删（清理步骤见 `intel-wifi.md` §5）；
> 反之，用 Intel 网卡的机器则**必须**有它们，别当成"用不到"删掉。

### 2.4 删除流程

1. **先把原件备份**到工作区（`cp -pR <Kexts>/X.kext <备份目录>/`），并记录大小
2. 删 config 条目：`plutil -remove 'Kernel.Add.<idx>' <config>`，多条时**从高索引往低删**
3. 删文件：`rm -rf <Kexts>/X.kext`
4. 校验：`scripts/oc-verify.sh`（`Add` 里每条引用的文件都必须存在）
5. 统计前后占用：`du -sh <Kexts>`

## 三、主题（OpenCanopy）不要顺手改

主题相关开关全部保留：`Misc>Boot>PickerMode=External`、`PickerAttributes`、`PickerVariant`、
以及 `EFI/OC/Resources/Image/<图标集>/`。

- 官方图标集（OcBinaryData 的 `GoldenGate` / `Syrah` / `Chardonnay`）**各只有 25 个 `.icns`**
- 日志里的 `OCUI: Failed to load image … Background.icns / Apple.icns / Other.icns / ExtTool.icns / ResetNVRAM.icns … - Not Found`
  是 OpenCanopy 探测**可选图标**后的正常回退 —— 这些名字在**任何官方图标集里都不存在**，**没有东西可补**，别去"修"
- `PickerAttributes` 位：`0x01` 卷图标、`0x02` `.disk_label`、`0x04` 通用标签图、`0x10` 指针控制、`0x40` 极简 UI、`0x80` Flavour 图标、`0x100` 反转 UI
