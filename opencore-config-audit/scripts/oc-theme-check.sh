#!/bin/bash
# 检查 OpenCanopy 的 Resources 树是否合规（必需图标 / 真实像素尺寸 / 标签 / 字体 / 音频）
#
# 用法: oc-theme-check.sh [Resources 目录]     默认 /Volumes/EFI/EFI/OC/Resources
# 依据: OpenCorePkg 文档 OpenCanopy 章节（图标清单与尺寸）+ Docs/Flavours.md
#
# 说明: .icns 的「块类型」只区分 1x/2x（ic07 / ic13 …），**真实尺寸要看块里 PNG 的像素**，
#       所以本脚本直接解析 PNG 尺寸，而不是按块类型推断。
set -u

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

# 必需图标（缺一个 OpenCanopy 不启动）；值为文档规定尺寸 (宽, 高)，None = 该维度不限/未规定
MANDATORY = {
    "HardDrive": (128, 128), "ExtHardDrive": (128, 128),
    "Selected": (144, 144),
    "Selector": (None, 40), "SetDefault": (None, 40),   # 最多 144x40，且两者宽度必须一致
    "Left": (40, 40), "Right": (40, 40),
    "Cursor": (None, None),                              # 最多 144x144
    "BtnFocus": (None, None), "Dot": (None, None), "Enter": (None, None), "Lock": (None, None),
    "Password": (None, None), "Restart": (None, None), "ShutDown": (None, None),
}
SHIPPED_OPTIONAL = ["AppleRecv", "AppleTM", "ExtAppleRecv", "ExtAppleTM", "Windows",
                    "OpticalDrive", "Other", "Shell", "Tool", "NetworkBoot", "FirmwareSettings"]
NOT_SHIPPED = ["Apple", "ExtApple", "ExtWindows", "ExtOpticalDrive", "ResetNVRAM", "Background"]
OPT_128 = {n: (128, 128) for n in SHIPPED_OPTIONAL + NOT_SHIPPED if n != "Background"}

CHUNK_1X = {"icp4","icp5","icp6","ic07","ic08","ic09","ic10","is32","il32","ih32","it32","ic04","ic05"}
CHUNK_2X = {"ic11","ic12","ic13","ic14"}

def png_size(b):
    if b[:8] == b"\x89PNG\r\n\x1a\n" and b[12:16] == b"IHDR":
        return struct.unpack(">II", b[16:24])
    return None

def scan(path):
    """→ (1x 最大尺寸, 2x 最大尺寸)；非法文件返回 'bad'"""
    try:
        d = open(path, "rb").read()
    except OSError:
        return None
    if len(d) < 8 or d[:4] != b"icns":
        return "bad"
    off, s1, s2 = 8, None, None
    while off + 8 <= len(d):
        t = d[off:off+4].decode("latin1"); n = struct.unpack(">I", d[off+4:off+8])[0]
        if n < 8 or off + n > len(d):
            break
        sz = png_size(d[off+8:off+n])
        if sz:
            if t in CHUNK_1X and (s1 is None or sz[0]*sz[1] > s1[0]*s1[1]): s1 = sz
            if t in CHUNK_2X and (s2 is None or sz[0]*sz[1] > s2[0]*s2[1]): s2 = sz
        off += n
    return (s1, s2)

def judge(name, got):
    exp = MANDATORY.get(name) or OPT_128.get(name)
    if not exp:
        return ""
    w, h = exp
    if not got:
        return f"  ★ 没有可读的 1x 图（文档要求 {w or '≤144'}x{h or '≤144'}）"
    gw, gh = got
    if w and gw != w:
        return f"  ★ 宽度应为 {w}，实为 {gw}"
    if h and gh != h:
        return f"  ★ 高度应为 {h}，实为 {gh}"
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
        sizes[icon] = s1
        t1 = f"{s1[0]}x{s1[1]}" if s1 else "—"
        t2 = f"{s2[0]}x{s2[1]}" if s2 else "—"
        note = judge(icon, s1)
        if s1 and s2 and s2[0] < s1[0]:   # 只在 2x 比 1x 还小时才提示（正常应≥1x）
            note += f"  ★ 2x({t2}) 比 1x({t1}) 还小"
        print(f"  必需 {icon+'.icns':22s} 1x={t1:>9}  2x={t2:>9}{note}")

    # 文档要求：SetDefault 宽度必须与 Selector 一致
    if sizes.get("Selector") and sizes.get("SetDefault"):
        if sizes["Selector"][0] != sizes["SetDefault"][0]:
            print(f"  ★ Selector 宽 {sizes['Selector'][0]} ≠ SetDefault 宽 {sizes['SetDefault'][0]}（文档要求同宽）")
        else:
            print(f"  ✓ Selector 与 SetDefault 同宽（{sizes['Selector'][0]}）")

    have = {f[:-5] for f in os.listdir(d) if f.endswith(".icns")}
    print(f"  ⇒ 必需图标缺失: {miss or '无 ✓'}")
    if bad: print(f"  ⇒ 不是合法 .icns: {bad}")
    print(f"  可选(官方提供)缺失: {sorted(set(SHIPPED_OPTIONAL)-have) or '无'}")
    print(f"  官方集本来就没有（报 Not Found 属正常）: {sorted(set(NOT_SHIPPED)-have)}")
    extra = sorted(have - set(MANDATORY) - set(SHIPPED_OPTIONAL) - set(NOT_SHIPPED))
    print(f"  额外图标（自行添加的）: {extra or '无'}")
    print()

print("== 标签 Resources/Label（全部必需；高度必须正好 12 px）==")
LABELS = ["EFIBoot","Apple","AppleRecv","AppleTM","Windows","Other","ResetNVRAM",
          "SIPDisabled","SIPEnabled","Shell","FirmwareSettings","Tool"]
ld = os.path.join(R, "Label")
if os.path.isdir(ld):
    for suf, tag in ((".lbl","1x"), (".l2x","2x")):
        miss = [x for x in LABELS if not os.path.exists(os.path.join(ld, x+suf))]
        print(f"  {tag}: 缺 {miss if miss else '无 ✓'}   共 {len([f for f in os.listdir(ld) if f.endswith(suf)])} 个")
else:
    print("  ★ 没有 Label 目录")

print()
print("== 字体 Resources/Font ==")
fd = os.path.join(R, "Font")
if os.path.isdir(fd):
    print(f"  .bin: {[f for f in os.listdir(fd) if f.endswith('.bin')] or '★ 没有'}（应为 AngelCode binary BMF）")
else:
    print("  ★ 没有 Font 目录")

print()
print("== 音频 Resources/Audio ==")
ad = os.path.join(R, "Audio")
if os.path.isdir(ad):
    mp3 = [f for f in os.listdir(ad) if f.lower().endswith(".mp3")]
    print(f"  .mp3 共 {len(mp3)} 个；示例: {sorted(mp3)[:3]}")
else:
    print("  （没有 Audio 目录 —— 只影响语音辅助/条目音效，不影响界面）")
PY
