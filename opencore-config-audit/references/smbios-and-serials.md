# SMBIOS 机型切换 + 三码（serial / MLB / UUID / ROM）

> 依据：Dortania《Choosing the right SMBIOS》与 USBToolBox 官方 README +
> 一次完整的换机型实战复盘（旧机型 → `MacPro7,1`，其中连败 6 次，最后靠「先修 ACPI 再换机型」过关）。
> 实战中的本机取值与备份路径见 `machine-facts.md`。
>
> ★★ 一句话：**换机型不是「改 4 个键」，它是一次耦合改动** —— 连带 ACPI/SSDT 前置、`CPUFriend` 数据、
> **内存注入的槽位数**、以及「关于本机」的显示名。
> ★★★ **而且换机型必须同时换三码**：机型名与 SMBIOS **解耦**，它是**序列号产品码**的函数（见 §1.3）。
> 三码（尤其 ROM）还直接决定 iMessage/FaceTime 能不能用。**按下面的顺序，一次做完整套。**

---

## 1. 先决策：什么时候该换机型

| 维度 | 结论 |
|---|---|
| 功能收益（macOS 15 Sequoia 下） | **零** —— Dortania：`iMacPro1,1` 与 `MacPro7,1` 是**仅有**的两个「把全部负载交给 dGPU」的机型 ⇒ 两者等价 |
| 成本 | 要新 serial / MLB / UUID；**board-id 变 ⇒ AGDP/AGDC 相关路径全变**；iMessage / FaceTime 需重新登录 |
| 风险 | ★ **污染正在跑的 A/B 基线**（如 BAR1 / 重影实验）—— 违反「一次只改一项」与「挂着改动就无法区分新旧症状」 |
| **升 macOS 26 Tahoe 时** | Apple 支持列表里 Tahoe 的 Intel 机型只剩 4 款：iMac 27″ 2020、MBP 16″ 2019、MBP 13″ 2020、**Mac Pro 2019 = `MacPro7,1`**；**`iMacPro1,1` 已被剔除**。**但这不构成「升级时顺便换机型」的理由** —— 见下 |

### 1.1 ★★ 两条路线，**默认走第一条**

| | **A. 保留原机型 + boot-arg 绕过**（**默认**） | B. 换到白名单机型 |
|---|---|---|
| 做法 | 加 `-no_compat_check`（能启动）+ `revpatch=sbvmm`（能收到 OTA 更新），机型一个字段都不动 | 换成 `MacPro7,1` |
| 升级风险 | **低**（只动 boot-args） | 高（**ACPI/SSDT 前置** + board-id + CPUFriend + **三码** 一起动） |
| 是否与升级耦合 | ✅ **解耦** —— 升级那一次只动 boot-args | ❌ 耦合 |

> ★★ **「升级系统时不许改机型」是硬约束**（`SKILL.md` 铁律 16）。
> 理由：换机型**不是「改 4 个键」，而是一次耦合改动**（见 §2、§3）——
> 连带 **board-id 变化触发 ACPI 重新解析**（§2）、系统卷重建、XCPM profile 变化、**三码与电脑名**（§1.3 / §3.2）。
> **升级本身已经是高风险操作，不要在同一轮里叠加第二个耦合改动。**
>
> ⇒ **换机型是独立的一次决策，单独做**；**绝不要**把它塞进升级那一次。

### 1.2 参考机器是怎么走的（说明清楚，避免误解）

参考机器**经历过两次独立的机型切换**，都不是「升级时顺手改的」：

| 时间 | 机型 | 做了什么 |
|---|---|---|
| 10-13 | `iMacPro1,1` → **`MacPro7,1`** | 走 §2 完整流程：先处理 `xh_adls3` SSDT → 换 SMBIOS → 重做 `CPUFriendDataProvider` |
| 10-15 | `MacPro7,1` → **`iMac20,1`** | ★ **同时换了三码**（这次才补上；见 §1.3 的教训）+ 重做 CPUFriend + 内存注入改 4 槽 + 改电脑名 |

⇒ 所以文档里同时出现「参考机器换过机型」和「升级时不许改机型」**并不矛盾**：
**前者是独立决策的结果，后者是升级时的纪律。**

> ★ 这两次切换的顺序都是：**先把 ACPI/SSDT 层做干净 → 再换机型 → 再补连带项**（§2.7）。
> 10-15 那次还多了一条：**换机型必须连三码一起换**（见下）。

### 1.3 ★★★ 换机型**必须**换码 —— 「关于本机」的机型名是**序列号的函数**

**实测（一次换机型事故）**：机型已经改成 `iMac20,1`，但「关于本机」**仍然显示 `Mac Pro (2019)`**。
排查一圈才找到真身 —— 它跟 `SystemProductName` **没有关系**：

| 证据 | 结论 |
|---|---|
| 清空 `~/Library/Preferences/com.apple.SystemProfiler.plist` 后重开「关于本机」，用**同一个序列号**重新推导，**仍**写回旧机型名 | 名字由**序列号**决定，与机型解耦 |
| `macserial -i <serial>` 直接给出 `SystemModel`（营销名） | 产品码 → 营销名是**一一映射** |
| 缓存键是 `ModelNames["<序列号后 4 位>-<locale>"]`，校验字段是 `cachedSerial` | **改机型不会让缓存失效** |

**产品码对照（`macserial -i` 的输出，可直接复现）**：

| 序列号产品码 | 对应机型 | 「关于本机」显示 |
|---|---|---|
| `P7QM` | MacPro7,1 | Mac Pro (2019) |
| `PN5T` | iMac20,1 | iMac (Retina 5K, 27-inch, 2020) |

⇒ **只换机型不换码，「关于本机」永远停在旧机型名。** 换机型与换三码是**同一个动作的两半**，一起做。

- ★ **换码前先用 `macserial -i <serial>` 确认产品码对不对**（比事后开「关于本机」快得多）
- ★ 那个 plist 只是**缓存**：**清掉它不会「修好」显示名** —— 名字仍会按同一个序列号推导回旧值
- ★ 排查顺序：**显示名不对 ⇒ 先看序列号产品码，再看缓存，最后才怀疑 config**

## 2. ★★ 换机型后「循环重启 / 进不去系统」的头号嫌疑：主板特有的 OEM SSDT

### 2.1 现象

换成目标机型后开机走到很后面、**然后循环重启**（**不是卡死** ⇒ 「多等一会儿」无效）。

### 2.2 根因（机理）

很多主板的 BIOS 里会塞一张**厂商自己的 OEM SSDT**（`OEM Table ID` 带厂商特征，例如 ASUS 的 `xh_adls3`；
具体表名因厂商/型号而异，得自己从 `SysReport/` 或 ioreg 里读），用来描述该板子的 USB / 电源 / 温控拓扑。

换机型（board-id 变）会触发 macOS **重新解析/校验 ACPI 表**。若这张表里引用的对象在新机型下解析不到，
ACPI 解释器会报 **`HS06 AE_NOT_FOUND`** ⇒ **电源管理 / ACPI 层面出问题 ⇒ 进不去系统。**

> ★★ **这是「主板特有」现象，不是「换机型」的普遍规律。**
> 所以**不要**把它当成通用结论背下来 —— 要当成一条**检查项**：
> 换机型前先看自己的板子有没有这类「厂商 OEM SSDT」。

### 2.3 修法（两步，缺一不可）

| 步骤 | 位置 | 内容 |
|---|---|---|
| ① **删掉 BIOS 原表** | `ACPI > Delete` | `TableSignature = SSDT` · `OemTableId = <那张表的 ID>` · `All = false` |
| ② **加载打补丁的替换表** | `ACPI > Add` | 自己改好的 `SSDT-XXXX.aml`（**Enabled**） |

> 替换表不是必须「重写整张」，多数情况只需把引用不到的路径（`\_SB.PCI0...`）改成新机型下存在的路径，
> 或用 `External` + 空方法兜住。改完用 `iasl -d` 反编译原表对比最省事。

**案例（本机 ASUS Z690 + `xh_adls3`）**：`ACPI>Delete` 删原表、`ACPI>Add` 加 `SSDT-XHADLS3.aml` 后进得去。
配置注释原文：*"Remove BIOS INTEL `xh_adls3` table; load patched replacement to avoid **HS06 AE_NOT_FOUND** on ASUS Z690"*。

### 2.4 怎么确认「是不是它」

| 证据 | 看哪里 |
|---|---|
| ACPI 表清单里有非 Apple 的 SSDT | `SysReport/`（DEBUG 构建）或 ioreg 的 `ACPI` 节点 |
| 日志出现 `AE_NOT_FOUND` | 串口 / `-v` 屏幕 / `system.log` |
| 换机型前后**只有**这一处变量变了，结果从「进得去」变「循环重启」 | 时间线对照 |

**案例时间线（本机）**：换机型 6 次全败 → 生成补丁表 → 加 `Delete`+`Add` → 进得去 → 归档为可用配置。
**这条时间线只证明「这台板子上是它」，不证明别的板子也是它。**

### 2.5 已经排除的因素（同类问题别再往这些方向猜）

| 因素 | 判据 |
|---|---|
| **USB 端口图** | ❌ 通常不是（若 USB 驱动日志全程正常、`ioreg` 端口齐全） |
| **OCLP 根补丁** | ❌ 不是唯一原因（把补丁快照 `restore` 回滚掉后**仍然失败**即排除） |
| **机型本身不被支持** | ❌ 先确认目标机型在 Dortania 支持列表里 |
| **15 端口上限** | ❌ 与「换机型后循环重启」无因果关系（那是端口不识别） |
| **NVRAM 残留** | ❌ Reset NVRAM 后同样失败即排除 |

### 2.6 ★ 顺带说清一个「文档里的一般机制」（知道就好，别一上来就猜它）

Dortania 与 USBToolBox README 确实说过：**macOS 会按「SMBIOS 机型 + 控制器名」附加内置 USB 端口图**，
USBToolBox 的存在意义就是覆盖它们 ⇒ 理论上**换机型可能引起 USB 图合并冲突**
（`AppleUSBHostMergeProperties`）。

**但在本机上实测不是这个原因**（见 §2.5）。⇒ 结论：

- **知道有这回事**，作为排查方向之一保留
- **但不要**把它当成「换机型必翻车」的主因，更**不要**因此先去重做整张 USB 图（那是大工程，且往往不是这里的问题）

### 2.7 ★★★ 顺序铁律：**先完善 SSDT，再换机型**

**只要你的板子存在「厂商 OEM SSDT 在目标机型下解析不过」的情况，不先处理掉它，换机型必失败。** 所以顺序不能反：

```
① 先完善 SSDT / ACPI（在【旧机型】下做完并验证）
        ↓
② 再换 SMBIOS / PlatformInfo（board-id）
        ↓
③ 再重做 CPUFriendDataProvider
```

★ **为什么必须在旧机型下先做完**：换机型会触发 ACPI 表的重新解析；
若此时 ACPI 层本来就有问题，**你分不清「是 ACPI 的问题」还是「是换机型的问题」** ——
本机当初连败 6 次就是这么耗掉的。**先把 ACPI 层验证干净，换机型这一步才只有一个变量。**

### 2.8 换机型前的检查清单

- [ ] **看自己的板子有没有厂商 OEM SSDT**：从 `SysReport/`（DEBUG 构建）或 ioreg 的 ACPI 表清单里，
      找**非 Apple** 的 SSDT（`OEM Table ID` 带厂商特征）
- [ ] **看日志有没有 `AE_NOT_FOUND`**（ACPI 对象解析失败）
- [ ] 若命中 ⇒ **准备「删原表 + 加补丁表」**这一对改动（**这往往才是能不能进系统的关键**）
- [ ] 备好**可引导的 U 盘 EFI**（改 ACPI 表同样可能开不了机）
- [ ] USB 图**只有在日志明确指向它时**才动（见 §2.6）
## 3. 机型会影响哪些东西（改之前先知道自己在动什么）

Dortania 列出的清单：**CPU 电源管理**（XCPM profile）、**GPU 配置**（AGPM / AGDP / **AGDC**）、
**USB 映射**、DRM / 硬解、OS 支持范围、**iMessage**（serial+MLB+UUID）、**`ByHost` 偏好**（按 UUID 命名）。

★ **一条实测确认的强耦合**：**机型 ↔ CPUFriend 数据**
`MacPro7,1` 强制 `hwp=on` ⇒ CPU 被压在 2.3 GHz；`iMacPro1,1` 不用 HWP ⇒ 流畅
⇒ **换机型必须同时重做 `CPUFriendDataProvider` 的数据**（详见 `intel-turbo.md`）。

### 3.1 ★★ 换机型 / 换码的「连带项」清单（漏一个就不完整）

| # | 连带项 | 为什么 | 证据 / 出处 |
|---|---|---|---|
| ① | **三码（serial / MLB / UUID）** | 「关于本机」的名字、iMessage 身份都绑在**码**上 | §1.3 —— `MacPro7,1` 的码配 `iMac20,1` ⇒ 显示 `Mac Pro (2019)` |
| ② | **`ACPI` / SSDT 前置** | board-id 变 ⇒ ACPI 重新解析 | §2（本机 `xh_adls3` ⇒ `HS06 AE_NOT_FOUND`） |
| ③ | **`CPUFriendDataProvider`** | 机型 profile 决定 HWP / `FrequencyVectors` | `MacPro7,1` 强制 `hwp=on` ⇒ 卡 2.3 GHz（`intel-turbo.md`） |
| ④ | **内存注入（`PlatformInfo>Memory>Devices`）** | ★ **槽位数随机型变** | `MacPro7,1` = **12 槽**；`iMac20,1` = **4 槽** ⇒ `memory-injection.md` |
| ⑤ | **`ROM`** | 必须 = **当前 `en0`** 的真实 MAC；而 `en0` 归属会漂 | §5.3 + `network-en0-order.md` |
| ⑥ | **电脑名 / 主机名 / SMB 名** | 与 SMBIOS **无关**、**不会自动改** | §3.2 |
| ⑦ | 「关于本机」显示名缓存 | `com.apple.SystemProfiler.plist` | §1.3 |

★ 顺序仍是 §2.7 那条：**先把 ACPI 层做干净 → 再换机型/换码 → 再逐个补 ③④⑤⑥**。

### 3.2 ★ 换机型后还要改「电脑名」—— 它藏在**两处**，不只一处

`ComputerName` / `LocalHostName` 与 SMBIOS **完全无关**，是独立的系统设置；换机型**不会动它**，
于是会出现「机型是 iMac，电脑名还叫 xxx 的 iMac Pro」。

| 位置 | 键 |
|---|---|
| `/Library/Preferences/SystemConfiguration/preferences.plist` | `System.System.ComputerName`、`System.Network.HostNames.LocalHostName` |
| `/Library/Preferences/SystemConfiguration/com.apple.smb.server.plist` | **`NetBIOSName`**、**`ServerDescription`** ← Windows / SMB 文件共享里显示的名字，**最容易漏** |

```bash
sudo scutil --set ComputerName  "Geek's iMac"
sudo scutil --set LocalHostName "Geeks-iMac"
# ★ 只跑 scutil 会漏掉 SMB 那两处 —— 在 Windows 的「网络」里还会看到旧名字
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName       -string "Geeks-iMac"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server ServerDescription -string "Geek's iMac"
```

- **不要**写死 `HostName`（保持未设置，交给 DHCP / 路由器）
- 运行中的 `hostname` 要**重启**才刷新；**iCloud 设备名**在服务端，要**重新登录**才刷新
- macOS 会留下 `preferences-<旧机型>.plist` 这类**惰性备份**（不参与启动），要清得用 `sudo rm`

## 4. 切换脚本的正确形态（三态 + 救援路径）

`try-smbios-macpro71.sh` 的设计值得照抄：

| 模式 | 行为 |
|---|---|
| `plan`（默认） | 只检查、**不动任何东西**：打印当前机型/sha、候选机型/sha/boot-args |
| `apply` | ★ **先在 ESP 上放一份基线副本** `config.plist.BASELINE-<时间戳>`，再写入候选配置 |
| `rollback` | 从 ESP 上的基线副本还原 |

要点：

- **绝不按固定盘号找 EFI**（盘号每次启动都变）⇒ 按**分区类型**找：
  ```bash
  for d in $(diskutil list | sed -n 's/.*[[:space:]]\(disk[0-9]*s[0-9]*\)$/\1/p'); do
    [ "$(diskutil info "$d" | awk -F': *' '/Partition Type/{print $2;exit}')" = EFI ] && echo "$d"
  done
  ```
- ★ **基线副本要放在 ESP 上**，这样即使 macOS 起不来也能用 OpenCore 选单里的 **UEFI Shell** 还原：
  ```
  OpenShell → map fs0: → cp fs0:\EFI\OC\config.plist.BASELINE-… fs0:\EFI\OC\config.plist
  ```
- 写入后 **`sync` → 卸载 → 重挂 → sha 复核**（别信同一挂载点的缓存）
- 候选文件先校验 sha 再写（脚本里 `[ "$(shasum -a 256 "$CAND")" = "$CAND_SHA" ] || 拒绝写入`）

## 5. 三码：生成、判据、ROM

### 5.1 生成

- 用 **官方 `macserial`**（OpenCore 自带，如 `macserial -m MacPro7,1`）或 corpnewt/GenSMBIOS
- 自写脚本也行：照官方 macserial 算法 + Apple OUI 表（`prefix.json`）生成，并**自检年/周/MLB 校验位**
- 一次多生成几套备用，凑成候选池再挑（挑的标准见 §5.2）
- ★★ **生成后先解码核对**（比事后开「关于本机」快）：
  ```bash
  macserial -i <serial>      # → Model: PN5T - iMac20,1 / SystemModel: iMac (Retina 5K, 27-inch, 2020)
  macserial --verify <MLB>   # → Valid MLB checksum.
  ```
  ⇒ **产品码必须与目标机型一致**，否则「关于本机」显示旧机型（§1.3）

### 5.2 ★ 序列号「类别」判据（拿序列号去 Apple 官网查）

| 类别 | 官网显示 | 判定 |
|---|---|---|
| ① | 「你输入的序列号无效。请再试一次。」 | **可用**（查无此人；适合信用良好的 Apple ID） |
| ② | 显示**保修 / 电话支持**信息 | **必须换**（已被真实机主激活） |
| ③ | 「请核实购买日期」 | **最理想** |

### 5.3 ★ ROM 必须是 `en0` 的真实 MAC

- Dortania 建议：`PlatformInfo/Generic/ROM` 填 **`en0` 的真实 MAC**
- 踩过的坑：**不要用 GenSMBIOS 的 Apple OUI 表去「生成」一个 MAC** —— 那是**假 MAC**，会被当成无效标识
  ⇒ 改成**你自己 `en0` 网卡的真实 MAC**（`ioreg -lw0 -r -c IOEthernetController | grep IOMACAddress`，
  或 `ifconfig en0 | grep ether`）
- **代价（改之前要知道）**：换 ROM ⇒ **重建 `ByHost` 偏好** + 可能要求**一次重新认证**
- ★ **改 ROM 的技巧**：`ROM` 在 XML 里是 **base64**（6 字节 MAC → 8 个 base64 字符）
  ⇒ 可**纯文本替换 base64**，**长度相同 ⇒ 格式零变化**，语义 diff 只 1 处，比整文件重写安全得多

### 5.4 换码纪律（别把自己玩坏）

- ★ **社区风控警告：脏三码 + 频繁换号是最典型的触发组合** ⇒ **换码要克制**（一天连换两套就是反面教材）
- 换完视为**新硬件** ⇒ 需要重新认证，**顺序：先 FaceTime → 再信息**
- 改 ROM / UUID 后 `ByHost` 偏好会重建（无害），但要预期「某些 App 的设置看起来重置了」

## 6. 台账模板（**自己填，别把真值写进仓库**）

★ 三码（serial / MLB / UUID）与 ROM **等同于这台机器的身份凭证**（iMessage / FaceTime 认的就是它们）
⇒ **一律不要写进任何会公开的地方**（仓库、issue、截图、日志）。

| | 机型 | serial | MLB | UUID | ROM | 时间 / 用途 |
|---|---|---|---|---|---|---|
| ① | `⟨旧机型⟩` | `⟨…⟩` | `⟨…⟩` | `⟨…⟩` | `⟨…⟩` | ⟨何时生成、为什么换⟩ |
| ② | `⟨目标机型⟩` | `⟨…⟩` | `⟨…⟩` | `⟨…⟩` | `⟨…⟩` | ⟨…⟩ |
| **③ 现行** | **`⟨当前机型⟩`** | **`⟨现行 serial，产品码须对应此机型⟩`** | **`⟨现行 MLB⟩`** | **`⟨现行 UUID⟩`** | **`⟨当前 en0 真实 MAC⟩`** | **⟨启用日期⟩** |

★ **机型列一定要记**：这样回退时才知道「这套码配的是哪个机型」（配错 ⇒ 「关于本机」显示旧机型，§1.3）。

- ★ **台账纪律**：**每次换都记下旧值**（记在本地，不进仓库），否则回退时不知道退到哪一套
- 建议连同**每套的生成时间与用途**一起记，回退时才能判断该退到哪一套

### 6.1 ★ 一个真实的未决问题：`en0` 归属变了之后 ROM 怎么办

Dortania 的口径是「ROM = `en0` 的真实 MAC」。但 `en0` 的归属会**随驱动挂载顺序变化**：
装网卡驱动 / 屏蔽某个网卡之后，`en0` 可能从有线变成无线 ⇒ **ROM 该不该跟着改？**

- **改** ⇒ 又要付一次「重建 `ByHost` + 重新认证」的代价
- **不改** ⇒ ROM 与当前 `en0` 不一致（多数情况下仍能用，但不合规范）

⇒ **这是个需要自己拍板的取舍**，没有唯一正确答案。换之前先把两边的 MAC 都记下来。

> ★★ **`en0` 归属为什么会变、怎么把它钉住** ⇒ 见 **`network-en0-order.md`**
> （驱动挂载顺序、`NetworkInterfaces.plist`、以及它对 iMessage / FaceTime / App Store 的连带影响）。
> ★ **`ROM` / 三码 / `SystemUUID` 与 AirDrop、接力无关**，别为它们去改 —— 见 `airdrop-handoff.md` §3。

## 7. 两条操作教训（都吃过亏）

| 教训 | 事实 |
|---|---|
| **EFI 内容与预期不符时，先怀疑「有外部改动」，不要先怀疑「写入丢失」** | 本机曾看到 EFI 是旧值 ⇒ 判定写入丢了 ⇒ 又写一遍 ⇒ **其实那是用户刚还原后的内容**（证据：系统 03:31:37 确实以旧机型启动过）⇒ **覆盖了用户的还原** |
| 判断持久化一律用 **「卸载 → 重挂 → 再读」** | 不要相信同一挂载点的缓存；`diskutil mount` 有时**先报失败后成功**，判断以 `diskutil info` 的 `Mounted` 为准 |
| **换了机型但「关于本机」名字没变 ⇒ 先怀疑序列号，不是 config** | 机型名由**序列号产品码**决定（§1.3）。本机曾在「config 已确认改对、5 项证据都指向 iMac20,1」的情况下仍显示 `Mac Pro (2019)` —— 因为**码没换**。清 `com.apple.SystemProfiler.plist` 也没用（会按同一个码推导回旧值） |
| 判断「这次引导用的是哪份 config」 | 比 sha 更直接：**比对 config 文件大小与引导日志的 `OC: Loaded configuration of N bytes`**（`ls -l config.plist` 的字节数与日志里的 N 必须相等） |
