#!/bin/bash
# 从官方 OcBinaryData 下载 OpenCanopy 资源；覆盖同名文件前请备份。
# 用法: oc-fetch-iconset.sh iconset <GoldenGate|Syrah|Chardonnay|all> [Resources]
#       oc-fetch-iconset.sh <font|label> [Resources]
#       oc-fetch-iconset.sh audio [语言码，如 zh_CN / en] [Resources]
# audio 省略语言只取通用音频；单独指定目录时用 ./目录 或绝对路径。
# 退出码: 0 所选文件全部下载，1 下载/列表失败，2 参数错误。
set -eu
REPO="acidanthera/OcBinaryData"
RAW="https://raw.githubusercontent.com/$REPO/master/Resources"
PY="${PYTHON:-python3}"
mode="${1:?用法: oc-fetch-iconset.sh <iconset|font|label|audio> [参数] [Resources]}"
shift
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
failed=0

list_files() {
  local sub="$1" suffix="$2"
  curl -fsSL --max-time 60 "https://api.github.com/repos/$REPO/contents/Resources/$sub" -o "$TMP/list.json" || return 1
  "$PY" - "$TMP/list.json" "$suffix" <<'PY'
import json, re, sys
try:
    entries = json.load(open(sys.argv[1]))
    if not isinstance(entries, list):
        raise ValueError("API 未返回文件列表")
    names = [x['name'] for x in entries if x.get('type', 'file') == 'file'
             and re.fullmatch(r'[A-Za-z0-9_.-]+', x.get('name', ''))
             and re.search(sys.argv[2], x['name'])]
    if not names:
        raise ValueError("资源列表为空")
    print('\n'.join(names))
except (OSError, ValueError, KeyError, TypeError) as error:
    print(f"列表读取失败: {error}", file=sys.stderr)
    sys.exit(1)
PY
}

fetch() {
  local sub="$1" file="$2" dst="$3" partial
  partial=$(mktemp "$dst/.oc-download-XXXXXX") || return 1
  if curl -fsSL --max-time 60 "$RAW/$sub/$file" -o "$partial" && [ -s "$partial" ]; then
    if mv -f "$partial" "$dst/$file"; then echo "  $file"; return 0; fi
  fi
  rm -f "$partial"
  echo "★ 下载失败: $sub/$file" >&2
  return 1
}

case "$mode" in
  iconset)
    SET="${1:?缺少图标集名}"; shift
    case "$SET" in
      all) SETS="GoldenGate Syrah Chardonnay";;
      GoldenGate|Syrah|Chardonnay) SETS="$SET";;
      *) echo "未知图标集: $SET" >&2; exit 2;;
    esac
    [ "$#" -le 1 ] || exit 2
    R="${1:-/Volumes/EFI/EFI/OC/Resources}"
    for s in $SETS; do
      sub="Image/Acidanthera/$s"; dst="$R/$sub"; mkdir -p "$dst"
      list=$(list_files "$sub" '\.icns$') || { echo "★ $s 列表拉取失败" >&2; failed=1; continue; }
      for f in $list; do fetch "$sub" "$f" "$dst" || failed=1; done
    done
    ;;
  font|label)
    [ "$#" -le 1 ] || exit 2
    R="${1:-/Volumes/EFI/EFI/OC/Resources}"
    if [ "$mode" = font ]; then
      sub=Font; list="Font_1x.bin Font_2x.bin Font_1x.png Font_2x.png"
    else
      sub=Label
      list=$(list_files "$sub" '\.(lbl|l2x)$') || { echo "★ 标签列表拉取失败" >&2; exit 1; }
    fi
    dst="$R/$sub"; mkdir -p "$dst"
    for f in $list; do fetch "$sub" "$f" "$dst" || failed=1; done
    ;;
  audio)
    [ "$#" -le 2 ] || exit 2
    LANG_="${1:-}"
    case "$LANG_" in
      /*|./*|../*|"") R="${1:-/Volumes/EFI/EFI/OC/Resources}"; LANG_="";;
      *) R="${2:-/Volumes/EFI/EFI/OC/Resources}";;
    esac
    [[ -z "$LANG_" || "$LANG_" =~ ^[A-Za-z]+(_[A-Za-z0-9]+)*$ ]] || { echo "无效语言码" >&2; exit 2; }
    sub=Audio; dst="$R/$sub"; mkdir -p "$dst"
    list=$(list_files "$sub" '\.mp3$') || { echo "★ 音频列表拉取失败" >&2; exit 1; }
    matched=0; selected=0
    for f in $list; do
      keep=0
      case "$f" in
        AXEFIAudio_Beep.mp3|AXEFIAudio_Click.mp3|AXEFIAudio_VoiceOver_Boot.mp3) keep=1;;
        AXEFIAudio_"$LANG_"_*) if [ -n "$LANG_" ]; then keep=1; matched=1; fi;;
      esac
      [ "$keep" = 1 ] || continue
      selected=$((selected+1))
      fetch "$sub" "$f" "$dst" || failed=1
    done
    if [ "$selected" -eq 0 ] || { [ -n "$LANG_" ] && [ "$matched" -eq 0 ]; }; then
      echo "★ 所请求的音频不存在（语言: ${LANG_:-通用}）" >&2; failed=1
    fi
    ;;
  *) echo "未知模式: $mode" >&2; exit 2;;
esac
[ "$failed" -eq 0 ] || { echo "资源下载未全部完成" >&2; exit 1; }
echo "下载完成。运行 oc-theme-check.sh 复核；实际写入 ESP 后还需卸载、重挂与哈希复验。"
