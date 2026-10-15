#!/bin/sh
# tcc-grant-mic.sh —— 在「AMFI 被关闭」的机器上，手工给 App 注入麦克风（或其它 TCC 服务）授权条目
#
# 背景：boot-args 里的 amfi=0x80 / amfi_get_out_of_my_way=0x1 会关掉 AMFI，
#       代价是 macOS 不再弹权限窗、也不在「隐私与安全性」里生成条目
#       ⇒ 语音类 App 永远拿不到麦克风。
#       详见 references/amfi-and-tcc.md（含「为什么不能改成开 AMFI」与判据）。
#
# 用法：
#   ./tcc-grant-mic.sh --scan                      # 扫 /Applications 里声明要用麦克风的 App
#   ./tcc-grant-mic.sh --list                      # 列出当前该服务的授权条目
#   ./tcc-grant-mic.sh --dry-run <App.app|bundle-id> ...
#   ./tcc-grant-mic.sh <App.app|bundle-id> ...     # 真正写入
#   ./tcc-grant-mic.sh --reset [bundle-id]         # 撤销（tccutil reset）
#
#   ★ 路径含空格/括号时必须加引号（脚本按整参数处理，不会拆词）：
#       ./tcc-grant-mic.sh --service audio "/Library/Audio/Plug-Ins/HAL/ARK.driver/Contents/Resources/Audio Routing Kit (ARK).app"
#
# 选项：
#   --service mic|camera|audio|<kTCCService...>   目标服务（默认 mic = kTCCServiceMicrophone）
#                                                 audio = kTCCServiceAudioCapture（「系统音频录制」）
#
# 依赖：sqlite3 / codesign / csreq / PlistBuddy（macOS 自带）。
# ★ 写入 TCC.db 需要放宽的 SIP（文件受系统保护）；只读操作不需要。
# ★ 条目不持久：系统大版本更新 / tccutil reset / 清理工具都会抹掉 ⇒ 需重跑。

set -u

DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
SERVICE="kTCCServiceMicrophone"
MODE=write
RESET_ID=""
ARGS=""

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --scan)    MODE=scan ;;
    --list)    MODE=list ;;
    --dry-run) MODE=dry ;;
    --reset)   MODE=reset; shift
             [ $# -gt 0 ] && case "$1" in -*) ;; *) RESET_ID="$1"; shift ;; esac
             continue ;;
    --service) shift
             [ $# -gt 0 ] || { echo "--service 需要参数" >&2; exit 2; }
             case "$1" in
               mic|microphone) SERVICE=kTCCServiceMicrophone ;;
               camera)         SERVICE=kTCCServiceCamera ;;
               audio)          SERVICE=kTCCServiceAudioCapture ;;
               *)              SERVICE="$1" ;;
             esac ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "未知参数：$1（-h 看用法）" >&2; exit 2 ;;
    *)  ARGS="${ARGS}${ARGS:+
}$1" ;;
  esac
  shift
done

[ -f "$DB" ] || { echo "找不到用户 TCC 库：$DB" >&2; exit 2; }

# 0 = bundle id 形态
bid_of() {  # $1 = .app 路径
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist" 2>/dev/null
}

resolve() { # $1 = .app 路径 或 bundle id ⇒ 打印 .app 路径
  case "$1" in
    *.app) [ -d "$1" ] && { printf '%s\n' "$1"; return 0; } || return 1 ;;
  esac
  p=$(mdfind "kMDItemCFBundleIdentifier == '$1'" 2>/dev/null | grep '\.app$' | head -1)
  [ -n "$p" ] && printf '%s\n' "$p"
}

# ---------- --list ----------
if [ "$MODE" = list ]; then
  echo "== 当前 $SERVICE 授权条目 =="
  n=$(sqlite3 "$DB" "select count(*) from access where service='$SERVICE';" 2>/dev/null)
  sqlite3 -separator ' | ' "$DB" \
    "select client, auth_value, auth_reason, length(csreq) from access where service='$SERVICE' order by client;" 2>/dev/null
  echo "  -- 共 ${n:-0} 条 --"
  echo "  ★ 条目数 0 或极少 ⇒ 弹窗被抑制（AMFI 关着）⇒ 见 references/amfi-and-tcc.md §1"
  echo "  ★ auth_value: 0=拒绝 / 2=允许 / 3=未决"
  exit 0
fi

# ---------- --scan ----------
if [ "$MODE" = scan ]; then
  echo "== 扫 /Applications 下声明 NSMicrophoneUsageDescription 的 App =="
  found=0
  for app in /Applications/*.app /Applications/*/*.app; do
    [ -d "$app" ] || continue
    desc=$(/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "$app/Contents/Info.plist" 2>/dev/null)
    [ -n "$desc" ] || continue
    bid=$(bid_of "$app")
    printf '  %-42s %s\n' "$(basename "$app")" "${bid:-<无 bundle id>}"
    found=$((found+1))
  done
  [ "$found" -gt 0 ] || echo "  （没找到；也可能装在其它目录，用 --dry-run 直接传路径）"
  echo "  -- 共 $found 个候选 --"
  echo "  ★ 要不要授权由你决定；脚本不会自动全写。"
  exit 0
fi

# ---------- --reset ----------
if [ "$MODE" = reset ]; then
  if [ -n "$RESET_ID" ]; then
    tccutil reset "$SERVICE" "$RESET_ID" && echo "已重置：$SERVICE / $RESET_ID"
  else
    tccutil reset "$SERVICE" && echo "已重置全部：$SERVICE"
  fi
  exit $?
fi

# ---------- write / dry-run ----------
[ -n "$ARGS" ] || { echo "没给 App。用 --scan 找候选，或 -h 看用法。" >&2; exit 2; }

TMP=$(mktemp -d /tmp/tccgrant.XXXXXX) || exit 1
trap 'rm -rf "$TMP"' EXIT

if [ "$MODE" = write ]; then
  echo "== 1) 备份 TCC 库 =="
  BK="$DB.bak-$(date +%Y%m%d-%H%M%S)"
  cp -p "$DB" "$BK" && echo "   -> $BK"
  echo
fi

echo "== 2) 逐 App 生成 csreq$([ "$MODE" = dry ] && echo '（dry-run，不写库）' || echo ' 并写入') =="
ok=0; skip=0
OLDIFS=$IFS; IFS='
'
for A in $ARGS; do
  IFS=$OLDIFS
  APP=$(resolve "$A") || { printf '   [跳过] %s  找不到对应的 .app\n' "$A"; skip=$((skip+1)); continue; }
  NAME=$(basename "$APP" .app)
  BID=$(bid_of "$APP")
  [ -n "$BID" ] || { printf '   [跳过] %s  读不到 CFBundleIdentifier\n' "$NAME"; skip=$((skip+1)); continue; }

  DR=$(codesign -d -r- "$APP" 2>&1 | sed -n 's/^designated => //p')
  [ -n "$DR" ] || { printf '   [跳过] %s  读不到 designated requirement（未签名？）\n' "$NAME"; skip=$((skip+1)); continue; }

  SAFE=$(printf '%s' "$BID" | tr -c 'A-Za-z0-9._-' '_')
  REQ="$TMP/$SAFE.bin"
  printf '%s\n' "$DR" | csreq -r- -b "$REQ" 2>/dev/null
  [ -s "$REQ" ] || { printf '   [跳过] %s  csreq 生成失败\n' "$NAME"; skip=$((skip+1)); continue; }

  magic=$(xxd -p -l 4 "$REQ" 2>/dev/null)
  [ "$magic" = "fade0c00" ] || printf '   ⚠ %s  csreq magic=%s（期望 fade0c00，fade0c01 会被 TCC 拒绝）\n' "$NAME" "${magic:-?}"

  SZ=$(wc -c <"$REQ" | tr -d ' ')
  if [ "$MODE" = dry ]; then
    printf '   [预演] %s  (%s, csreq %s B)\n' "$NAME" "$BID" "$SZ"
    ok=$((ok+1)); continue
  fi

  if sqlite3 "$DB" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, policy_id, indirect_object_identifier_type, indirect_object_identifier, flags, last_modified) VALUES ('$SERVICE','$BID',0,2,4,1,readfile('$REQ'),NULL,0,'UNUSED',0,strftime('%s','now'));" 2>/dev/null; then
    printf '   [OK]   %s  (%s, csreq %s B)\n' "$NAME" "$BID" "$SZ"
    ok=$((ok+1))
  else
    printf '   [失败] %s  写入报错（SIP 没放宽？）\n' "$NAME"
    skip=$((skip+1))
  fi
done
IFS=$OLDIFS

if [ "$MODE" = dry ]; then
  echo "  -- 预演成功 $ok / 跳过 $skip --（去掉 --dry-run 才真正写库）"
  exit 0
fi

echo
echo "== 3) 让 tccd 重新读库 =="
if killall tccd 2>/dev/null; then
  echo "   killall tccd 已发出（root 那份会拒绝，属正常）"
else
  echo "   tccd 未在运行或无法结束"
fi
sleep 2

echo
echo "== 4) 回读验证 =="
sqlite3 -separator ' | ' "$DB" \
  "select client, auth_value, auth_reason, length(csreq) from access where service='$SERVICE' order by client;"
echo "   （auth_value=2 = 已允许；条数应 ≥ 上面成功的 $ok 条）"
echo "   ★ 条目扛住 tccd 重启 = 被接受。撤销：$0 --reset [bundle-id]"
exit 0
