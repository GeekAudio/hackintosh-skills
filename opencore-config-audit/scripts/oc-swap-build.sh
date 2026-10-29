#!/bin/bash
# 把指定 EFI 的 OpenCore 换成同版本的另一个构建（RELEASE <-> DEBUG）。
# 用法: oc-swap-build.sh <debug|release> <目标版本号> [--efi <EFI 根目录>] [--yes]
# 版本必须由目标 EFI 的记录/日志确认后显式给出；不使用宿主 NVRAM 猜测离线目标。
# 默认 EFI 根目录 = /Volumes/EFI/EFI；只替换目标已有的官方同名 Drivers。
set -euo pipefail

TARGET="${1:?用法: oc-swap-build.sh <debug|release> <目标版本号> [--efi <EFI 根目录>] [--yes]}"
shift
VER=""; EFIROOT="/Volumes/EFI/EFI"; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --efi)
      case "${2:-}" in ""|--*) echo "--efi 缺少目录" >&2; exit 2;; esac
      EFIROOT="$2"; shift 2;;
    --yes) YES=1; shift;;
    -*) echo "未知参数: $1" >&2; exit 2;;
    *) [ -z "$VER" ] || { echo "只能指定一个版本号" >&2; exit 2; }; VER="$1"; shift;;
  esac
done
case "$TARGET" in debug|DEBUG) TARGET=debug; KIND=DEBUG;; release|RELEASE) TARGET=release; KIND=RELEASE;; *) echo "目标只能是 debug 或 release"; exit 2;; esac
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "请显式给出经目标 EFI 确认的版本号，例如 1.0.8；不从宿主 NVRAM 推断" >&2; exit 2; }
[ -f "$EFIROOT/OC/OpenCore.efi" ] || { echo "找不到 $EFIROOT/OC/OpenCore.efi" >&2; exit 2; }
EFIROOT="$(cd "$EFIROOT" && pwd -P)"
OC="$EFIROOT/OC"
BK=""; BACKUP_READY=0; CHANGED=0
fail() {
  echo "★ $*" >&2
  if [ "$BACKUP_READY" = 1 ]; then
    echo "  已替换 $CHANGED 项；保留备份 ${BK}，请先恢复并校验再重启。" >&2
    echo "  回滚：cp -pR \"$BK/.\" \"$EFIROOT/\"" >&2
  else
    echo "  尚未开始替换目标；备份未完成。" >&2
  fi
  exit 1
}
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
echo "== 目标 EFI: $EFIROOT =="
echo "   目标版本（显式指定）: $VER    目标构建: $KIND"
echo "   当前目标 OpenCore SHA: $(sha "$OC/OpenCore.efi")"

WORK="${PWD}/_oc-build-swap"; mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd -P)"
ZIP="$WORK/OpenCore-$VER-$KIND.zip"
if [ ! -f "$ZIP" ]; then
  DOWNLOAD=$(mktemp "$WORK/.download.XXXXXX")
  if ! curl -fsSL --max-time 300 "https://github.com/acidanthera/OpenCorePkg/releases/download/$VER/OpenCore-$VER-$KIND.zip" -o "$DOWNLOAD"; then
    rm -f "$DOWNLOAD"; fail "官方包下载失败"
  fi
  mv "$DOWNLOAD" "$ZIP"
fi
STAGE=$(mktemp -d "$WORK/_oc-build-src.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
unzip -oq "$ZIP" -d "$STAGE" || fail "官方包解压失败"
SRC="$STAGE/X64/EFI"
[ -f "$SRC/OC/OpenCore.efi" ] && [ -f "$SRC/BOOT/BOOTx64.efi" ] || fail "官方包缺少 OpenCore/BOOT 文件"

# 备份、替换、校验共用相同的目标相对路径。缺少目标 BOOT 时不新增文件，
# 从而回滚仅需恢复原有文件。第三方 Drivers 不进入替换清单。
RELS=("OC/OpenCore.efi")
if [ -f "$EFIROOT/BOOT/BOOTx64.efi" ]; then
  RELS[${#RELS[@]}]="BOOT/BOOTx64.efi"
elif [ -f "$EFIROOT/BOOT/bootx64.efi" ]; then
  RELS[${#RELS[@]}]="BOOT/bootx64.efi"
fi
for file in "$SRC/OC/Drivers"/*; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  [ ! -f "$OC/Drivers/$name" ] || RELS[${#RELS[@]}]="OC/Drivers/$name"
done
source_file() {
  case "$1" in BOOT/*) printf '%s\n' "$SRC/BOOT/BOOTx64.efi";; *) printf '%s\n' "$SRC/$1";; esac
}
for rel in "${RELS[@]}"; do
  [ ! -L "$EFIROOT/$rel" ] || fail "目标 $rel 是符号链接，拒绝写入目标目录以外的文件"
  TARGET_DIR=$(cd "$(dirname "$EFIROOT/$rel")" && pwd -P)
  case "$TARGET_DIR/" in "$EFIROOT"/*) ;; *) fail "目标 $rel 的目录链接超出指定 EFI，拒绝替换";; esac
done
if [ "$YES" != 1 ]; then
  printf '将替换 %s 中 %d 个文件为 %s %s。继续？[y/N] ' "$EFIROOT" "${#RELS[@]}" "$VER" "$KIND"
  read -r answer || answer=""
  case "$answer" in y|Y) ;; *) echo "已取消"; exit 0;; esac
fi

BK=$(mktemp -d "$WORK/_oc-build-backup-$(date +%Y%m%d-%H%M%S).XXXXXX")
BASES=(); EXPECTED=()
for rel in "${RELS[@]}"; do
  BASE=$(sha "$EFIROOT/$rel") || fail "无法读取目标 $rel"
  EXPECT=$(sha "$(source_file "$rel")") || fail "无法读取源文件 $rel"
  mkdir -p "$BK/$(dirname "$rel")"
  cp -p "$EFIROOT/$rel" "$BK/$rel" || fail "备份 $rel 失败"
  SAVED=$(sha "$BK/$rel") || fail "无法读取备份 $rel"
  [ "$SAVED" = "$BASE" ] || fail "备份 $rel SHA 不一致"
  BASES[${#BASES[@]}]="$BASE"; EXPECTED[${#EXPECTED[@]}]="$EXPECT"
done
BACKUP_READY=1
echo "== 完整备份: $BK =="
for ((i=0; i<${#RELS[@]}; i++)); do
  CURRENT=$(sha "$EFIROOT/${RELS[$i]}") || fail "无法复读目标 ${RELS[$i]}"
  [ "$CURRENT" = "${BASES[$i]}" ] || fail "备份后目标 ${RELS[$i]} 被修改，停止替换"
done
for rel in "${RELS[@]}"; do
  cp -p "$(source_file "$rel")" "$EFIROOT/$rel" || fail "替换 $rel 失败（可能部分写入）"
  CHANGED=$((CHANGED+1)); echo "   已替换 $rel"
done
verify_target() {
  local i actual
  for ((i=0; i<${#RELS[@]}; i++)); do
    actual=$(sha "$EFIROOT/${RELS[$i]}") || fail "无法校验 ${RELS[$i]}"
    [ "$actual" = "${EXPECTED[$i]}" ] || fail "${RELS[$i]} SHA 与官方包不一致"
  done
}
verify_target
sync || fail "sync 失败"
ESP_DEV=""; MP=$(df -P "$OC/OpenCore.efi" | awk 'NR==2{print $NF}')
case "$MP" in
  /Volumes/*)
    INFO=$(diskutil info "$MP" 2>/dev/null || true)
    if printf '%s\n' "$INFO" | grep -q 'Partition Type:.*EFI'; then
      ESP_DEV=$(printf '%s\n' "$INFO" | awk -F': *' '/Device Identifier/{print $2}')
    fi;;
esac
if [ -n "$ESP_DEV" ]; then
  diskutil unmount "$ESP_DEV" || fail "卸载 ${ESP_DEV} 失败，未完成落盘复验"
  diskutil mount "$ESP_DEV" || fail "重挂 ${ESP_DEV} 失败，请先挂回并检查备份"
  verify_target
fi
echo "== 完成：全部 ${#RELS[@]} 项 SHA 与官方包一致 =="
echo "   回滚：cp -pR \"$BK/.\" \"$EFIROOT/\""
echo "   回滚后逐项核对上述目标文件与备份的 SHA；未通过前不要重启。"
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
