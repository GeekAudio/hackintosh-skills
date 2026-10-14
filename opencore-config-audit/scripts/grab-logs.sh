#!/bin/bash
# 抓引导期证据：OpenCore 自己的日志 + 本次开机内核日志（ACPI / 平台设备）
#
# 用法: grab-logs.sh [输出目录] [--oc-only]     默认 ./_oc-logs
#   --oc-only  只抓 OpenCore 日志（不需要 root；便于先看一眼）
#   内核日志部分需要 root；非 root 时会自动走提权 AppleScript（会弹密码）
set -u

OUT="./_oc-logs"; OC_ONLY=0
for a in "$@"; do
  case "$a" in
    --oc-only) OC_ONLY=1;;
    *) OUT="$a";;
  esac
done
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

# ---------- 1) OpenCore 引导日志 ----------
echo "== 1) OpenCore 引导日志（ESP 根目录 opencore-*.txt，需 Target 含 0x40）=="
: > "$OUT/oc-boot-log-summary.txt"
FOUND=0
for esp in /Volumes/*/; do
  for f in "$esp"opencore-*.txt; do
    [ -f "$f" ] || continue
    FOUND=1
    echo "--- $f  ($(stat -f %z "$f") B) ---" >> "$OUT/oc-boot-log-summary.txt"
    grep -aE "OpenCore .*(loading|is loading)|OCABC:|OCA: (Found|Deleting|Inserted)|OCJS: APFS driver|OCB: Registering entry|OCB: Not adding hidden|OC: (WARN|ERROR)|OCB: ERROR|OCAU: [0-9]" "$f" \
      | cut -c1-190 >> "$OUT/oc-boot-log-summary.txt" 2>/dev/null
    cp -p "$f" "$OUT/" 2>/dev/null || true
  done
done
if [ "$FOUND" = 0 ]; then
  echo "   没找到 opencore-*.txt。可能原因：" | tee -a "$OUT/oc-boot-log-summary.txt"
  echo "   - Misc>Debug>Target 不含 0x40（不写文件）" | tee -a "$OUT/oc-boot-log-summary.txt"
  echo "   - ESP 没挂载（ls -d /Volumes/EFI）" | tee -a "$OUT/oc-boot-log-summary.txt"
  echo "   兜底读法（Target 含 0x04 即可）：" | tee -a "$OUT/oc-boot-log-summary.txt"
  echo "   ioreg -lw0 -p IODeviceTree | grep boot-log | sort | sed 's/.*<\\(.*\\)>.*/\\1/' | xxd -r -p" | tee -a "$OUT/oc-boot-log-summary.txt"
else
  echo "   → $OUT/oc-boot-log-summary.txt"
fi

# ---------- 2) 本次开机内核日志 ----------
if [ "$OC_ONLY" = 1 ]; then
  echo
  echo "(--oc-only：跳过了内核日志部分)"
  echo "== 完成 =="; ls -la "$OUT"; exit 0
fi

BOOT=$(sysctl -n kern.boottime 2>/dev/null | sed -n 's/.*sec = \([0-9]*\).*/\1/p')
START=$(date -r "${BOOT:-0}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
echo
echo "== 2) 本次开机内核日志（开机时间 ${START:-未知}）=="

SCRIPT="$OUT/_grab-kernel.sh"
cat > "$SCRIPT" <<EOF
#!/bin/bash
OUT="$OUT/kernel-log-acpi.txt"
{
  echo "=== 抓取时间 ==="; date
  echo "=== 开机时间 ==="; sysctl -n kern.boottime
  echo
  echo "=== A) ACPI 报错（0 命中 = ACPI 没坏）==="
  /usr/bin/log show --start "$START" --style compact 2>&1 \
    | grep -aiE "acpi error|ae_not_found|ae_already|ae_error|namespace lookup|ACPI Exception|Error evaluating" | head -40
  echo
  echo "=== B) macOS 解析到的 ACPI 表 ==="
  /usr/bin/log show --start "$START" --style compact 2>&1 \
    | grep -a "AppleACPIPlatform" | grep -aE "FACP|FACS|DSDT|XSDT|RSDT|RSDP|MCFG|HPET|APIC|SSDT|DMAR|BGRT|WSMT" | sort -u | head -40
  echo
  echo "=== C) 平台设备 / 驱动挂载 ==="
  /usr/bin/log show --start "$START" --style compact --predicate 'process == "kernel"' 2>&1 \
    | grep -aiE "smbus|AppleSMBus|hpet|AppleRTC|GPRW|GPE |xhci|AppleUSB|igc|I225|AppleIntelPCH|SATA|AHCI|COMRESET|AppleHDAController|AppleSMC|Previous shutdown cause" | head -80
  echo
  echo "=== D) ACPI 平面设备存在性 ==="
  for n in SBUS BUS0 MCHC PMCR AWAC RTC RTC0 HPET GPRW XHCI GFX0 IGPU PEG0 PEG1 SAT0 HDAS; do
    printf "  %-6s %s\n" "\$n" "\$(/usr/sbin/ioreg -p IOACPIPlane -w0 2>/dev/null | grep -c "\$n")"
  done
  echo
  echo "=== E) 磁盘 / 挂载 ==="
  /usr/sbin/diskutil list 2>&1 | head -40
  /bin/ls -1 /Volumes
} > "\$OUT" 2>&1
/bin/chmod 644 "\$OUT"
echo done
EOF
chmod +x "$SCRIPT"

if [ "$(id -u)" = 0 ]; then
  bash "$SCRIPT"
else
  echo "   需要提权（会弹密码框）..."
  osascript -e "do shell script \"/bin/bash \\\"$SCRIPT\\\"\" with administrator privileges" 2>&1 | tail -2
fi

if [ -s "$OUT/kernel-log-acpi.txt" ]; then
  echo "   → $OUT/kernel-log-acpi.txt"
else
  echo "   ★ 没抓到内容。可手动跑: sudo bash \"$SCRIPT\""
fi

echo
echo "== 完成 =="
ls -la "$OUT"
