#!/bin/bash
# 发布前敏感信息自检（只读）。用法: redact-check.sh <目录> [更多目录...]
# 退出码: 0 无命中，1 有命中，2 输入/读取失败。只输出位置，避免再次打印敏感值。
set -eu
exec "${PYTHON:-python3}" - "$@" <<'PYSCAN'
import os, plistlib, re, sys
from pathlib import Path

if len(sys.argv) < 2:
    print("用法: redact-check.sh <目录> [更多目录...]", file=sys.stderr)
    sys.exit(2)
# 只豁免 UUID 本身，不豁免同一行的其他内容。
public_guids = set("4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102 4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14 7C436110-AB2A-4BBB-A880-FE41995C9F82 E6B92AC5-B7DB-4B0D-B1B5-8A0E0A0E0A0E 8BE4DF61-93CA-11D2-AA0D-00E098032B8C A17579F0-4FEC-4936-9364-249460863BE5 6994AD04-93EF-11D0-A3CC-00A0C9223196".split())
serial_key = r"(?:SystemSerialNumber|BoardSerialNumber|IOPlatformSerialNumber|SerialNumber|SystemSerial|BoardSerial|serial|MLB)"
serial = re.compile(r"(?i)\b" + serial_key + r"\b[\s\"'`]*[:=][\s\"'`]*([A-Z0-9]{8,})(?![A-Z0-9])")
xml_serial = re.compile(r"(?is)<key>\s*" + serial_key + r"\s*</key>\s*<string>\s*([^<]+)\s*</string>")
uuid = re.compile(r"\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b", re.I)
patterns = [
    ("MAC 地址", re.compile(r"\b(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\b", re.I)),
    ("密钥 / token", re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN [A-Z ]*PRIVATE KEY|(?:api[_-]?key|access[_-]?token|client[_-]?secret|passwd|password)[\s\"']*[:=][\s\"']*[^\s\"',;<>]{8,}", re.I)),
    ("凭据路径", re.compile(r"\.ssh/id_|\bid_rsa\b|\.(?:pem|p12)\b|\.netrc\b|credentials\.json")),
    ("邮箱", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
    ("私有 IP", re.compile(r"\b(?:10\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3})\.\d{1,3}\b")),
]

def placeholder(value):
    # 明确的占位值；真实值中碰巧有 X 不应被整体豁免。
    value = str(value).strip()
    return not value or bool(re.fullmatch(r"[Xx0*? -]+|<[^>]+>|⟨[^⟩]+⟩|\$\{[^}]+\}", value))

hits, errors, seen = set(), [], set()
def record(path, line, label):
    hits.add((str(path), line, label))

def scan_line(path, number, line):
    for match in serial.finditer(line):
        if not placeholder(match.group(1)):
            record(path, number, '三码')
    for label, pattern in patterns:
        if pattern.search(line):
            record(path, number, label)
    if any(m.group().upper() not in public_guids for m in uuid.finditer(line)):
        record(path, number, 'UUID')

def walk_plist(value, path):
    if isinstance(value, dict):
        for key, item in value.items():
            if re.fullmatch(serial_key, key, re.I) and isinstance(item, str) and not placeholder(item):
                record(path, 0, "三码")
            if isinstance(item, str):
                scan_line(path, 0, f"{key}: {item}")
            if key.upper() == 'ROM':
                if isinstance(item, bytes) and len(item) == 6 and any(item):
                    record(path, 0, 'ROM 地址')
                if isinstance(item, str) and re.fullmatch(r'[0-9A-Fa-f]{12}', item) and not placeholder(item):
                    record(path, 0, 'ROM 地址')
            walk_plist(item, path)
    elif isinstance(value, list):
        for item in value:
            walk_plist(item, path)
    elif isinstance(value, str):
        scan_line(path, 0, value)

for arg in sys.argv[1:]:
    root = Path(arg)
    if not root.is_dir():
        errors.append(f"不是目录: {root}"); continue
    def onerror(error):
        errors.append(f"遍历失败: {error.filename}")
    for parent, dirs, files in os.walk(root, onerror=onerror):
        dirs[:] = [d for d in dirs if d != '.git']
        for name in files:
            path = Path(parent) / name
            if name == 'redact-check.sh' or path.resolve() in seen:
                continue
            seen.add(path.resolve())
            try:
                data = path.read_bytes()
            except OSError:
                errors.append(f"读取失败: {path}"); continue
            if data.startswith(b'bplist00') or b'<plist' in data[:512]:
                try:
                    walk_plist(plistlib.loads(data), path)
                except Exception:
                    errors.append(f"plist 解析失败: {path}")
                if data.startswith(b'bplist00'):
                    continue
            if b'\x00' in data:
                continue
            content = data.decode('utf-8', errors='replace')
            for match in xml_serial.finditer(content):
                if not placeholder(match.group(1)):
                    record(path, content.count('\n', 0, match.start()) + 1, '三码（XML 字段）')
            for number, line in enumerate(content.splitlines(), 1):
                scan_line(path, number, line)
for path, line, label in sorted(hits):
    print(f"  [{label}] {path}:{line or 'plist'}")
for error in errors:
    print(error, file=sys.stderr)
if errors:
    sys.exit(2)
if hits:
    print(f"⚠️ 有 {len(hits)} 处命中；发布前核实并替换为占位符。")
    sys.exit(1)
print("✅ 没有命中（自动扫描不能代替人工审阅）")
PYSCAN
