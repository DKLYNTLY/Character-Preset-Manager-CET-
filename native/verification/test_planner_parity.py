import json
import copy
from pathlib import Path
import random
import subprocess

from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[2]
mod = root / 'native/verification/reference'
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
runtime = {helpers={}, log=function() end, setStatus=function() end,
  refreshCustomizationUi=function() end}
setmetatable(runtime,{__index=_G})
package.preload['modules/runtime']=function() return runtime end
LocKeyToString=function(value) return value end
NameToString=function(value) return value end
''')
for module in ['constants', 'state', 'filesystem', 'options', 'comparison', 'view_cache', 'load_engine']:
    lua.execute(f'dofile([[{mod.as_posix()}/{module}.lua]])')
lua.execute('''
runtime.helpers.logLoadMeasurements=function() end
runtime.helpers.finalVerifyUnconfirmed=function() return 0 end
runtime.helpers.checkPendingChange=function() return 'none' end
runtime.helpers.pollPendingOption=function() return 'full' end
runtime.helpers.beginPendingChange=function(system, option, target, kind, key, current)
  captured={position=option.position,target=target,kind=kind,trackingKey=key,current=current}
  runtime.state.load.pendingChange={}
  return true
end
function plan(preset,options,initial)
  runtime.resetLoadState()
  captured=nil
  local state=runtime.state.load
  for key,value in pairs(initial) do state[key]=value end
  state.pass=1
  runtime.state.library.selected='fixture'
  runtime.state.library.presets.fixture=preset
  state.presetName='fixture'
  local values,counts,entries,slots,total,byKey=runtime.helpers.preparePresetEntries(preset)
  state.values=values;state.savedCounts=counts;state.orderedEntries=entries
  state.savedSlotCounts=slots;state.savedEntryByKey=byKey
  runtime.continueLoadPass({},options,preset,values,counts,entries,slots,total,byKey)
  if captured then captured.forced=state.pendingChange.forced==true end
  return captured,state.phase,state.remaining,state.needsContinue
end
function plannerState()
  local result={}
  for _,key in ipairs({'phase','forceFull','resetBefore','returnToCleanup','satisfied',
      'unconfirmed','forcedKeys','cleanupSkipped','dependencyRemaps','remaining',
      'needsContinue','stalled','previousUnresolvedSignature','unresolvedRepeatCount'}) do
    result[key]=runtime.state.load[key]
  end
  return result
end
''')

def plain(value):
    return {key: item for key, item in value.items()} if value is not None else None

def recursive(value):
    if hasattr(value, 'items'):
        return {key: recursive(item) for key, item in value.items()}
    return value

def check(preset, options, state):
    live = []
    for option in options:
        copied = dict(option)
        copied['info'] = {'name': copied['key'], 'uiSlot': copied.get('slot')}
        for field, values in copied.get('choices', {}).items():
            copied['info'][field] = [{'localizedName': item} for item in values] if field == 'options' else values
        live.append(copied)
    expected, phase, remaining, continuing = lua.globals().plan(lua.table_from(preset, recursive=True),
        lua.table_from(live, recursive=True), lua.table_from(state, recursive=True))
    expected = plain(expected)
    process.stdin.write(json.dumps({'operation': 'plan', 'preset': preset, 'options': options, 'state': state}) + '\n')
    process.stdin.flush()
    result = json.loads(process.stdout.readline())
    assert 'error' not in result, result
    actual = result.get('change')
    if actual is not None:
        actual = {key: actual[key] for key in ['position', 'target', 'kind', 'trackingKey', 'current', 'forced']}
    assert actual == expected, (preset, options, state, expected, actual)
    if expected is None:
        assert result['state']['phase'] == phase, (state, phase, result)
        assert result['state']['remaining'] == remaining, (preset, options, state, remaining, result)
        assert result['state']['needsContinue'] == continuing, (state, continuing, result)
    return result

def sequence(preset, initial_options, mode):
    options = copy.deepcopy(initial_options)
    states = [{'phase': 'precleanup', 'forceFull': True, 'resetBefore': True} for _ in range(2)]
    changed = 0
    reverted = False
    for step in range(100):
        live = []
        for option in options:
            copied = copy.deepcopy(option)
            copied['info'] = {'name': copied['key'], 'uiSlot': copied.get('slot')}
            for field, values in copied.get('choices', {}).items():
                copied['info'][field] = [{'localizedName': item} for item in values] if field == 'options' else values
            live.append(copied)
        expected, phase, remaining, continuing = lua.globals().plan(
            lua.table_from(preset, recursive=True), lua.table_from(live, recursive=True),
            lua.table_from(states[0], recursive=True))
        states[0] = recursive(lua.globals().plannerState())
        process.stdin.write(json.dumps({'operation': 'plan', 'preset': preset, 'options': options,
            'state': states[1], 'loadId': 12, 'snapshot': step}) + '\n')
        process.stdin.flush()
        result = json.loads(process.stdout.readline())
        assert 'error' not in result, result
        assert result['loadId'] == 12 and result['snapshot'] == step
        states[1] = result['state']
        actual = result.get('change')
        expected = plain(expected)
        if actual is not None:
            comparable = {key: actual[key] for key in ['position', 'target', 'kind', 'trackingKey', 'current', 'forced']}
            assert comparable == expected, (mode, step, expected, actual)
            changed += 1
            target = options[actual['position'] - 1]
            key = actual['trackingKey']
            unconfirmed = mode == 'unconfirmed' and changed == 1
            if not unconfirmed:
                target['currIndex'] = actual['target']
            for state in states:
                if actual['kind'] == 'apply':
                    state.setdefault('satisfied', {})[key] = True
                    if unconfirmed: state.setdefault('unconfirmed', {})[key] = True
                    if actual['forced']: state.setdefault('forcedKeys', {})[key] = True
                elif unconfirmed:
                    state.setdefault('cleanupSkipped', {})[key] = True
            if mode == 'revert' and changed == 2 and not reverted:
                options[0]['currIndex'] = (options[0]['currIndex'] + 1) % 4
                reverted = True
        else:
            assert expected is None, (mode, step, expected, result)
            assert states[1]['phase'] == phase and states[1]['remaining'] == remaining, (mode, step, states)
            assert states[1]['needsContinue'] == continuing, (mode, step, states)
            if not continuing:
                assert result['outcome'] in ('complete', 'partial', 'failed'), result
                return step + 1
    raise AssertionError(('Planner did not finish', mode, states))

process = subprocess.Popen([root / 'native/build-vs18/Release/CharacterPresetManagerCodecTests.exe'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding='utf-8')
try:
    random.seed(312)
    for case in range(300):
        options = []
        for index in range(random.randrange(1, 8)):
            options.append({'key': random.choice(['Hair', 'Skin', 'Eyes', 'Custom']),
                'slot': random.choice(['hair', 'skin', 'eyes', 'custom']), 'currIndex': random.randrange(4),
                'isActive': random.choice([True, True, False]), 'isEditable': True,
                'choices': {'options': random.sample(['A', 'B', 'C', 'D'], 4)}})
        entries = []
        for index in range(random.randrange(1, 8)):
            entry = {'key': random.choice(['Hair', 'Skin', 'Eyes', 'Custom', 'Missing']), 'index': random.randrange(4)}
            if random.choice([True, False]): entry['slot'] = random.choice(['hair', 'skin', 'eyes', 'custom'])
            if random.choice([True, False]): entry['choice'] = random.choice(['options:A', 'options:Missing'])
            entries.append(entry)
        state = {'phase': random.choice(['precleanup', 'apply', 'cleanup', 'verify']), 'forceFull': random.choice([True, False]), 'resetBefore': True}
        if case % 3 == 0:
            state['satisfied'] = {entries[0]['key'] + '\x1f1': True}
            state['unconfirmed'] = {entries[0]['key'] + '\x1f1': True} if case % 2 == 0 else {}
        check({'format': 8, 'entries': entries}, options, state)
    result = check({'format': 8, 'entries': [{'key': 'Old', 'slot': 'hair', 'index': 1, 'choice': 'options:Missing'}]},
        [{'key': 'New', 'slot': 'hair', 'currIndex': 0, 'isActive': True, 'isEditable': True, 'choices': {'options': ['A', 'B']}}],
        {'phase': 'apply', 'forceFull': True, 'resetBefore': True})
    assert result['outcome'] != 'change'
    steps = 0
    for case in range(120):
        options = [{'key': key, 'slot': key.lower(), 'currIndex': random.randrange(4),
            'isActive': True, 'isEditable': True, 'choices': {'options': ['A', 'B', 'C', 'D']}}
            for key in ['Hair', 'Skin', 'Eyes', 'Extra']]
        entries = [{'key': key, 'slot': key.lower(), 'index': random.randrange(4)}
            for key in ['Hair', 'Skin', 'Eyes']]
        if case % 5 == 0: entries[0]['key'] = 'Old Hair'
        if case % 7 == 0: entries[1]['choice'] = 'options:Missing'
        if case % 11 == 0: entries.append({'key': 'Unavailable', 'index': 2})
        steps += sequence({'format': 8, 'entries': entries}, options,
            ['normal', 'revert', 'unconfirmed'][case % 3])
    print(f'Native/Lua load-planning parity: 301 individual decisions and 120 staged sequences ({steps} decisions) passed.')
finally:
    process.stdin.close()
    process.wait(timeout=5)
