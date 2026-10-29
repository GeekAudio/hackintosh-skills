#!/bin/bash
# 用 fstab noauto 屏蔽非系统、非 EFI、非 APFS 卷；保留用户原有规则。
# 用法：mask-other-disks.sh [--apply | --undo] [--keep <卷 UUID> ...]
# 默认只打印计划；--apply 需 root 并卸载选中卷；--undo 只删除本工具的 managed block。
# 未带本工具标记的旧规则不会自动删除，请核对旧备份后手工处理。
set -euo pipefail

APPLY=0; UNDO=0; KEEP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift;;
    --undo) UNDO=1; shift;;
    --keep)
      [[ "${2:-}" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] || { echo "--keep 需要完整卷 UUID" >&2; exit 2; }
      KEEP="$KEEP $(printf '%s' "$2" | tr 'a-f' 'A-F')"; shift 2;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# *//'; exit 0;;
    *) echo "未知参数: $1" >&2; exit 2;;
  esac
done
[ "$APPLY" -eq 0 ] || [ "$UNDO" -eq 0 ] || { echo "--apply 和 --undo 不能同时使用" >&2; exit 2; }
FSTAB=/etc/fstab
PY="${PYTHON:-python3}"
WORK=$(mktemp -d)
PENDING=""
cleanup() { rm -rf "$WORK"; [ -z "$PENDING" ] || rm -f "$PENDING"; }
trap cleanup EXIT
fail() { echo "★ $*" >&2; exit 1; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
TARGETS="$WORK/targets.tsv"; : > "$TARGETS"
EXISTED=0
if [ -e "$FSTAB" ]; then
  [ -f "$FSTAB" ] && [ ! -L "$FSTAB" ] || fail "fstab 不是普通文件，拒绝替换"
  cp -p "$FSTAB" "$WORK/original" || fail "无法读取原 fstab"
  ORIGINAL=$(sha "$WORK/original") || fail "无法校验原 fstab"
  EXISTED=1
else
  : > "$WORK/original"; ORIGINAL=""
fi

if [ "$UNDO" = 0 ]; then
  diskutil list > "$WORK/disks" || fail "无法枚举磁盘"
  grep -oE 'disk[0-9]+s[0-9]+' "$WORK/disks" | sort -u > "$WORK/devices" || true
  echo "== 非系统、非 EFI、非 APFS 卷的计划 =="
  while IFS= read -r dev; do
    info=$(diskutil info "$dev" 2>/dev/null) || fail "无法检查 ${dev}，未写入规则"
    uuid=$(printf '%s\n' "$info" | awk -F': *' '/Volume UUID/{print $2}')
    name=$(printf '%s\n' "$info" | awk -F': *' '/Volume Name/{print $2}')
    fs=$(printf '%s\n' "$info" | awk -F': *' '/File System Personality/{print $2}')
    ptype=$(printf '%s\n' "$info" | awk -F': *' '/Partition Type/{print $2}')
    mp=$(printf '%s\n' "$info" | awk -F': *' '/Mount Point/{print $2}')
    [ -n "$uuid" ] || continue
    [[ "$uuid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] || fail "$dev 的卷 UUID 不合法"
    uuid=$(printf '%s' "$uuid" | tr 'a-f' 'A-F')
    [ "$ptype" != EFI ] || { echo "   skip $dev EFI"; continue; }
    case "$mp" in /|/System/*) echo "   skip $dev 系统挂载点"; continue;; esac
    case "$fs" in *APFS*) echo "   skip $dev APFS（保守保留）"; continue;; esac
    case " $KEEP " in *" $uuid "*) echo "   keep $dev $name"; continue;; esac
    # fstab 第三字段必须是文件系统类型，不能直接放带空格的显示名称。
    case "$fs" in
      NTFS|*NTFS*) fs=ntfs;; ExFAT|exfat) fs=exfat;; MS-DOS*|FAT*|msdos) fs=msdos;; *HFS*|hfs) fs=hfs;;
      *) echo "   skip $dev 未支持的文件系统: $fs"; continue;;
    esac
    name=$(printf '%s' "${name:-unnamed}" | tr '\t\r\n' '   ')
    printf '%s\t%s\t%s\t%s\n' "$uuid" "$dev" "$fs" "$name" >> "$TARGETS"
    printf '   MASK %s %s (%s)\n' "$dev" "$name" "$uuid"
  done < "$WORK/devices"
fi

# 按完整标记行移除/替换本工具区块；其余字节保留，标记损坏时拒绝写入。
"$PY" - "$WORK/original" "$TARGETS" "$WORK/merged" "$UNDO" <<'PY'
from pathlib import Path
import sys
original, targets, destination, undo = sys.argv[1:]
begin = b"# BEGIN opencore-config-audit mask-other-disks"
end = b"# END opencore-config-audit mask-other-disks"
keep = []; inside = False; found = False
for line in Path(original).read_bytes().splitlines(keepends=True):
    marker = line.rstrip(b"\r\n")
    if marker == begin:
        if inside or found: raise SystemExit("fstab managed block 重复/嵌套，拒绝修改")
        inside = True; found = True
    elif marker == end:
        if not inside: raise SystemExit("fstab managed block 结束标记孤立，拒绝修改")
        inside = False
    elif not inside:
        keep.append(line)
if inside: raise SystemExit("fstab managed block 缺少结束标记，拒绝修改")
result = b"".join(keep)
rows = Path(targets).read_text().splitlines()
if undo == "0" and rows:
    if result and not result.endswith(b"\n"): result += b"\n"
    result += begin + b"\n"
    for row in rows:
        uuid, dev, fs, name = row.split("\t", 3)
        result += f"UUID={uuid} none {fs} noauto   # {name} ({dev})\n".encode()
    result += end + b"\n"
Path(destination).write_bytes(result)
PY

if cmp -s "$WORK/original" "$WORK/merged"; then
  echo "== 规则没有变化；未写入或卸载任何卷 =="
  exit 0
fi
echo "== 合并后的 fstab（用户规则保留）=="
cat "$WORK/merged"
if [ "$APPLY" = 0 ] && [ "$UNDO" = 0 ]; then
  echo "== dry-run：未写入 fstab、未卸载卷；确认后用 sudo bash \"$0\" --apply =="
  exit 0
fi
[ "$(id -u)" = 0 ] || { echo "写入 fstab 需要 root；请用 sudo 运行同一命令" >&2; exit 2; }

if [ "$EXISTED" = 1 ]; then
  [ -f "$FSTAB" ] && [ ! -L "$FSTAB" ] || fail "计划后 fstab 类型变化，停止"
  NOW=$(sha "$FSTAB") || fail "无法复读 fstab"
  [ "$NOW" = "$ORIGINAL" ] || fail "计划后 fstab 被修改，停止以保留其他修改"
  BACKUP=$(mktemp "${FSTAB}.oc-mask-backup.XXXXXX")
  cp -p "$FSTAB" "$BACKUP" || fail "fstab 备份失败，未写入"
  SAVED=$(sha "$BACKUP") || fail "fstab 备份不可读"
  [ "$SAVED" = "$ORIGINAL" ] || fail "fstab 备份 SHA 不一致，未写入"
  echo "   备份: $BACKUP"
else
  [ ! -e "$FSTAB" ] || fail "计划后新出现 fstab，停止以保留它"
fi
PENDING=$(mktemp "${FSTAB}.oc-mask-new.XXXXXX")
cp "$WORK/merged" "$PENDING" || fail "fstab 临时文件写入失败"
chmod 644 "$PENDING"; chown root:wheel "$PENDING"
# 在原子替换前再次检查，避免备份/准备期间覆盖其他修改。
if [ "$EXISTED" = 1 ]; then
  [ "$(sha "$FSTAB")" = "$ORIGINAL" ] || fail "写入前 fstab 被修改，停止"
else
  [ ! -e "$FSTAB" ] || fail "写入前新出现 fstab，停止"
fi
mv -f "$PENDING" "$FSTAB" || fail "fstab 替换失败"
PENDING=""
[ "$(sha "$FSTAB")" = "$(sha "$WORK/merged")" ] || fail "写入后的 fstab SHA 不一致"
sync || fail "fstab 已写入，但 sync 失败"
if [ "$UNDO" = 1 ]; then
  echo "== 已仅删除本工具区块；其他 fstab 规则保留，未卸载任何卷 =="
  exit 0
fi

# 不执行动态子脚本，不重挂任意 ESP。仅重新核对选中卷的 UUID 后卸载。
while IFS=$'\t' read -r uuid dev fs name; do
  info=$(diskutil info "$dev" 2>/dev/null) || fail "规则已写入，但无法复核 ${dev}；未继续卸载"
  actual=$(printf '%s\n' "$info" | awk -F': *' '/Volume UUID/{print $2}' | tr 'a-f' 'A-F')
  [ "$actual" = "$uuid" ] || fail "规则已写入，但 $dev 的 UUID 已变化；未继续卸载"
  if printf '%s\n' "$info" | grep -q 'Partition Type:.*EFI'; then fail "复核发现 $dev 是 EFI，拒绝卸载"; fi
  if printf '%s\n' "$info" | grep -q 'Mounted:.*No'; then continue; fi
  diskutil unmount "$dev" || fail "规则已写入，但卸载 $dev 失败；请核对部分完成状态"
done < "$TARGETS"
echo "== managed block 已写入，选中卷已卸载；EFI/APFS 卷未操作 =="
