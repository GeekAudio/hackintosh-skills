#!/usr/bin/env python3
"""Mutation-helper regressions; all targets and command side effects are temporary mocks.

Run: python3 tools/test_mutation_safety.py
Never run these helpers against the real EFI, fstab, disks, or NVRAM.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest
import zipfile

import test_script_safety as safety

SCRIPTS = safety.SCRIPTS
UUID = "AAAAAAAA-1111-2222-3333-444444444444"
BEGIN = "# BEGIN opencore-config-audit mask-other-disks"
END = "# END opencore-config-audit mask-other-disks"


class MutationSafetyTests(unittest.TestCase):
    def setUp(self):
        self.fx = safety.ScriptSafetyTests()
        self.fx.setUp()
        self.addCleanup(self.fx.doCleanups)
        self.root = self.fx.root.resolve()
        self.env = dict(self.fx.env)
        self.env["TEST_ROOT"] = str(self.root)
        self.env["MUTATION_LOG"] = str(self.root / "mutations.log")
        self.env["TEST_PYTHON"] = sys.executable
        (self.root / "tmp").mkdir()
        self.env["TMPDIR"] = str(self.root / "tmp")
        self.fx.env.update(self.env)
        self.fx.executable(self.fx.mockbin / "id", "echo 0\n")
        self.fx.executable(self.fx.mockbin / "curl", "echo unexpected-network-call >&2; exit 99\n")
        self.fx.executable(self.fx.mockbin / "chown", "exit 0\n")
        self.fx.python_mock(self.fx.mockbin / "mktemp", r'''
import os, pathlib, sys, tempfile
root = pathlib.Path(os.environ["TEST_ROOT"]).resolve()
args = sys.argv[1:]; templates = [arg for arg in args if not arg.startswith("-")]
template = pathlib.Path(templates[0]) if templates else root / "tmp/fixture.XXXXXX"
parent = template.parent.resolve()
if parent != root and root not in parent.parents: raise SystemExit("blocked mktemp outside fixture")
prefix = template.name.rstrip("X")
if "-d" in args: print(tempfile.mkdtemp(prefix=prefix, dir=parent))
else:
    fd, name = tempfile.mkstemp(prefix=prefix, dir=parent); os.close(fd); print(name)
''')
        self.fx.python_mock(self.fx.mockbin / "cp", r'''
import os, pathlib, subprocess, sys
args = sys.argv[1:]; source, destination = args[-2:]
root = pathlib.Path(os.environ["TEST_ROOT"]).resolve()
for name in (source, destination):
    p = pathlib.Path(name).resolve()
    if p != root and root not in p.parents:
        raise SystemExit("blocked copy outside temporary fixture: " + str(p))
kind = "other"
if "_oc-build-backup-" in destination: kind = "swap_backup"
elif "_oc-build-src." in source: kind = "swap_replace"
elif destination.endswith("_oc-current.plist"): kind = "mirror"
elif "/config.plist.v" in destination: kind = "archive"
elif ".oc-mask-backup." in destination: kind = "fstab_backup"
elif ".oc-mask-new." in destination: kind = "fstab_pending"
with open(os.environ["MUTATION_LOG"], "a") as log: log.write("copy " + kind + " " + destination + "\n")
selected = os.environ.get("MOCK_COPY_REL", "")
if os.environ.get("MOCK_COPY_FAIL") == kind and (not selected or destination.endswith(selected)):
    raise SystemExit(1)
result = subprocess.run(["/bin/cp", *args])
if result.returncode: raise SystemExit(result.returncode)
if os.environ.get("MOCK_COPY_CORRUPT") == kind and (not selected or destination.endswith(selected)):
    with open(destination, "ab") as output: output.write(b"corrupted")
if kind == os.environ.get("MOCK_EXTERNAL_AFTER_COPY"):
    replacement = pathlib.Path(os.environ["MOCK_EXTERNAL_PLIST"]).resolve()
    if root not in replacement.parents: raise SystemExit("blocked external writer outside fixture")
    pathlib.Path(source).write_bytes(replacement.read_bytes())
if kind == "fstab_backup" and os.environ.get("MOCK_CONCURRENT_FSTAB"):
    with open(os.environ["MOCK_CONCURRENT_FSTAB"], "a") as output: output.write("# concurrent user rule\n")
''')

    def run_script(self, name, *args, env=None, cwd=None, script=None):
        if name in ("oc-nvram-bootentry.sh", "mask-other-disks.sh"):
            self.assertIsNotNone(script, "A host-mutating helper requires an isolated test copy")
            self.assertIn(self.root, Path(script).resolve().parents)
        return subprocess.run(
            ["/bin/bash", str(script or SCRIPTS / name), *map(str, args)],
            env={**self.env, **(env or {})}, cwd=cwd or self.root,
            encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=20,
        )

    def assert_code(self, result, expected):
        self.assertEqual(result.returncode, expected, result.stdout)

    def swap_fixture(self):
        target = self.root / "target efi"
        for rel, content in (("OC/OpenCore.efi", b"old core"), ("BOOT/BOOTx64.efi", b"old boot"),
                             ("OC/Drivers/OpenRuntime.efi", b"old driver"),
                             ("OC/Drivers/ThirdParty.efi", b"third party")):
            path = target / rel; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(content)
        cache = self.root / "_oc-build-swap"; cache.mkdir()
        with zipfile.ZipFile(cache / "OpenCore-1.0.8-RELEASE.zip", "w") as archive:
            for rel, content in (("OC/OpenCore.efi", b"new core"), ("BOOT/BOOTx64.efi", b"new boot"),
                                 ("OC/Drivers/OpenRuntime.efi", b"new driver"),
                                 ("OC/Drivers/NotInstalled.efi", b"unused driver")):
                archive.writestr("X64/EFI/" + rel, content)
        return target

    def swap(self, target, **env):
        return self.run_script("oc-swap-build.sh", "release", "1.0.8", "--efi", target, "--yes", env=env)

    def test_swap_backup_shape_rolls_back_all_replaced_files(self):
        target = self.swap_fixture()
        self.assert_code(self.swap(target), 0)
        backup = next((self.root / "_oc-build-swap").glob("_oc-build-backup-*"))
        self.assertEqual((backup / "OC/Drivers/OpenRuntime.efi").read_bytes(), b"old driver")
        self.assertFalse((backup / "Drivers").exists())
        shutil.copytree(backup, target, dirs_exist_ok=True)
        self.assertEqual((target / "OC/OpenCore.efi").read_bytes(), b"old core")
        self.assertEqual((target / "OC/Drivers/OpenRuntime.efi").read_bytes(), b"old driver")
        self.assertEqual((target / "BOOT/BOOTx64.efi").read_bytes(), b"old boot")
        self.assertEqual((target / "OC/Drivers/ThirdParty.efi").read_bytes(), b"third party")
        self.assertFalse((target / "OC/Drivers/NotInstalled.efi").exists())
        self.assertNotIn("nvram", self.fx.calls.read_text())

    def test_swap_backup_failure_or_bad_backup_never_changes_target(self):
        target = self.swap_fixture()
        for env in ({"MOCK_COPY_FAIL": "swap_backup"}, {"MOCK_COPY_CORRUPT": "swap_backup"}):
            with self.subTest(env=env):
                result = self.swap(target, **env)
                self.assert_code(result, 1)
                self.assertEqual((target / "OC/OpenCore.efi").read_bytes(), b"old core")
                self.assertEqual((target / "OC/Drivers/OpenRuntime.efi").read_bytes(), b"old driver")
                self.assertNotIn("== 完成", result.stdout)
        self.assertFalse(self.fx.calls.exists(), "Backup failure must precede sync/disk operations")

    def test_swap_copy_and_verification_failure_report_partial_state(self):
        target = self.swap_fixture()
        result = self.swap(target, MOCK_COPY_FAIL="swap_replace", MOCK_COPY_REL="OC/Drivers/OpenRuntime.efi")
        self.assert_code(result, 1)
        self.assertIn("回滚", result.stdout)
        self.assertNotIn("== 完成", result.stdout)
        self.assertFalse(self.fx.calls.exists())
        result = self.swap(target, MOCK_COPY_CORRUPT="swap_replace", MOCK_COPY_REL="OC/Drivers/OpenRuntime.efi")
        self.assert_code(result, 1)
        self.assertIn("SHA 与官方包不一致", result.stdout)
        self.assertFalse(self.fx.calls.exists())

    def test_swap_checks_every_file_again_after_mocked_remount(self):
        target = self.swap_fixture()
        result = self.swap(target, MOCK_ESP="1", MOCK_CORRUPT="1",
                           MOCK_CONFIG=str(target / "OC/Drivers/OpenRuntime.efi"))
        self.assert_code(result, 1)
        self.assertIn("OC/Drivers/OpenRuntime.efi SHA", result.stdout)
        self.assertNotIn("== 完成", result.stdout)

    def test_swap_mocked_remount_failure_is_not_success(self):
        target = self.swap_fixture()
        self.assert_code(self.swap(target, MOCK_ESP="1", MOCK_MOUNT_RC="1"), 1)

    def test_swap_uses_explicit_target_and_handles_relative_path_and_unique_backups(self):
        target = self.swap_fixture()
        self.assert_code(self.swap(target.name), 0)
        self.assert_code(self.swap(target.name), 0)
        self.assertEqual(len(list((self.root / "_oc-build-swap").glob("_oc-build-backup-*"))), 2)
        self.assertEqual((target / "OC/OpenCore.efi").read_bytes(), b"new core")
        result = self.run_script("oc-swap-build.sh", "release", "--efi", target, "--yes")
        self.assert_code(result, 2)
        self.assertIn("显式", result.stdout)
        self.assertNotIn("nvram", self.fx.calls.read_text())
        self.assert_code(self.run_script("oc-swap-build.sh", "release", "1.0.8", "--efi", "--yes"), 2)

    def test_edit_mirror_and_archive_copy_failures_stop_before_sync(self):
        work, config = self.fx.edit_fixture()
        for kind in ("mirror", "archive"):
            with self.subTest(kind=kind):
                self.fx.calls.unlink(missing_ok=True)
                result = self.run_script("oc-edit-safe.sh", "finish", config, work, env={"MOCK_COPY_FAIL": kind})
                self.assert_code(result, 1)
                self.assertNotIn("sync", self.fx.calls.read_text())
                self.assertNotIn("== 结论 ==", result.stdout)

    def test_edit_mirror_and_archive_hash_mismatch_stop_before_sync(self):
        work, config = self.fx.edit_fixture()
        for kind in ("mirror", "archive"):
            with self.subTest(kind=kind):
                self.fx.calls.unlink(missing_ok=True)
                result = self.run_script("oc-edit-safe.sh", "finish", config, work, env={"MOCK_COPY_CORRUPT": kind})
                self.assert_code(result, 1)
                self.assertIn("SHA 不一致", result.stdout)
                self.assertNotIn("sync", self.fx.calls.read_text())

    def external_config(self):
        external = self.root / "external.plist"
        external.write_bytes(safety.plistlib.dumps({"Misc": {"Debug": {"Target": 777}}}))
        return external

    def test_edit_validator_external_write_is_not_adopted_as_current(self):
        work, config = self.fx.edit_fixture()
        external = self.external_config()
        validator = work / "_oc-docs-audit/oc1.0.5/Utilities/ocvalidate/ocvalidate"
        self.fx.executable(validator, 'cat "$MOCK_EXTERNAL_PLIST" > "$1"\nexit 0\n')
        result = self.run_script("oc-edit-safe.sh", "finish", config, work,
                                 env={"MOCK_EXTERNAL_PLIST": str(external)})
        self.assert_code(result, 1)
        self.assertIn("官方校验期间 config 被并发修改", result.stdout)
        self.assertEqual(config.read_bytes(), external.read_bytes())
        self.assertFalse((work / "_oc-current.plist").exists())
        self.assertFalse((work / "oc-config-archive").exists())
        self.assertFalse(self.fx.calls.exists(), "Validator-side write must stop before sync/disk operations")

    def test_edit_external_write_after_copy_stops_before_sync_without_rollback(self):
        work, config = self.fx.edit_fixture()
        original = config.read_bytes(); external = self.external_config()
        for kind in ("mirror", "archive"):
            with self.subTest(kind=kind):
                config.write_bytes(original)
                self.fx.calls.unlink(missing_ok=True)
                result = self.run_script("oc-edit-safe.sh", "finish", config, work, env={
                    "MOCK_EXTERNAL_AFTER_COPY": kind, "MOCK_EXTERNAL_PLIST": str(external),
                })
                self.assert_code(result, 1)
                self.assertIn("并发修改", result.stdout)
                self.assertEqual(config.read_bytes(), external.read_bytes(), "Never overwrite the external writer")
                self.assertEqual((work / "_oc-current.plist").read_bytes(), original)
                self.assertNotIn("sync", self.fx.calls.read_text())
                self.assertNotIn("== 结论 ==", result.stdout)
                if kind == "archive":
                    archived = list((work / "oc-config-archive").glob("config.plist.v*"))
                    self.assertEqual(len(archived), 1)
                    self.assertEqual(archived[0].read_bytes(), original)

    def test_edit_external_write_during_sync_or_remount_fails_against_validated_hash(self):
        work, config = self.fx.edit_fixture()
        original = config.read_bytes(); external = self.external_config()
        self.fx.executable(self.fx.mockbin / "sync", '''
echo sync >> "$MOCK_LOG"
if [ "${MOCK_WRITE_DURING_SYNC:-0}" = 1 ]; then cat "$MOCK_EXTERNAL_PLIST" > "$MOCK_CONFIG"; fi
''')
        self.fx.executable(self.fx.mockbin / "diskutil", '''
echo "diskutil $*" >> "$MOCK_LOG"
case "$1" in
info) printf 'Partition Type: EFI\\nDevice Identifier: disk99s1\\n';;
unmount) exit 0;;
mount) cat "$MOCK_EXTERNAL_PLIST" > "$MOCK_CONFIG";;
*) exit 99;;
esac
''')
        for esp in ("0", "1"):
            with self.subTest(esp=esp):
                config.write_bytes(original)
                result = self.run_script("oc-edit-safe.sh", "finish", config, work, env={
                    "MOCK_ESP": esp, "MOCK_WRITE_DURING_SYNC": "1" if esp == "0" else "0",
                    "MOCK_EXTERNAL_PLIST": str(external), "MOCK_CONFIG": str(config),
                })
                self.assert_code(result, 1)
                self.assertIn("并发修改", result.stdout)
                self.assertEqual(config.read_bytes(), external.read_bytes())
                self.assertEqual((work / "_oc-current.plist").read_bytes(), original)
                self.assertNotIn("== 结论 ==", result.stdout)

    def nvram_fixture(self, values, **faults):
        self.state = self.root / "nvram.json"
        self.state.write_text(json.dumps({"values": values, **faults}))
        self.env["NVRAM_STATE"] = str(self.state)
        binary = self.fx.mockbin / "nvram-fixture"
        self.fx.python_mock(binary, r'''
import json, os, pathlib, sys
state_path = pathlib.Path(os.environ["NVRAM_STATE"]); state = json.loads(state_path.read_text())
values = state["values"]; args = sys.argv[1:]
with open(os.environ["MUTATION_LOG"], "a") as log: log.write("nvram " + " ".join(args) + "\n")
def name(value):
    prefix = "8BE4DF61-93CA-11D2-AA0D-00E098032B8C:"
    if not value.startswith(prefix): raise SystemExit("blocked unexpected namespace")
    return value[len(prefix):]
if args[0] == "-d":
    key = name(args[1])
    if key in state.get("fail_del", []) or key not in values: raise SystemExit(1)
    del values[key]; state_path.write_text(json.dumps(state)); raise SystemExit(0)
keyvalue = name(args[0])
if "=" in keyvalue:
    key, value = keyvalue.split("=", 1)
    if key in state.get("fail_set", []): raise SystemExit(1)
    values[key] = value; state_path.write_text(json.dumps(state)); raise SystemExit(0)
key = keyvalue
if key in state.get("fail_get", []):
    print("not privileged", file=sys.stderr); raise SystemExit(1)
if key not in values:
    print("data was not found", file=sys.stderr); raise SystemExit(1)
value = values[key]
if key in state.get("corrupt_read", []): value = "wrong value"
# Deliberately normalize percent-encoded printable ASCII as the real utility does.
import re
value = re.sub(r"%([0-9a-fA-F]{2})", lambda m: chr(int(m[1], 16)) if 32 <= int(m[1], 16) < 127 and int(m[1],16) != 37 else m[0], value)
print(args[0] + "\t" + value)
''')
        self.fx.executable(self.fx.mockbin / "diskutil", '''
[ "$1" = info ] || exit 99
printf 'Partition UUID: 11111111-2222-3333-4444-555555555555\nPartition Offset: 1048576 Bytes (2048 512-Byte-Device-Blocks)\nDisk Size: 524288 Bytes (exactly 1024 512-Byte-Units)\n'
''')
        script = self.root / "isolated-nvram.sh"
        source = (SCRIPTS / "oc-nvram-bootentry.sh").read_text()
        nvram_pattern = 'NVRAM   = "/usr/sbin/nvram"'
        python_pattern = "exec /usr/bin/python3 -"
        self.assertEqual(source.count(nvram_pattern), 1, "NVRAM isolation pattern changed")
        self.assertEqual(source.count(python_pattern), 1, "Interpreter isolation pattern changed")
        nvram_replacement = "NVRAM   = " + repr(str(binary))
        source = source.replace(nvram_pattern, nvram_replacement)
        source = source.replace(python_pattern, 'exec "$TEST_PYTHON" -')
        self.assertNotIn(nvram_pattern, source)
        self.assertNotIn(python_pattern, source)
        self.assertIn(nvram_replacement, source)
        script.write_text(source)
        self.nvscript = script
        return script

    def nv(self, *args):
        return self.run_script("oc-nvram-bootentry.sh", *args, script=self.nvscript)

    def nv_values(self):
        return json.loads(self.state.read_text())["values"]

    def add_nv(self, *extra):
        return self.nv("add", "--esp", "disk99s1", "--name", "Fixture", "--dp-prefix", "PciRoot(0x0)", *extra)

    def test_nvram_allocation_preserves_entries_absent_from_order_and_mixed_readback(self):
        self.nvram_fixture({"BootOrder": "%00%00", "Boot0000": "old", "Boot0001": "orphan"})
        self.assert_code(self.add_nv(), 0)
        values = self.nv_values()
        self.assertEqual(values["Boot0001"], "orphan")
        self.assertIn("Boot0002", values)
        self.assertEqual(values["BootOrder"], "%00%00%02%00")
        before = dict(values)
        self.assert_code(self.add_nv("--index", "1"), 1)
        self.assertEqual(self.nv_values(), before)

    def test_nvram_add_order_failure_reports_partial_add(self):
        self.nvram_fixture({"BootOrder": "%00%00", "Boot0000": "old"}, fail_set=["BootOrder"])
        result = self.add_nv()
        self.assert_code(result, 1)
        self.assertIn("部分添加", result.stdout)
        self.assertIn("Boot0001", self.nv_values())
        self.assertEqual(self.nv_values()["BootOrder"], "%00%00")

    def test_nvram_add_write_or_readback_failure_preserves_order(self):
        for fault in ({"fail_set": ["Boot0001"]}, {"corrupt_read": ["Boot0001"]}):
            with self.subTest(fault=fault):
                self.nvram_fixture({"BootOrder": "%00%00", "Boot0000": "old"}, **fault)
                self.assert_code(self.add_nv(), 1)
                self.assertEqual(self.nv_values()["BootOrder"], "%00%00")

    def test_nvram_delete_failure_does_not_rewrite_order(self):
        self.nvram_fixture({"BootOrder": "%00%00%01%00", "Boot0000": "zero", "Boot0001": "one"}, fail_del=["Boot0001"])
        result = self.nv("del", "0", "1")
        self.assert_code(result, 1)
        self.assertIn("未改 BootOrder", result.stdout)
        values = self.nv_values()
        self.assertNotIn("Boot0000", values)
        self.assertIn("Boot0001", values)
        self.assertEqual(values["BootOrder"], "%00%00%01%00")

    def test_nvram_delete_order_write_failure_is_nonzero(self):
        self.nvram_fixture({"BootOrder": "%00%00%01%00", "Boot0000": "zero", "Boot0001": "one"}, fail_set=["BootOrder"])
        result = self.nv("del", "1")
        self.assert_code(result, 1)
        self.assertIn("部分删除", result.stdout)

    def test_nvram_partial_restore_never_installs_order_for_failed_entries(self):
        backup = self.root / "nv-backup"; backup.mkdir()
        (backup / "Boot0000.txt").write_text("new zero")
        (backup / "Boot0001.txt").write_text("new one")
        (backup / "BootOrder.txt").write_text("%01%00")
        self.nvram_fixture({"BootOrder": "%00%00", "Boot0000": "old"}, fail_set=["Boot0001"])
        result = self.nv("restore", backup)
        self.assert_code(result, 1)
        self.assertIn("部分恢复", result.stdout)
        self.assertEqual(self.nv_values()["BootOrder"], "%00%00")

    def test_nvram_restore_order_failure_and_success(self):
        backup = self.root / "nv-backup"; backup.mkdir()
        (backup / "Boot0001.txt").write_text("new one")
        (backup / "BootOrder.txt").write_text("%01%00")
        self.nvram_fixture({"BootOrder": "%00%00"}, fail_set=["BootOrder"])
        self.assert_code(self.nv("restore", backup), 1)
        self.nvram_fixture({"BootOrder": "%00%00"})
        self.assert_code(self.nv("restore", backup), 0)
        self.assertEqual(self.nv_values()["BootOrder"], "%01%00")

    def test_nvram_dry_run_never_writes(self):
        before = {"BootOrder": "%00%00", "Boot0000": "old", "Boot0001": "orphan"}
        self.nvram_fixture(before)
        self.assert_code(self.add_nv("--dry-run"), 0)
        self.assertEqual(self.nv_values(), before)

    def test_nvram_read_failure_is_not_treated_as_a_free_or_absent_entry(self):
        before = {"BootOrder": "%00%00", "Boot0000": "old"}
        self.nvram_fixture(before, fail_get=["Boot0001"])
        self.assert_code(self.add_nv(), 1)
        self.assertEqual(self.nv_values(), before)
        self.assert_code(self.nv("del", "1"), 1)
        self.assertEqual(self.nv_values(), before)

    def mask_fixture(self, content="# user mount policy\nUUID=USER none hfs rw,noauto\n", **faults):
        directory = self.root / "fixture etc"; directory.mkdir(exist_ok=True)
        fstab = directory / "fstab"; fstab.write_text(content)
        self.mask_state = self.root / "disks.json"
        volumes = [
            {"dev": "disk99s1", "uuid": UUID, "name": "Data Disk $(literal)", "fs": "NTFS", "ptype": "Microsoft Basic Data"},
            {"dev": "disk99s2", "uuid": "BBBBBBBB-1111-2222-3333-444444444444", "name": "EFI", "fs": "MS-DOS FAT32", "ptype": "EFI"},
            {"dev": "disk99s3", "uuid": "CCCCCCCC-1111-2222-3333-444444444444", "name": "System", "fs": "APFS", "ptype": "Apple_APFS"},
        ]
        self.mask_state.write_text(json.dumps({"volumes": volumes, "counts": {}, **faults}))
        self.env["DISK_STATE"] = str(self.mask_state)
        self.fx.python_mock(self.fx.mockbin / "diskutil", r'''
import json, os, pathlib, sys
path = pathlib.Path(os.environ["DISK_STATE"]); state = json.loads(path.read_text()); args = sys.argv[1:]
with open(os.environ["MUTATION_LOG"], "a") as log: log.write("diskutil " + " ".join(args) + "\n")
if args[0] == "list":
    print("\n".join(v["dev"] for v in state["volumes"])); raise SystemExit(0)
volume = next((v for v in state["volumes"] if len(args) > 1 and v["dev"] == args[1]), None)
if volume is None: raise SystemExit("blocked unknown disk fixture")
if args[0] == "info":
    dev = volume["dev"]; state["counts"][dev] = state["counts"].get(dev, 0) + 1; path.write_text(json.dumps(state))
    uuid = volume["uuid"]
    if state.get("change_uuid") == dev and state["counts"][dev] >= 2: uuid = "DDDDDDDD-1111-2222-3333-444444444444"
    print("Volume UUID: " + uuid + "\nVolume Name: " + volume["name"] + "\nFile System Personality: " + volume["fs"] + "\nPartition Type: " + volume["ptype"] + "\nMount Point: /Volumes/" + volume["name"] + "\nMounted: Yes")
    raise SystemExit(0)
if args[0] == "unmount": raise SystemExit(1 if state.get("fail_unmount") == volume["dev"] else 0)
raise SystemExit("blocked disk operation")
''')
        isolated = self.root / "isolated-mask.sh"
        source = (SCRIPTS / "mask-other-disks.sh").read_text()
        pattern = "\nFSTAB=/etc/fstab\n"
        self.assertEqual(source.count(pattern), 1, "fstab isolation pattern changed")
        replacement = "\nFSTAB=" + "'" + str(fstab) + "'\n"
        source = source.replace(pattern, replacement)
        self.assertNotIn(pattern, source)
        self.assertIn(replacement, source)
        isolated.write_text(source)
        self.mask_script = isolated
        return fstab

    def mask(self, *args, **env):
        return self.run_script("mask-other-disks.sh", *args, script=self.mask_script, env=env)

    def mutation_log(self):
        path = Path(self.env["MUTATION_LOG"])
        return path.read_text() if path.exists() else ""

    def test_mask_dry_run_preserves_user_rules_and_spaced_names(self):
        fstab = self.mask_fixture(); original = fstab.read_bytes()
        result = self.mask()
        self.assert_code(result, 0)
        self.assertEqual(fstab.read_bytes(), original)
        self.assertIn("UUID=" + UUID + " none ntfs noauto", result.stdout)
        self.assertIn("Data Disk $(literal)", result.stdout)
        self.assertNotIn("UUID=Disk", result.stdout)
        self.assertNotIn("unmount", self.mutation_log())
        self.assertEqual(list(fstab.parent.glob("*.oc-mask-*")), [])

    def test_mask_apply_is_managed_idempotent_and_never_unmounts_efi(self):
        fstab = self.mask_fixture(); original = fstab.read_text()
        self.assert_code(self.mask("--apply"), 0)
        self.assertTrue(fstab.read_text().startswith(original))
        self.assertEqual(fstab.read_text().count(BEGIN), 1)
        self.assertIn("diskutil unmount disk99s1", self.mutation_log())
        self.assertNotIn("diskutil unmount disk99s2", self.mutation_log())
        self.assertNotIn("diskutil unmount disk99s3", self.mutation_log())
        self.assert_code(self.mask("--apply"), 0)
        self.assertEqual(fstab.read_text().count(BEGIN), 1)
        self.assertEqual(self.mutation_log().count("diskutil unmount disk99s1"), 1)
        backups = list(fstab.parent.glob("fstab.oc-mask-backup.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), original)

    def test_mask_undo_preserves_rules_before_and_after_block(self):
        before = "# before\nUUID=USER none hfs rw\n"; after = "# after\nUUID=OTHER none exfat noauto\n"
        fstab = self.mask_fixture(before + BEGIN + "\nUUID=MANAGED none ntfs noauto\n" + END + "\n" + after)
        self.assert_code(self.mask("--undo"), 0)
        self.assertEqual(fstab.read_text(), before + after)
        self.assertNotIn("diskutil", self.mutation_log())
        self.assert_code(self.mask("--undo"), 0)
        self.assertEqual(fstab.read_text(), before + after)

    def test_mask_unmarked_legacy_rules_are_not_deleted(self):
        original = "# unmarked old policy\nUUID=LEGACY none ntfs noauto\n"
        fstab = self.mask_fixture(original)
        self.assert_code(self.mask("--undo"), 0)
        self.assertEqual(fstab.read_text(), original)
        self.assertNotIn("diskutil", self.mutation_log())
        self.assertEqual(list(fstab.parent.glob("fstab.oc-mask-*")), [])

    def test_mask_keep_accepts_lowercase_uuid_and_missing_values_fail(self):
        fstab = self.mask_fixture(); original = fstab.read_bytes()
        self.assert_code(self.mask("--apply", "--keep", UUID.lower()), 0)
        self.assertEqual(fstab.read_bytes(), original)
        self.assertNotIn("unmount", self.mutation_log())
        self.assert_code(self.mask("--keep"), 2)
        self.assert_code(self.mask("--apply", "--undo"), 2)

    def test_mask_bad_markers_fail_without_writing(self):
        for content in (BEGIN + "\nmissing end\n", END + "\n", BEGIN + "\n" + END + "\n" + BEGIN + "\n" + END + "\n"):
            with self.subTest(content=content):
                fstab = self.mask_fixture(content)
                self.assert_code(self.mask("--apply"), 1)
                self.assertEqual(fstab.read_text(), content)
                self.assertNotIn("unmount", self.mutation_log())

    def test_mask_backup_and_pending_write_failures_leave_user_file_unchanged(self):
        fstab = self.mask_fixture(); original = fstab.read_bytes()
        for kind in ("fstab_backup", "fstab_pending"):
            with self.subTest(kind=kind):
                self.assert_code(self.mask("--apply", MOCK_COPY_FAIL=kind), 1)
                self.assertEqual(fstab.read_bytes(), original)
                self.assertNotIn("unmount", self.mutation_log())

    def test_mask_preserves_concurrent_user_changes(self):
        fstab = self.mask_fixture(); original = fstab.read_text()
        result = self.mask("--apply", MOCK_CONCURRENT_FSTAB=str(fstab))
        self.assert_code(result, 1)
        self.assertEqual(fstab.read_text(), original + "# concurrent user rule\n")
        self.assertNotIn("unmount", self.mutation_log())

    def test_mask_unmount_failure_reports_persisted_partial_state(self):
        fstab = self.mask_fixture(fail_unmount="disk99s1")
        result = self.mask("--apply")
        self.assert_code(result, 1)
        self.assertIn(BEGIN, fstab.read_text())
        self.assertIn("规则已写入", result.stdout)

    def test_mask_changed_device_identity_blocks_unmount(self):
        self.mask_fixture(change_uuid="disk99s1")
        result = self.mask("--apply")
        self.assert_code(result, 1)
        self.assertIn("UUID 已变化", result.stdout)
        self.assertNotIn("unmount", self.mutation_log())


if __name__ == "__main__":
    unittest.main(verbosity=2)
