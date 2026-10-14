#!/bin/bash
# 校验 MacPro 机型的内存注入摆位（PlatformInfo > Memory > Devices）
#
# 用法: mem-check.sh [config.plist]        默认 /Volumes/EFI/EFI/OC/config.plist
#
# 规则（本机 10-13 破案，v38 实测通过）：
#   「关于本机 → 内存」图把 Devices 的**第 j 个条目画到固定的第 f(j) 个图位**，
#   f = [8,7,10,9,12,11,5,6,3,4,1,2]（= 真机 SMBIOS Type 17 的表顺序）
#   ⇒ 槽号必须用真机编号、且数组要按 f 序排，才能「图位 v = Slot v = 列表第 v 行」
set -u

CFG="${1:-/Volumes/EFI/EFI/OC/config.plist}"
PY="${PYTHON:-python3}"
[ -f "$CFG" ] || { echo "找不到 ${CFG}（ESP 挂载了吗？ls -d /Volumes/EFI）"; exit 2; }

echo "== 目标 =="; echo "   $CFG"
echo

"$PY" - "$CFG" <<'PY'
import plistlib, re, sys

F = [8, 7, 10, 9, 12, 11, 5, 6, 3, 4, 1, 2]          # 数组第 j 项 → 图位 F[j-1]
SLOT2CH = {1:"F1",2:"F2",3:"E1",4:"E2",5:"D1",6:"D2",
           7:"A2",8:"A1",9:"B2",10:"B1",11:"C2",12:"C1"}

p = plistlib.load(open(sys.argv[1], "rb"))
mem = p.get("PlatformInfo", {}).get("Memory")
if not mem:
    print("★ 没有 PlatformInfo > Memory 段 —— 内存由 macOS 自行枚举（不做定制）")
    sys.exit(0)

devs = mem.get("Devices") or []
cap = mem.get("MaxCapacity")
print(f"== 顶层 ==")
print(f"   Devices 条目数 : {len(devs)}")
print(f"   MaxCapacity    : {cap} ({'≈ %.1f GB' % (cap/1024**3) if isinstance(cap, int) and cap else '未设'}；★单位 bytes)")
print()

print("== 逐条：数组序号 → 预测图位 ==")
print("   序号 | 预测图位 | DeviceLocator                                    | Size(MB) | 判定")
print("   -----+----------+--------------------------------------------------+----------+------")
bad = 0
filled = []
for j, d in enumerate(devs, 1):
    loc = str(d.get("DeviceLocator", ""))
    size = d.get("Size", 0)
    m = re.search(r"Slot\s*(\d+)", loc)
    slot = int(m.group(1)) if m else None
    pred = F[j - 1] if j <= len(F) else None
    if slot is None:
        verdict = "★ 名字里没有 'Slot N'，无法判定"
        bad += 1
    elif pred is None:
        verdict = f"★ 超出 12 槽（第 {j} 项不会被画到图上）"
        bad += 1
    elif slot == pred:
        verdict = "✓ 一致"
    else:
        verdict = f"★ 错位：会画到图位 {pred}（那里显示的是本条的 Slot {slot}）"
        bad += 1
    if isinstance(size, int) and size > 0:
        filled.append((slot, pred, size, loc))
    print(f"   {j:>4} | {str(pred):>8} | {loc[:48]:<48} | {str(size):>8} | {verdict}")

print()
print("== 结论 ==")
if bad == 0 and devs:
    print("   ✓ 数组顺序正确：图位 v = Slot v = 列表第 v 行，两处永远一致")
else:
    print(f"   ★ 有 {bad} 条不一致 ⇒ 「关于本机」的内存图会与「系统信息」列表错位")
    print("     修法：① 槽号用真机编号（1=F1 2=F2 3=E1 4=E2 5=D1 6=D2 7=A2 8=A1 9=B2 10=B1 11=C2 12=C1）")
    print("           ② Devices 数组按 f 序排：第1项=Slot8、第2项=Slot7、第3项=Slot10 … 第12项=Slot2")
print()
if filled:
    print("== 实装（Size>0）==")
    for slot, pred, size, loc in filled:
        ch = SLOT2CH.get(slot, "?")
        print(f"   Slot {slot:<2} ({ch:<2}) → 图位 {pred:<2} | {size} MB | {loc}")
    if len(filled) not in (4, 6, 8, 10, 12):
        print(f"   ⚠ 实装 {len(filled)} 条：Apple 官方只支持 4/6/8/10/12 条")
        print("     ⇒ macOS 会弹「建议成对、至少四条」+ 顾问 ! 标记 —— 真机也一样，改位置去不掉")
else:
    print("== 实装：无（全部 Size=0）==")
PY
