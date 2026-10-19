import json
from pathlib import Path
import subprocess
import sys

from lupa.luajit21 import LuaRuntime

root = Path(__file__).resolve().parents[2]
mod = root / 'native/verification/legacy_312'
json_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('D:/SteamLibrary/steamapps/common/Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/scripts/json/json.lua')
process = subprocess.Popen([root / 'native/build-vs18/Release/CharacterPresetManagerCodecTests.exe'],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding='utf-8')

def plan(payload, operation):
    data = json.loads(payload)
    data['operation'] = 'plan'
    if not data.get('loadId'):
        data['loadId'] = int(operation)
    process.stdin.write(json.dumps(data) + '\n')
    process.stdin.flush()
    result = process.stdout.readline()
    assert 'error' not in json.loads(result), result
    return result

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().native_plan = plan
lua.execute(f'json = dofile([[{json_path.as_posix()}]])')
lua.execute('''
runtime={helpers={},log=function(message) assert(not message:find('[NATIVE SERVICE]',1,true),message) end,
  setStatus=function(section,message,failed,kind) lastStatus=message;lastKind=kind end}
setmetatable(runtime,{__index=_G})
package.preload['modules/runtime']=function() return runtime end
LocKeyToString=function(value) return value end
NameToString=function(value) return value end
ToCName=function(value) return value end
local session,sequence=0,0
jobs={}
Game={
  CPMNativeStatus=function() return json.encode({available=true,protocol=1,version='3.1.3'}) end,
  CPMNativeBegin=function() session=session+1;return session end,
  CPMNativeClose=function() return true end,
  CPMNativeSubmit=function(current,action,payload)
    assert(current==session)
    sequence=sequence+1
    jobs[sequence]={result=json.decode(native_plan(payload,sequence)),status='complete'}
    return json.encode({accepted=true,session=session,operation=sequence})
  end,
  CPMNativePoll=function(current,id)
    return json.encode({accepted=true,session=session,operation=id,status=jobs[id].status,result=jobs[id].result})
  end,
  CPMNativeCancel=function(current,id) jobs[id].status='canceled';return '{"accepted":true}' end,
  CPMNativeEndAppearance=function() return '{"accepted":true}' end,
}
''')
for module in ['constants', 'state', 'filesystem', 'options', 'comparison', 'view_cache', 'load_engine',
               'native_service', 'native_appearance', 'native_loader']:
    lua.execute(f'dofile([[{mod.as_posix()}/modules/{module}.lua]])')
try:
    lua.execute(r'''
local runtime=runtime
runtime.log=function(message) assert(not message:find('[NATIVE SERVICE]',1,true),message) end
runtime.setStatus=function(section,message,failed,kind) lastStatus=message;lastKind=kind end
runtime.helpers.auditSection=function() end
runtime.helpers.releaseFinishedLoadWorkingData=function() end
runtime.state.invalidatePreflight=function() end
runtime.refreshCustomizationUi=function() end
local function option(key,current,choices)
  local values={}
  for _,name in ipairs(choices or {'A','B','C','D'}) do values[#values+1]={localizedName=name} end
  return {info={name=key,uiSlot=key:lower(),options=values},currIndex=current,isActive=true,isEditable=true}
end
local function run(mode)
  assert(runtime.nativeService.connect())
  runtime.nativeAppearance.close()
  runtime.resetLoadState()
  runtime.state.app.inCustomization=true
  local options={option('Hair',0),option('Skin',0),option('Extra',3)}
  local preset={format=8,entries={{key='Hair',index=2,slot='hair'},{key='Skin',index=1,slot='skin'}}}
  if mode=='named-unconfirmed' then
    options={option('Hair',0,{'B','A'})}
    preset.entries={{key='Hair',index=0,slot='hair',choice='options:A'}}
  elseif mode=='missing' then
    preset.entries[1].choice='options:Missing'
  elseif mode=='dependency' then
    preset.entries[2].index=0
  end
  runtime.state.library.selected='fixture'
  runtime.state.library.presets.fixture=preset
  runtime.state.load.resetBefore=true
  local values,counts,entries,slots,total,byKey=runtime.beginLoadPass(preset,'fixture')
  runtime.state.load.auto=true
  local applied, delayed={},nil
  local system={ApplyChangeToOption=function(self,selected,target)
    applied[#applied+1]={key=selected.info.name,target=target}
    assert(not runtime.nativeAppearance.pending)
    if mode=='named-unconfirmed' then return end
    if mode=='delayed' then delayed={selected=selected,target=target,at=runtime.state.load.elapsed+0.1};return end
    selected.currIndex=target
    if mode=='dependency' and selected.info.name=='Hair' then options[2].isActive=false end
  end}
  runtime.getOptions=function() return system,options end
  for tick=1,600 do
    runtime.state.load.elapsed=runtime.state.load.elapsed+0.05
    runtime.state.load.pass=tick
    if delayed and runtime.state.load.elapsed>=delayed.at then
      delayed.selected.currIndex=delayed.target;delayed=nil
    end
    runtime.helpers.continueNativeLoad(system,options,preset,values,counts,entries,slots,total,byKey)
    if mode=='stale' and tick==1 then options[1].currIndex=1 end
    if mode=='cancel' and tick==1 then runtime.nativeAppearance.cancel() end
    if mode=='close' and tick==1 then runtime.state.app.inCustomization=false end
    runtime.nativeService.update(0.05)
    if not runtime.state.load.needsContinue then
      assert(runtime.nativeAppearance.loadId==nil and runtime.nativeAppearance.pending==nil,'Appearance request was not released in '..mode..': '..tostring(lastStatus))
      if mode=='cancel' or mode=='close' then
        assert(#applied==0 and lastStatus:find('canceled',1,true),lastStatus)
      elseif mode=='named-unconfirmed' then
        assert(#applied==1 and lastKind=='warning' and runtime.state.load.unconfirmed['Hair\31'..'1'],lastStatus)
      elseif mode=='missing' then
        for _,change in ipairs(applied) do assert(change.key~='Hair') end
        assert(lastKind=='warning',lastStatus)
      else
        assert(options[1].currIndex==2 and options[3].currIndex==0,lastStatus)
        assert(mode=='dependency' or options[2].currIndex==1,lastStatus)
        assert(lastKind=='success',lastStatus)
      end
      runtime.nativeService.close()
      runtime.nativeAppearance.close()
      return
    end
  end
  error('Native staged load did not finish: '..mode..' '..tostring(lastStatus))
end
for _,mode in ipairs({'normal','delayed','dependency','stale','missing','named-unconfirmed','cancel','close'}) do run(mode) end
''')
    print('Native staged loading passed eight game-adapter simulations: settling, delayed changes, dependencies, stale snapshots, missing/named choices, cancellation, and editor closure.')
finally:
    process.stdin.close()
    process.wait(timeout=5)
