#!/bin/bash
# redact-check.sh —— 发布前敏感信息自检（只读）
#
# 用途：把 skill 目录打包 / 上传到任何公开位置**之前**，扫一遍不该出现的东西。
#
# 为什么要做：平台上传时会先跑一次 preflight 检查，其中一类确认项就是 `credential`
#   —— 检测到疑似凭据会要求确认，甚至直接拦下。更根本的是：**上传/推送即公开**，
#   三码、网卡 MAC 这类东西等同于这台机器的身份凭证（iMessage / FaceTime 认的就是它们）。
#
# 用法：
#   bash redact-check.sh <目录> [更多目录...]
#   bash redact-check.sh .
#
# 退出码：0 = 没发现问题；1 = 有命中（需要处理）
# 只读，不修改任何东西。

set -u

if [ "$#" -eq 0 ]; then
  echo "用法: bash redact-check.sh <目录> [更多目录...]"
  exit 2
fi

DIRS=("$@")

# 白名单：这些 UUID 是 Apple / OpenCore / UEFI / 微软规范里的标准 GUID（公开常量），不是本机数据
#   —— 每台机器都一样，出现在文档里不构成泄露。新增公开常量请加到这个列表并注明来源。
ALLOW='4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102|4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14|7C436110-AB2A-4BBB-A880-FE41995C9F82|E6B92AC5-B7DB-4B0D-B1B5-8A0E0A0E0A0E|8BE4DF61-93CA-11D2-AA0D-00E098032B8C|A17579F0-4FEC-4936-9364-249460863BE5|6994AD04-93EF-11D0-A3CC-00A0C9223196'
# 注释：后两条是 Windows HD Audio 私有接口类 GUID 与 KS 媒体类 GUID（微软公开，HDAU/HDAudDev 文档路线用）

TOTAL=0

# 注意：这里必须用全局 DIRS，不能用 "$@" —— 函数内的 "$@" 是函数自己的参数
check() {   # check <标签> <正则> <严重度>
  local label="$1" re="$2" sev="$3"
  local out
  out=$(grep -rnIE --binary-files=without-match --exclude=redact-check.sh "$re" "${DIRS[@]}" 2>/dev/null \
        | grep -vE "$ALLOW" | head -20)
  if [ -n "$out" ]; then
    echo "  [${sev}] ${label}"
    printf '%s\n' "$out" | sed 's/^/        /' | cut -c1-170
    echo
    TOTAL=$(( TOTAL + 1 ))
  fi
}

for DIR in "${DIRS[@]}"; do
  if [ ! -d "${DIR}" ]; then
    echo "跳过（不是目录）: ${DIR}"
    continue
  fi
  echo "══════════════════════════════════════════════════════════════"
  echo " 扫描: ${DIR}"
  echo "══════════════════════════════════════════════════════════════"

  # ── 高：身份凭证类（等同于机器身份，绝不能公开）──
  check "网卡 MAC 地址（含 ROM 用的 en0 MAC）" \
        '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' "高"

  check "三码（serial / MLB，上下文型匹配）" \
        '(?i)(serial|MLB|BoardSerial|SystemSerial)[^A-Za-z0-9]{0,6}[A-Z0-9]{8,}' "高"

  check "密钥 / token" \
        '(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY|(?i)(api[_-]?key|access[_-]?token|client[_-]?secret|passwd|password)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,})' "高"

  check "凭据文件路径" \
        '(\.ssh/id_|id_rsa|\.pem\b|\.p12\b|\.netrc|credentials\.json)' "高"

  # ── 中：可识别到具体机器 / 人的信息 ──
  check "卷 UUID（已排除 Apple / UEFI 标准 GUID）" \
        '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' "中"

  check "邮箱地址" \
        '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "中"

  check "内网 / 私有 IP" \
        '\b(10\.[0-9]{1,3}|192\.168\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3})\.[0-9]{1,3}\b' "中"

  echo
done

echo "══════════════════════════════════════════════════════════════"
if [ "$TOTAL" -eq 0 ]; then
  echo " ✅ 没有命中"
  echo "    （自动扫描只是兜底，发布前仍建议人工扫一眼：有没有明显是本机专有的值）"
  exit 0
else
  echo " ⚠️  有 ${TOTAL} 类命中 —— 处理干净再发布 / 上传"
  echo "    · 高：**必须**删掉或换成 ⟨占位符⟩（三码、MAC、密钥）"
  echo "    · 中：换成 ⟨占位符⟩（卷 UUID、主机名），对读者也更清楚"
  echo "    · 邮箱：确认是不是你愿意公开的"
  exit 1
fi
