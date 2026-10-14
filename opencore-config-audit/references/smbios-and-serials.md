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
| **升 macOS 26 Tahoe 时** | ★ **必须换** —— Apple 支持列表里 Tahoe 的 Intel 机型只剩 4 款：iMac 27″ 2020、MBP 16″ 2019、MBP 13″ 2020、**Mac Pro 2019 = `MacPro7,1`**；**`iMacPro1,1` 已被剔除** |

⇒ **做法：把「换 `MacPro7,1`」绑死在「升级 Tahoe」这一个动作上，同一次做，不单独做。**
（留在 `iMacPro1,1` 上跑 Tahoe 只能靠 `-no_compat_check` 硬顶 ⇒ 全局关掉兼容检查、安装器/更新器行为难预测；
换 `MacPro7,1` 则原生受支持、OTA 正常，**而且与上游 macOS 26 测试者同机型** ⇒ 我们报的 issue 在作者环境可复现。）

**备选（可行但不推荐）**：`iMacPro1,1` + `-no_compat_check` + RestrictEvents `revpatch=sbvmm`
（官方说明：*"forces VMM SB model, allowing OTA updates for unsupported models on macOS 11.3 or newer"*）—— 等于在 hack 之上再叠一层 hack。

## 2. ★★ 最容易翻车的点：机型 ↔ 内置 USB 图的冲突

**本机实测：换 `MacPro7,1` 后开机卡在 `AppleUSBHost*`（内核早期 USB 栈），完全开不了机。**

机制（两条官方依据）：

- **Dortania**：*"Certain SMBIOS will have their own USB map which may attach to your hardware causing USB issues."*
- **USBToolBox README（决定性）**：*"Override any built-in Apple USB maps attaching based on SMBIOS and controller name"* ——
  即 **macOS 内置了一批按「SMBIOS 机型 + 控制器名」附加的端口图**，USBToolBox 的存在意义就是**覆盖**它们

⇒ 换机型 = 换了 macOS 想附加的那张图 ⇒ 与 `UTBMap` 在 **`AppleUSBHostMergeProperties`** 合并时冲突 ⇒ XHCI `start()` 走不完 ⇒ 卡死。

**加重因素**：当时本机的 `UTBMap` 是 `"Diagnostic map 1.1"`（**USB2-only 半成品**、连接器类型未映射）
⇒ 抗机型图干扰的能力弱。

> ★★★ **核心认识：「换机型」和「换 USB 图」是耦合的同一个改动，不是两个独立变量。**
> 当时按「一次只改一项」只换 SMBIOS，**反而制造了不一致** —— 这是失败的直接原因。

### 重试的正确顺序

1. **先把 `UTBMap` 换成完整、明确的端口图**（USB2 + USB3、连接器类型都映射；用 USBToolBox 在**当前系统**下重新生成；
   可选给每个个性加 `model` 键）
2. **备一张 U 盘 EFI** —— 回退从「改文件」变成「改启动项」，秒级
3. **再换 SMBIOS**
4. `-v` 开机，**拍下卡住的那一行**。若仍停在 `AppleUSBHost*` ⇒ 合并冲突仍在（UTBMap 没压住自带图）
5. 仍失败 ⇒ 走备选：`iMacPro1,1` + `-no_compat_check` + `revpatch=sbvmm`
6. 最后手段：给 XHCI 控制器改 `IOName`（避开自带图的"控制器名"匹配）—— 属 ACPI/DeviceProperties 层，**风险最高，放最后**

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
