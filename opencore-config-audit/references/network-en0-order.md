# `en0` 归属与网络接口顺序

> ★ **本文是通用规则**，被 `broadcom-wifi.md` / `intel-wifi.md` / `mediatek-wifi.md` /
> `os-upgrade-15-to-26.md` / `smbios-and-serials.md` 引用。
> **凡是要动网卡驱动 / 打 Wi-Fi 补丁 / 换网卡之前，先读这里。**

## 0. 一句话

**`en0` 是 Apple 服务认定的「主网卡」。**
内核按**驱动挂载先后**给 `en` 编号 —— **与 PCI 地址序无关**。
所以**装 / 删网卡驱动、打 Wi-Fi 补丁、换网卡**之后，`en0` 可能**换人**，凡是依赖它的东西都跟着受影响。

## 1. 谁依赖 `en0`

| 依赖项 | 说明 |
|---|---|
| **`PlatformInfo > Generic > ROM`** | Dortania 要求填 **`en0` 的真实 MAC** ⇒ `en0` 换人后 ROM 就不一致了（见 `smbios-and-serials.md` §5.3 / §6.1） |
| **iMessage / FaceTime / App Store** | 按 `en0` 判机器身份；`en0` 不对会「登录不了 / 掉线」 |
| **Wi-Fi 本体** | 见 §2 —— 打补丁 / 换卡之后要确认无线是不是 `en0` |

> ★★ **不依赖 `en0` 的：AirDrop / 接力 / Handoff / 连续互通。**
> 它只取决于「有没有 `awdl0`」（= 无线是否跑 Broadcom 原生 `IO80211Family` 栈）+ 蓝牙 BLE 服务，
> 与 `en0` / `ROM` / 序列号 / UUID **都无关**。
> 早前本文把 `Continuity / AirDrop` 列进「依赖 `en0`」是**错的** —— 那是把 Dortania 的
> **iServices**（iMessage）要求错误扩展到了 AirDrop（Dortania 原文：*"The type doesn't matter"*，
> 且通篇不提 AirDrop；Apple 官方对连续互通只要求「同一 Apple ID + Wi-Fi + 蓝牙」）。
> ⇒ **排查 AirDrop 请走 `airdrop-handoff.md`，不要在这里找。**

## 2. ★★ 为什么「修补 Wi-Fi」之后必须确认 `en0`

打 **OCLP root patch**、**换网卡**、**增删网卡 kext** 都会改变**驱动挂载顺序** ⇒
**无线可能从 `en0` 掉到 `en1`（或有线抢走 `en0`）**。后果：

- `ROM` 与 `en0` 不一致 ⇒ **iMessage / FaceTime / App Store 可能异常**
- 依赖「主网卡」的服务表现异常

> ★ **AirDrop / 接力不会因此失效** —— 那是 `awdl0` 的事（见 `airdrop-handoff.md`）。
> 别把「换完卡 AirDrop 坏了」归因到 `en0` 换人上。

⇒ **所以 Wi-Fi 修补流程（`broadcom-wifi.md` §3 / `os-upgrade-15-to-26.md` 升级后）里必须加一步：
确认 `en0` 是不是无线。**

## 3. 怎么查

```bash
networksetup -listallhardwareports      # 看 Wi-Fi 对应哪个 en
ifconfig en0 | head -3                  # en0 的 MAC 与状态
ioreg -l -w0 | grep -i "IOBuiltin"      # built-in 标记
scutil --nwi                            # 当前主网络接口
```

**判据**：`networksetup -listallhardwareports` 里 **Wi-Fi 那一段显示的 Device 就是 `en0`**（而不是 `en1`）。

## 4. 怎么把无线「钉」到 `en0`

```bash
# ① 临时禁用有线驱动（本机 = AppleIntelI210Ethernet.kext；早前是 AppleIGC.kext）
#    OpenCore: Kernel > Add > 对应条目的 Enabled = false
# ② 删掉接口顺序缓存
sudo rm /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist
# ③ 重启
# ④ 起来后确认 Wi-Fi = en0
networksetup -listallhardwareports
# ⑤ 需要时再把有线驱动加回来（编号已固定，不会再抢）
```

★ **重启后无线可能先锁在 2.4 GHz** ⇒ 复位一下：

```bash
networksetup -setairportpower en0 off
networksetup -setairportpower en0 on
```

## 5. 连带影响：`ROM` 要不要跟着改

`en0` 换人之后，`ROM`（= 原 `en0` 的 MAC）就与当前 `en0` 不一致了。

- **改** ⇒ 又要付一次「重建 `ByHost` + 重新认证」的代价
- **不改** ⇒ 多数情况下仍能用，但不合 Dortania 规范

⇒ 这是个**需要自己拍板**的取舍（详见 `smbios-and-serials.md` §6.1）。
**换之前把两边的 MAC 都记下来**（记在本地，别进仓库）。

## 6. 判据纪律

- ★ **看 `ifconfig`，别只看 `system_profiler`** —— 重启后驱动要读卡、关联、DHCP，**十几秒才起来**，
  期间 `system_profiler` 返回空 ⇒ 容易误判成「失败」（见 `broadcom-wifi.md` §4）
- 无线是否真的活：`ifconfig en0`（或 `en1`）要有 **`inet` + `status: active`**
- **`awdl0` 存在** ⇒ AirDrop / 接力**有戏**（完整判据见 `airdrop-handoff.md`：
  还要 `llw0` + 蓝牙 `LEA`/`AACP`/`GATT`）
- 换网卡后**同一台机器不要同时注入多套网卡驱动**（`intel-wifi.md` §5）
