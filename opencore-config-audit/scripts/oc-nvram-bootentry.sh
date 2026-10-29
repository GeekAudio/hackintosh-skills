#!/bin/bash
# oc-nvram-bootentry.sh —— 从 macOS 读 / 写固件启动项（EFI_GLOBAL_VARIABLE_GUID 下的 Boot#### / BootOrder）
#
# 用途：在 macOS 里检查、备份、回滚、添加、删除 BIOS/UEFI 启动项，不必重启进 BIOS 或借 Windows。
#
# ★★ 先读这条，否则会白忙 ★★
#   若 config 里 `UEFI>Quirks>RequestBootVarRouting=true`（且加载了 OpenRuntime.efi），
#   OpenRuntime 会把 EFI_GLOBAL_VARIABLE_GUID 下所有以 `Boot` 开头的变量
#   **重定向**到 OC_VENDOR_VARIABLE_GUID（`Boot0001` → `OCBt0001`、`BootOrder` → `OCBtOrder`）。
#   ⇒ 此时 `add` / `del` 看起来成功（回读也一致），但**很可能只落在 OpenCore 自己的命名空间**，
#     **没有落到固件**。必须重启进 BIOS 才能确认。
#   ⇒ 要让 `add` / `del` 直接生效：该次启动的 config 用 `RequestBootVarRouting=false`（官方对 Linux efibootmgr 的要求同此）。
#   ★ 官方推荐的做法是 **OpenShell 里的 `bcfg boot add`**（纯 U 盘、不用进任何 OS）；
#     `bcfg` 报「写不进去」时先跑 `\EFI\OC\Tools\OpenControl.efi disable`，之后再重试。
#   ★ `dump` / `backup` / `restore` 不受此影响（读与回写同一个命名空间，自洽）。
#
# 用法：
#   oc-nvram-bootentry.sh dump [--scan 0x0000-0x001f]
#   oc-nvram-bootentry.sh backup [目录]
#   oc-nvram-bootentry.sh restore <目录>
#   oc-nvram-bootentry.sh del <N> [N...]
#   oc-nvram-bootentry.sh add --esp diskXs1 --name OpenCore \
#          [--file '\EFI\OC\OpenCore.efi'] [--index N] [--first] \
#          (--dp-prefix '<UEFI 字符串>' | --dp-prefix-hex <hex> | --from-entry BootXXXX)
#
# 依赖：/usr/sbin/nvram、/usr/bin/python3、diskutil（都是系统自带）
# 实现：主逻辑在下方内嵌的 Python 里（单个进程 —— 逐个 fork `nvram` 会慢十倍）

exec /usr/bin/python3 - "$0" "$@" <<'PYEOF'
import os, re, subprocess, sys, time

SCRIPT = sys.argv[1]

G       = "8BE4DF61-93CA-11D2-AA0D-00E098032B8C"   # EFI_GLOBAL_VARIABLE_GUID
NVRAM   = "/usr/sbin/nvram"
PROG    = "oc-nvram-bootentry.sh"

def die(msg): print("  ✗ %s" % msg, file=sys.stderr); sys.exit(1)
def info(msg): print("  %s" % msg)

# ── nvram 读写（macOS 的 nvram 用 %XX 编码不可打印字节，'%' 本身编码为 %25）──
def nv_get(name):
    r = subprocess.run([NVRAM, "%s:%s" % (G, name)], capture_output=True, text=True)
    if r.returncode != 0:
        # 权限/服务错误不能被当成空闲编号或“已不存在”。
        if "data was not found" in r.stderr.lower(): return None
        die("读取 %s 失败，无法确认变量状态：%s" % (name, r.stderr.strip() or "nvram 返回非零"))
    line = r.stdout.rstrip("\n")
    return line.split("\t", 1)[1] if "\t" in line else line

def nv_set(name, val):
    return subprocess.run([NVRAM, "%s:%s=%s" % (G, name, val)], capture_output=True).returncode == 0

def nv_del(name):
    return subprocess.run([NVRAM, "-d", "%s:%s" % (G, name)], capture_output=True).returncode == 0

def nv_write_verified(name, value):
    if not nv_set(name, value): return False
    readback = nv_get(name)
    # nvram 可把可打印字节显示成 ASCII；比较解码后的值，不比较显示编码。
    return readback is not None and decode(readback) == decode(value)

def decode(s):
    out = bytearray(); i = 0
    while i < len(s):
        if s[i] == "%" and i + 3 <= len(s):
            try: out.append(int(s[i+1:i+3], 16)); i += 3; continue
            except ValueError: pass
        out.append(ord(s[i]) & 0xFF); i += 1
    return bytes(out)

def encode(b):
    # ★ 每个字节都写成 %XX，不留任何字面字符。
    #   原因：macOS 的 nvram 会把【值里的字面空格】当成参数分隔符（写进去会失败），
    #   所以「读出来什么样就原样写回去」是不可靠的 —— 必须先 decode 再统一 encode。
    #   （macOS 自己的输出是「可打印 ASCII 原样 + 其余 %XX」，我们只是换一种等价写法。）
    return "".join("%%%02x" % c for c in b)

def order_list():
    raw = nv_get("BootOrder")
    if not raw: return []
    b = decode(raw)
    return [int.from_bytes(b[j:j+2], "little") for j in range(0, len(b) - 1, 2)]

def order_enc(nums):
    b = bytearray()
    for n in nums: b += int(n).to_bytes(2, "little")
    return encode(bytes(b))

# ── 设备路径 ──
def node(t, st, body): return bytes([t, st]) + (4 + len(body)).to_bytes(2, "little") + body

def dp_parse(dp):
    out = []; k = 0
    while k + 4 <= len(dp):
        t, st = dp[k], dp[k+1]; ln = int.from_bytes(dp[k+2:k+4], "little")
        if ln < 4: break
        out.append((t, st, dp[k+4:k+ln])); k += ln
    return out

def guid_bytes(g):
    p = g.split("-")
    return (bytes.fromhex(p[0])[::-1] + bytes.fromhex(p[1])[::-1]
            + bytes.fromhex(p[2])[::-1] + bytes.fromhex(p[3]) + bytes.fromhex(p[4]))

def dp_show(dp):
    for t, st, body in dp_parse(dp):
        if (t, st) == (0x02, 0x01):
            print("     ACPI  PciRoot(0x%x)" % int.from_bytes(body[4:8], "little"))
        elif (t, st) == (0x01, 0x01):
            # UEFI: PCI 节点里 Function 在前、Device 在后；文本写法是 Pci(Device,Function)
            print("     Pci   (0x%x,0x%x)" % (body[1], body[0]))
        elif (t, st) == (0x03, 0x17):
            print("     NVMe  (0x%x,%s)" % (int.from_bytes(body[0:4], "little"),
                  "-".join("%02X" % c for c in body[4:12])))
        elif (t, st) == (0x04, 0x01):
            pn = int.from_bytes(body[0:4], "little")
            lba = int.from_bytes(body[4:12], "little"); sz = int.from_bytes(body[12:20], "little")
            sig = body[20:36]; styp = body[37] if len(body) > 37 else 0
            if styp == 2:
                a, c, d, e = (sig[0:4][::-1].hex(), sig[4:6][::-1].hex(),
                              sig[6:8][::-1].hex(), sig[8:16].hex())
                sigs = "%s-%s-%s-%s-%s" % (a, c, d, e[:4], e[4:])
            else:
                sigs = sig.hex()
            print("     HD    (%d, %s, %s, 0x%x, 0x%x)" % (
                  pn, "GPT" if styp == 2 else "type%d" % styp, sigs, lba, sz))
        elif (t, st) == (0x04, 0x04):
            print("     File  %s" % body.decode("utf-16-le", "replace"))
        elif (t, st) == (0x7f, 0xff):
            pass
        else:
            print("     node  type=0x%02x sub=0x%02x len=%d" % (t, st, len(body) + 4))

def dp_text(dp):
    """还原成 UEFI 文本写法（能认的节点），其余用 hex 兜底。"""
    out = []
    for t, st, body in dp_parse(dp):
        if (t, st) == (0x02, 0x01): out.append("PciRoot(0x%x)" % int.from_bytes(body[4:8], "little"))
        elif (t, st) == (0x01, 0x01): out.append("Pci(0x%x,0x%x)" % (body[1], body[0]))
        elif (t, st) == (0x03, 0x17):
            out.append("NVMe(0x%x,%s)" % (int.from_bytes(body[0:4], "little"),
                       "-".join("%02X" % c for c in body[4:12])))
        elif (t, st) == (0x04, 0x01):
            out.append("HD(%d,GPT,%s,0x%x,0x%x)" % (
                int.from_bytes(body[0:4], "little"),
                "%s-%s-%s-%s-%s" % (body[20:24][::-1].hex(), body[24:26][::-1].hex(),
                                    body[26:28][::-1].hex(), body[28:30].hex(), body[30:36].hex()),
                int.from_bytes(body[4:12], "little"), int.from_bytes(body[12:20], "little")))
        elif (t, st) == (0x04, 0x04): out.append(body.decode("utf-16-le", "replace"))
        elif (t, st) == (0x7f, 0xff): pass
        else: out.append("<type=0x%02x,sub=0x%02x>" % (t, st))
    return "/".join(out)

def dp_from_text(s):
    out = bytearray()
    for part in [x for x in s.split("/") if x.strip()]:
        m = re.fullmatch(r"PciRoot\((0x[0-9a-fA-F]+)\)", part)
        if m:
            # ACPI 节点 = HID(UINT32) + UID(UINT32)；PciRoot 的 HID 固定 = EISA_PNP_ID(0x0A03) = 0x0A0341D0
            out += node(0x02, 0x01, (0x0A0341D0).to_bytes(4, "little")
                        + int(m.group(1), 16).to_bytes(4, "little")); continue
        m = re.fullmatch(r"Pci\((0x[0-9a-fA-F]+),(0x[0-9a-fA-F]+)\)", part)
        if m: out += node(0x01, 0x01, bytes([int(m.group(2), 16), int(m.group(1), 16)])); continue
        m = re.fullmatch(r"NVMe\((0x[0-9a-fA-F]+),([0-9A-Fa-f-]+)\)", part)
        if m:
            out += node(0x03, 0x17, int(m.group(1), 16).to_bytes(4, "little")
                        + bytes(int(x, 16) for x in m.group(2).split("-"))); continue
        die("不认识的节点: %s\n（PciRoot/Pci/NVMe 之外请改用 --dp-prefix-hex）" % part)
    return bytes(out)

def parse_entry(b):
    """EFI_LOAD_OPTION → (attrs, desc, device_path)"""
    if len(b) < 6: return None
    attrs = int.from_bytes(b[0:4], "little"); fpll = int.from_bytes(b[4:6], "little")
    j = 6
    while j + 1 < len(b) and b[j:j+2] != b"\x00\x00": j += 2
    desc = b[6:j].decode("utf-16-le", "replace")
    return attrs, desc, (b[j+2:j+2+fpll] if fpll else b[j+2:])

def build_entry(name, fpath, guid, off, size, prefix):
    dp  = prefix
    hd  = (1).to_bytes(4, "little") + int(off).to_bytes(8, "little") + int(size).to_bytes(8, "little")
    hd += guid_bytes(guid) + bytes([2, 2])
    dp += node(0x04, 0x01, hd)
    dp += node(0x04, 0x04, fpath.encode("utf-16-le"))     # 无结尾 NUL，与 OpenCore 自身写法一致
    dp += bytes.fromhex("7fff0400")
    blob = (1).to_bytes(4, "little") + len(dp).to_bytes(2, "little") + name.encode("utf-16-le") + b"\x00\x00" + dp
    return encode(blob)

def diskutil_info(esp):
    r = subprocess.run(["diskutil", "info", esp], capture_output=True, text=True)
    if r.returncode != 0: die("diskutil 读不到 %s" % esp)
    t = r.stdout
    g = re.search(r"Partition UUID:\s*([0-9A-Fa-f-]{36})", t)
    o = re.search(r"Partition Offset:\s*(\d+)\s*Bytes\s*\((\d+)\s+512-Byte-Device-Blocks\)", t)
    s = re.search(r"exactly\s+(\d+)\s+512-Byte-Units", t)
    if not g: die("%s 没有 Partition UUID（不是 GPT 分区？）" % esp)
    if not (o and s): die("取不到 %s 的 Partition Offset / Disk Size" % esp)
    # ★ HD 节点里的起始 LBA 单位是【512 字节块】（UEFI 规定），不是字节数
    return g.group(1), int(o.group(2)), int(s.group(1))

def scan_range(spec):
    a, b = spec.split("-"); return list(range(int(a, 16), int(b, 16) + 1))

# ── 子命令 ──
def cmd_dump(argv):
    spec = "0x0000-0x001f"
    if argv and argv[0] == "--scan": spec = argv[1]
    order = order_list()
    print("BootOrder = %s" % (nv_get("BootOrder") or "(空)"))
    if order: print("  顺序 → %s" % " ".join("Boot%04X" % n for n in order))
    print("\n── 各启动项 ─────────────────────────────────────────────")
    idx = sorted(set(scan_range(spec)) | set(order) | {128, 129})
    found = 0
    for i in idx:
        nm = "Boot%04X" % i
        raw = nv_get(nm)
        if not raw: continue
        found += 1
        pe = parse_entry(decode(raw))
        print("\n%s" % nm)
        if not pe: print("   (太短，无法解析)"); continue
        attrs, desc, dp = pe
        print("   名称      : %s" % desc)
        print("   Attributes: 0x%08x%s" % (attrs, "  (ACTIVE)" if attrs & 1 else "  (不活跃)"))
        print("   设备路径  : %d 字节" % len(dp))
        dp_show(dp)
    if not found: info("（扫描范围内没有启动项）")
    print()
    info("扫描范围: %s + BootOrder 里的编号（改范围用 --scan A-B）" % spec)

def cmd_backup(argv):
    d = argv[0] if argv else "nvram-bootentry-备份-%s" % time.strftime("%Y%m%d-%H%M%S")
    os.makedirs(d, exist_ok=True)
    n = 0
    for i in sorted(set(scan_range("0x0000-0x001f")) | set(order_list()) | {128, 129}):
        nm = "Boot%04X" % i; v = nv_get(nm)
        if not v: continue
        open(os.path.join(d, nm + ".txt"), "w").write(v + "\n"); n += 1
        info("备份 %s（%d 字节）" % (nm, len(v)))
    bo = nv_get("BootOrder")
    if bo: open(os.path.join(d, "BootOrder.txt"), "w").write(bo + "\n"); info("备份 BootOrder")
    info("→ %s（%d 个变量）" % (d, n))

def cmd_restore(argv):
    if not argv: die("用法: %s restore <备份目录>" % PROG)
    d = argv[0]
    if not os.path.isdir(d): die("目录不存在: %s" % d)
    n = 0; failed = []; order = None
    for f in sorted(os.listdir(d)):
        if not re.fullmatch(r"Boot(?:[0-9A-Fa-f]{4}|Order)\.txt", f): continue
        nm = f[:-4]; v = open(os.path.join(d, f)).read().rstrip("\n")
        if nm == "BootOrder": order = encode(decode(v)); continue
        # ★ 必须重编码：备份里是 macOS 的混合写法（含字面空格），直接写回去会失败
        if nv_write_verified(nm, encode(decode(v))): info("已回写并验证 %s" % nm); n += 1
        else: failed.append(nm); info("回写或验证 %s 失败" % nm)
    if failed: die("部分恢复：已回写 %d 项，失败 %s；未改 BootOrder" % (n, ", ".join(failed)))
    if order is not None:
        if not nv_write_verified("BootOrder", order): die("已回写 %d 项，但恢复 BootOrder 失败；请检查部分恢复状态" % n)
        info("已回写并验证 BootOrder"); n += 1
    if not n: die("没有回写任何变量")

def cmd_del(argv):
    if not argv: die("用法: %s del <N> [N...]" % PROG)
    tgt = [int(x, 0) for x in argv]
    if any(n < 0 or n > 0xFFFF for n in tgt): die("编号必须在 0..65535 内")
    original_order = order_list(); deleted = []
    for i in tgt:
        nm = "Boot%04X" % i
        if nv_get(nm) is None: info("%s 已不存在" % nm); continue
        if not nv_del(nm) or nv_get(nm) is not None:
            die("删除 %s 失败；此前已删除 %s，未改 BootOrder" % (nm, ", ".join(deleted) or "无"))
        deleted.append(nm); info("已删除 %s" % nm)
    keep = [n for n in original_order if n not in tgt]
    if keep:
        v = order_enc(keep)
        if not nv_write_verified("BootOrder", v): die("启动项已处理，但写 BootOrder 失败；请检查部分删除状态")
        info("BootOrder 重写为 %s" % v)
    else:
        if nv_get("BootOrder") is not None and (not nv_del("BootOrder") or nv_get("BootOrder") is not None):
            die("启动项已处理，但清空 BootOrder 失败；请检查部分删除状态")
        info("BootOrder 已清空")

def cmd_add(argv):
    a = {"esp": None, "name": None, "file": "\\EFI\\OC\\OpenCore.efi",
         "index": None, "first": False, "dpp": None, "dphx": None, "from": None, "dry": False}
    while argv:
        k = argv.pop(0)
        if k == "--first": a["first"] = True; continue
        if k == "--dry-run": a["dry"] = True; continue
        if k not in ("--esp", "--name", "--file", "--index", "--dp-prefix", "--dp-prefix-hex", "--from-entry"):
            die("未知参数: %s" % k)
        if not argv: die("%s 缺少值" % k)
        a[{"--esp": "esp", "--name": "name", "--file": "file", "--index": "index",
           "--dp-prefix": "dpp", "--dp-prefix-hex": "dphx", "--from-entry": "from"}[k]] = argv.pop(0)
    if not a["esp"]: die("必须给 --esp（如 disk2s1）")
    if not a["name"]: die("必须给 --name（BIOS 里显示的名字）")

    guid, off, size = diskutil_info(a["esp"])

    if a["dphx"]:
        prefix = bytes.fromhex(a["dphx"])
    elif a["dpp"]:
        prefix = dp_from_text(a["dpp"])
    elif a["from"]:
        raw = nv_get(a["from"]) or die("%s 不存在" % a["from"])
        _, _, dp = parse_entry(decode(raw))
        pre = bytearray()
        for t, st, body in dp_parse(dp):
            if (t, st) in ((0x04, 0x01), (0x7f, 0xff)): break
            pre += node(t, st, body)
        prefix = bytes(pre)
    else:
        die("必须给 --dp-prefix '<UEFI 字符串>' / --dp-prefix-hex <hex> / --from-entry BootXXXX 三者之一")
    if not prefix: die("设备路径前缀为空")

    payload = build_entry(a["name"], a["file"], guid, off, size, prefix)
    idx = int(a["index"], 0) if a["index"] else None
    if idx is None:
        used = set(order_list())
        idx = next((i for i in range(1, 0xFFFF)
                    if i not in used and nv_get("Boot%04X" % i) is None), None)
        if idx is None: die("没有可用的 Boot 编号")
    if idx < 0 or idx > 0xFFFF: die("编号必须在 0..65535 内")
    nm = "Boot%04X" % idx
    if nv_get(nm) is not None: die("%s 已存在；先备份并显式删除后再添加，拒绝覆盖" % nm)

    info("写入 %s  →  %s" % (nm, a["name"]))
    info("  ESP   : %s   GUID %s   LBA 0x%x   0x%x 扇区" % (a["esp"], guid, off, size))
    info("  文件  : %s" % a["file"])
    info("  设备路径前缀: %s" % dp_text(prefix))
    info("  载荷  : %d 字节（编码后 %d 字符）" % (len(decode(payload)), len(payload)))
    if a["dry"]:
        print(); info("--dry-run：没有写入任何变量。载荷如下：")
        print(payload)
        print(); info("比对：%s dump 看现有项；或 %s add ... --index N 真正写入" % (PROG, PROG))
        return
    if not nv_write_verified(nm, payload): die("写入或回读 %s 失败；BootOrder 未修改，请检查该项是否部分写入" % nm)
    info("✅ 回读逐字节一致（★ 不等于已落固件，见文件头警告）")

    rest = [n for n in order_list() if n != idx]
    new_order = ([idx] + rest) if a["first"] else (rest + [idx])
    v = order_enc(new_order)
    if not nv_write_verified("BootOrder", v):
        die("%s 已写入，但 BootOrder 写入或回读失败；部分添加，回滚可运行 %s del %d" % (nm, PROG, idx))
    info("BootOrder = %s%s" % (v, "（已置顶）" if a["first"] else "（已追加）"))
    print(); info("回滚：%s del %d" % (PROG, idx))

def usage():
    for ln in open(SCRIPT, encoding="utf-8").read().splitlines()[1:34]:
        print(re.sub(r"^# ?", "", ln))

CMDS = {"dump": cmd_dump, "backup": cmd_backup, "restore": cmd_restore,
        "del": cmd_del, "rm": cmd_del, "add": cmd_add}
argv = sys.argv[2:]
if not argv or argv[0] in ("-h", "--help", "help"):
    usage(); sys.exit(0)
cmd = CMDS.get(argv[0])
if not cmd: die("未知子命令: %s（试试 --help）" % argv[0])
cmd(argv[1:])
PYEOF
