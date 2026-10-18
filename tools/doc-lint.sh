#!/bin/bash
# doc-lint.sh —— skill 文档一致性自检（只读，不改任何文件）
#
# 为什么需要：本 skill 的 references 互相引用，一处结论写错会顺着引用链传染。
#   已经踩过一次：`network-en0-order.md` 把 Dortania 的 **iServices**（iMessage）要求
#   错误扩展到了 **AirDrop**，结果 `broadcom-wifi.md` / `ethernet-drivers.md` /
#   `smbios-and-serials.md` / `SKILL.md` 全部跟着错，排查时被误导到 `ROM` 上。
#   靠人眼 review 抓不住，所以把已知的「错误说法」写成规则，每次改完跑一遍。
#
# 用法：
#   bash tools/doc-lint.sh              # 全量自检
#   bash tools/doc-lint.sh --with-redact  # 顺带跑脱敏检查（发布前用）
#
# 退出码：0 = 全部通过；1 = 有告警
#
# ★ 误报豁免：行内出现「」或 “”或 "（引用别人的说法），或含 `doc-lint:ignore`，
#   视为「引用 / 有意保留」，不报。需要长期豁免就在那行加 `doc-lint:ignore`。

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/opencore-config-audit"
GREP=/usr/bin/grep
ERRORS=0

if [ ! -d "$SKILL" ]; then
  echo "✗ 找不到技能目录：$SKILL"
  exit 2
fi

# 被扫描的文档：技能正文 + 使用说明 + 全部 references + 仓库 README
# ★ 不能用 mapfile —— macOS 自带 bash 3.2 没有这个内建命令
DOCS=()
while IFS= read -r p; do
  [ -n "$p" ] && DOCS+=("$p")
done < <(
  {
    [ -f "$SKILL/SKILL.md" ] && echo "$SKILL/SKILL.md"
    [ -f "$SKILL/USAGE.md" ] && echo "$SKILL/USAGE.md"
    ls "$SKILL"/references/*.md 2>/dev/null
    [ -f "$ROOT/README.md" ] && echo "$ROOT/README.md"
  } | sort -u
)

hdr() { echo; echo "── $* ──"; }
bad() { echo "   ✗ $*"; ERRORS=$((ERRORS + 1)); }

# 行是否属于「引用 / 豁免」语境
exempt_line() {
  case "$1" in
    *「*|*“*|*\"*|*doc-lint:ignore*) return 0 ;;
  esac
  return 1
}

# 规则 A1：AirDrop 系 × en0 —— 不能说「AirDrop 依赖 en0」
rule_airdrop_en0() {
  hdr "A1  AirDrop / 接力 是否被错误地说成依赖 en0"
  local hit=0 line n f
  while IFS= read -r f; do
    while IFS=: read -r n line; do
      exempt_line "$line" && continue
      case "$line" in
        *无关*|*不依赖*|*独立于*|*不在*|*不受影响*|*不是*|*别*|*错*|*误判*|*❌*|*不挂*|*不需要*|*不影响*|*没有一处*|*unrelated*|*never*|*not\ related*) continue ;;
      esac
      bad "$(basename "$f"):$n  AirDrop 与 en0 混为一谈"
      echo "      ${line:0:150}"
      hit=1
    done < <($GREP -nE '(AirDrop|接力|Handoff|Continuity|连续互通).*(en0)|(en0).*(AirDrop|接力|Handoff|Continuity|连续互通)|(AirDrop|接力|Handoff|Continuity|连续互通)[^。]{0,20}挂在(它|上面|其上)' "$f" 2>/dev/null)
  done < <(printf '%s\n' "${DOCS[@]}")
  [ "$hit" -eq 0 ] && echo "   ✓ 无命中"
}

# 规则 A2：itlwm × AirDrop —— 不能说 itlwm 能拿到 AirDrop
rule_itlwm_airdrop() {
  hdr "A2  itlwm 是否被错误地说成支持 AirDrop"
  local hit=0 line n f
  while IFS= read -r f; do
    while IFS=: read -r n line; do
      exempt_line "$line" && continue
      case "$line" in
        *不支持*|*不可用*|*不能*|*不可能*|*必然*|*没有*|*❌*) continue ;;
      esac
      bad "$(basename "$f"):$n  itlwm 与 AirDrop 正向表述"
      echo "      ${line:0:150}"
      hit=1
    done < <($GREP -nE 'itlwm.*(AirDrop|接力)|(AirDrop|接力).*itlwm' "$f" 2>/dev/null \
             | $GREP -E '(支持|可用|能用|可以)')
  done < <(printf '%s\n' "${DOCS[@]}")
  [ "$hit" -eq 0 ] && echo "   ✓ 无命中"
}

# 规则 A3：ROM × AirDrop —— 不能说 AirDrop 要正确的 ROM
rule_rom_airdrop() {
  hdr "A3  ROM 是否被错误地说成 AirDrop 的前提"
  local hit=0 line n f
  while IFS= read -r f; do
    while IFS=: read -r n line; do
      exempt_line "$line" && continue
      case "$line" in
        *无关*|*不依赖*|*不影响*|*不是*|*别*|*错*|*误判*|*❌*) continue ;;
      esac
      bad "$(basename "$f"):$n  ROM 与 AirDrop 正向表述"
      echo "      ${line:0:150}"
      hit=1
    done < <($GREP -nE 'ROM.*(AirDrop|接力)|(AirDrop|接力).*ROM' "$f" 2>/dev/null \
             | $GREP -E '(必须|要填|否则|一致|改成|失效)')
  done < <(printf '%s\n' "${DOCS[@]}")
  [ "$hit" -eq 0 ] && echo "   ✓ 无命中"
}

# 规则 B：索引完整性 —— references / scripts 与 SKILL.md 双向对齐
rule_index() {
  hdr "B1  每个 reference 都在 SKILL.md 里被索引"
  local miss=0 f b
  for f in "$SKILL"/references/*.md; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    $GREP -q "$b" "$SKILL/SKILL.md" || { bad "未索引：references/$b"; miss=1; }
  done
  [ "$miss" -eq 0 ] && echo "   ✓ 无命中"

  hdr "B2  每个 script 都在 SKILL.md 里被索引"
  miss=0
  for f in "$SKILL"/scripts/*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    $GREP -q "$b" "$SKILL/SKILL.md" || { bad "未索引：scripts/$b"; miss=1; }
  done
  [ "$miss" -eq 0 ] && echo "   ✓ 无命中"

  hdr "B3  SKILL.md 引用的文件都真实存在"
  miss=0
  while read -r p; do
    [ -z "$p" ] && continue
    [ -f "$SKILL/$p" ] || { bad "死链：$p"; miss=1; }
  done < <($GREP -oE '\b(references|scripts)/[A-Za-z0-9._-]+\.[A-Za-z0-9]+' "$SKILL/SKILL.md" | sort -u)
  [ "$miss" -eq 0 ] && echo "   ✓ 无命中"

  hdr "B4  各文档里写的 references/ 与 scripts/ 路径都真实存在"
  # ★ 只查带目录前缀**且带扩展名**的路径。两个原因：
  #   ① 裸文件名（`install.sh` / `Audio_Tahoe.md` 这类）多半是**别的仓库**的文档，查了全是假阳性；
  #   ② 正文里会出现「references/scripts 索引」这种连写，不是路径，不能当死链。
  miss=0
  while read -r p; do
    [ -z "$p" ] && continue
    [ -f "$SKILL/$p" ] || { bad "死链：$p"; miss=1; }
  done < <(
    for f in "${DOCS[@]}"; do
      $GREP -ohE '\b(references|scripts)/[A-Za-z0-9._-]+\.[A-Za-z0-9]+' "$f" 2>/dev/null
    done | sort -u
  )
  [ "$miss" -eq 0 ] && echo "   ✓ 无命中"

  hdr "B5  资源清单里每条独立成行（防编辑时粘连）"
  # ★ 症状：两条 `- \`references/xxx.md\` —— …` 被粘成一行（多半是编辑时漏了换行）。
  #   路径本身都存在 ⇒ B3/B4 查不出来，只有条目数对不上时才暴露。
  #   判据：以 `- \`references/` 或 `- \`scripts/` 开头的行，行内不应再出现第二个同样的开头。
  #   正文里「用 A；先 B」这种多路径叙述不算——它不以 `- \`` 开头。
  python3 - "$SKILL/SKILL.md" <<'PY'
import re, sys
path = sys.argv[1]
head = re.compile(r'^- `(?:references|scripts)/')
item = re.compile(r'- `(?:references|scripts)/')
hits = []
for i, line in enumerate(open(path, encoding='utf-8'), 1):
    if not head.match(line):
        continue
    n = len(item.findall(line))
    if n > 1:
        hits.append((i, n, line.strip()[:60]))
for i, n, s in hits:
    print(f"   ✗ 条目粘连（{n} 条并成一行）L{i}：{s}…")
if not hits:
    print("   ✓ 无命中")
sys.exit(1 if hits else 0)
PY
  [ $? -eq 0 ] || ERRORS=$((ERRORS + 1))
}

# 规则 C：版本号三处一致（发布前最容易漏的一步）
rule_version() {
  hdr "C1  版本号三处一致（SKILL.md / plugin.json / marketplace.json）"
  python3 - "$SKILL" "$ROOT/.codebuddy-plugin/marketplace.json" <<'PY'
import json, sys, re, os
skill, market = sys.argv[1], sys.argv[2]
name = os.path.basename(skill)
found = {}
try:
    txt = open(os.path.join(skill, "SKILL.md"), encoding="utf-8").read()
    fm = txt.split("---", 2)[1] if txt.startswith("---") else ""
    m = re.search(r"^version:\s*(\S+)", fm, re.M)
    found["SKILL.md"] = m.group(1).strip("'\"") if m else None
except FileNotFoundError:
    found["SKILL.md"] = "MISSING"
try:
    found["plugin.json"] = json.load(open(os.path.join(skill, ".codebuddy-plugin", "plugin.json"), encoding="utf-8")).get("version")
except Exception:
    found["plugin.json"] = "MISSING"
try:
    mk = json.load(open(market, encoding="utf-8"))
    e = next((p for p in mk.get("plugins", []) if p.get("name") == name), {})
    found["marketplace.json"] = e.get("version")
except Exception:
    found["marketplace.json"] = "MISSING"
for k, v in found.items():
    print(f"      {k:<18} {v}")
vals = list(found.values())
ok = len(set(vals)) == 1 and vals[0] not in (None, "MISSING")
print("   ✓ 三处一致" if ok else "   ✗ 版本号不一致，发布前必须对齐")
sys.exit(0 if ok else 1)
PY
  [ $? -ne 0 ] && ERRORS=$((ERRORS + 1))
}

echo "══════════════════════════════════════════════════════════"
echo "  doc-lint · $(basename "$ROOT")"
echo "  扫描 $(( ${#DOCS[@]} )) 份文档"
echo "══════════════════════════════════════════════════════════"

rule_airdrop_en0
rule_itlwm_airdrop
rule_rom_airdrop
rule_index
rule_version

if [ "${1:-}" = "--with-redact" ]; then
  hdr "D1  发布前脱敏检查"
  if bash "$SKILL/scripts/redact-check.sh" "$SKILL" > /tmp/.doclint_redact.$$ 2>&1; then
    echo "   ✓ 无命中"
  else
    bad "脱敏检查有命中（详情：bash opencore-config-audit/scripts/redact-check.sh opencore-config-audit）"
  fi
  rm -f /tmp/.doclint_redact.$$
fi

echo
echo "══════════════════════════════════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  echo " ✅ 全部通过"
else
  echo " ⚠️  $ERRORS 处告警"
fi
echo "══════════════════════════════════════════════════════════"
exit $([ "$ERRORS" -eq 0 ] && echo 0 || echo 1)
