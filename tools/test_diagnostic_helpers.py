#!/usr/bin/env python3
"""Temporary fixtures for read-only diagnostics/downloads; no real hardware or network."""
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import unittest
import zipfile
import zlib

spec = importlib.util.spec_from_file_location('safety_fixtures', Path(__file__).with_name('test_script_safety.py'))
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)
SCRIPTS = fixtures.SCRIPTS


class DiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.ScriptSafetyTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        self.bin = self.fixture.mockbin
        self.env = self.fixture.env

    def run_script(self, name, *args, **kwargs):
        return self.fixture.run_script(name, *args, **kwargs)

    def test_redact_plain_xml_and_binary_serial_fields(self):
        for fmt in ('plain', 'xml', 'binary'):
            with self.subTest(fmt=fmt):
                target = self.root / fmt
                target.mkdir()
                path = target / 'config.plist'
                if fmt == 'plain':
                    path.write_text('SystemSerialNumber: SYNTHETIC123456\nBoardSerialNumber: SYNTHETICMLB123456\n')
                else:
                    path.write_bytes(plistlib.dumps({'PlatformInfo': {'Generic': {
                        'SystemSerialNumber': 'SYNTHETIC123456', 'MLB': 'SYNTHETICMLB123456'
                    }}}, fmt=plistlib.FMT_XML if fmt == 'xml' else plistlib.FMT_BINARY))
                result = self.run_script('redact-check.sh', target)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn('三码', result.stdout)
                self.assertNotIn('SYNTHETIC123456', result.stdout, 'Do not echo sensitive values')

    def test_public_guid_does_not_hide_secret_or_second_uuid_on_same_line(self):
        target = self.root / 'scan'
        target.mkdir()
        path = target / 'minified.json'
        path.write_text(json.dumps({'guid': '7C436110-AB2A-4BBB-A880-FE41995C9F82',
                                    'api_key': 'syntheticSecret123456',
                                    'uuid': '11111111-2222-3333-4444-555555555555'}))
        result = self.run_script('redact-check.sh', target)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('密钥 / token', result.stdout)
        self.assertIn('[UUID]', result.stdout)

    def test_redact_public_guid_and_explicit_placeholders_are_allowed(self):
        target = self.root / 'examples'
        target.mkdir()
        (target / 'example.txt').write_text('7C436110-AB2A-4BBB-A880-FE41995C9F82\nSystemSerialNumber: XXXXXXXXXXXX\nMLB: <your-mlb>\n')
        self.assertEqual(self.run_script('redact-check.sh', target).returncode, 0)
        self.assertEqual(self.run_script('redact-check.sh', self.root / 'missing').returncode, 2)

    def test_redact_structured_uuid_secret_and_rom(self):
        for fmt in (plistlib.FMT_BINARY, plistlib.FMT_XML):
            with self.subTest(fmt=fmt):
                target = self.root / ('bplist' if fmt == plistlib.FMT_BINARY else 'xmlplist')
                target.mkdir()
                path = target / 'config.plist'
                path.write_bytes(plistlib.dumps({
                    'public': '7C436110-AB2A-4BBB-A880-FE41995C9F82',
                    'api_key': 'syntheticSecret123456',
                    'SystemUUID': '11111111-2222-3333-4444-555555555555',
                    'ROM': bytes.fromhex('001122334455'),
                }, fmt=fmt))
                result = self.run_script('redact-check.sh', target)
                self.assertEqual(result.returncode, 1, result.stdout)
                for label in ('密钥 / token', 'UUID', 'ROM 地址'):
                    self.assertIn('['+label+']', result.stdout)
                self.assertNotIn('syntheticSecret123456', result.stdout)
                path.write_bytes(plistlib.dumps({'public': '7C436110-AB2A-4BBB-A880-FE41995C9F82', 'ROM': bytes(6)}, fmt=fmt))
                self.assertEqual(self.run_script('redact-check.sh', target).returncode, 0)

    def resource_fixture(self):
        resource = self.root / 'Resources'
        iconset = resource / 'Image/Vendor/Set'
        iconset.mkdir(parents=True)
        return resource, iconset

    def test_theme_empty_set_is_failure(self):
        resource, _ = self.resource_fixture()
        result = self.run_script('oc-theme-check.sh', resource)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('必需资源错误', result.stdout)

    def theme_complete(self):
        resource, iconset = self.resource_fixture()
        names = {'HardDrive': (128, 128), 'ExtHardDrive': (128, 128), 'Selected': (144, 144),
                 'Selector': (40, 40), 'SetDefault': (40, 40), 'Left': (40, 40), 'Right': (40, 40),
                 'Cursor': (16, 16), 'BtnFocus': (144, 144), 'Dot': (10, 10), 'Enter': (75, 30),
                 'Lock': (144, 144), 'Password': (288, 30), 'Restart': (128, 128), 'ShutDown': (128, 128)}
        for name, size in names.items():
            self.write_icon(iconset / (name + '.icns'), size)
        font = resource / 'Font'
        font.mkdir()
        for name in ('Font_1x.bin', 'Font_2x.bin'):
            (font / name).write_bytes(b'BMF\x03')
        for name in ('Font_1x.png', 'Font_2x.png'):
            (font / name).write_bytes(b'\x89PNG\r\n\x1a\n')
        label = resource / 'Label'
        label.mkdir()
        for name in ('EFIBoot', 'Apple', 'AppleRecv', 'AppleTM', 'Windows', 'Other', 'ResetNVRAM', 'SIPDisabled', 'SIPEnabled', 'Shell', 'FirmwareSettings', 'Tool', 'NetworkBoot'):
            for suffix in ('.lbl', '.l2x'):
                (label / (name + suffix)).write_bytes(b'fixture')
        return resource, iconset

    @staticmethod
    def write_icon(path, size_1x, size_2x=None):
        def png(size):
            width, height = size
            def chunk(kind, data):
                return (struct.pack('>I', len(data)) + kind + data
                        + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))
            return (b'\x89PNG\r\n\x1a\n'
                    + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
                    + chunk(b'IDAT', zlib.compress((b'\0' + bytes(width * 4)) * height))
                    + chunk(b'IEND', b''))
        records = b''
        for kind, size in ((b'ic07', size_1x), (b'ic13', size_2x)):
            if size is not None:
                payload = png(size)
                records += kind + struct.pack('>I', 8 + len(payload)) + payload
        path.write_bytes(b'icns' + struct.pack('>I', 8 + len(records)) + records)

    def test_theme_optional_missing_is_not_failure_but_required_size_is(self):
        resource, iconset = self.theme_complete()
        result = self.run_script('oc-theme-check.sh', resource)
        self.assertEqual(result.returncode, 0, result.stdout)
        (iconset / 'HardDrive.icns').write_bytes(b'bad')
        self.assertEqual(self.run_script('oc-theme-check.sh', resource).returncode, 1)

    def test_theme_missing_font_atlas_fails(self):
        resource, _ = self.theme_complete()
        (resource / 'Font/Font_2x.png').unlink()
        result = self.run_script('oc-theme-check.sh', resource)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('Font_2x.png: ★', result.stdout)

    def test_theme_variable_icons_accept_official_size_boundaries(self):
        resource, iconset = self.theme_complete()
        # Source: OpenCore 1.0.8 GuiApp.c AllowLessSize and GuiApp.h dimensions.
        for name, sizes in (
                ('Cursor', ((4, 4), (144, 144))),
                ('BtnFocus', ((1, 1), (144, 144))),
                ('Dot', ((1, 1), (10, 10))),
                ('Enter', ((1, 1), (75, 30))),
                ('Lock', ((1, 1), (144, 144))),
                ('Password', ((1, 1), (288, 30))),
                ('Restart', ((1, 1), (128, 128))),
                ('ShutDown', ((1, 1), (128, 128)))):
            for size in sizes:
                with self.subTest(icon=name, size=size):
                    self.write_icon(iconset / (name + '.icns'), size)
                    result = self.run_script('oc-theme-check.sh', resource)
                    self.assertEqual(result.returncode, 0, result.stdout)
        for size in ((1, 1), (40, 20), (144, 40)):
            with self.subTest(selector_size=size):
                for name in ('Selector', 'SetDefault'):
                    self.write_icon(iconset / (name + '.icns'), size)
                result = self.run_script('oc-theme-check.sh', resource)
                self.assertEqual(result.returncode, 0, result.stdout)

    def test_theme_out_of_range_icon_dimensions_fail(self):
        resource, iconset = self.theme_complete()
        for name, invalid_sizes in (
                ('HardDrive', ((127, 128), (128, 129))),
                ('ExtHardDrive', ((129, 128),)),
                ('Selected', ((143, 144),)),
                ('Left', ((40, 39),)), ('Right', ((41, 40),)),
                ('Cursor', ((3, 4), (4, 3), (145, 144))),
                ('BtnFocus', ((145, 144),)),
                ('Dot', ((11, 10), (10, 11))),
                ('Enter', ((76, 30), (75, 31))),
                ('Lock', ((144, 145),)),
                ('Password', ((289, 30), (288, 31))),
                ('Restart', ((129, 128),)), ('ShutDown', ((128, 129),)),
                ('Selector', ((145, 40), (144, 41), (1, 0))),
                ('SetDefault', ((145, 40), (144, 41)))):
            path = iconset / (name + '.icns')
            original = path.read_bytes()
            for size in invalid_sizes:
                with self.subTest(icon=name, size=size):
                    self.write_icon(path, size)
                    result = self.run_script('oc-theme-check.sh', resource)
                    self.assertEqual(result.returncode, 1, result.stdout)
                    self.assertIn('1x 尺寸应为', result.stdout)
            path.write_bytes(original)

    def test_theme_checks_each_present_scale_and_selector_widths(self):
        resource, iconset = self.theme_complete()
        # Variable icons need not fill their maximum box, at either scale.
        self.write_icon(iconset / 'Password.icns', (288, 30), (576, 60))
        self.write_icon(iconset / 'Selected.icns', (144, 144), (288, 288))
        self.write_icon(iconset / 'Dot.icns', (10, 10), (20, 20))
        for name in ('Selector', 'SetDefault'):
            self.write_icon(iconset / (name + '.icns'), (40, 20), (20, 20))
        self.assertEqual(self.run_script('oc-theme-check.sh', resource).returncode, 0)
        # AllowLessSize requires positive actual pixels; only the cursor has a
        # scaled minimum (4 pixels at 1x, 8 at 2x).
        self.write_icon(iconset / 'Dot.icns', (10, 10), (1, 1))
        self.write_icon(iconset / 'Cursor.icns', (4, 4), (8, 8))
        self.assertEqual(self.run_script('oc-theme-check.sh', resource).returncode, 0)
        self.write_icon(iconset / 'Cursor.icns', (4, 4), (7, 8))
        result = self.run_script('oc-theme-check.sh', resource)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('2x 尺寸应为', result.stdout)
        self.write_icon(iconset / 'Cursor.icns', (4, 4), (8, 8))
        self.write_icon(iconset / 'Password.icns', (288, 30), (576, 61))
        result = self.run_script('oc-theme-check.sh', resource)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('2x 尺寸应为', result.stdout)
        self.write_icon(iconset / 'Password.icns', (288, 30), (576, 60))
        self.write_icon(iconset / 'SetDefault.icns', (40, 20), (21, 20))
        result = self.run_script('oc-theme-check.sh', resource)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('2x Selector 宽', result.stdout)
        self.write_icon(iconset / 'SetDefault.icns', (41, 20), (20, 20))
        result = self.run_script('oc-theme-check.sh', resource)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('1x Selector 宽', result.stdout)

    def test_theme_networkboot_label_is_required_at_both_scales(self):
        resource, _ = self.theme_complete()
        for suffix in ('.lbl', '.l2x'):
            with self.subTest(suffix=suffix):
                path = resource / ('Label/NetworkBoot' + suffix)
                path.unlink()
                result = self.run_script('oc-theme-check.sh', resource)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn('NetworkBoot', result.stdout)
                path.write_bytes(b'fixture')

    def curl_mock(self):
        self.fixture.python_mock(self.bin / 'curl', '''
import json, os, pathlib, sys
args=sys.argv[1:]; url=next(x for x in args if x.startswith('https://'))
out=pathlib.Path(args[args.index('-o')+1])
with open(os.environ['MOCK_LOG'], 'a') as log: log.write(url+'\\n')
if os.environ.get('CURL_FAIL') == '1':
    out.write_text('partial'); sys.exit(22)
if 'api.github.com' in url:
    names=json.loads(os.environ.get('CURL_NAMES', '[]'))
    out.write_text(json.dumps([{'name': n, 'type': 'file'} for n in names]))
else:
    out.write_text(os.environ.get('CURL_BODY', 'fixture download'))
''')

    def test_audio_uses_requested_language_not_host_locale(self):
        self.curl_mock()
        target = self.root / 'resources with space'
        result = self.run_script('oc-fetch-iconset.sh', 'audio', 'zh_CN', target, env={
            'LANG': 'en_US.UTF-8', 'CURL_NAMES': json.dumps(['AXEFIAudio_Beep.mp3', 'AXEFIAudio_zh_CN_Welcome.mp3', 'AXEFIAudio_en_Welcome.mp3'])})
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue((target / 'Audio/AXEFIAudio_zh_CN_Welcome.mp3').exists())
        self.assertFalse((target / 'Audio/AXEFIAudio_en_Welcome.mp3').exists())

    def test_audio_matches_real_ocbinarydata_names_and_numeric_region(self):
        self.curl_mock()
        # Read-only inventory of OcBinaryData Resources/Audio, 2026-10-29.
        generic = {'AXEFIAudio_Beep.mp3', 'AXEFIAudio_Click.mp3', 'AXEFIAudio_VoiceOver_Boot.mp3'}
        localized = {
            'zh_CN': {'AXEFIAudio_zh_CN_Password.mp3', 'AXEFIAudio_zh_CN_VoiceOverOn.mp3'},
            'es_419': {'AXEFIAudio_es_419_VoiceOverOff.mp3'},
        }
        names = generic | localized['zh_CN'] | localized['es_419'] | {'AXEFIAudio_en_VoiceOverOff.mp3'}
        for language, expected in localized.items():
            with self.subTest(language=language):
                target = self.root / ('real-audio-' + language)
                result = self.run_script('oc-fetch-iconset.sh', 'audio', language, target, env={
                    'LANG': 'en_US.UTF-8', 'CURL_NAMES': json.dumps(sorted(names))})
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertEqual({p.name for p in (target / 'Audio').iterdir()}, generic | expected)

    def test_audio_rejects_invalid_language_before_downloading(self):
        self.curl_mock()
        for language in ('en/../other', 'es_419;bad', 'en_', '_en', 'es__419'):
            with self.subTest(language=language):
                target = self.root / 'must-not-be-created'
                result = self.run_script('oc-fetch-iconset.sh', 'audio', language, target)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertFalse(target.exists())
                self.assertFalse(self.fixture.calls.exists())

    def test_resource_failure_preserves_existing_file_and_is_nonzero(self):
        self.curl_mock()
        target = self.root / 'Resources'
        (target / 'Font').mkdir(parents=True)
        existing = target / 'Font/Font_1x.bin'
        existing.write_bytes(b'old valid font')
        result = self.run_script('oc-fetch-iconset.sh', 'font', target, env={'CURL_FAIL': '1'})
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertEqual(existing.read_bytes(), b'old valid font')
        self.assertFalse(list((target / 'Font').glob('.oc-download-*')))

    def test_empty_or_failed_api_list_is_nonzero(self):
        self.curl_mock()
        for mode, args in (('iconset', ('GoldenGate',)), ('label', ()), ('audio', ('zh_CN',))):
            for env in ({'CURL_NAMES': '[]'}, {'CURL_FAIL': '1'}):
                with self.subTest(mode=mode, env=env):
                    result = self.run_script('oc-fetch-iconset.sh', mode, *args, self.root / 'resources', env=env)
                    self.assertEqual(result.returncode, 1, result.stdout)

    def test_relative_docs_output_works_with_cached_zip(self):
        self.curl_mock()
        out = self.root / '_oc-docs-audit'
        out.mkdir()
        with zipfile.ZipFile(out / 'oc-1.0.8.zip', 'w') as archive:
            archive.writestr('Utilities/ocvalidate/ocvalidate', 'fixture')
        source = '\\section{Kernel}\n\\subsection{Properties}\n\\texttt{Fixture}\\\\\n\\textbf{Type}: string\n\\textbf{Description}: fixture\n\\end{enumerate}\n'
        self.fixture.executable(self.bin / 'xattr', 'exit 0\n')
        result = self.run_script('fetch-opencore-docs.sh', '1.0.8', env={'CURL_BODY': source})
        self.assertEqual(result.returncode, 0, result.stdout)
        keys = json.loads((out / 'oc-doc-keys.json').read_text())
        self.assertIn('Fixture', keys['Kernel']['Properties'])

    def test_bad_cpu_name_config_reports_failure_without_traceback(self):
        self.fixture.executable(self.bin / 'sysctl', 'echo fixture\n')
        self.fixture.executable(self.bin / 'system_profiler', "echo 'Processor Name: fixture'\n")
        self.fixture.executable(self.bin / 'nvram', 'exit 1\n')
        self.fixture.executable(self.bin / 'kmutil', 'echo RestrictEvents\n')
        path = self.root / 'broken.plist'
        path.write_text('not plist')
        result = self.run_script('cpu-name-check.sh', path)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertNotIn('Traceback', result.stdout)
        self.assertNotIn('4) 判读', result.stdout)

    def test_launchd_uses_boot_epoch_not_first_record(self):
        logfile = self.root / 'launchd.log'
        logfile.write_text('2026-10-28 10:00:00.000 WindowServer old\n2026-10-29 10:00:02.000 Dock new\n2026-10-29 10:00:03.000 WindowServer new\n')
        source = (SCRIPTS / 'boot-timeline.sh').read_text().split("<<'PYLAUNCH'\n", 1)[1].split('\nPYLAUNCH', 1)[0]
        source = source.replace('"/var/log/com.apple.xpc.launchd/launchd.log"', repr(str(logfile)))
        import datetime
        epoch = int(datetime.datetime(2026, 10, 29, 10).timestamp())
        result = subprocess.run([sys.executable, '-', str(epoch), 'ignored'], input=source,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn('2026-10-28', result.stdout)
        self.assertIn('+   2s', result.stdout)
        self.assertIn('WindowServer: 2026-10-29 10:00:03', result.stdout)

    def test_frequency_probe_really_runs_concurrently(self):
        probe = self.root / 'probe'
        state = self.root / 'concurrency.json'
        state.write_text(json.dumps({'active': 0, 'maximum': 0, 'calls': 0}))
        self.fixture.python_mock(probe, '''
import fcntl, json, os, time
path=os.environ['PROBE_STATE']
def update(delta):
    with open(path, 'r+') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        d=json.load(f); d['active']+=delta
        if delta > 0: d['calls']+=1
        d['maximum']=max(d['maximum'],d['active'])
        f.seek(0); json.dump(d,f); f.truncate()
update(1); time.sleep(.15); update(-1)
print('4.70', end='')
''')
        self.fixture.executable(self.bin / 'clang', 'while [ "$1" != -o ]; do shift; done\nshift\ncp "$PROBE_PROGRAM" "$1"\n')
        self.fixture.executable(self.bin / 'system_profiler', 'exit 0\n')
        result = self.run_script('cpu-freq-probe.sh', env={'PROBE_STATE': str(state), 'PROBE_PROGRAM': str(probe)})
        self.assertEqual(result.returncode, 0, result.stdout)
        actual = json.loads(state.read_text())
        self.assertEqual(actual['calls'], 9)
        self.assertGreater(actual['maximum'], 1)
        self.assertEqual(actual['active'], 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
