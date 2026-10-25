#!/usr/bin/env python3
"""Read-only local-reference and release-metadata checks (Python standard library).

This checks the required scalar frontmatter fields, not the whole YAML language;
skill-creator's quick_validate.py remains the full skill-schema check.
"""

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


RESOURCE = re.compile(r"(?<![\w/.:~-])((?:opencore-config-audit/)?(?:references|scripts)/(?:[\w.-]+/)*[\w.-]+\.[\w-]+)")
LINK = re.compile(r"!?\[[^\]\n]*\]\(\s*(?:<([^>]+)>|([^\s)]+))(?:\s+[\"'][^\n]*?[\"'])?\s*\)")
CODE = re.compile(r"`([^`\n]+)`")
SEMVER = re.compile(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\Z")


class Checks:
    def __init__(self, root):
        self.root = root.resolve()
        self.skill = self.root / "opencore-config-audit"
        self.errors = 0

    def bad(self, message):
        print("   ✗ " + message)
        self.errors += 1

    def label(self, path):
        return str(path.relative_to(self.root))

    def load_json(self, path):
        def unique_pairs(pairs):
            result = {}
            for key, value in pairs:
                if key in result:
                    raise ValueError("重复键：" + key)
                result[key] = value
            return result

        try:
            value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_pairs)
            if not isinstance(value, dict):
                raise ValueError("顶层必须是对象")
            return value
        except (OSError, ValueError) as error:
            self.bad("{}：{}".format(self.label(path), error))
            return {}

    def frontmatter(self, text):
        match = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", text, re.S)
        if not match:
            self.bad("SKILL.md 缺少完整的 frontmatter 分隔符")
            return {}
        fields = {}
        current = None
        for line in match.group(1).splitlines():
            key = re.match(r"^([\w-]+):\s*(.*)$", line)
            if key:
                current, value = key.groups()
                if current in fields:
                    self.bad("SKILL.md frontmatter 重复键：" + current)
                fields[current] = [value]
            elif current and line[:1].isspace():
                fields[current].append(line)

        def scalar(key, lines):
            value = lines[0].strip()
            if value in ("|", "|-", "|+", ">", ">-", ">+"):
                value = " ".join(line.strip() for line in lines[1:])
            elif value.startswith('"'):
                try:
                    value = json.loads(value)
                except ValueError:
                    self.bad("SKILL.md {}：双引号字符串无效".format(key))
                    return None
            elif value.startswith("'"):
                if not value.endswith("'") or len(value) < 2:
                    self.bad("SKILL.md {}：单引号未闭合".format(key))
                    return None
                value = value[1:-1].replace("''", "'")
            else:
                value = re.split(r"\s+#", value, maxsplit=1)[0].rstrip()
                if re.search(r":\s", value) or value.startswith(("[", "{", "&", "*", "!")):
                    self.bad("SKILL.md {}：应为字符串，特殊字符请用引号包裹".format(key))
                    return None
                if value.lower() in ("null", "~", "true", "false", "yes", "no", "on", "off") or re.fullmatch(r"[-+]?\d+(?:\.\d+)?", value):
                    self.bad("SKILL.md {}：应为字符串".format(key))
                    return None
            if not isinstance(value, str) or not value.strip():
                self.bad("SKILL.md {}：不能为空".format(key))
                return None
            return value

        result = {}
        for key in ("name", "description"):
            if key not in fields:
                self.bad("SKILL.md frontmatter 缺少 " + key)
            else:
                result[key] = scalar(key, fields[key])
        if result.get("name") != self.skill.name:
            self.bad("SKILL.md name 必须与技能目录名一致")

        # Current layout uses metadata.version; top-level version is accepted for
        # older releases, but two conflicting declarations must never pass.
        versions = []
        if "version" in fields:
            versions.append(scalar("version", fields["version"]))
        metadata_keys = set()
        metadata_lines = fields.get("metadata", [])[1:]
        indents = [len(line) - len(line.lstrip(" ")) for line in metadata_lines if re.match(r"^ +[\w-]+:", line)]
        indent = min(indents) if indents else 2
        for line in metadata_lines:
            field = re.match(r"^ {%d}([\w-]+):\s*(.*)$" % indent, line)
            if not field:
                continue
            key, value = field.groups()
            if key in metadata_keys:
                self.bad("SKILL.md metadata 重复键：" + key)
            metadata_keys.add(key)
            if key == "version":
                versions.append(scalar("metadata.version", [value]))
        if not versions:
            self.bad("SKILL.md 缺少 metadata.version")
        elif any(value != versions[0] for value in versions):
            self.bad("SKILL.md version 与 metadata.version 冲突")
        result["version"] = versions[-1] if versions else None
        return result

    def metadata(self, text):
        print("\n── C1  frontmatter 必需字段 / 发布清单 / 版本同步 ──")
        initial = self.errors
        frontmatter = self.frontmatter(text)
        plugin = self.load_json(self.skill / ".codebuddy-plugin/plugin.json")
        market = self.load_json(self.root / ".codebuddy-plugin/marketplace.json")
        entries = market.get("plugins", [])
        if not isinstance(entries, list) or any(not isinstance(entry, dict) for entry in entries):
            self.bad("marketplace.json plugins 必须是对象数组")
            entries = []
        matches = [entry for entry in entries if entry.get("name") == self.skill.name]
        if len(matches) != 1:
            self.bad("marketplace.json 应且仅应有一条 " + self.skill.name)
        entry = matches[0] if matches else {}
        if plugin.get("name") != self.skill.name:
            self.bad("plugin.json name 必须与技能目录名一致")
        source = entry.get("source")
        if not isinstance(source, str) or (self.root / source).resolve() != self.skill:
            self.bad("marketplace.json source 未指向当前技能目录")
        skills = plugin.get("skills")
        if not isinstance(skills, list) or not skills or any(not isinstance(path, str) for path in skills):
            self.bad("plugin.json skills 必须是非空路径数组")
        else:
            resolved = [(self.skill / path).resolve() for path in skills]
            if self.skill / "SKILL.md" not in resolved:
                self.bad("plugin.json skills 未包含当前 SKILL.md")
            for path in resolved:
                if self.skill not in path.parents or not path.is_file():
                    self.bad("plugin.json skills 引用不存在或位于插件之外：" + str(path))
        versions = {
            "SKILL.md": frontmatter.get("version"),
            "plugin.json": plugin.get("version"),
            "marketplace.json": entry.get("version"),
        }
        for name, version in versions.items():
            print("      {:<18} {}".format(name, version))
        values = list(versions.values())
        if any(not isinstance(value, str) or not SEMVER.fullmatch(value) for value in values):
            self.bad("三处版本号都必须是有效的 x.y.z 字符串")
        elif len(set(values)) != 1:
            self.bad("版本号不一致，发布前必须对齐")
        if initial == self.errors:
            print("   ✓ 必需字段、发布路径与版本一致")

    def references(self, docs):
        print("\n── B1  本地链接 / 资源存在性 / 从 SKILL.md 可发现性 ──")
        initial = self.errors
        graph = {}
        for path in docs:
            if self.root not in path.resolve().parents:
                self.bad("文档软链接越出仓库：" + self.label(path))
                continue
            text = path.read_text(encoding="utf-8")
            targets = graph.setdefault(path, set())
            # Markdown links are document-relative. Inline references/scripts
            # commands are conventionally skill-root-relative in this project.
            for number, line in enumerate(text.splitlines(), 1):
                if "doc-lint:ignore" in line:
                    continue
                prose = LINK.sub("", line)
                prose = re.sub(r"\b[A-Za-z][A-Za-z0-9+.-]*://\S+", "", prose)
                local = [(match.group(1), self.root if match.group(1).startswith(self.skill.name + "/") else self.skill) for match in RESOURCE.finditer(prose)]
                for match in LINK.finditer(line):
                    target = match.group(1) or match.group(2)
                    parsed = urlsplit(target)
                    if not parsed.scheme and not parsed.netloc and parsed.path:
                        local.append((unquote(parsed.path), path.parent))
                # Bare .md filenames in inline code are sibling references in
                # references/, but can name third-party docs elsewhere.
                if path.parent == self.skill / "references":
                    local += [(value, path.parent) for value in CODE.findall(line) if re.fullmatch(r"[\w.-]+\.md", value) and (path.parent / value).is_file()]
                for target, base in local:
                    resolved = (base / target).resolve()
                    if resolved != self.root and self.root not in resolved.parents:
                        self.bad("{}:{} 本地引用越出仓库：{}".format(self.label(path), number, target))
                    elif not resolved.exists():
                        self.bad("{}:{} 死链：{}".format(self.label(path), number, target))
                    else:
                        targets.add(resolved)
                if re.match(r"^- `(?:references|scripts)/", line) and len(re.findall(r"- `(?:references|scripts)/", line)) > 1:
                    self.bad("{}:{} 资源条目粘连".format(self.label(path), number))
        discovered = set()
        pending = [self.skill / "SKILL.md"]
        while pending:
            path = pending.pop()
            if path not in discovered:
                discovered.add(path)
                pending.extend(graph.get(path, ()))
        resources = list((self.skill / "references").rglob("*.md"))
        resources += [path for path in (self.skill / "scripts").rglob("*") if path.is_file() and not path.name.startswith(".")]
        for path in sorted(resources):
            if path.resolve() not in discovered:
                self.bad("从 SKILL.md 无法发现：" + self.label(path))
        if initial == self.errors:
            print("   ✓ 本地链接有效，全部 reference / script 可发现")

    def run(self):
        docs = sorted(set(self.root.glob("*.md")) | set(self.skill.rglob("*.md")))
        skill_md = self.skill / "SKILL.md"
        if not skill_md.is_file():
            self.bad("缺少 opencore-config-audit/SKILL.md")
            return 1
        self.references(docs)
        self.metadata(skill_md.read_text(encoding="utf-8"))
        return 1 if self.errors else 0


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).resolve().parent.parent
    sys.exit(Checks(root).run())
