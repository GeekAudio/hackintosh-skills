#!/bin/bash
# 取「与机器同版本」的官方 OpenCore 文档与校验器，并建配置键库
#
# 用法: fetch-opencore-docs.sh <版本号> [输出目录]
#   例: fetch-opencore-docs.sh 1.0.8            → 默认输出 ./_oc-docs-audit
#       fetch-opencore-docs.sh 1.0.8 /tmp/ocdoc
#
# 版本号从 NVRAM 读：nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version
#   DBG-108-2026-09-27 → 1.0.8（DBG- 前缀 = DEBUG 构建）
#   1.0.8-2026-09-27   → 1.0.8（RELEASE）
set -eu

VER="${1:?用法: fetch-opencore-docs.sh <版本号> [输出目录]}"
OUT="${2:-./_oc-docs-audit}"
PY="${PYTHON:-python3}"

mkdir -p "$OUT"
cd "$OUT"

echo "== 1) 下载官方 RELEASE 包 OpenCore-$VER =="
if [ ! -f "oc-$VER.zip" ]; then
  curl -sSL --max-time 300 \
    "https://github.com/acidanthera/OpenCorePkg/releases/download/$VER/OpenCore-$VER-RELEASE.zip" \
    -o "oc-$VER.zip"
fi
ls -la "oc-$VER.zip"
rm -rf "oc$VER"; unzip -oq "oc-$VER.zip" -d "oc$VER"

echo "== 2) 关键产物 =="
ls -la "oc$VER/Utilities/ocvalidate/ocvalidate" "oc$VER/Docs/Sample.plist" 2>/dev/null || true
echo "   AcpiSamples 官方样例数: $(ls "oc$VER/Docs/AcpiSamples/Source/"*.dsl 2>/dev/null | wc -l | tr -d ' ')"
chmod +x "oc$VER/Utilities/ocvalidate/ocvalidate" 2>/dev/null || true
xattr -d com.apple.quarantine "oc$VER/Utilities/ocvalidate/ocvalidate" 2>/dev/null || true

echo "== 3) 取该版本的 Configuration.tex（LaTeX 源，便于检索）=="
curl -sSL --max-time 120 \
  "https://raw.githubusercontent.com/acidanthera/OpenCorePkg/$VER/Docs/Configuration.tex" \
  -o "Configuration-$VER.tex"
ls -la "Configuration-$VER.tex"

echo "== 4) 抽取全部配置键 → oc-doc-keys.json =="
"$PY" - "$OUT/Configuration-$VER.tex" "$OUT/oc-doc-keys.json" <<'PY'
import json, re, sys
src, dst = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8", errors="replace").read().split("\n")
sec = sub = ""
out, i = {}, 0
while i < len(lines):
    l = lines[i]
    m = re.match(r"\\section\{(.+?)\}", l)
    if m: sec = m.group(1)
    m = re.match(r"\\subsection\{(.+?)\}", l)
    if m: sub = m.group(1)
    m = re.match(r"\s*\\texttt\{([A-Za-z0-9_#:\-\(\)\. ]+)\}\\\\\s*$", l)
    if m and i + 1 < len(lines) and "textbf{Type}" in lines[i + 1]:
        key = m.group(1)
        body, j = [], i + 1
        while j < len(lines) and not re.match(r"\s*\\item\s*$", lines[j]) and "\\end{enumerate}" not in lines[j]:
            body.append(lines[j]); j += 1
        txt = "\n".join(body)
        fld = lambda n: (re.search(r"\\textbf\{" + n + r"\}:\s*(.*)", txt) or [None, ""])[1]
        d = re.search(r"\\textbf\{Description\}:\s*(.*)", txt, re.S)
        d = d.group(1) if d else ""
        d = d.replace("\\texttt{", "").replace("}", "").replace("\\ ", " ").replace("\\emph{", "")
        d = re.sub(r"\\[a-zA-Z]+\{?", "", d)
        out.setdefault(sec, {}).setdefault(sub, {})[key] = {
            "type": fld("Type").replace("\\texttt{", "").replace("}", "").replace("\\ ", " "),
            "failsafe": fld("Failsafe").replace("\\texttt{", "").replace("}", ""),
            "desc": re.sub(r"\s+", " ", d).strip(),
        }
        i = j; continue
    i += 1
json.dump(out, open(dst, "w"), ensure_ascii=False, indent=1)
total = sum(len(v) for s in out.values() for v in s.values())
print(f"   段: {list(out)}")
print(f"   键总数: {total}  →  {dst}")
PY

echo
echo "== 完成 =="
echo "  校验器: $OUT/oc$VER/Utilities/ocvalidate/ocvalidate"
echo "  样例:   $OUT/oc$VER/Docs/Sample.plist"
echo "  SSDT:   $OUT/oc$VER/Docs/AcpiSamples/"
echo "  键库:   $OUT/oc-doc-keys.json"
echo
echo "下一步: oc-verify.sh <config.plist> $OUT"
