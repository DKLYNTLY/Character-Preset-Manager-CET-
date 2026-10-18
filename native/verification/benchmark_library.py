import json
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory
from time import perf_counter, sleep

from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[2]
reference = root / 'native/verification/reference'
measurements = []

def milliseconds(function):
    start = perf_counter()
    value = function()
    return (perf_counter() - start) * 1000, value

with TemporaryDirectory(prefix='cpm-benchmark-') as temporary:
    for size in [64, 2048]:
        workspace = Path(temporary) / str(size)
        old = workspace / 'old'
        current = workspace / 'current'
        for manager in [old, current]:
            (manager / 'Character Presets').mkdir(parents=True)
            (manager / 'Data/Catalog').mkdir(parents=True)
        process = subprocess.Popen([root / 'native/build-vs18/Release/CharacterPresetManagerOperationServer.exe', current],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding='utf-8')

        def command(**request):
            process.stdin.write(json.dumps(request) + '\n')
            process.stdin.flush()
            return json.loads(process.stdout.readline())

        session = command(method='begin')['session']

        def native(action, **payload):
            submitted = command(method='submit', session=session, action=action, payload=json.dumps(payload))
            assert submitted.get('accepted'), submitted
            while True:
                result = command(method='poll', session=session, operation=submitted['operation'], consume=True)
                assert result.get('accepted'), result
                if result['status'] in ['complete', 'failed', 'canceled']:
                    assert result['status'] == 'complete', result
                    return result['result']
                sleep(0.0001)

        try:
            contents = native('encode', preset={'entries': [
                {'key': f'LocKey#{index}', 'index': index % 4, 'slot': f'slot{index}', 'label': f'Option {index}'}
                for index in range(16)], 'tags': 'benchmark', 'presetName': 'Example'})['contents']
            for index in range(size):
                path = old / f'Character Presets/Group {index % 32:02d}/Preset {index:04d}.preset'
                path.parent.mkdir(exist_ok=True)
                path.write_text(contents, encoding='utf-8')
            shutil.copytree(old / 'Character Presets', current / 'Character Presets', dirs_exist_ok=True)
            lua = LuaRuntime(unpack_returned_tuples=True)
            lua.execute('''
runtime={helpers={},log=function() end}
setmetatable(runtime,{__index=_G})
package.preload['modules/runtime']=function() return runtime end
''')
            for name in ['constants', 'state', 'filesystem', 'native_catalog', 'catalog', 'options', 'presets', 'view_cache']:
                lua.execute(f'dofile([[{reference.as_posix()}/{name}.lua]])')
            runtime = lua.globals().runtime
            runtime.PRESET_DIR = (old / 'Character Presets').as_posix()
            runtime.CATALOG_FILE = (old / 'Data/Catalog/Virtual Folders.txt').as_posix()
            runtime.INVENTORY_FILE = (old / 'Data/Catalog/Preset Inventory.txt').as_posix()
            runtime.NATIVE_FILE_CATALOG = (old / 'Data/Catalog/Native File Catalog.txt').as_posix()
            runtime.log = lambda *args: None

            def list_directory(path):
                folder = Path(path)
                return lua.table_from([{'name': item.name, 'type': 'directory' if item.is_dir() else 'file'}
                    for item in folder.iterdir()], recursive=True) if folder.is_dir() else lua.table()

            lua.globals().dir = list_directory
            old_start, result = milliseconds(lambda: runtime.refreshPresets('startup'))
            assert result[1], result
            new_start, fresh = milliseconds(lambda: native('refresh'))
            assert fresh['count'] == size
            inventory_ms, _ = milliseconds(lambda: native('inventory', revision=fresh['revision']))
            new_start += inventory_ms
            runtime.state.app.ready = True
            old_refresh, result = milliseconds(lambda: runtime.refreshPresets('external'))
            assert result[1], result
            new_refresh, _ = milliseconds(lambda: native('refresh'))
            runtime.state.library.searchText = 'benchmark'
            old_search, _ = milliseconds(lambda: runtime.helpers.rebuildFilteredViewCache())
            new_search, results = milliseconds(lambda: native('query', query='benchmark', limit=256))
            assert results['total'] == size and len(runtime.state.cache.filteredPresetNames) == size
            cached_search, _ = milliseconds(lambda: native('query', query='benchmark', limit=256))
            row = {'presets': size, 'entries_each': 16, 'lua_first_refresh_ms': round(old_start, 3),
                'native_first_refresh_and_inventory_ms': round(new_start, 3),
                'lua_unchanged_refresh_ms': round(old_refresh, 3), 'native_unchanged_refresh_ms': round(new_refresh, 3),
                'lua_search_and_sort_ms': round(old_search, 3), 'native_search_and_sort_ms': round(new_search, 3),
                'native_cached_search_ms': round(cached_search, 3)}
            measurements.append(row)
            print(json.dumps(row))
        finally:
            process.stdin.close()
            process.wait(timeout=10)

output = root / 'native/verification/performance.json'
output.write_text(json.dumps({'scope': 'Offline Windows fixture benchmark; includes test transport. Not in-game startup, editor, or load timings.',
    'results': measurements}, indent=2) + '\n', encoding='utf-8')
