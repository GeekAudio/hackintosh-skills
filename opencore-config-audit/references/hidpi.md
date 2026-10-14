# HiDPI：非 Retina 显示器「更清晰」的等效分辨率

> 工具：**`xzhih/one-key-hidpi`**（脚本，一键给非 Retina 屏模拟 macOS HiDPI）。
> 依据：该仓库 README + `hidpi.sh` 实现（写入路径/选项/恢复方式）。
> ★ **本机特别注意**：显示驱动是 NullMoth 的 NVIDIA 驱动（**自述未完善**），
> HiDPI 恰好踩在「显示模式 / 缩放 / 元数据」这条它最容易出问题的路径上 ⇒ 见 §5 的风险与前置动作。

## 1. 什么时候需要

- 显示器不是 Retina，但分辨率够高（如 4K/2K 屏），macOS 默认按 1:1 显示 ⇒ **字太小、界面元素发虚**
- 想拿到「看起来像 1080p 的尺寸、但用 4K 的像素渲染」那种效果（系统设置里出现 "Native" 缩放档）

**原理**：HiDPI = 让 macOS 以 **2× 逻辑分辨率渲染**，再缩放到面板实际像素。
它**不改面板真实分辨率**，是往显示器上挂一份 **Display Override**（含 `scale-resolutions`）来"造"出中间档位。
⇒ 官方 README 也提醒：**开机 logo 的缩放问题可能解决不了**（因为高分辨率是"假"的）。

## 2. 它写在哪（决定了风险大小）

脚本写的是 **`/Library/Displays/Contents/Resources/Overrides/`**（注意**不是** `/System/Library/...`）：

```
/Library/Displays/Contents/Resources/Overrides/
└── DisplayVendorID-<VID>/
    └── DisplayProductID-<PID>            ← 注入的 override（含 scale-resolutions，EDID 模式还含 IODisplayEDID）
        DisplayProductID-<PID>.icns/.tiff ← 可选：给「显示器」图标换个 Mac 的样子
```

- **不动密封系统卷**、不需要 root patch —— 这点比 OCLP 那条路线省心得多
- VID/PID 从 EDID 推：脚本用 `ioreg -lw0 | grep -i "IODisplayEDID"` 取当前显示器的 EDID 再解析
- 卸载 = **删掉 `DisplayVendorID-<VID>` 这个目录**即可

## 3. 怎么用

```bash
# 远程模式（直接跑 master 上的脚本）
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xzhih/one-key-hidpi/master/hidpi.sh)"

# 或本地模式：下载 ZIP 解压 → 双击 hidpi.command
```

菜单流程（按提示走）：**选显示器 → 选显示器图标（iMac / MacBook / MBP / ProDisplayXDR / 自定义）→ 选分辨率配置**
（有预设列表，也可手动输入多个分辨率）。两个模式：

| 模式 | 说明 |
|---|---|
| `Enable HIDPI` | 只注入 `scale-resolutions` override |
| `Enable HIDPI (with EDID)` | **同时注入 patched EDID** —— 官方 README：*"Some device have wake-up issue, script's second option may help, it inject a patched EDID, but another problem may exists here."*（**可能解决唤醒问题，也可能引入新问题**） |

⇒ **先试第一个**；只有遇到唤醒/模式异常才考虑第二个。

## 4. 恢复（**必须先知道这个再做**）

| 情况 | 做法 |
|---|---|
| 能进系统 | 再跑一次脚本，选 **恢复/disable** 那一项（README 里写的是「选项 3」，以脚本菜单实际显示为准） |
| 脚本生成的便捷脚本 | 脚本会在你的用户目录生成 **`.hidpi-disable`**，直接 `./.hidpi-disable` 即可 |
| **进不去系统** | 进 **macOS Recovery** 的「终端」：<br>`ls /Volumes/` → `cd /Volumes/<系统盘>/Users/<用户名>` → `./.hidpi-disable` |
| Recovery 里手动清 | `rm -rf "/Volumes/<系统盘>/Library/Displays/Contents/Resources/Overrides"`（删掉整个 Overrides，或只删注入的 `DisplayVendorID-<VID>`） |

## 5. ★★ 与 NVIDIA（NullMoth）驱动的风险 —— 本机尤其要小心

HiDPI 要求驱动正确处理**「非面板原生分辨率的模式 + 缩放 + 模式元数据」**，而这正是这个驱动已知薄弱的地方：

| 已知事实 | 为什么与 HiDPI 相关 |
|---|---|
| 本机曾出现**显示器被报成 30.5 英寸** | 真因 = 驱动没填 `IODisplayModeInformation.imageWidth/imageHeight`（后已修，PR #199）。**说明这个驱动在「显示模式元数据」上出过真 bug** |
| 官方 `TROUBLESHOOTING` 里有「**100–240 Hz 黑屏/闪**」「**DSC 模式黑屏**」 | HiDPI 会引入新的模式/时序组合，容易踩到同一条路 |
| 官方 `Known issues` 里有「**BAR ≥ 4 GB 时窗口重叠出现幽灵/黑块**（#127）」 | 缩放合成路径更容易暴露这类合成问题 |
| 官方自述「Most testing is done on an RTX 5060」、`CARD-SUPPORT` 里 Ampere 一栏写 **Pending** | 本机是 RTX 3080 ⇒ 属"能跑但未系统验证"的组合 |

### 开 HiDPI 之前/之后必须做的四件事

1. **记录基线**（出问题才有对比）：
   ```bash
   system_profiler SPDisplaysDataType > ~/before-hidpi-displays.txt
   ioreg -l -w0 | grep -iE "IODisplayMode|IODisplayEDID|IOFBCurrentPixel" | head -50 > ~/before-hidpi-ioreg.txt
   ```
2. **一次只改一项**：先只开 HiDPI（不要同时改 boot-args / 换驱动 / 动 `ResizeGpuBars`）
3. **准备好恢复路径**：确认 `.hidpi-disable` 已生成、知道 Recovery 里怎么删（§4）
4. **出问题的典型症状**（按概率）：模式列表异常 / 选完黑屏或花屏 / 闪 / 唤醒后异常 / 开机 logo 不缩放
   ⇒ **黑屏或进不去系统时优先按 §4 恢复**，再考虑是不是驱动侧的问题（查 `log show` 里 NVRM/NVRMFB 的消息）

> 若 HiDPI 在驱动侧反复出问题，可考虑：先在**较低的目标分辨率**上试（更接近原生、时序更简单），
> 或暂时放弃 HiDPI 等驱动完善 —— **不要为了 HiDPI 去动驱动基线**（`ResizeGpuBars` 等）。

## 6. 别和「选择器的 HiDPI」搞混

| | 系统内 HiDPI（本文） | 引导期 HiDPI |
|---|---|---|
| 管什么 | macOS 桌面的缩放档位 | OpenCore 选择器 / FileVault 界面 / 开机 logo 的文字与图标 |
| 怎么设 | Display Override（本工具） | `UEFI>Output>UIScale`（`1` 普通 / `2` HiDPI / `0` 自动 / `-1` 不变）+ `Resolution=Max` |
| 资源要求 | — | 图标/标签要有 @2x（`.l2x`）；见 `opencore-picker-theme` skill |

两者**互相独立**，可以只开一个。

## 7. 本机速记

- 显示路径：RTX 3080（`10de:2206`）→ NVRMFB；驱动包 1.15.0；`ResizeGpuBars=13` + `ResizeAppleGpuBars=-1`
- 已知显示侧历史：显示器尺寸报错（已修）、无 HDMI/DP 音频、雷电 eGPU 无显示
- 屏幕如果被识别为电视（`kDisplayModeTelevisionFlag`）或尺寸异常，**先查是不是驱动侧的模式元数据问题**，再考虑 HiDPI
- 改完记得：Display Override 在 `/Library/Displays/...`（**不在 ESP**）⇒ 与 EFI 改动无关，但同样**改前备份、改后验证**
