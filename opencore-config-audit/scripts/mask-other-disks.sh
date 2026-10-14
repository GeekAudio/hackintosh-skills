#!/bin/bash
# 在 macOS 里屏蔽「除系统卷之外」的所有磁盘卷：/etc/fstab + noauto ⇒ 启动不自动挂载
#   ⇒ 桌面 / 访达 / Spotlight 都不出现；手动仍可挂载（sudo diskutil mount <dev>）
#
# 用法:
#   mask-other-disks.sh                 # 只打印计划（dry-run），不写任何东西
#   mask-other-disks.sh --apply         # 写 /etc/fstab 并立即卸载被屏蔽的卷（需要 root）
#   mask-other-disks.sh --apply --keep B97A1BB4-…    # 额外保留某些卷（可多次 --keep）
#   mask-other-disks.sh --undo          # 删除 /etc/fstab（撤销全部屏蔽）
#
# ★ 铁律：EFI 分区（Partition Type = EFI）永不写入 fstab；写完后会做一次
#   「按 UUID 找 ESP → 卸载 → 重挂 → 读 config.plist」的验证。
set -u

APPLY=0; UNDO=0; KEEP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1;;
    --undo)  UNDO=1;;
    --keep)  KEEP="$KEEP ${2:-}"; shift;;
    *) echo "未知参数: $1"; exit 2;;
  esac
  shift
done

FSTAB=/etc/fstab

if [ "$UNDO" = 1 ]; then
  echo "== 撤销屏蔽：删除 $FSTAB =="
  if [ -f "$FSTAB" ]; then
    cp -p "$FSTAB" "/tmp/fstab.bak-$(date +%Y%m%d-%H%M%S)"
    if [ "$(id -u)" = 0 ]; then rm -f "$FSTAB"; else
      osascript -e "do shell script \"/bin/rm -f $FSTAB\" with administrator privileges"; fi
    echo "   已删除（旧内容备份在 /tmp）。重启后生效。"
  else
    echo "   $FSTAB 不存在，无需撤销。"
  fi
  exit 0
fi

echo "== 1) 枚举所有真实卷，挑出「非系统、非 EFI」的 =="
TARGETS=""
while IFS= read -r dev; do
  info=$(diskutil info "$dev" 2>/dev/null) || continue
  uuid=$(printf '%s\n' "$info" | awk -F': *' '/Volume UUID/{print $2}')
  name=$(printf '%s\n' "$info" | awk -F': *' '/Volume Name/{print $2}')
  fs=$(printf '%s\n'   "$info" | awk -F': *' '/File System Personality/{print $2}')
  ptype=$(printf '%s\n' "$info" | awk -F': *' '/Partition Type/{print $2}')
  mp=$(printf '%s\n'  "$info" | awk -F': *' '/Mount Point/{print $2}')
  [ -n "$uuid" ] || continue                       # 无卷 UUID（合成卷/容器）跳过
  [ "$ptype" = "EFI" ] && { printf '   skip %-10s %-22s EFI 分区（永不屏蔽）\n' "$dev" "$name"; continue; }
  case "$fs" in *APFS*) printf '   skip %-10s %-22s APFS（系统卷）\n' "$dev" "$name"; continue;; esac
  case "$mp" in /|/System/*) printf '   skip %-10s %-22s 系统挂载点\n' "$dev" "$name"; continue;; esac
  case " $KEEP " in *" $uuid "*) printf '   keep %-10s %-22s 用户指定保留\n' "$dev" "$name"; continue;; esac
  printf '   MASK %-10s %-22s %-6s %s\n' "$dev" "${name:-<无名>}" "${fs:-?}" "$uuid"
  TARGETS="$TARGETS $uuid|$dev|${name:-unnamed}|${fs:-ntfs}"
done <<EOF
$(diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | sort -u)
EOF

if [ -z "$TARGETS" ]; then echo "   （没有需要屏蔽的卷）"; fi

echo
echo "== 2) 计划写入 $FSTAB 的内容 =="
{
  echo "# 屏蔽非 macOS 卷 —— 只自动挂载系统卷（由 mask-other-disks.sh 生成，$(date +%Y-%m-%d)）"
  echo "# ★★ EFI 分区不在此列！引导在它上面，安装 App 要靠它读写 config.plist ⇒ 永不屏蔽"
  echo "# 临时访问：sudo diskutil mount /dev/diskXsY   撤销全部：sudo rm /etc/fstab 后重启"
  for t in $TARGETS; do
    u=${t%%|*}; rest=${t#*|}; d=${rest%%|*}; rest=${rest#*|}; n=${rest%%|*}; fs=${rest##*|}
    printf 'UUID=%s none %s noauto   # %s (%s)\n' "$u" "$(echo "$fs" | tr 'A-Z' 'a-z')" "$n" "$d"
  done
} | tee /tmp/_fstab.new

if [ "$APPLY" != 1 ]; then
  echo
  echo "== dry-run：没有写任何东西。确认后执行 =="
  echo "   sudo bash \"$0\" --apply"
  exit 0
fi

echo
echo "== 3) 写入 $FSTAB 并立即卸载被屏蔽的卷 =="
SCRIPT=/tmp/_mask-apply-$$.sh
cat > "$SCRIPT" <<EOF
#!/bin/bash
cp -p "$FSTAB" /tmp/fstab.bak-\$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
cp /tmp/_fstab.new "$FSTAB"
chmod 644 "$FSTAB"; chown root:wheel "$FSTAB"
echo "== fstab 已写入 =="; cat "$FSTAB"
echo
echo "== 卸载被屏蔽的卷 =="
for t in $(for x in $TARGETS; do printf '%s ' "${x%%|*}"; done); do
  for d in \$(diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | sort -u); do
    u=\$(diskutil info "\$d" 2>/dev/null | awk -F': *' '/Volume UUID/{print \$2}')
    if [ "\$u" = "$t" ]; then printf '  %s (%s) -> ' "\$d" "\$u"; diskutil unmount "\$d" 2>&1 | tail -1; fi
  done
done
echo
echo "== 现在 /Volumes =="; ls -1 /Volumes
echo
echo "== 验证 EFI 分区不受影响（按 UUID 找 ESP → 卸载 → 重挂 → 读 config）=="
esp=""
for d in \$(diskutil list | grep -oE 'disk[0-9]+s[0-9]+' | sort -u); do
  i=\$(diskutil info "\$d" 2>/dev/null)
  echo "\$i" | grep -q 'Partition Type:.*EFI' && esp="\$d"
done
if [ -n "\$esp" ]; then
  echo "  ESP = \$esp"
  diskutil unmount "\$esp" 2>&1 | tail -1
  diskutil mount   "\$esp" 2>&1 | tail -1
  ls -d /Volumes/EFI && ls -la /Volumes/EFI/EFI/OC/config.plist | tail -1
  echo "  ↑ 能卸载、能挂载、config 可读 ⇒ EFI 未受影响"
else
  echo "  ★ 没找到 EFI 分区，请手工确认"
fi
EOF
chmod +x "$SCRIPT"
if [ "$(id -u)" = 0 ]; then bash "$SCRIPT"; else
  osascript -e "do shell script \"/bin/bash \\\"$SCRIPT\\\"\" with administrator privileges"; fi
rm -f "$SCRIPT"
