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
# 退出码：0 = 全部通过；1 = 有告警；2 = 用法 / 依赖错误
#
# ★ 误报豁免：行内出现「」或 “”或 "（引用别人的说法），或含 `doc-lint:ignore`，
#   视为「引用 / 有意保留」，不报。需要长期豁免就在那行加 `doc-lint:ignore`。

set -u

if [ "$#" -gt 1 ]; then
  echo "用法：bash tools/doc-lint.sh [--with-redact]" >&2
  exit 2
fi
case "${1:-}" in
  ""|--with-redact) ;;
  -h|--help)
    echo "用法：bash tools/doc-lint.sh [--with-redact]"
    exit 0 ;;
  *) echo "未知参数：$1" >&2; exit 2 ;;
esac
if ! command -v python3 >/dev/null 2>&1; then
  echo "✗ 需要 Python 3（结构 / 发布元数据校验仅使用标准库）" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/opencore-config-audit"
GREP=/usr/bin/grep
ERRORS=0

if [ ! -d "$SKILL" ]; then
  echo "✗ 找不到技能目录：$SKILL"
  exit 2
fi

# 被扫描的文档：技能正文 + 使用说明 + 全部 references + 仓库根文档
# ★ 不能用 mapfile —— macOS 自带 bash 3.2 没有这个内建命令
DOCS=()
while IFS= read -r p; do
  [ -n "$p" ] && DOCS+=("$p")
done < <(
  {
    [ -f "$SKILL/SKILL.md" ] && echo "$SKILL/SKILL.md"
    [ -f "$SKILL/USAGE.md" ] && echo "$SKILL/USAGE.md"
    ls "$SKILL"/references/*.md 2>/dev/null
    for p in "$ROOT"/*.md; do
      [ -f "$p" ] && echo "$p"
    done
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
    # 只关联同一句内的两个术语，避免上一句讲 en0、下一句链接到
    # AirDrop 排障时被拼成不存在的依赖关系。
    done < <($GREP -nE '(AirDrop|接力|Handoff|Continuity|连续互通)[^.。！？!?;；]*(en0)|(en0)[^.。！？!?;；]*(AirDrop|接力|Handoff|Continuity|连续互通)|(AirDrop|接力|Handoff|Continuity|连续互通)[^。]{0,20}挂在(它|上面|其上)' "$f" 2>/dev/null)
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

# 规则 B/C：真正的本地引用、可发现性、frontmatter 与发布清单。
# 独立为 stdlib Python helper，避免 grep 把“文件名子串”误当作引用。
rule_structure() {
  python3 "$ROOT/tools/doc-structure.py" "$ROOT" || ERRORS=$((ERRORS + 1))
}

# 规则 G1：通用性 —— 别人拿到这个 skill 要能用，不能是某台机器的备忘录
#   允许的三种位置（见 SKILL.md「写作规范」）：① 证据标注（含「实测 / 曾 / 踩过 / 案例」）
#   ② 「示例 / 速记」小节 ③ 指针（指向 machine-facts.md）。其余「本机」视为把特例写成了规则。
#   `machine-facts.md` 本身是唯一放本机事实的地方，整份豁免。
rule_generality() {
  hdr "G1  通用性：本机特例没被写成通用规则"
  local hit=0 f n line
  for f in "$SKILL"/references/*.md "$SKILL"/SKILL.md; do
    case "$(basename "$f")" in machine-facts.md) continue ;; esac
    # (a) 标题里出现「本机」，但不是「关于本机」/「实测」/「示例」/「速记」/「案例」/「写作规范」
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      case "$line" in
        \#*) ;;
        *) continue ;;
      esac
      case "$line" in
        *本机*) ;;
        *) continue ;;
      esac
      case "$line" in
        *关于本机*|*实测*|*示例*|*速记*|*案例*|*写作规范*) continue ;;
      esac
      bad "$(basename "$f"):$n 标题里写「本机」⇒ 改成通用表述（本机值放正文括号或 machine-facts.md）"
      echo "      $line"
      hit=$((hit + 1))
    done < "$f"
    # (b) 正文里出现作者机器的绝对路径
    n=0
    while IFS= read -r line; do
      n=$((n + 1))
      case "$line" in
        *"/Users/"*) ;;
        *) continue ;;
      esac
      case "$line" in
        *"/Users/<"*|*"/Users/x/"*) continue ;;
      esac
      bad "$(basename "$f"):$n 出现本机绝对路径 ⇒ 换成占位符或相对路径"
      echo "      $line"
      hit=$((hit + 1))
    done < "$f"
  done
  [ "$hit" -eq 0 ] && echo "   ✓ 无命中"
}

echo "══════════════════════════════════════════════════════════"
echo "  doc-lint · $(basename "$ROOT")"
echo "  扫描 $(( ${#DOCS[@]} )) 份文档"
echo "══════════════════════════════════════════════════════════"

rule_airdrop_en0
rule_itlwm_airdrop
rule_rom_airdrop
rule_structure
rule_generality

if [ "${1:-}" = "--with-redact" ]; then
  hdr "D1  发布前脱敏检查"
  # 保留检查器输出，避免把缺依赖 / 扫描失败伪装成普通“有命中”。
  if bash "$SKILL/scripts/redact-check.sh" "$SKILL"; then
    echo "   ✓ 无命中"
  else
    bad "脱敏检查未通过（见上方详情）"
  fi
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
