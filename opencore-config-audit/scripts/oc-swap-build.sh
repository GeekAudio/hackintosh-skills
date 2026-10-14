#!/bin/bash
# 把 ESP 上的 OpenCore 换成同版本的另一个构建（RELEASE <-> DEBUG）
#
# 用法: oc-swap-build.sh <debug|release> [版本号] [--efi <EFI 根目录>] [--yes]
#   版本号省略时从 NVRAM 推断：DBG-108-2026-09-27 → 1.0.8 / 1.0.8-2026-09-27 → 1.0.8
#   默认 EFI 根目录 = /Volumes/EFI/EFI
#
# 为什么必须连 Drivers 一起换：同版本下 RELEASE 与 DEBUG 的**所有** Drivers 内容都不同
#   （例 1.0.8：OpenRuntime.efi 24,576 → 36,864；OpenCanopy.efi 114,688 → 151,552）
#   只换 OpenCore.efi 会得到「构建混搭」的引导器。
# 只替换**官方同名**驱动，第三方驱动（如驱动安装 App 放的 NullMothLogo.efi）保持不动。
set -u

TARGET="${1:?用法: oc-swap-build.sh <debug|release> [版本号] [--efi <EFI 根目录>] [--yes]}"
shift
VER=""; EFIROOT="/Volumes/EFI/EFI"; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --efi) EFIROOT="${2:-}"; shift;;
    --yes) YES=1;;
    *) [ -z "$VER" ] && VER="$1";;
  esac
  shift
done
case "$TARGET" in debug|DEBUG) TARGET=debug; KIND=DEBUG;; release|RELEASE) TARGET=release; KIND=RELEASE;; *) echo "目标只能是 debug 或 release"; exit 2;; esac

# ---------- 1) 版本与当前构建 ----------
CUR=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null | awk '{print $2}')
echo "== 1) 现状 =="
echo "   NVRAM opencore-version : ${CUR:-<读不到>}"
CURKIND="未知"
case "$CUR" in DBG-*) CURKIND=DEBUG;; ""|-*) CURKIND=未知;; *) CURKIND=RELEASE;; esac
if [ -z "$VER" ]; then
  # DBG-108-2026-09-27 → 108 → 1.0.8
  N=$(printf '%s' "$CUR" | sed -n 's/^DBG-\([0-9][0-9]*\)-.*/\1/p')
  [ -n "$N" ] || N=$(printf '%s' "$CUR" | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p')
  if [ -n "$N" ] && [ ${#N} -ge 3 ]; then
    VER="$(printf '%s' "$N" | cut -c1).$(printf '%s' "$N" | cut -c2).$(printf '%s' "$N" | cut -c3-)"
  fi
fi
[ -n "$VER" ] || { echo "   ★ 推断不出版本号，请显式给出，例如: oc-swap-build.sh $TARGET 1.0.8"; exit 2; }
echo "   版本 : $VER      当前构建 : $CURKIND      目标构建 : $KIND"
if [ "$CURKIND" = "$KIND" ]; then echo; echo "== 已经是 ${KIND}，无需切换。=="; exit 0; fi

# ---------- 2) 取官方包 ----------
WORK="${PWD}/_oc-build-swap"; mkdir -p "$WORK"; cd "$WORK"
ZIP="OpenCore-$VER-$KIND.zip"
echo
echo "== 2) 取官方 ${KIND} 包（OpenCore-${VER}）=="
[ -f "$ZIP" ] || curl -sSL --max-time 300 \
  "https://github.com/acidanthera/OpenCorePkg/releases/download/$VER/$ZIP" -o "$ZIP"
ls -la "$ZIP"
rm -rf "src"; unzip -oq "$ZIP" -d src
SRC="src/X64/EFI"
[ -f "$SRC/OC/OpenCore.efi" ] || { echo "   ★ 包里没找到 $SRC/OC/OpenCore.efi，版本号对吗？"; exit 1; }

# ---------- 3) 校验 ESP ----------
OC="$EFIROOT/OC"; BOOT="$EFIROOT/BOOT"
[ -f "$OC/OpenCore.efi" ] || { echo "   ★ 找不到 $OC/OpenCore.efi（ESP 挂载了吗？）"; exit 1; }
ESP_DEV=""; MP=$(df -P "$OC/OpenCore.efi" | awk 'NR==2{print $NF}')
case "$MP" in
  /Volumes/*) INFO=$(diskutil info "$MP" 2>/dev/null || true)
              printf '%s\n' "$INFO" | grep -q 'Partition Type:.*EFI' && ESP_DEV=$(printf '%s\n' "$INFO" | awk -F': *' '/Device Identifier/{print $2}');;
esac

# ---------- 4) 备份 ----------
TS=$(date +%Y%m%d-%H%M%S); BK="${PWD}/_oc-build-backup-$TS"
echo
echo "== 3) 备份到 $BK =="
mkdir -p "$BK/OC" "$BK/BOOT" "$BK/Drivers"
cp -p "$OC/OpenCore.efi" "$BK/OC/" 2>/dev/null && echo "   OpenCore.efi"
cp -p "$BOOT/bootx64.efi" "$BK/BOOT/" 2>/dev/null && echo "   BOOT/bootx64.efi"
cp -pR "$OC/Drivers/." "$BK/Drivers/" 2>/dev/null && echo "   Drivers/（$(ls "$OC/Drivers" | wc -l | tr -d ' ') 个文件）"

# ---------- 5) 替换 ----------
echo
echo "== 4) 替换 =="
if [ "$YES" != 1 ]; then
  printf "   将把 %s 的 OpenCore.efi / BOOTx64.efi / 官方同名 Drivers 换成 $KIND 版。继续？[y/N] " "$EFIROOT"
  read -r a; case "$a" in y|Y) ;; *) echo "   已取消"; exit 0;; esac
fi
cp -p "$SRC/OC/OpenCore.efi" "$OC/OpenCore.efi" && echo "   OC/OpenCore.efi"
[ -f "$SRC/BOOT/BOOTx64.efi" ] && cp -p "$SRC/BOOT/BOOTx64.efi" "$BOOT/bootx64.efi" && echo "   BOOT/bootx64.efi"
for f in "$SRC/OC/Drivers"/*; do
  n=$(basename "$f")
  [ -f "$OC/Drivers/$n" ] || continue          # 只换 ESP 上已有的
  cp -p "$f" "$OC/Drivers/$n" && echo "   Drivers/$n"
done
echo "   （保留第三方驱动：$(ls "$OC/Drivers" | while read -r n; do [ -f "$SRC/OC/Drivers/$n" ] || printf '%s ' "$n"; done)）"

# ---------- 6) 校验 ----------
echo
echo "== 5) 校验（sha 必须与官方包一致）=="
rc=0
for rel in OC/OpenCore.efi BOOT/BOOTx64.efi; do
  a=$(shasum -a 256 "$EFIROOT/$rel" 2>/dev/null | awk '{print $1}')
  b=$(shasum -a 256 "$SRC/$rel" 2>/dev/null | awk '{print $1}')
  if [ "$a" = "$b" ]; then echo "   ✓ $rel  $a"; else echo "   ★ $rel 不一致"; rc=1; fi
done
for f in "$SRC/OC/Drivers"/*; do
  n=$(basename "$f"); [ -f "$OC/Drivers/$n" ] || continue
  a=$(shasum -a 256 "$OC/Drivers/$n" | awk '{print $1}'); b=$(shasum -a 256 "$f" | awk '{print $1}')
  [ "$a" = "$b" ] || { echo "   ★ Drivers/$n 不一致"; rc=1; }
done
[ $rc -eq 0 ] && echo "   全部一致 ✓"

# ---------- 7) 落盘 + 重启提示 ----------
echo
echo "== 6) 落盘（sync → 卸载 → 重挂）=="
sync
if [ -n "$ESP_DEV" ]; then
  diskutil unmount "$ESP_DEV" >/dev/null 2>&1 || true
  diskutil mount   "$ESP_DEV" >/dev/null 2>&1 || \
    osascript -e "do shell script \"diskutil mount $ESP_DEV\" with administrator privileges" >/dev/null 2>&1 || true
  shasum -a 256 "$OC/OpenCore.efi" | sed 's/^/   重挂后 OpenCore.efi: /'
fi

echo
echo "== 完成。重启后才生效，重启后验证： =="
echo "   nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version    # 期望 $([ "$TARGET" = debug ] && echo "DBG-$VER-*" || echo "$VER-*")"
echo "   shasum -a 256 $OC/OpenCore.efi"
echo "   回滚：cp -pR \"$BK/.\" \"$EFIROOT/\""
if [ "$TARGET" = release ]; then
  cat <<'TIP'

== 切到 RELEASE 通常还要「关掉 debug 日志」（日常使用态）==
   （先用本 skill 的 oc-edit-safe.sh begin，再执行下面几条，最后 finish）
   plutil -replace 'Misc.Debug.Target'        -integer 3          <config>   # 只留 记录+控制台；不再往 ESP 写日志
   plutil -replace 'Misc.Debug.DisplayLevel'  -integer 2147483650 <config>   # 0x80000002 = ERROR+WARN
   plutil -replace 'Misc.Debug.AppleDebug'    -bool false         <config>
   plutil -replace 'Misc.Debug.ApplePanic'    -bool false         <config>   # 想保留 panic 落盘就设 true
   plutil -replace 'Misc.Debug.DisableWatchDog' -bool false       <config>
   plutil -replace 'Misc.Debug.SysReport'     -bool false         <config>   # RELEASE 下本来就无效
   以上即 OpenCore 官方 Sample.plist 的默认值。
   ★ boot-args 的 -v 要不要留，必须问用户，不要自己决定（见 lifecycle.md 阶段⑥）。
TIP
fi
