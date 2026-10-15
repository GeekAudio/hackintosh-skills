#!/bin/sh
# cpu-name-check.sh —— CPU 显示名（「关于本机」的处理器名称）体检
#
# 用途：判「显示的 CPU 名对不对」「改名的三个键配齐没有」，并给出判读。
#       配合 references/cpu-name.md 使用。
#
# 用法：
#   ./cpu-name-check.sh                     # 完整体检
#   ./cpu-name-check.sh --name              # 只看名字对照
#   ./cpu-name-check.sh --args              # 只看 rev* 参数
#   ./cpu-name-check.sh /path/to/config.plist   # 额外核对 config（ProcessorType 等）
#
# 依赖：sysctl / system_profiler / nvram（macOS 自带）。config 检查需 python3。
# 退出码：0 正常；1 有可疑项（仅提示）。

set -u

ONLY=""
CONFIG=""
for a in "$@"; do
  case "$a" in
    --name) ONLY=name ;;
    --args) ONLY=args ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "未知参数：$a（-h 看用法）" >&2; exit 2 ;;
    *) CONFIG="$a" ;;
  esac
done

REV_GUID="4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102"
WARN=0

names() {
  echo "=========== 1) 名字对照 ==========="
  pn=$(system_profiler SPHardwareDataType 2>/dev/null | sed -n 's/^ *Processor Name: *//p' | head -1)
  bs=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
  printf '  %-26s = %s\n' "显示的 Processor Name" "${pn:-<空>}"
  printf '  %-26s = %s\n' "CPU 自报 brand_string" "${bs:-<空>}"
  printf '  %-26s = %s\n' "机型 hw.model" "$(sysctl -n hw.model 2>/dev/null)"
  echo
  if [ -n "$pn" ] && [ -n "$bs" ]; then
    if [ "$pn" = "$bs" ]; then
      echo "  ✅ 两者一致 ⇒ 显示名就是 CPU 自报值（未被机型映射改掉）"
    else
      echo "  ⚠ 两者不一致 ⇒ 显示名是按机型映射出来的（cpu-name.md §0）"
      echo "     想改成 brand_string 或自定义名 ⇒ 用 revpatch=cpuname + revcpu=1 + revcpuname"
      WARN=1
    fi
  fi
  # 常见「机型映射」错名特征
  case "$pn" in
    *Xeon*W*) echo "  ★ 典型症状：Xeon W 是 MacPro7,1 的映射名（真 CPU 若是 i7/i9 则明显不符）" ;;
  esac
}

args() {
  echo "=========== 2) rev* 参数（RestrictEvents） ==========="
  ba=$(sysctl -n kern.bootargs 2>/dev/null)
  echo "  -- boot-args 里的 rev* --"
  echo "$ba" | tr ' ' '\n' | grep -E '^-?rev|^revpatch=|^revcpu=|^revcpuname=|^revblock=' | sed 's/^/     /'
  [ -n "$(echo "$ba" | tr ' ' '\n' | grep -E '^rev')" ] || echo "     （无）"

  echo "  -- NVRAM ($REV_GUID) --"
  got=0
  for k in revpatch revcpu revcpuname revblock; do
    # nvram 把不可打印字节打成 %XX；结尾的 %00 是 C 字符串终止符，去掉更可读
    v=$(nvram "$REV_GUID:$k" 2>/dev/null | sed "s/^$REV_GUID:$k[[:space:]]*//" | sed 's/%00$//')
    if [ -n "$v" ]; then printf '     %-12s = %s\n' "$k" "$v"; got=1; fi
  done
  [ "$got" -eq 1 ] || echo "     （无）"

  echo "  -- RestrictEvents 是否加载 --"
  if command -v kmutil >/dev/null 2>&1; then
    if kmutil showloaded --list-only 2>/dev/null | grep -qi RestrictEvents; then
      echo "     ✅ 已加载"
    else
      echo "     ❌ 未加载（或需提权）⇒ 三件套都不会生效"
      WARN=1
    fi
  else
    echo "     kmutil 不可用，跳过"
  fi
  echo
  echo "  ★★ 优先级坑：NVRAM 的 rev* 与 boot-arg 同效，但**优先级更低**"
  echo "     ⇒ boot-args 里若也有 revpatch=…，就**以 boot-args 为准**"
  echo "     ⇒ 想让 cpuname 生效，boot-args 的 revpatch 里**必须也含 cpuname**（cpu-name.md §3）"
  echo "  ★ revcpuname 含空格 ⇒ **只能放 NVRAM**（boot-args 会按空格切碎）（§3.1）"
  echo "  ★ Intel CPU 上 revcpu **默认 0** ⇒ 必须显式 revcpu=1（§2）"
}

cfg() {
  [ -n "$CONFIG" ] || return 0
  echo
  # ★ bash 3.2：`$VAR` 后紧跟全角字符必须写成 `${VAR}`，否则变量名会被吞进去
  echo "=========== 3) config 核对（${CONFIG}） ==========="
  [ -f "$CONFIG" ] || { echo "  找不到该文件，跳过"; return 0; }
  python3 - "$CONFIG" <<'PY'
import sys, plistlib
d = plistlib.load(open(sys.argv[1], "rb"))
pi = d.get("PlatformInfo", {})
g  = pi.get("Generic", {}) or {}
pt = g.get("ProcessorType", "<缺>")
print(f"  PlatformInfo>Generic>ProcessorType = {pt}")
try:
    pt = int(pt)
    n = 0x0F01 if pt == 0x0F01 else (0x0601 if pt == 0x0601 else None)
    if n == 0x0F01:
        print("     ✓ 0x0F01 = 8 核及以上（官方要求，见 cpu-name.md §5）")
    elif n == 0x0601:
        print("     ✓ 0x0601 = 1/2/4/6 核（官方要求）")
    else:
        print("     ⚠ 不是 0x0F01 / 0x0601 ⇒ 可能导致 CPU 图标 / 核数显示异常")
except Exception:
    pass
print(f"  SystemProductName = {g.get('SystemProductName','<缺>')}")
ba = ""
for guid, dd in (d.get("NVRAM", {}).get("Add", {}) or {}).items():
    if isinstance(dd, dict) and "boot-args" in dd:
        ba = dd["boot-args"]
toks = ba.split()
has = lambda t: any(x == t or x.startswith(t) for x in toks)
print(f"  boot-args 含 revpatch=cpuname : {'✓' if has('revpatch=cpuname') or any(x.startswith('revpatch=') and 'cpuname' in x for x in toks) else '✗ 缺'}")
print(f"  boot-args 含 revcpu=1         : {'✓' if 'revcpu=1' in toks else '✗ 缺（Intel 默认 0）'}")
nvr = d.get("NVRAM", {}).get("Add", {}).get("4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102", {}) or {}
rn = nvr.get("revcpuname")
print(f"  NVRAM revcpuname              : {rn if rn else '（无）'}" + (f"  [{len(rn)} 字符，上限 48]" if rn else ""))
# Delete 里是否也列了这些键
dl = d.get("NVRAM", {}).get("Delete", {}).get("4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102", []) or []
print(f"  NVRAM>Delete 是否列出 rev* 键 : {dl if dl else '（空 ⇒ Add 的键可能不生效）'}")
PY
}

verdict() {
  echo
  echo "=========== 4) 判读 ==========="
  echo "  名字不一致 且 想改 ⇒ 三件套缺一不可："
  echo "    revpatch=cpuname（boot-args） + revcpu=1（boot-args） + revcpuname=<名>（NVRAM）"
  echo "  ★ 改完必须重启；★ 别忘了 NVRAM>Delete 也要有这些键"
  echo "  ★ 这是纯外观改动，不影响性能 —— 不在意就别改（cpu-name.md §0）"
}

case "$ONLY" in
  name) names ;;
  args) args ;;
  *)    names; args; cfg; verdict ;;
esac

[ "$WARN" -eq 0 ] || exit 1
exit 0
