#!/bin/bash
# 检查 OpenCanopy 的 Resources 树是否合规（必需图标 / 真实像素尺寸 / 标签 / 字体 / 音频）
#
# 用法: oc-theme-check.sh [Resources 目录]     默认 /Volumes/EFI/EFI/OC/Resources
# 依据: OpenCorePkg 1.0.8 OpenCanopy 章节 + Platform/OpenCanopy/GuiApp.c、GuiApp.h
#
# 说明: .icns 的「块类型」只区分 1x/2x（ic07 / ic13 …），**真实尺寸要看块里 PNG 的像素**，
#       所以本脚本直接解析 PNG 尺寸，而不是按块类型推断。
set -eu

R="${1:-/Volumes/EFI/EFI/OC/Resources}"
PY="${PYTHON:-python3}"
[ -d "$R" ] || { echo "找不到 ${R}（ESP 挂载了吗？ls -d /Volumes/EFI）"; exit 2; }

echo "== 资源树 =="
find "$R" -maxdepth 3 -type d | sed "s|^$R|  .|" | sort
echo

echo "== 图标集 =="
if [ -d "$R/Image" ]; then
  find "$R/Image" -mindepth 2 -maxdepth 2 -type d | sort | while read -r s; do
    printf "  %-40s %s 个 .icns\n" "${s#$R/Image/}" "$(ls "$s"/*.icns 2>/dev/null | wc -l | tr -d ' ')"
  done
fi
echo

"$PY" - "$R" <<'PY'
import os, struct, sys

R = sys.argv[1]
errors = 0

# 1x 范围 (最小宽, 最小高, 最大宽, 最大高)。固定尺寸的上下限相同。
# None 下限表示只要求实际像素为正，不随缩放增加最小像素数。
# GuiApp.c 的 AllowLessSize 图标允许小于上限；Cursor 另有 4x4 下限。
# 来源: https://github.com/acidanthera/OpenCorePkg/blob/1.0.8/Platform/OpenCanopy/GuiApp.h
MANDATORY = {
    "HardDrive": (128, 128, 128, 128), "ExtHardDrive": (128, 128, 128, 128),
    "Selected": (144, 144, 144, 144),
    "Selector": (None, None, 144, 40), "SetDefault": (None, None, 144, 40),
    "Left": (40, 40, 40, 40), "Right": (40, 40, 40, 40),
    "Cursor": (4, 4, 144, 144),
    "BtnFocus": (None, None, 144, 144), "Dot": (None, None, 10, 10),
    "Enter": (None, None, 75, 30), "Lock": (None, None, 144, 144),
    "Password": (None, None, 288, 30),
    "Restart": (None, None, 128, 128), "ShutDown": (None, None, 128, 128),
}
SHIPPED_OPTIONAL = ["AppleRecv", "AppleTM", "ExtAppleRecv", "ExtAppleTM", "Windows",
                    "OpticalDrive", "Other", "Shell", "Tool", "NetworkBoot", "FirmwareSettings"]
NOT_SHIPPED = ["Apple", "ExtApple", "ExtWindows", "ExtOpticalDrive", "ResetNVRAM", "Background"]

CHUNK_1X = {"icp4","icp5","icp6","ic07","ic08","ic09","ic10","is32","il32","ih32","it32","ic04","ic05"}
CHUNK_2X = {"ic11","ic12","ic13","ic14"}

def png_size(b):
    if len(b) >= 24 and b[:8] == b"\x89PNG\r\n\x1a\n" and b[12:16] == b"IHDR":
        return struct.unpack(">II", b[16:24])
    return None

def scan(path):
    """→ (1x 最大尺寸, 2x 最大尺寸)；非法文件返回 'bad'"""
    try:
        d = open(path, "rb").read()
    except OSError:
        return None
    if len(d) < 8 or d[:4] != b"icns" or struct.unpack(">I", d[4:8])[0] != len(d):
        return "bad"
    off, s1, s2 = 8, None, None
    while off + 8 <= len(d):
        t = d[off:off+4].decode("latin1"); n = struct.unpack(">I", d[off+4:off+8])[0]
        if n < 8 or off + n > len(d):
            return "bad"
        sz = png_size(d[off+8:off+n])
        if sz:
            if t in CHUNK_1X and (s1 is None or sz[0]*sz[1] > s1[0]*s1[1]): s1 = sz
            if t in CHUNK_2X and (s2 is None or sz[0]*sz[1] > s2[0]*s2[1]): s2 = sz
        off += n
    return (s1, s2) if off == len(d) else "bad"

def judge(name, got, scale=1):
    low_w, low_h, high_w, high_h = (1 if n is None else n * scale for n in MANDATORY[name])
    if not got:
        return f"  ★ 没有可读的 {scale}x 图"
    gw, gh = got
    if not (low_w <= gw <= high_w and low_h <= gh <= high_h):
        if low_w == high_w and low_h == high_h:
            expected = f"{high_w}x{high_h}"
        else:
            expected = f"宽 {low_w}–{high_w}、高 {low_h}–{high_h}"
        return f"  ★ {scale}x 尺寸应为 {expected}，实为 {gw}x{gh}"
    return ""

img = os.path.join(R, "Image")
sets = []
if os.path.isdir(img):
    for v in sorted(os.listdir(img)):
        vd = os.path.join(img, v)
        if not os.path.isdir(vd): continue
        for s in sorted(os.listdir(vd)):
            if os.path.isdir(os.path.join(vd, s)): sets.append((f"{v}\\{s}", os.path.join(vd, s)))
if not sets:
    print("★ 没找到任何图标集（应为 Resources/Image/<厂商>/<图标集>/）"); sys.exit(1)

for name, d in sets:
    print(f"== 图标集 {name} ==")
    miss, bad, sizes = [], [], {}
    for icon in MANDATORY:
        p = os.path.join(d, icon + ".icns")
        if not os.path.exists(p): miss.append(icon); continue
        got = scan(p)
        if got in ("bad", None): bad.append(icon); continue
        s1, s2 = got
        sizes[icon] = (s1, s2)
        t1 = f"{s1[0]}x{s1[1]}" if s1 else "—"
        t2 = f"{s2[0]}x{s2[1]}" if s2 else "—"
        note = judge(icon, s1)
        if s2:
            note += judge(icon, s2, 2)
        if note: errors += 1
        print(f"  必需 {icon+'.icns':22s} 1x={t1:>9}  2x={t2:>9}{note}")

    # 文档要求：SetDefault 宽度必须与 Selector 一致
    for index, scale in enumerate((1, 2)):
        selector = sizes.get("Selector", (None, None))[index]
        default = sizes.get("SetDefault", (None, None))[index]
        if selector and default:
            if selector[0] != default[0]:
                errors += 1
                print(f"  ★ {scale}x Selector 宽 {selector[0]} ≠ SetDefault 宽 {default[0]}（文档要求同宽）")
            else:
                print(f"  ✓ {scale}x Selector 与 SetDefault 同宽（{selector[0]}）")

    errors += len(miss) + len(bad)
    have = {f[:-5] for f in os.listdir(d) if f.endswith(".icns")}
    print(f"  ⇒ 必需图标缺失: {miss or '无 ✓'}")
    if bad: print(f"  ⇒ 不是合法 .icns: {bad}")
    print(f"  可选(官方提供)缺失: {sorted(set(SHIPPED_OPTIONAL)-have) or '无'}")
    print(f"  官方集本来就没有（报 Not Found 属正常）: {sorted(set(NOT_SHIPPED)-have)}")
    extra = sorted(have - set(MANDATORY) - set(SHIPPED_OPTIONAL) - set(NOT_SHIPPED))
    print(f"  额外图标（自行添加的）: {extra or '无'}")
    print()

print("== 标签 Resources/Label（检查必需文件是否存在）==")
LABELS = ["EFIBoot","Apple","AppleRecv","AppleTM","Windows","Other","ResetNVRAM",
          "SIPDisabled","SIPEnabled","Shell","FirmwareSettings","Tool","NetworkBoot"]
ld = os.path.join(R, "Label")
if os.path.isdir(ld):
    for suf, tag in ((".lbl","1x"), (".l2x","2x")):
        miss = [x for x in LABELS if not os.path.exists(os.path.join(ld, x+suf))]
        errors += len(miss)
        print(f"  {tag}: 缺 {miss if miss else '无 ✓'}   共 {len([f for f in os.listdir(ld) if f.endswith(suf)])} 个")
else:
    errors += 1
    print("  ★ 没有 Label 目录")

print()
print("== 字体 Resources/Font ==")
fd = os.path.join(R, "Font")
if os.path.isdir(fd):
    for name in ("Font_1x.bin", "Font_2x.bin", "Font_1x.png", "Font_2x.png"):
        path = os.path.join(fd, name)
        try:
            with open(path, "rb") as source:
                expected = b"BMF\x03" if name.endswith(".bin") else b"\x89PNG\r\n\x1a\n"
                valid = source.read(len(expected)) == expected
        except OSError:
            valid = False
        if not valid: errors += 1
        print(f"  {name}: {'✓ 文件签名' if valid else '★ 缺失或文件签名错误'}")
else:
    errors += 1
    print("  ★ 没有 Font 目录")

print()
print("== 音频 Resources/Audio ==")
ad = os.path.join(R, "Audio")
if os.path.isdir(ad):
    mp3 = [f for f in os.listdir(ad) if f.lower().endswith(".mp3")]
    print(f"  .mp3 共 {len(mp3)} 个；示例: {sorted(mp3)[:3]}")
else:
    print("  （没有 Audio 目录 —— 只影响语音辅助/条目音效，不影响界面）")
print(f"\n必需资源错误: {errors}；可选图标/音频缺失仅作提示。")
sys.exit(1 if errors else 0)
PY
