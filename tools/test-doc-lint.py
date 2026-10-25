#!/usr/bin/env python3
"""Exercise lint exit statuses with isolated release fixtures; never edit the repo."""

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


TOOLS = Path(__file__).resolve().parent
NAME = "opencore-config-audit"
VERSION = "1.2.3"
FRONTMATTER = """---
name: opencore-config-audit
description: Review OpenCore configurations.
metadata:
  version: 1.2.3
---
[Guide](references/guide.md)
"""


class DocumentLintTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="skill-doc-lint-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.skill = self.root / NAME
        self.write(NAME + "/SKILL.md", FRONTMATTER)
        self.write(NAME + "/USAGE.md", "# Usage\n")
        self.write(NAME + "/references/guide.md", "Run `scripts/nested/check.sh`.\n")
        self.write(NAME + "/scripts/nested/check.sh", "#!/bin/bash\nexit 0\n")
        self.write("README.md", "[Usage](opencore-config-audit/USAGE.md)\n")
        self.write("USAGE.md", "[README](README.md)\n")
        self.write("PUBLISHING.md", "# Publish\n")
        self.plugin = {"name": NAME, "version": VERSION, "skills": ["./SKILL.md"]}
        self.market = {"plugins": [{"name": NAME, "version": VERSION, "source": "./" + NAME}]}
        self.write_metadata()

    def write(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def write_metadata(self):
        self.write(NAME + "/.codebuddy-plugin/plugin.json", json.dumps(self.plugin))
        self.write(".codebuddy-plugin/marketplace.json", json.dumps(self.market))

    def append(self, relative, content):
        path = self.root / relative
        self.write(relative, path.read_text(encoding="utf-8") + content)

    def run_lint(self, expected):
        result = subprocess.run([sys.executable, str(TOOLS / "doc-structure.py"), str(self.root)], capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def test_valid_transitive_nested_resources(self):
        self.run_lint(0)

    def test_external_urls_and_example_placeholders_are_ignored(self):
        self.append("README.md", "[External](https://example.invalid/scripts/missing.sh)\n[references/missing.md](https://example.invalid/?path=references/missing.md)\nhttps://example.invalid/?path=references/missing.md\n`references/<name>.md`\n")
        self.run_lint(0)

    def test_local_markdown_links_with_encoded_spaces_and_fragments(self):
        self.write("More details.md", "# Details\n")
        self.append("README.md", "[Details](More%20details.md#details)\n[Root](.)\n")
        self.run_lint(0)

    def test_missing_links_in_root_usage_and_publishing(self):
        for name in ("USAGE.md", "PUBLISHING.md"):
            with self.subTest(name=name):
                original = (self.root / name).read_text(encoding="utf-8")
                self.append(name, "[Missing](missing.md)\n")
                self.run_lint(1)
                self.write(name, original)

    def test_missing_nested_resource(self):
        (self.skill / "scripts/nested/check.sh").unlink()
        self.run_lint(1)

    def test_similar_filename_does_not_index_resource(self):
        self.write(NAME + "/references/check.sh-notes.md", "# Notes\n")
        self.append(NAME + "/SKILL.md", "[Notes](references/check.sh-notes.md)\n")
        self.write(NAME + "/references/guide.md", "The script check.sh is mentioned here.\n")
        self.run_lint(1)

    def test_repository_relative_resource_is_checked(self):
        self.append("README.md", "`opencore-config-audit/references/missing.md`\n")
        self.run_lint(1)

    def test_link_outside_repository_is_rejected(self):
        self.append("README.md", "[Outside](../outside.md)\n")
        self.run_lint(1)

    def test_symlink_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as other:
            target = Path(other) / "outside.md"
            target.write_text("outside", encoding="utf-8")
            (self.root / "linked.md").symlink_to(target)
            self.append("README.md", "[Outside](linked.md)\n")
            self.run_lint(1)

    def test_frontmatter_missing_delimiter_field_or_value(self):
        for broken in (FRONTMATTER.replace("---\n", "", 1), FRONTMATTER.rsplit("---\n", 1)[0], FRONTMATTER.replace("description: Review OpenCore configurations.\n", ""), FRONTMATTER.replace("Review OpenCore configurations.", "false"), FRONTMATTER.replace("Review OpenCore configurations.", '"')):
            with self.subTest(frontmatter=broken):
                self.write(NAME + "/SKILL.md", broken)
                self.run_lint(1)

    def test_duplicate_frontmatter_fields(self):
        for broken in (FRONTMATTER.replace("metadata:", "name: another-skill\nmetadata:"), FRONTMATTER.replace("  version: 1.2.3", "  version: 1.2.3\n  version: 1.2.3")):
            with self.subTest(frontmatter=broken):
                self.write(NAME + "/SKILL.md", broken)
                self.run_lint(1)

    def test_folded_description_and_legacy_version(self):
        self.write(NAME + "/SKILL.md", FRONTMATTER.replace("description: Review OpenCore configurations.", "description: >-\n  Review OpenCore configurations.").replace("metadata:\n  version:", "version:"))
        self.run_lint(0)

    def test_metadata_indentation_is_not_limited_to_two_spaces(self):
        self.write(NAME + "/SKILL.md", FRONTMATTER.replace("  version:", "    version:"))
        self.run_lint(0)

    def test_conflicting_version_declarations(self):
        self.write(NAME + "/SKILL.md", FRONTMATTER.replace("metadata:", "version: 9.0.0\nmetadata:"))
        self.run_lint(1)

    def test_release_name_path_and_version_must_match(self):
        mutations = (("name", "different-skill"), ("skills", ["./missing.md"]), ("skills", ["../README.md"]), ("version", "1.2.4"), ("version", None))
        for key, value in mutations:
            with self.subTest(key=key, value=value):
                original = self.plugin[key]
                self.plugin[key] = value
                self.write_metadata()
                self.run_lint(1)
                self.plugin[key] = original
        self.market["plugins"][0]["source"] = "./missing"
        self.write_metadata()
        self.run_lint(1)

    def test_duplicate_and_malformed_json_are_rejected(self):
        for value in ('{"name":"' + NAME + '","name":"' + NAME + '"}', "{"):
            with self.subTest(value=value):
                self.write(NAME + "/.codebuddy-plugin/plugin.json", value)
                self.run_lint(1)

    def test_wrapper_rejects_unknown_flags_and_preserves_scan_failure(self):
        for name in ("doc-lint.sh", "doc-structure.py"):
            destination = self.root / "tools" / name
            destination.parent.mkdir(exist_ok=True)
            shutil.copyfile(TOOLS / name, destination)
        command = ["bash", str(self.root / "tools/doc-lint.sh")]
        result = subprocess.run(command + ["--typo"], capture_output=True)
        self.assertEqual(result.returncode, 2)
        result = subprocess.run(command, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.append("README.md", "有线可为 en0。AirDrop 另见连续互通排障。\n")
        result = subprocess.run(command, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout)
        # A failed redact command must make the wrapper fail, not become a pass.
        self.write(NAME + "/scripts/redact-check.sh", "#!/bin/bash\nexit 2\n")
        self.append(NAME + "/references/guide.md", "Run `scripts/redact-check.sh`.\n")
        result = subprocess.run(command + ["--with-redact"], capture_output=True)
        self.assertEqual(result.returncode, 1, result.stdout)


if __name__ == "__main__":
    unittest.main()
