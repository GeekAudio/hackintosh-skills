#!/bin/bash
# 一键校验 OpenCore config.plist（schema + 引用完整性 + sha）
#
# 用法: oc-verify.sh <config.plist> [docs-dir]
#   docs-dir = fetch-opencore-docs.sh 的输出目录或单个 oc<版本> 官方包目录
#              省略时自动在 <config 同级>/_oc-docs-audit 与 ./_oc-docs-audit 里找
#              发现多个校验器时失败；请指定与目标 OpenCore 同版的唯一目录。
set -u

CFG="${1:?用法: oc-verify.sh <config.plist> [docs-dir]}"
DOCS="${2:-}"
PY="${PYTHON:-python3}"
rc=0

[ -f "$CFG" ] || { echo "找不到 $CFG"; exit 2; }
OCDIR="$(cd "$(dirname "$CFG")" && pwd)"

# --- 找 ocvalidate ---
OV=""
OVS=()
if [ -n "$DOCS" ]; then
  ROOTS=("$DOCS")
else
  ROOTS=("$OCDIR/_oc-docs-audit" "./_oc-docs-audit")
fi
for ROOT in "${ROOTS[@]}"; do
  for CANDIDATE in "$ROOT"/Utilities/ocvalidate/ocvalidate "$ROOT"/oc*/Utilities/ocvalidate/ocvalidate; do
    [ -f "$CANDIDATE" ] || continue
    CANDIDATE="$(cd "$(dirname "$CANDIDATE")" && pwd -P)/ocvalidate"
    FOUND=0
    for ((i=0; i<${#OVS[@]}; i++)); do
      [ "${OVS[$i]}" != "$CANDIDATE" ] || FOUND=1
    done
    [ "$FOUND" -eq 1 ] || OVS[${#OVS[@]}]="$CANDIDATE"
  done
done
if [ "${#OVS[@]}" -gt 1 ]; then
  echo "★ 找到多个 ocvalidate，无法确认应使用哪个版本：" >&2
  printf '   %s\n' "${OVS[@]}" >&2
  echo "请用第二参数指定与目标 OpenCore 同版的唯一官方包目录，或清理目录歧义。" >&2
  exit 1
fi
[ "${#OVS[@]}" -eq 0 ] || OV="${OVS[0]}"

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
echo "== 3) ACPI / Kernel / Drivers / Tools 引用的文件是否存在 =="
"$PY" - "$CFG" "$OCDIR" <<'PY'
import os, plistlib, sys
cfg, ocdir = sys.argv[1], sys.argv[2]
d = plistlib.load(open(cfg, "rb"))
bad = 0
base = os.path.join(ocdir, "ACPI")
for e in d.get("ACPI", {}).get("Add", []):
    p = os.path.join(base, e.get("Path", ""))
    ok = os.path.isfile(p)
    if e.get("Enabled") and not ok:
        bad += 1
    print(f"   [{'启用' if e.get('Enabled') else '禁用'}] ACPI/{e.get('Path'):34s} {'存在' if ok else '★缺失★'}")
kbase = os.path.join(ocdir, "Kexts")
for e in d.get("Kernel", {}).get("Add", []):
    p = os.path.join(kbase, e.get("BundlePath", ""))
    ok = os.path.isdir(p)
    if e.get("Enabled") and not ok:
        bad += 1
    print(f"   [{'启用' if e.get('Enabled') else '禁用'}] Kexts/{e.get('BundlePath'):34s} {'存在' if ok else '★缺失★'}")
    # bundle 目录存在不足以说明 kext 可加载；文件路径均相对 bundle。
    # 无代码 kext 的 ExecutablePath 允许为空，PlistPath 必须指向文件。
    for key in ("PlistPath", "ExecutablePath"):
        rel = e.get(key, "")
        if key == "ExecutablePath" and not rel:
            continue
        present = bool(rel) and os.path.isfile(os.path.join(p, rel))
        if e.get("Enabled") and not present:
            bad += 1
        print(f"     {key}: {rel or '(空)'} {'存在' if present else '★缺失★'}")
# 当前 schema 使用字典条目。旧版字符串 Drivers 不猜测启用语义，
# 应先用目标版本的 ocvalidate 核对，再使用支持该旧版格式的工具。
for section, key, folder in (("UEFI", "Drivers", "Drivers"), ("Misc", "Tools", "Tools")):
    for e in d.get(section, {}).get(key, []):
        if not isinstance(e, dict):
            bad += 1
            print(f"   ★ {section}/{key} 需要当前 schema 的字典条目，无法核对旧格式: {e!r}")
            continue
        rel = e.get("Path", "")
        present = bool(rel) and os.path.isfile(os.path.join(ocdir, folder, rel))
        if e.get("Enabled") and not present:
            bad += 1
        print(f"   [{'启用' if e.get('Enabled') else '禁用'}] {folder}/{rel:34s} {'存在' if present else '★缺失★'}")
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
shasum -a 256 "$CFG" || rc=1

echo
if [ $rc -eq 0 ]; then echo "== 结论: 校验通过 =="; else echo "== 结论: 有问题，见上 =="; fi
exit $rc
