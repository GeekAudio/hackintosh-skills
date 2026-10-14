# SMBIOS 机型切换 + 三码（serial / MLB / UUID / ROM）

> 依据：本机 10-12 与 10-13 的实战（`SMBIOS换机执行记录-20261012.md`、`DECISION-机型-SMBIOS-20261012.md`、
> `SMBIOS-三码更换-20261013/`、`SMBIOS-Tahoe-切换-20261013/`、`try-smbios-macpro71.sh`）+ Dortania
> 《Choosing the right SMBIOS》与 USBToolBox 官方 README。
>
> ★★ 一句话：**换机型不是「改 4 个键」，它会连带换掉 macOS 想附加的内置 USB 图、CPU 电源 profile、AGDC 路径……
> 而三码（尤其 ROM）直接决定 iMessage/FaceTime 能不能用。** 两个都要按下面的顺序做。

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
| 升级风险 | **低**（只动 boot-args） | 高（USB 图 + board-id + CPUFriend 一起动） |
| 是否与升级耦合 | ✅ **解耦** —— 升级那一次只动 boot-args | ❌ 耦合 |

> ★★ **「升级系统时不许改机型」是硬约束**（`SKILL.md` 铁律 16）。
> 理由：换机型**不是「改 4 个键」，而是一次耦合改动**（见 §2、§3）——
> 连带换掉 macOS 想附加的**内置 USB 图**、board-id 触发**系统卷重建**、XCPM profile 变化。
> **升级本身已经是高风险操作，不要在同一轮里叠加第二个耦合改动。**
>
> ⇒ **换机型是独立的一次决策，单独做**；**绝不要**把它塞进升级那一次。

### 1.2 参考机器是怎么走的（说明清楚，避免误解）

参考机器**最终用的是 `MacPro7,1`**（在白名单内，因此不需要 `-no_compat_check` / `revpatch=sbvmm` 来绕过机型限制）。

但那是**独立做过的一次机型切换**（走 §2 的完整流程：先把 `UTBMap` 换成完整图 + 备 U 盘 EFI，再换 SMBIOS，并同步重做 `CPUFriendDataProvider`），
**不是**「升级 Tahoe 时顺手改的」。两件事在时间上和风险上是分开的。

⇒ 所以文档里同时出现「参考机器是 `MacPro7,1`」和「升级时不许改机型」**并不矛盾**：
**前者是独立决策的结果，后者是升级时的纪律。**

## 2. ★★ 真正让本机「进不去系统」的是什么：主板特有的 BIOS SSDT

### 2.1 现象

换成 `MacPro7,1` 后开机走到很后面、**然后循环重启**（**不是卡死** ⇒ 「多等一会儿」无效）。

### 2.2 根因（实测锁定）

**本机（ASUS Z690）的 BIOS 里有一张 OEM SSDT，`OEM Table ID = xh_adls3`。**
换机型（board-id 变）会触发 macOS **重新解析/校验 ACPI 表**，
而这张表在 `MacPro7,1` 下解析不过 —— 报 **`HS06 AE_NOT_FOUND`**（表里引用的对象解析不了）
⇒ **电源管理 / ACPI 层面出问题 ⇒ 进不去系统。**

> ★★ **这是「主板特有」现象，不是「换机型」的普遍规律。**
> 所以**不要**把它当成通用结论背下来 —— 要当成一条**检查项**：
> 换机型前先看本机有没有这类「厂商 OEM SSDT」。

### 2.3 修法（实测有效，两步）

| 步骤 | 位置 | 内容 |
|---|---|---|
| ① **删掉 BIOS 原表** | `ACPI > Delete` | `TableSignature = SSDT` · `OemTableId = xh_adls3` · `All = false` |
| ② **加载打补丁的替换表** | `ACPI > Add` | `SSDT-XHADLS3.aml`（**Enabled**） |

> 配置里那句注释把原因写得很清楚：
> *"Remove BIOS INTEL `xh_adls3` table; load patched replacement to avoid **HS06 AE_NOT_FOUND** on ASUS Z690"*

### 2.4 时间线证据（说明「是不是它」）

| 时间 | 事件 |
|---|---|
| 10-12 | 换机型 **6 次全败**（循环重启）—— **当时还没有这张补丁表** |
| 10-13 05:51 | 生成 `SSDT-XH_ADLS3.aml` |
| 10-13 05:54 | 加 `ACPI>Delete`（原表）+ `ACPI>Add`（补丁表）⇒ **进得去了** |
| 10-13 11:15 | 归档 `config.plist.GOOD-MacPro71-WORKING-20261013` ⇒ 确认可用 |

### 2.5 已经排除的因素（别再往这些方向猜）

| 因素 | 状态 |
|---|---|
| **USB 端口图** | ❌ **不是**（T3 图已验证可用；USB 驱动日志全程正常） |
| **OCLP 根补丁** | ❌ 不是唯一原因（把补丁快照 `restore` 回滚掉后**仍然失败**） |
| **机型本身不被支持** | ❌ 不是（`MacPro7,1` 是官方支持机型） |
| **15 端口上限** | ❌ 与本次失败无关 |
| **NVRAM 残留** | ❌ 不是（Reset NVRAM 后同样失败） |

### 2.6 ★ 顺带说清一个「文档里的一般机制」（知道就好，别一上来就猜它）

Dortania 与 USBToolBox README 确实说过：**macOS 会按「SMBIOS 机型 + 控制器名」附加内置 USB 端口图**，
USBToolBox 的存在意义就是覆盖它们 ⇒ 理论上**换机型可能引起 USB 图合并冲突**
（`AppleUSBHostMergeProperties`）。

**但本机实测不是这个原因**（见 §2.5）。⇒ 结论：

- **知道有这回事**，作为排查方向之一保留
- **但不要**把它当成「换机型必翻车」的主因，更**不要**因此先去重做整张 USB 图（那是大工程，且不是这里的问题）

### 2.7 ★★★ 顺序铁律：**先完善 SSDT，再换机型**

**本机是特例** —— 不先处理掉 BIOS 那张 `xh_adls3`，**换机型必失败**。所以顺序不能反：

```
① 先完善 SSDT / ACPI（在【旧机型】下做完并验证）
        ↓
② 再换 SMBIOS / PlatformInfo（board-id）
        ↓
③ 再重做 CPUFriendDataProvider
```

★ **为什么必须在旧机型下先做完**：换机型会触发 ACPI 表的重新解析；
若此时 ACPI 层本来就有问题（厂商 OEM SSDT 解析不过），**你分不清「是 ACPI 的问题」还是「是换机型的问题」** ——
本机 10-12 连败 6 次就是这么耗掉的。**先把 ACPI 层验证干净，换机型这一步才只有一个变量。**

### 2.8 换机型前的检查清单（按本机教训总结）

- [ ] **看本机有没有厂商 OEM SSDT**：从 `SysReport/`（DEBUG 构建）或 ioreg 的 ACPI 表清单里，
      找**非 Apple** 的 SSDT（`OEM Table ID` 带厂商特征，如 `xh_adls3`）
- [ ] **看日志有没有 `AE_NOT_FOUND`**（ACPI 对象解析失败）
- [ ] 若命中 ⇒ **准备「删原表 + 加补丁表」**这一对改动（**这往往才是能不能进系统的关键**）
- [ ] 备好**可引导的 U 盘 EFI**（改 ACPI 表同样可能开不了机）
- [ ] USB 图**只有在日志明确指向它时**才动（见 §2.6）
## 3. 机型会影响哪些东西（改之前先知道自己在动什么）

Dortania 列出的清单：**CPU 电源管理**（XCPM profile）、**GPU 配置**（AGPM / AGDP / **AGDC**）、
**USB 映射**、DRM / 硬解、OS 支持范围、**iMessage**（serial+MLB+UUID）、**`ByHost` 偏好**（按 UUID 命名）。

★ **本机实证的一条强耦合**：**机型 ↔ CPUFriend 数据**
`MacPro7,1` 强制 `hwp=on` ⇒ CPU 被压在 2.3 GHz；`iMacPro1,1` 不用 HWP ⇒ 流畅
⇒ **换机型必须同时重做 `CPUFriendDataProvider` 的数据**（详见 `intel-turbo.md`）。

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

- 用 **官方 `macserial`**（OpenCore 自带，如 `macserial -m MacPro7,1`）或 corpnewt/GenSMBIOS 的算法
- 本机做法：`gen-smibios.py` = 官方 macserial 算法 + Apple OUI 表（`prefix.json`），**年/周/MLB 校验位自检通过**
- 一次多生成几套备用（本机曾一次生成 **22 套**候选池）

### 5.2 ★ 序列号「类别」判据（拿序列号去 Apple 官网查）

| 类别 | 官网显示 | 判定 |
|---|---|---|
| ① | 「你输入的序列号无效。请再试一次。」 | **可用**（查无此人；适合信用良好的 Apple ID） |
| ② | 显示**保修 / 电话支持**信息 | **必须换**（已被真实机主激活） |
| ③ | 「请核实购买日期」 | **最理想** |

### 5.3 ★ ROM 必须是 `en0` 的真实 MAC

- Dortania 建议：`PlatformInfo/Generic/ROM` 填 **`en0` 的真实 MAC**
- 踩过的坑：**不要用 GenSMBIOS 的 Apple OUI 表去「生成」一个 MAC** —— 那是**假 MAC**，会被当成无效标识
  ⇒ 改成**本机 `en0` 网卡的真实 MAC**
- **代价（改之前要知道）**：换 ROM ⇒ **重建 `ByHost` 偏好** + 可能要求**一次重新认证**
- ★ **改 ROM 的技巧**：`ROM` 在 XML 里是 **base64**（6 字节 MAC → 8 个 base64 字符）
  ⇒ 可**纯文本替换 base64**，**长度相同 ⇒ 格式零变化**，语义 diff 只 1 处，比整文件重写安全得多

### 5.4 换码纪律（别把自己玩坏）

- ★ **社区风控警告：脏三码 + 频繁换号是最典型的触发组合** ⇒ **换码要克制**（本机曾一天换两套，属反面教材）
- 换完视为**新硬件** ⇒ 需要重新认证，**顺序：先 FaceTime → 再信息**
- 改 ROM / UUID 后 `ByHost` 偏好会重建（无害），但要预期「某些 App 的设置看起来重置了」

## 6. 台账模板（**自己填，别把真值写进仓库**）

★ 三码（serial / MLB / UUID）与 ROM **等同于这台机器的身份凭证**（iMessage / FaceTime 认的就是它们）
⇒ **一律不要写进任何会公开的地方**（仓库、issue、截图、日志）。

| | serial | MLB | UUID | ROM |
|---|---|---|---|---|
| ① 第一套（已被替换） | `⟨已替换⟩` | `⟨已替换⟩` | `⟨已替换⟩` | `⟨已替换⟩` |
| ② 第二套（曾部署未生效） | `⟨已替换⟩` | `⟨已替换⟩` | `⟨已替换⟩` | `⟨已替换⟩` |
| **③ 现行** | **`⟨现行 serial⟩`** | **`⟨现行 MLB⟩`** | **`⟨现行 UUID⟩`** | **`⟨en0 真实 MAC⟩`** |

- ★ **台账纪律**：**每次换都记下旧值**（记在本地，不进仓库），否则回退时不知道退到哪一套
- 建议连同**每套的生成时间与用途**一起记，回退时才能判断该退到哪一套

### 6.1 ★ 一个真实的未决问题：`en0` 归属变了之后 ROM 怎么办

Dortania 的口径是「ROM = `en0` 的真实 MAC」。但 `en0` 的归属会**随驱动挂载顺序变化**：
装网卡驱动 / 屏蔽某个网卡之后，`en0` 可能从有线变成无线 ⇒ **ROM 该不该跟着改？**

- **改** ⇒ 又要付一次「重建 `ByHost` + 重新认证」的代价
- **不改** ⇒ ROM 与当前 `en0` 不一致（多数情况下仍能用，但不合规范）

⇒ **这是个需要自己拍板的取舍**，没有唯一正确答案。换之前先把两边的 MAC 都记下来。

## 7. 两条操作教训（都吃过亏）

| 教训 | 事实 |
|---|---|
| **EFI 内容与预期不符时，先怀疑「有外部改动」，不要先怀疑「写入丢失」** | 本机曾看到 EFI 是旧值 ⇒ 判定写入丢了 ⇒ 又写一遍 ⇒ **其实那是用户刚还原后的内容**（证据：系统 03:31:37 确实以旧机型启动过）⇒ **覆盖了用户的还原** |
| 判断持久化一律用 **「卸载 → 重挂 → 再读」** | 不要相信同一挂载点的缓存；`diskutil mount` 有时**先报失败后成功**，判断以 `diskutil info` 的 `Mounted` 为准 |
