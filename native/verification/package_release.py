import hashlib
from pathlib import Path
import re
import shutil
import subprocess
from tempfile import TemporaryDirectory
import zipfile

root = Path(__file__).resolve().parents[2]
version = '3.1.3'
raw = root / 'source/raw'
mod = raw / 'bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)'
constants = (mod / 'modules/constants.lua').read_text(encoding='utf-8')
assert f'version = "{version}"' in constants
assert f'<Version>{version}</Version>' in (root / 'Character Preset Manager CET.cpmodproj').read_text(encoding='utf-8')
assert f'**Version {version}**' in (root / 'README.md').read_text(encoding='utf-8')
assert re.search(r'^## (.+)$', (root / 'CHANGELOG.md').read_text(encoding='utf-8'), re.M).group(1) == version
assert f'RED4EXT_V1_SEMVER({version.replace(".", ", ")})' in (root / 'native/src/Main.cpp').read_text(encoding='utf-8')
node = shutil.which('node') or r'C:\Program Files\nodejs\node.exe'
parser = root / '.audit_lua_parser/node_modules/luaparse'
check = '''
const fs=require('fs'),path=require('path'),parser=require(process.argv[1]);let count=0;
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){
const f=path.join(dir,e.name);if(e.isDirectory())walk(f);else if(f.endsWith('.lua')){
parser.parse(fs.readFileSync(f,'utf8'),{luaVersion:'5.1'});count++;}}}
walk(process.argv[2]);console.log('Parsed '+count+' shipped Lua files, including init.lua.');
'''
subprocess.run([node, '-e', check, str(parser), str(mod)], check=True)
compiled = root / 'native/build-vs18/Release/CharacterPresetManager.dll'
assert compiled.is_file(), 'Build the Release DLL before packaging.'
destination = raw / 'red4ext/plugins/CharacterPresetManager/CharacterPresetManager.dll'
shutil.copyfile(compiled, destination)
archive = root / f'Character Preset Manager (CET) {version}.zip'
files = sorted(path for path in raw.rglob('*') if path.is_file())
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for path in files:
        package.write(path, path.relative_to(raw).as_posix())

init_entry = 'bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)/init.lua'
dll_entry = 'red4ext/plugins/CharacterPresetManager/CharacterPresetManager.dll'
with zipfile.ZipFile(archive) as package:
    names = package.namelist()
    assert len(names) == len(set(names)) == len(files)
    assert package.testzip() is None
    assert names[0].startswith('bin/x64/')
    assert not any(name.startswith('raw/') or '/verification/' in name for name in names)
    assert sum(name.endswith('/init.lua') for name in names) == 1
    for required in [init_entry, dll_entry, 'r6/scripts/CharacterPresetManager/Bridge.reds',
                     'r6/scripts/CharacterPresetManager/Panel.reds', 'r6/scripts/CharacterPresetManager/Service.reds',
                     'r6/scripts/CharacterPresetManager/Types.reds', 'r6/scripts/CharacterPresetManager/Manager.reds', 'r6/scripts/CharacterPresetManager/Input.reds']:
        assert required in names, required
    assert package.read(init_entry) == (mod / 'init.lua').read_bytes()
    assert package.read(dll_entry) == compiled.read_bytes()
    assert not any(name.endswith('/modules/' + retired + '.lua')
                   for name in names for retired in ['native_catalog', 'bundles', 'backup', 'folders', 'history'])
    assert sum(name.endswith('.lua') for name in names) == 3
    assert not any('/legacy_312/' in name or '/Data/' in name for name in names)
    assert sum('/Bundled Presets/' in name and name.endswith('.preset') for name in names) == 6
    with TemporaryDirectory(prefix='cpm-archive-parse-') as temporary:
        extracted = Path(temporary) / 'init.lua'
        extracted.write_bytes(package.read(init_entry))
        subprocess.run([node, '-e',
            "require(process.argv[1]).parse(require('fs').readFileSync(process.argv[2],'utf8'),{luaVersion:'5.1'});",
            str(parser), str(extracted)], check=True)
print(f'Validated {archive.name}: {len(files)} files; bin/x64 layout; Lua, redscript, and matching Release DLL.')
print('SHA256 ' + hashlib.sha256(archive.read_bytes()).hexdigest())
