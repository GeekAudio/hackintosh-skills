#!/bin/bash
# 从官方 OcBinaryData 取 OpenCanopy 资源（图标集 / 字体 / 标签 / 音频）
#
# 用法:
#   oc-fetch-iconset.sh iconset <GoldenGate|Syrah|Chardonnay|all> [Resources 目录]
#   oc-fetch-iconset.sh font    [Resources 目录]
#   oc-fetch-iconset.sh label   [Resources 目录]
#   oc-fetch-iconset.sh audio   [语言码] [Resources 目录]     # 语言码如 zh_CN / en；省略只取通用几个
#   默认 Resources 目录 = /Volumes/EFI/EFI/OC/Resources
#
# 来源: https://github.com/acidanthera/OcBinaryData（官方资源仓库）
# 注意: 只新增文件，不删除任何现有文件；已有同名文件会被覆盖（先自己备份）
set -u

REPO="acidanthera/OcBinaryData"
RAW="https://raw.githubusercontent.com/$REPO/master/Resources"

mode="${1:?用法: oc-fetch-iconset.sh <iconset|font|label|audio> [参数] [Resources 目录]}"
shift

case "$mode" in
  iconset)
    SET="${1:?缺少图标集名：GoldenGate | Syrah | Chardonnay | all}"; shift
    R="${1:-/Volumes/EFI/EFI/OC/Resources}"
    [ -d "$R" ] || { echo "找不到 $R"; exit 2; }
    case "$SET" in
      all) SETS="GoldenGate Syrah Chardonnay";;
      *)   SETS="$SET";;
    esac
    for s in $SETS; do
      dst="$R/Image/Acidanthera/$s"
      mkdir -p "$dst"
      echo "== 取图标集 $s → $dst =="
      list=$(curl -sSL --max-time 60 "https://api.github.com/repos/$REPO/contents/Resources/Image/Acidanthera/$s" \
             | grep -o '"name": "[^"]*\.icns"' | sed 's/.*: "//;s/"//')
      [ -n "$list" ] || { echo "   ★ 列表拉取失败（网络/限流？）"; continue; }
      n=0
      for f in $list; do
        if curl -sSL --max-time 60 -f "$RAW/Image/Acidanthera/$s/$f" -o "$dst/$f"; then n=$((n+1)); else echo "   ★ 下载失败 $f"; fi
      done
      echo "   完成 $n 个 .icns"
    done
    ;;

  font)
    R="${1:-/Volumes/EFI/EFI/OC/Resources}"; dst="$R/Font"; mkdir -p "$dst"
    echo "== 取字体 → $dst =="
    for f in Font_1x.bin Font_2x.bin Font_1x.png Font_2x.png; do
      curl -sSL --max-time 60 -f "$RAW/Font/$f" -o "$dst/$f" && echo "   $f" || echo "   ★ $f 失败"
    done
    ;;

  label)
    R="${1:-/Volumes/EFI/EFI/OC/Resources}"; dst="$R/Label"; mkdir -p "$dst"
    echo "== 取标签 → $dst =="
    list=$(curl -sSL --max-time 60 "https://api.github.com/repos/$REPO/contents/Resources/Label" \
           | grep -o '"name": "[^"]*"' | sed 's/.*: "//;s/"//' | grep -E '\.(lbl|l2x)$')
    n=0
    for f in $list; do
      curl -sSL --max-time 60 -f "$RAW/Label/$f" -o "$dst/$f" && n=$((n+1)) || echo "   ★ $f 失败"
    done
    echo "   完成 $n 个标签"
    ;;

  audio)
    LANG_="${1:-}"; case "$LANG_" in /*|"") R="${1:-/Volumes/EFI/EFI/OC/Resources}"; LANG_="";; *) R="${2:-/Volumes/EFI/EFI/OC/Resources}";; esac
    dst="$R/Audio"; mkdir -p "$dst"
    echo "== 取音频 → $dst （语言: ${LANG_:-仅通用}）=="
    list=$(curl -sSL --max-time 60 "https://api.github.com/repos/$REPO/contents/Resources/Audio" \
           | grep -o '"name": "[^"]*\.mp3"' | sed 's/.*: "//;s/"//')
    [ -n "$list" ] || { echo "   ★ 列表拉取失败"; exit 1; }
    n=0
    for f in $list; do
      keep=0
      case "$f" in
        AXEFIAudio_Beep.mp3|AXEFIAudio_Click.mp3|AXEFIAudio_VoiceOver_Boot.mp3) keep=1;;
        AXEFIAudio_"$LANG"_*) [ -n "$LANG_" ] && keep=1;;
      esac
      [ "$keep" = 1 ] || continue
      curl -sSL --max-time 60 -f "$RAW/Audio/$f" -o "$dst/$f" && n=$((n+1)) || echo "   ★ $f 失败"
    done
    echo "   完成 $n 个 mp3（完整集合有 362 个，按需再取）"
    ;;

  *) echo "未知模式 ${mode}（可选 iconset / font / label / audio）"; exit 2;;
esac

echo
echo "== 提示 =="
echo "  1) 之后在 config 里把 Misc>Boot>PickerMode 设为 External、PickerVariant 指到图标集（如 Acidanthera\\GoldenGate）"
echo "  2) 跑 oc-theme-check.sh 复核，重启后看 OC 日志的 OCUI: 行"
echo "  3) 改的是 ESP ⇒ 记得 sync → 卸载 → 重挂 → 复验 sha"
