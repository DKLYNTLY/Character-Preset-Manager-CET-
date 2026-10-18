import json
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[2]
mod = root / 'native/verification/reference'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
runtime = {state={}, helpers={}, log=function() end}
setmetatable(runtime, {__index=_G})
package.preload['modules/runtime'] = function() return runtime end
function upvalue(fn, wanted)
  for index = 1, 100 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return value end
  end
  error('Missing reader: ' .. wanted)
end
''')
for module in ['constants', 'filesystem', 'catalog', 'presets', 'view_cache', 'bundles', 'backup']:
    lua.execute(f'dofile([[{mod.as_posix()}/{module}.lua]])')
bundle_reader = lua.globals().upvalue(lua.globals().runtime.viewSelectedFolderBundleContents, 'inspectFolderBundle')
backup_reader = lua.globals().upvalue(lua.globals().runtime.importLibraryBackup, 'readBackup')
payload = 'LocKey#1:3\n'.encode().hex().upper()
cases = [
    (False, f'CPMFOLDER\t1\nROOT\tShared\nF\tEmpty\nP\tOld\t{payload}\n'),
    (False, f'\nCPMFOLDER\t1\nROOT\t100%Good\nP\tOld\t{payload}\n'),
    (False, f'CPMFOLDER\t1\r\nROOT\tShared\r\nP\tNested/Old\t{payload}\r\n'),
    (True, f'CPMBACKUP\t1\nCONFIG\t\nF\tEmpty\nP\tOld\t{payload}\n'),
    (True, f'CPMBACKUP\t1\nCONFIG\t706172743D310A\nP\tOld\t{payload}\n'),
]
for backup in [False, True]:
    header = 'CPMBACKUP\t1\nCONFIG\t\n' if backup else 'CPMFOLDER\t1\nROOT\tShared\n'
    for tail in ['P\t../Unsafe\t41\n', 'P\tA\t4G\n', 'P\tA\t4\n', 'P\tA\t41\nP\ta\t42\n', '', 'UNKNOWN\tA\n']:
        cases.append((backup, header + tail))
process = subprocess.Popen([root / 'native/build-vs18/Release/CharacterPresetManagerCodecTests.exe'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding='utf-8')
try:
    with TemporaryDirectory() as directory:
        path = Path(directory) / 'shared.txt'
        for backup, contents in cases:
            path.write_text(contents, encoding='utf-8', newline='')
            result = (backup_reader if backup else bundle_reader)(path.as_posix())
            expected = result[0] if isinstance(result, tuple) else result
            process.stdin.write(json.dumps({'operation': 'archive_read', 'backup': backup, 'contents': contents}) + '\n')
            process.stdin.flush()
            actual = json.loads(process.stdout.readline())
            assert (expected is None) == ('error' in actual), (contents, expected, actual)
            if expected is not None:
                assert actual['folders'] == sorted(expected['folders'].keys())
                assert sorted(actual['presets']) == sorted(item['name'] for _, item in expected['presets'].items())
                if backup:
                    assert actual['config'] == expected['config']
                    for _, item in expected['presets'].items():
                        assert actual['presets'][item['name']] == item['contents']
                else:
                    assert actual['root'] == expected['root']
            assert path.read_bytes() == contents.encode(), 'Archive inspection changed the input file.'
    print(f'Native/Lua archive reader parity: {len(cases)} cases passed.')
finally:
    process.stdin.close()
    process.wait(timeout=5)
