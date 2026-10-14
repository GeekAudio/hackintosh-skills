#!/bin/bash
# 一键校验 OpenCore config.plist（schema + 引用完整性 + sha）
#
# 用法: oc-verify.sh <config.plist> [docs-dir]
#   docs-dir = fetch-opencore-docs.sh 的输出目录（含 oc<版本>/Utilities/ocvalidate/ocvalidate）
#              省略时自动在 <config 同级>/_oc-docs-audit 与 ./_oc-docs-audit 里找
set -u

CFG="${1:?用法: oc-verify.sh <config.plist> [docs-dir]}"
DOCS="${2:-}"
PY="${PYTHON:-python3}"
rc=0

[ -f "$CFG" ] || { echo "找不到 $CFG"; exit 2; }
OCDIR="$(cd "$(dirname "$CFG")" && pwd)"

# --- 找 ocvalidate ---
OV=""
if [ -n "$DOCS" ]; then
  OV=$(ls -1 "$DOCS"/oc*/Utilities/ocvalidate/ocvalidate 2>/dev/null | head -1)
fi
[ -n "$OV" ] || OV=$(ls -1 "$OCDIR"/_oc-docs-audit/oc*/Utilities/ocvalidate/ocvalidate 2>/dev/null | head -1)
[ -n "$OV" ] || OV=$(ls -1 ./_oc-docs-audit/oc*/Utilities/ocvalidate/ocvalidate 2>/dev/null | head -1)

echo "== 1) plutil 语法 =="
plutil -lint "$CFG" || rc=1

echo
echo "== 2) 官方 ocvalidate =="
if [ -n "$OV" ]; then
  echo "   校验器: $OV"
  "$OV" "$CFG" || rc=1
else
  echo "   ★ 没找到 ocvalidate。先跑 fetch-opencore-docs.sh <版本> 拿到官方校验器"
  echo "     （版本必须与机器上的 OpenCore 相同，用 nvram 4D1FDA02-…:opencore-version 确认）"
  rc=1
fi

echo
echo "== 3) ACPI / Kernel 引用的文件是否存在 =="
"$PY" - "$CFG" "$OCDIR" <<'PY'
import os, plistlib, sys
cfg, ocdir = sys.argv[1], sys.argv[2]
d = plistlib.load(open(cfg, "rb"))
bad = 0
base = os.path.join(ocdir, "ACPI")
for e in d.get("ACPI", {}).get("Add", []):
    p = os.path.join(base, e.get("Path", ""))
    ok = os.path.exists(p)
    if e.get("Enabled") and not ok:
        bad += 1
    print(f"   [{'启用' if e.get('Enabled') else '禁用'}] ACPI/{e.get('Path'):34s} {'存在' if ok else '★缺失★'}")
kbase = os.path.join(ocdir, "Kexts")
for e in d.get("Kernel", {}).get("Add", []):
    p = os.path.join(kbase, e.get("BundlePath", ""))
    ok = os.path.exists(p)
    if e.get("Enabled") and not ok:
        bad += 1
    print(f"   [{'启用' if e.get('Enabled') else '禁用'}] Kexts/{e.get('BundlePath'):34s} {'存在' if ok else '★缺失★'}")
# 孤儿文件（忽略 macOS 在 FAT 上生成的 AppleDouble ._xxx）
ref = {e.get("BundlePath", "") for e in d.get("Kernel", {}).get("Add", [])}
if os.path.isdir(kbase):
    for f in sorted(os.listdir(kbase)):
        if f.startswith("._") or f == ".DS_Store":
            continue
        if f not in ref:
            print(f"   孤儿(未被 Add 引用): Kexts/{f}")
print(f"   ⇒ 启用项缺失数: {bad}")
sys.exit(1 if bad else 0)
PY
[ $? -eq 0 ] || rc=1

echo
echo "== 4) sha256 =="
shasum -a 256 "$CFG"

echo
if [ $rc -eq 0 ]; then echo "== 结论: 校验通过 =="; else echo "== 结论: 有问题，见上 =="; fi
exit $rc
