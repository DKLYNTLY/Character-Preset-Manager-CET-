import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory
from time import perf_counter

from lupa import LuaRuntime

root = Path(__file__).resolve().parents[2]
mod = root / 'native/verification/reference'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
runtime = {state={}, helpers={}, log=function() end}
setmetatable(runtime, {__index=_G})
package.preload['modules/runtime'] = function() return runtime end
''')
for module in ['constants', 'filesystem', 'catalog', 'options', 'presets', 'view_cache']:
    lua.execute(f'dofile([[{mod.as_posix()}/{module}.lua]])')
runtime = lua.globals().runtime

def plain(value):
    if hasattr(value, 'items'):
        keys = list(value.keys())
        if keys and all(isinstance(key, int) for key in keys):
            return [plain(value[index]) for index in range(1, len(keys) + 1)]
        return {key: plain(item) for key, item in value.items()}
    return value

process = subprocess.Popen(
    [root / 'native/build-vs18/Release/CharacterPresetManagerCodecTests.exe'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding='utf-8',
)

def native(**request):
    process.stdin.write(json.dumps(request) + '\n')
    process.stdin.flush()
    return json.loads(process.stdout.readline())

cases = {
    'duplicate_keys': 'LocKey#1:2\nLocKey#1:3\n',
    'malformed_line': 'wrong line\nLocKey#2:4\n',
    'negative': 'LocKey#2:-1\n',
    'too_large_index': 'LocKey#2:4294967296\n',
    'too_many': 'LocKey#2:1\n' * 4097,
    'old_metadata': '# CPM\tformat\t7\n# CPM\tnotes\tA%20note\n# CPM\tslot\thair\n# CPM\tchoice\toptions%3Ahair1\nLocKey#4:2\n',
    'inactive': json.dumps({'options': [{'name': 'A', 'value': 1, 'isActive': False}, {'name': 'B', 'value': 3}]}),
    'inactive_snake': json.dumps({'values': [{'name': 'A', 'value': 1, 'is_active': False}, {'key': 'B', 'index': '3'}]}),
    'malformed_entries': json.dumps({'options': [None, False, 7, {}, {'name': 'A', 'value': 1.5}, {'name': 'B', 'value': 3}]}),
    'top_array': json.dumps([{'optionName': 'A', 'index': 3}, {'name': 'A', 'value': 4}]),
    'empty': '{}',
}
for path in (root / 'native/verification/fixtures').glob('*.preset'):
    cases[path.name] = path.read_text(encoding='utf-8')
for path in (root / 'source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/Character Presets/Default Presets').glob('*.preset'):
    cases[path.name] = path.read_text(encoding='utf-8')

try:
    with TemporaryDirectory() as directory:
        path = Path(directory) / 'parity.preset'
        checked = 0
        for name, contents in cases.items():
            path.write_text(contents, encoding='utf-8')
            before = path.read_bytes()
            for metadata_only in [False, True]:
                expected = plain(runtime.readPresetFile(path.as_posix(), metadata_only))
                actual = native(contents=contents, metadataOnly=metadata_only)
                assert expected == actual, (name, metadata_only, expected, actual)
                checked += 1
            assert path.read_bytes() == before, f'Read changed {name}'
        preset = {
            'format': 8, 'presetName': 'Round trip', 'libraryFolder': 'Tests',
            'notes': 'My notes', 'tags': 'hair', 'favorite': True,
            'entries': [{'key': 'LocKey#123', 'index': 3, 'slot': 'hairstyle', 'choice': 'options:hair-red', 'label': 'Hair'}],
        }
        written = native(operation='write', preset=preset)
        path.write_text(written, encoding='utf-8')
        expected = plain(runtime.readPresetFile(path.as_posix(), False))
        assert native(contents=written) == expected
        assert '# Format: 8' in written and '# Editor slot: hairstyle' in written
        assert '# Saved choice: options:hair-red' in written
        assert native(contents='{"options": [{"name": "A", "value": 01}]}') is None
        assert native(contents='[' * 18 + '1' + ']' * 18) is None
        print(f'Native/Lua parser parity: {checked} reads and format-8 round trip passed.')
        for size in [10, 1000]:
            start = perf_counter()
            for _ in range(size):
                runtime.readPresetFile(path.as_posix(), False)
            lua_ms = (perf_counter() - start) * 1000
            start = perf_counter()
            for _ in range(size):
                native(contents=written)
            native_ms = (perf_counter() - start) * 1000
            print(f'{size} parser calls: Lua file reads {lua_ms:.2f} ms; native with test-process transport {native_ms:.2f} ms. Not a game benchmark.')
finally:
    process.stdin.close()
    process.wait(timeout=10)
