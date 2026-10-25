#!/usr/bin/env python3
"""Regression tests for OpenCore helpers, using temporary files and system mocks.

Run: python3 tools/test_script_safety.py
No test mounts disks, writes NVRAM, elevates privileges, or changes a live EFI.
"""

import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPTS = REPO / "opencore-config-audit" / "scripts"


class ScriptSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="opencore-script-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.mockbin = self.root / "bin"
        self.calls = self.root / "calls.log"
        self.env = os.environ.copy()
        for name in ("OC_ARCHIVE_DIR", "OC_DOCS_DIR", "PYTHON"):
            self.env.pop(name, None)
        self.env.update({
            "PATH": str(self.mockbin) + os.pathsep + os.defpath,
            "PYTHON": sys.executable,
            "TEST_PYTHON": sys.executable,
            "TEST_MOCK_BIN": str(self.mockbin),
            "TEST_SYSTEM_PATH": os.defpath,
            "MOCK_LOG": str(self.calls),
        })
        # Intercept every system-mutating command used by the helpers. The disk
        # commands below can only log calls or change MOCK_CONFIG in this tempdir.
        self.executable(self.mockbin / "sync", 'echo sync >> "$MOCK_LOG"\n')
        self.executable(self.mockbin / "osascript", 'echo osascript >> "$MOCK_LOG"; exit 1\n')
        self.executable(self.mockbin / "date", 'echo 20261025-120000\n')
        self.executable(self.mockbin / "nvram", 'echo nvram >> "$MOCK_LOG"; echo "opencore-version REL-999.0.0"\n')
        # toolcheck resets PATH in production. Its isolated test copy below
        # places these harmless probes first, so no user-installed tool runs.
        for name, version in (("git", "git version fixture"), ("iasl", "version 20261025"),
                              ("dot", "dot fixture"), ("shellcheck", "version: fixture"),
                              ("jq", "jq-fixture")):
            self.executable(self.mockbin / name,
                            'echo "probe ' + name + '" >> "$MOCK_LOG"; echo "' + version + '"\n')
        self.executable(self.mockbin / "python3", 'exec "$TEST_PYTHON" "$@"\n')
        self.executable(self.mockbin / "df", '''
if [ "${MOCK_ESP:-0}" = 1 ]; then
  printf 'Filesystem 512-blocks Used Available Capacity Mounted on\\n/dev/disk99s1 1 1 1 1%% /Volumes/MockEFI\\n'
else
  printf 'Filesystem 512-blocks Used Available Capacity Mounted on\\n/dev/disk99s2 1 1 1 1%% /tmp\\n'
fi
''')
        self.executable(self.mockbin / "diskutil", '''
echo "diskutil $*" >> "$MOCK_LOG"
case "$1" in
  info) printf 'Partition Type: EFI\\nDevice Identifier: disk99s1\\n';;
  unmount) exit "${MOCK_UNMOUNT_RC:-0}";;
  mount)
    [ "${MOCK_MOUNT_RC:-0}" = 0 ] || exit "$MOCK_MOUNT_RC"
    if [ "${MOCK_CORRUPT:-0}" = 1 ]; then printf '\\n' >> "$MOCK_CONFIG"; fi
    ;;
  *) exit 99;;
esac
''')
        self.python_mock(self.mockbin / "plutil", '''
import plistlib, sys
try:
    with open(sys.argv[-1], "rb") as source:
        data = plistlib.load(source)
    if "-extract" in sys.argv:
        print(data[sys.argv[sys.argv.index("-extract") + 1]])
except Exception as error:
    print(error)
    sys.exit(1)
''')
        self.python_mock(self.mockbin / "shasum", '''
import hashlib, os, sys
if os.environ.get("MOCK_HASH_FAIL") == "1":
    sys.exit(1)
with open(sys.argv[-1], "rb") as source:
    print(hashlib.sha256(source.read()).hexdigest(), sys.argv[-1])
''')
        self.python_mock(self.mockbin / "stat", '''
import os, sys
print(os.stat(sys.argv[-1]).st_size)
''')

    @staticmethod
    def executable(path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/bash\n" + body, encoding="utf-8")
        path.chmod(0o755)

    def python_mock(self, path, body):
        self.executable(path, 'exec "$TEST_PYTHON" - "$@" <<\'PY\'\n' + body + "\nPY\n")

    def run_script(self, name, *args, env=None, cwd=None):
        script = SCRIPTS / name
        if name in ("toolcheck.sh", "kext-inventory.sh"):
            # Preserve production behavior except PATH setup, which would put
            # real system/user probes before mocks. Never edit the source file.
            isolated = self.root / "isolated" / name
            isolated.parent.mkdir(exist_ok=True)
            isolated.write_text("".join(
                'export PATH="$TEST_MOCK_BIN:$TEST_SYSTEM_PATH"\n'
                if line.startswith("export PATH=") else line
                for line in script.read_text().splitlines(keepends=True)
            ))
            script = isolated
        result = subprocess.run(
            ["/bin/sh" if name == "kext-inventory.sh" else "/bin/bash", str(script), *map(str, args)],
            env={**self.env, **(env or {})}, cwd=cwd or self.root,
            encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=15,
        )
        return result

    def assert_code(self, result, code):
        self.assertEqual(result.returncode, code, result.stdout)

    def validator(self, docs, version="1.0.5"):
        binary = docs / ("oc" + version) / "Utilities/ocvalidate/ocvalidate"
        self.executable(binary, 'echo "validate $*" >> "$MOCK_LOG"; exit "${MOCK_VALIDATE_RC:-0}"\n')
        return binary

    def edit_fixture(self, validator=True, begin=True):
        work = self.root / "work"
        work.mkdir()
        config = work / "config.plist"
        config.write_bytes(plistlib.dumps({"Misc": {"Debug": {"Target": 0}}}))
        if validator:
            self.validator(work / "_oc-docs-audit")
        if begin:
            self.assert_code(self.run_script("oc-edit-safe.sh", "begin", config, work), 0)
        return work, config

    def verify_fixture(self):
        config = self.root / "config.plist"
        bundle = self.root / "Kexts/Test.kext"
        (bundle / "Contents/MacOS").mkdir(parents=True)
        data = {"ACPI": {"Add": []}, "Kernel": {"Add": [{
            "Enabled": True, "BundlePath": "Test.kext",
            "PlistPath": "Contents/Info.plist", "ExecutablePath": "Contents/MacOS/Test",
        }]}}
        config.write_bytes(plistlib.dumps(data))
        docs = self.root / "docs"
        self.validator(docs)
        return config, bundle, data, docs

    def inventory_fixture(self):
        target = self.root / "offline-efi"
        ocdir = target / "EFI/OC"
        bundle = ocdir / "Kexts/Fixture.kext"
        (bundle / "Contents/MacOS").mkdir(parents=True)
        (bundle / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleVersion": "1.2.3", "DTXcode": "1600", "DTSDKName": "macosx15.0",
            "CFBundleExecutable": "Fixture",
        }))
        (bundle / "Contents/MacOS/Fixture").write_bytes(b"fixture binary")
        config = ocdir / "config.plist"
        config.write_bytes(plistlib.dumps({"Kernel": {"Add": [{
            "BundlePath": "Fixture.kext", "Enabled": True,
        }]}}))
        return target, config

    def test_toolcheck_nonzero_version_probes_still_produce_json(self):
        ocdir = self.root / "official package"
        self.executable(ocdir / "Utilities/ocvalidate/ocvalidate", "echo 'OpenCore version 1.0.5'; exit 1\n")
        self.executable(ocdir / "Utilities/macserial/macserial", "echo 'macserial 2.1'; exit 1\n")
        result = self.run_script("toolcheck.sh", "--json", "--oc-dir", ocdir)
        self.assert_code(result, 0)
        tools = {tool["name"]: tool for tool in json.loads(result.stdout)["tools"]}
        self.assertEqual(tools["ocvalidate"]["version"], "OpenCore version 1.0.5")
        self.assertIn("shellcheck", tools)
        self.assertEqual(tools["git"]["path"], str(self.mockbin / "git"))
        self.assertIn("probe git", self.calls.read_text())

    def test_toolcheck_missing_directory_argument(self):
        for args in (("--oc-dir",), ("--oc-dir", "--json")):
            with self.subTest(args=args):
                result = self.run_script("toolcheck.sh", *args)
                self.assert_code(result, 2)
                self.assertIn("缺少目录参数", result.stdout)

    def test_verify_requires_kext_internal_files(self):
        config, bundle, _, docs = self.verify_fixture()
        result = self.run_script("oc-verify.sh", config, docs)
        self.assert_code(result, 1)
        self.assertIn("Contents/Info.plist ★缺失★", result.stdout)
        (bundle / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "test.fixture"}))
        (bundle / "Contents/MacOS/Test").write_bytes(b"fixture")
        self.assert_code(self.run_script("oc-verify.sh", config, docs), 0)

    def test_verify_accepts_codeless_and_disabled_missing_kexts(self):
        config, bundle, data, docs = self.verify_fixture()
        data["Kernel"]["Add"][0]["ExecutablePath"] = ""
        config.write_bytes(plistlib.dumps(data))
        info = bundle / "Contents/Info.plist"
        info.write_bytes(plistlib.dumps({"CFBundleIdentifier": "test.fixture"}))
        self.assert_code(self.run_script("oc-verify.sh", config, docs), 0)
        data["Kernel"]["Add"][0]["Enabled"] = False
        info.unlink()
        config.write_bytes(plistlib.dumps(data))
        self.assert_code(self.run_script("oc-verify.sh", config, docs), 0)

    def test_verify_rejects_directory_for_acpi_reference(self):
        config, _, data, docs = self.verify_fixture()
        data["Kernel"]["Add"] = []
        data["ACPI"]["Add"] = [{"Enabled": True, "Path": "SSDT.aml"}]
        (self.root / "ACPI/SSDT.aml").mkdir(parents=True)
        config.write_bytes(plistlib.dumps(data))
        self.assert_code(self.run_script("oc-verify.sh", config, docs), 1)

    def test_verify_hash_failure_propagates(self):
        config, _, data, docs = self.verify_fixture()
        data["Kernel"]["Add"] = []
        config.write_bytes(plistlib.dumps(data))
        result = self.run_script("oc-verify.sh", config, docs, env={"MOCK_HASH_FAIL": "1"})
        self.assert_code(result, 1)
        self.assertNotIn("结论: 校验通过", result.stdout)

    def test_verify_checks_enabled_drivers_and_tools(self):
        config, _, data, docs = self.verify_fixture()
        data["Kernel"]["Add"] = []
        data["UEFI"] = {"Drivers": [{"Enabled": True, "Path": "OpenRuntime.efi"}]}
        data["Misc"] = {"Tools": [{"Enabled": True, "Path": "Subdir/OpenShell.efi", "RealPath": True}]}
        config.write_bytes(plistlib.dumps(data))
        result = self.run_script("oc-verify.sh", config, docs)
        self.assert_code(result, 1)
        self.assertIn("Drivers/OpenRuntime.efi", result.stdout)
        self.assertIn("Tools/Subdir/OpenShell.efi", result.stdout)
        (self.root / "Drivers").mkdir()
        (self.root / "Drivers/OpenRuntime.efi").write_bytes(b"driver")
        (self.root / "Tools/Subdir").mkdir(parents=True)
        (self.root / "Tools/Subdir/OpenShell.efi").write_bytes(b"tool")
        self.assert_code(self.run_script("oc-verify.sh", config, docs), 0)
        (self.root / "Drivers/OpenRuntime.efi").unlink()
        (self.root / "Tools/Subdir/OpenShell.efi").unlink()
        data["UEFI"]["Drivers"][0]["Enabled"] = False
        data["Misc"]["Tools"][0]["Enabled"] = False
        config.write_bytes(plistlib.dumps(data))
        self.assert_code(self.run_script("oc-verify.sh", config, docs), 0)

    def test_verify_rejects_legacy_string_drivers_explicitly(self):
        config = self.root / "config.plist"
        config.write_bytes(plistlib.dumps({"UEFI": {"Drivers": ["OpenRuntime.efi"]}}))
        docs = self.root / "docs"
        self.validator(docs)
        result = self.run_script("oc-verify.sh", config, docs)
        self.assert_code(result, 1)
        self.assertIn("无法核对旧格式", result.stdout)
        self.assertNotIn("Traceback", result.stdout)

    def test_inventory_defaults_to_target_files_and_host_nvram_is_opt_in(self):
        target, _ = self.inventory_fixture()
        result = self.run_script("kext-inventory.sh", target)
        self.assert_code(result, 0)
        self.assertIn("Fixture.kext", result.stdout)
        self.assertIn("1.2.3", result.stdout)
        self.assertNotIn("REL-999", result.stdout)
        self.assertFalse(self.calls.exists(), "Offline inventory must not read host NVRAM")
        result = self.run_script("kext-inventory.sh", target, "--host-nvram")
        self.assert_code(result, 0)
        self.assertIn("REL-999.0.0", result.stdout)
        self.assertIn("不代表目标 EFI", result.stdout)
        self.assertIn("nvram", self.calls.read_text())

    def test_inventory_save_matches_stdout_and_preserves_failed_audit_status(self):
        target, config = self.inventory_fixture()
        saved = self.root / "versions.txt"
        result = self.run_script("kext-inventory.sh", target, "--save", saved)
        self.assert_code(result, 0)
        self.assertEqual(saved.read_text(), result.stdout)
        config.write_bytes(plistlib.dumps({"Kernel": {"Add": [{
            "BundlePath": "Missing.kext", "Enabled": True,
        }]}}))
        result = self.run_script("kext-inventory.sh", target, "--save", saved)
        self.assert_code(result, 1)
        self.assertEqual(saved.read_text(), result.stdout)
        self.assertIn("Missing.kext", saved.read_text())

    def test_inventory_bad_arguments_and_unwritable_save_are_errors(self):
        target, _ = self.inventory_fixture()
        for args in (("--config",), ("--save",), ("--save", "--tsv"),
                     ("--config", str(self.root / "missing.plist"))):
            with self.subTest(args=args):
                self.assert_code(self.run_script("kext-inventory.sh", target, *args), 2)
        self.assert_code(self.run_script("kext-inventory.sh", target, "--save", self.root), 2)

    def test_inventory_disabled_missing_kext_is_informational(self):
        target, config = self.inventory_fixture()
        config.write_bytes(plistlib.dumps({"Kernel": {"Add": [{
            "BundlePath": "Disabled.kext", "Enabled": False,
        }]}}))
        result = self.run_script("kext-inventory.sh", target)
        self.assert_code(result, 0)
        self.assertIn("Disabled.kext（已禁用）", result.stdout)
        self.assertIn("启用引用 0 缺失", result.stdout)

    def test_inventory_malformed_config_is_not_reported_as_success(self):
        target, config = self.inventory_fixture()
        config.write_bytes(b"invalid plist")
        result = self.run_script("kext-inventory.sh", target)
        self.assert_code(result, 1)
        self.assertIn("读不了 config", result.stdout)

    def test_verify_rejects_ambiguous_validators_and_accepts_exact_package(self):
        config, _, data, docs = self.verify_fixture()
        data["Kernel"]["Add"] = []
        config.write_bytes(plistlib.dumps(data))
        self.validator(docs, "1.0.6")
        result = self.run_script("oc-verify.sh", config, docs)
        self.assert_code(result, 1)
        self.assertIn("多个 ocvalidate", result.stdout)
        self.assertFalse(self.calls.exists(), "Ambiguous candidates must not be executed")
        self.assert_code(self.run_script("oc-verify.sh", config, docs / "oc1.0.5"), 0)

    def test_verify_autodiscovery_deduplicates_same_directory(self):
        config = self.root / "config.plist"
        config.write_bytes(plistlib.dumps({}))
        self.validator(self.root / "_oc-docs-audit")
        self.assert_code(self.run_script("oc-verify.sh", config, cwd=self.root), 0)
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        self.validator(elsewhere / "_oc-docs-audit", "1.0.6")
        result = self.run_script("oc-verify.sh", config, cwd=elsewhere)
        self.assert_code(result, 1)
        self.assertIn("多个 ocvalidate", result.stdout)

    def test_finish_requires_begin_and_intact_backup(self):
        work, config = self.edit_fixture(begin=False)
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work), 1)
        self.assertFalse((work / "_oc-current.plist").exists())
        self.assert_code(self.run_script("oc-edit-safe.sh", "begin", config, work), 0)
        state = work / ".oc-edit-baseline"
        backup = Path(state.read_text().splitlines()[1])
        backup.write_bytes(backup.read_bytes() + b"\n")
        result = self.run_script("oc-edit-safe.sh", "finish", config, work)
        self.assert_code(result, 1)
        self.assertIn("备份 SHA", result.stdout)
        backup.unlink()
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work), 1)
        self.assertFalse(self.calls.exists())

    def test_finish_rejects_hash_only_legacy_or_wrong_config_state(self):
        work, config = self.edit_fixture()
        state = work / ".oc-edit-baseline"
        complete = state.read_text()
        state.write_text(complete.splitlines()[0])
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work), 1)
        state.write_text(complete)
        other = work / "other.plist"
        other.write_bytes(config.read_bytes())
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", other, work), 1)
        self.assertFalse((work / "_oc-current.plist").exists())

    def test_same_second_begin_keeps_distinct_backups_and_label_fallback(self):
        work, config = self.edit_fixture()
        state = work / ".oc-edit-baseline"
        first = Path(state.read_text().splitlines()[1])
        original = first.read_bytes()
        config.write_bytes(plistlib.dumps({"Misc": {"Debug": {"Target": 1}}}))
        self.assert_code(self.run_script("oc-edit-safe.sh", "begin", config, work), 0)
        second = Path(state.read_text().splitlines()[1])
        self.assertNotEqual(first, second)
        self.assertEqual(first.read_bytes(), original)
        self.assertEqual(second.read_bytes(), config.read_bytes())
        result = self.run_script("oc-edit-safe.sh", "finish", config, work, "renamed")
        self.assert_code(result, 0)
        self.assertIn("基线: " + str(second), result.stdout)
        self.assertTrue((work / "oc-config-archive/config.plist.v1-renamed").exists())

    def test_finish_stops_on_missing_or_failed_official_validator(self):
        work, config = self.edit_fixture(validator=False)
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work), 1)
        self.assertFalse((work / "_oc-current.plist").exists())
        self.assertFalse(self.calls.exists())
        self.validator(work / "_oc-docs-audit")
        result = self.run_script("oc-edit-safe.sh", "finish", config, work, env={"MOCK_VALIDATE_RC": "1"})
        self.assert_code(result, 1)
        self.assertFalse((work / "_oc-current.plist").exists())
        self.assertNotIn("sync", self.calls.read_text())

    def test_finish_rejects_ambiguous_validators_and_accepts_explicit_package(self):
        work, config = self.edit_fixture()
        self.validator(work / "_oc-docs-audit", "1.0.6")
        result = self.run_script("oc-edit-safe.sh", "finish", config, work)
        self.assert_code(result, 1)
        self.assertIn("多个 ocvalidate", result.stdout)
        self.assertFalse((work / "_oc-current.plist").exists())
        self.assertFalse(self.calls.exists())
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work,
                                        env={"OC_DOCS_DIR": str(work / "_oc-docs-audit/oc1.0.5")}), 0)

    def test_finish_archive_sequence_and_custom_directory(self):
        work, config = self.edit_fixture()
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work, "first"), 0)
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work, "second.v999"), 0)
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work, "third"), 0)
        self.assertEqual((work / "_oc-current.plist").read_bytes(), config.read_bytes())
        archive = work / "oc-config-archive"
        self.assertTrue((archive / "config.plist.v1-first").exists())
        self.assertTrue((archive / "config.plist.v2-second.v999").exists())
        self.assertTrue((archive / "config.plist.v3-third").exists())
        custom = self.root / "custom archive"
        self.assert_code(self.run_script("oc-edit-safe.sh", "finish", config, work,
                                        env={"OC_ARCHIVE_DIR": str(custom)}), 0)
        self.assertTrue((custom / "config.plist.v1-edit").exists())
        self.assertNotIn("diskutil", self.calls.read_text(), "A workspace copy must never trigger disk actions")

    def test_mocked_remount_hash_mismatch_fails(self):
        work, config = self.edit_fixture()
        result = self.run_script("oc-edit-safe.sh", "finish", config, work, env={
            "MOCK_ESP": "1", "MOCK_CONFIG": str(config), "MOCK_CORRUPT": "1",
        })
        self.assert_code(result, 1)
        self.assertIn("重挂后 sha 不一致", result.stdout)
        self.assertIn("diskutil mount disk99s1", self.calls.read_text())

    def test_mocked_unmount_failure_never_attempts_mount(self):
        work, config = self.edit_fixture()
        result = self.run_script("oc-edit-safe.sh", "finish", config, work,
                                 env={"MOCK_ESP": "1", "MOCK_UNMOUNT_RC": "1"})
        self.assert_code(result, 1)
        self.assertIn("无法卸载", result.stdout)
        self.assertNotIn("diskutil mount ", self.calls.read_text())

    def test_mocked_mount_failure_propagates(self):
        work, config = self.edit_fixture()
        result = self.run_script("oc-edit-safe.sh", "finish", config, work,
                                 env={"MOCK_ESP": "1", "MOCK_MOUNT_RC": "1"})
        self.assert_code(result, 1)
        self.assertIn("无法重挂", result.stdout)
        self.assertIn("osascript", self.calls.read_text())

    def test_scripts_parse_with_system_bash(self):
        for name in ("toolcheck.sh", "oc-verify.sh", "oc-edit-safe.sh", "kext-inventory.sh"):
            with self.subTest(script=name):
                shell = "/bin/sh" if name == "kext-inventory.sh" else "/bin/bash"
                result = subprocess.run([shell, "-n", str(SCRIPTS / name)],
                                        encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                self.assert_code(result, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
