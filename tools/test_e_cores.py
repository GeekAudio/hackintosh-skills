#!/usr/bin/env python3
"""Run e-cores-check against synthetic sysctl data and a harmless probe stub."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "opencore-config-audit/scripts/e-cores-check.sh"


class ECoresTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="e-cores-fixture-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.calls = self.root / "calls.txt"
        self.script = self.root / SCRIPT.name
        shutil.copyfile(SCRIPT, self.script)
        self.data = {
            "hw.ncpu": 20,
            "hw.physicalcpu": 12,
            "hw.logicalcpu": 20,
            "hw.nperflevels": 1,
            "hw.perflevel0.physicalcpu": 12,
            "hw.perflevel0.logicalcpu": 20,
            "machdep.cpu.brand_string": "Fixture CPU",
            "machdep.cpu.core_count": 12,
            "machdep.cpu.thread_count": 20,
            "hw.model": "FixtureModel",
        }
        self.env = {
            "PATH": str(self.bin) + os.pathsep + os.defpath,
            "TEST_PYTHON": sys.executable,
            "TEST_DATA": str(self.root / "sysctl.json"),
            "TEST_CALLS": str(self.calls),
            "LC_ALL": "C",
        }
        self.executable("bin/sysctl", '''exec "$TEST_PYTHON" - "$@" <<'PY'
import json, os, sys
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write("sysctl " + " ".join(sys.argv[1:]) + "\\n")
with open(os.environ["TEST_DATA"]) as source:
    data = json.load(source)
key = sys.argv[-1]
if key not in data:
    sys.exit(1)
print(data[key])
PY
''')
        self.executable("bin/system_profiler", 'echo system_profiler >> "$TEST_CALLS"\necho "Processor Name: Fixture CPU"\n')
        self.executable("bin/kmutil", 'echo kmutil >> "$TEST_CALLS"\n[ "${TEST_KMUTIL_FAIL:-0}" = 0 ] || exit 1\necho "org.b00t0x.CpuTopologyRebuild"\n')
        self.executable("cpu-freq-probe.sh", 'echo probe >> "$TEST_CALLS"\nexit "${TEST_PROBE_RC:-0}"\n')
        for name in ("diskutil", "nvram", "sudo", "osascript"):
            self.executable("bin/" + name, 'echo forbidden >> "$TEST_CALLS"\nexit 99\n')

    def executable(self, relative, source):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\n" + source, encoding="utf-8")
        path.chmod(0o755)

    def run_check(self, *arguments, expected=0, env=None):
        Path(self.env["TEST_DATA"]).write_text(json.dumps(self.data), encoding="utf-8")
        result = subprocess.run(["/bin/sh", str(self.script), *arguments],
                                env={**self.env, **(env or {})}, cwd=self.root,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        self.assertNotIn("integer expression expected", result.stderr)
        if self.calls.exists():
            self.assertNotIn("forbidden", self.calls.read_text())
        return result

    def test_x86_twenty_threads_with_single_perflevel_matches_explicit_target(self):
        self.run_check("--expected-threads", "20")
        calls = self.calls.read_text().splitlines()
        self.assertIn("probe", calls)
        self.assertIn("kmutil", calls)

    def test_different_cpu_thread_count_has_no_twenty_thread_threshold(self):
        self.data.update({"hw.ncpu": 12, "hw.logicalcpu": 12, "hw.physicalcpu": 6})
        self.run_check("--expected-threads", "12")

    def test_missing_perflevel_and_optional_machdep_keys_are_not_failures(self):
        self.data = {key: value for key, value in self.data.items()
                     if "perflevel" not in key and not key.startswith("machdep.")}
        self.run_check("--topo", "--expected-threads", "20")

    def test_known_target_mismatch_fails_even_when_perflevel_is_one(self):
        self.data.update({"hw.ncpu": 16, "hw.logicalcpu": 16, "hw.physicalcpu": 8})
        self.run_check("--topo", "--expected-threads", "20", expected=1)

    def test_without_target_sixteen_threads_are_not_declared_a_failure(self):
        self.data.update({"hw.ncpu": 16, "hw.logicalcpu": 16, "hw.physicalcpu": 8})
        self.run_check("--topo")
        calls = self.calls.read_text().splitlines()
        self.assertNotIn("probe", calls)
        self.assertNotIn("kmutil", calls)

    def test_missing_or_malformed_required_cpu_count_fails(self):
        for value in (None, "invalid", 0):
            with self.subTest(value=value):
                if value is None:
                    self.data.pop("hw.logicalcpu", None)
                else:
                    self.data["hw.logicalcpu"] = value
                self.run_check("--topo", expected=1)

    def test_impossible_count_relationship_fails(self):
        self.data["hw.physicalcpu"] = 24
        self.run_check("--topo", expected=1)

    def test_topology_mode_does_not_execute_probe(self):
        self.run_check("--topo", env={"TEST_PROBE_RC": "7"})
        self.assertNotIn("probe", self.calls.read_text().splitlines())

    def test_frequency_probe_failure_is_propagated(self):
        self.run_check("--freq", expected=1, env={"TEST_PROBE_RC": "7"})
        self.assertEqual(self.calls.read_text().splitlines(), ["probe"])

    def test_unreadable_optional_kext_list_does_not_guess_e_core_state(self):
        self.run_check(env={"TEST_KMUTIL_FAIL": "1"})

    def test_bad_arguments_fail_before_any_hardware_query(self):
        for arguments in (("--expected-threads",), ("--expected-threads", "0"),
                          ("--expected-threads", "twenty"), ("--topo", "--freq"),
                          ("--unknown",)):
            with self.subTest(arguments=arguments):
                self.run_check(*arguments, expected=2)
                self.assertFalse(self.calls.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
