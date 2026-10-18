import json
from pathlib import Path
import random
import subprocess

from lupa import LuaRuntime

root = Path(__file__).resolve().parents[2]
mod = root / 'native/verification/reference'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
runtime = {state={}, helpers={}, log=function() end}
setmetatable(runtime, {__index=_G})
package.preload['modules/runtime'] = function() return runtime end
LocKeyToString = function(value) return value end
NameToString = function(value) return value end
''')
for module in ['constants', 'options', 'comparison']:
    lua.execute(f'dofile([[{mod.as_posix()}/{module}.lua]])')

def plain(value):
    if hasattr(value, 'items'):
        keys = list(value.keys())
        if keys and all(isinstance(key, int) for key in keys):
            return [plain(value[index]) for index in range(1, len(keys) + 1)]
        return {key: plain(item) for key, item in value.items()}
    return value

def check(preset, options):
    live = []
    for option in options:
        copied = dict(option)
        copied['info'] = {'name': copied['key'], 'uiSlot': copied.get('slot')}
        for field, values in copied.get('choices', {}).items():
            copied['info'][field] = [{'localizedName': item} for item in values] if field == 'options' else values
        live.append(copied)
    expected = plain(lua.globals().runtime.comparePresetWithCurrent(
        lua.table_from(preset, recursive=True), lua.table_from(live, recursive=True)))
    if expected['details'] == {}:
        expected['details'] = []
    process.stdin.write(json.dumps({'operation': 'compare', 'preset': preset, 'options': options}) + '\n')
    process.stdin.flush()
    actual = json.loads(process.stdout.readline())
    assert actual == expected, (preset, options, expected, actual)
    return actual

process = subprocess.Popen([root / 'native/build-vs18/Release/CharacterPresetManagerCodecTests.exe'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding='utf-8')
try:
    random.seed(312)
    for case in range(250):
        options = []
        for index in range(random.randrange(1, 12)):
            options.append({'key': random.choice(['Hair', 'Skin', 'Eyes', 'Custom']),
                'slot': random.choice(['hair', 'skin', 'eyes', 'custom']),
                'currIndex': random.randrange(4), 'isEditable': random.choice([True, True, False]),
                'isActive': random.choice([True, True, False]),
                'choices': {'options': random.sample(['A', 'B', 'C', 'D'], 4)}})
        saved = []
        for index in range(random.randrange(1, 12)):
            entry = {'key': random.choice(['Hair', 'Skin', 'Eyes', 'Custom', 'Missing']),
                'index': random.choice([0, 1, 2, 3, -1, 4294967296])}
            if random.choice([True, False]):
                entry['slot'] = random.choice(['hair', 'skin', 'eyes', 'custom'])
            if random.choice([True, False]):
                entry['choice'] = random.choice(['options:A', 'options:Missing'])
            saved.append(entry)
        check({'entries': saved}, options)
    check({'entries': [{'key': 'Hair', 'index': 1, 'choice': 'options:A'}]},
        [{'key': 'Hair', 'currIndex': 0, 'isActive': True, 'isEditable': True, 'choices': {'options': ['A', 'A']}}])
    matched_by_slot = check({'entries': [{'key': 'OldLabel', 'slot': 'hair', 'index': 3}]},
        [{'key': 'NewLabel', 'slot': 'hair', 'currIndex': 3, 'isActive': True, 'isEditable': True}])
    assert matched_by_slot['matching'] == 1 and matched_by_slot['clearing'] == 0
    print('Native/Lua appearance comparison parity: 252 cases passed, including slot-matched cleanup regression.')
finally:
    process.stdin.close()
    process.wait(timeout=5)
