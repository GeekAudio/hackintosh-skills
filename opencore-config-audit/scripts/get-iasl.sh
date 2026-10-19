#!/bin/bash
# 取 iasl（ACPI 编译器）—— macOS 走 ACPICA 源码编译
#
# 用法: get-iasl.sh [版本|latest] [安装目录]
#   版本       ACPICA release tag，如 20260930；省略或 latest = 取最新
#   安装目录   默认 $HOME/bin
#
# ★ 为什么不用 ACPICA release 页上的预编译 iasl：实测那是 Linux ELF（interpreter
#   /lib64/ld-linux-x86-64.so.2），macOS 跑不了。详见 references/toolchain.md §3.1
# ★ 只读源码 + 编译，不碰系统目录；产物只落在安装目录。
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/opt/local/bin:${PATH:-}"

VER="${1:-latest}"
DEST="${2:-$HOME/bin}"
REPO="open-acpica/acpica"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "缺 curl" >&2; exit 2; }
command -v make >/dev/null 2>&1 || {
  echo "★ 缺 make ⇒ 先装 Xcode Command Line Tools：xcode-select --install" >&2; exit 2; }
XCDEV="$(xcode-select -p 2>/dev/null || true)"
[ -n "$XCDEV" ] && [ -d "$XCDEV" ] || {
  echo "★ 需要 Xcode Command Line Tools：xcode-select --install" >&2; exit 2; }

if [ "$VER" = "latest" ]; then
  echo "== 查 ACPICA 最新版本 =="
  VER="$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["tag_name"])' 2>/dev/null || true)"
  if [ -z "$VER" ]; then
    echo "★ 取最新版本失败（多半是 API 限流）⇒ 手动指定版本：$0 20260930" >&2
    echo "  可用版本见 https://github.com/$REPO/releases" >&2
    exit 1
  fi
fi
echo "   版本: $VER"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

URL="https://github.com/$REPO/releases/download/$VER/acpica-unix-$VER.tar.gz"
echo "== 下载源码 =="
echo "   $URL"
curl -fL --retry 2 -o "$WORK/src.tar.gz" "$URL" || {
  echo "★ 下载失败（版本号不存在 / 网络不通）" >&2; exit 1; }

echo "== 解压 =="
tar xzf "$WORK/src.tar.gz" -C "$WORK"
SRC="$WORK/acpica-unix-$VER"
if [ ! -d "$SRC" ]; then
  SRC="$(ls -d "$WORK"/acpica-unix-* 2>/dev/null | head -1 || true)"
fi
[ -n "$SRC" ] && [ -d "$SRC" ] || { echo "★ 解压后找不到源码目录" >&2; exit 1; }

echo "== 编译 iasl（官方 README 的 macOS 参数）=="
if ! ( cd "$SRC" && CFLAGS="-mmacosx-version-min=10.7 -O3" LDFLAGS="-mmacosx-version-min=10.7" \
       make iasl -j "$(getconf _NPROCESSORS_ONLN)" >"$WORK/build.log" 2>&1 ); then
  echo "★ 编译失败，日志末尾：" >&2
  tail -20 "$WORK/build.log" >&2
  exit 1
fi

BIN="$SRC/generate/unix/bin/iasl"
[ -x "$BIN" ] || { echo "★ 没有生成 $BIN" >&2; exit 1; }

echo "== 校验产物 =="
if ! file "$BIN" | grep -q "Mach-O"; then
  echo "★ 产物不是 Mach-O（编译环境异常）：" >&2
  file "$BIN" >&2
  exit 1
fi
"$BIN" -v | head -3

mkdir -p "$DEST"
cp "$BIN" "$DEST/iasl"
chmod +x "$DEST/iasl"

echo
echo "== 安装完成 =="
echo "   路径:   $DEST/iasl"
echo "   版本:   $("$DEST/iasl" -v 2>&1 | grep -i 'compiler/disassembler version' | head -1 || true)"
echo "   sha256: $(shasum -a 256 "$DEST/iasl" | cut -d' ' -f1)"
case ":$PATH:" in
  *":$DEST:"*) echo "   PATH:   已包含 $DEST" ;;
  *) echo "   ★ PATH 里没有 $DEST ⇒ 加到 ~/.zshrc：export PATH=\"\$HOME/bin:\$PATH\"" ;;
esac
echo
echo "★ 验证编译链：iasl -p out.aml in.dsl   →   反编译回读：iasl -d out.aml"
echo "★ 判据与报错对照见 references/acpi-ssdt.md §6"
