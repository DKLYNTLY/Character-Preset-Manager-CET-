from pathlib import Path
import sys

from lupa.luajit21 import LuaRuntime

root = Path(__file__).resolve().parents[2]
mod = root / 'source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)'
json_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('D:/SteamLibrary/steamapps/common/Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/scripts/json/json.lua')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(f'json = dofile([[{json_path.as_posix()}]])')
lua.execute('''
runtime = {VERSION='3.1.2', helpers={}, log=function() end}
setmetatable(runtime, {__index=_G})
package.preload['modules/runtime'] = function() return runtime end
session, sequence, polls, closes, received = 0, 0, 0, 0, 0
jobs = {}
Game = {
  CPMNativeStatus = function() return json.encode({available=true,protocol=1,version='3.1.2'}) end,
  CPMNativeBegin = function() session=session+1; return session end,
  CPMNativeClose = function(value) assert(value==session); closes=closes+1; return true end,
  CPMNativeSubmit = function(value, action, payload)
    assert(value==session and payload~='[]')
    sequence=sequence+1
    jobs[sequence]={payload=json.decode(payload),action=action,status='running',session=value}
    return json.encode({accepted=true,session=value,operation=sequence})
  end,
  CPMNativePoll = function(value, operation, consume)
    assert(consume==true)
    polls=polls+1
    local job=jobs[operation]
    return json.encode({accepted=true,session=job.session,operation=operation,
      status=job.status,completed=2,total=5,result=job.result or {value=job.action}})
  end,
  CPMNativeCancel = function(value, operation)
    assert(value==session)
    jobs[operation].status='canceled'
    return json.encode({accepted=true})
  end,
  CPMNativeEndAppearance = function(value, operation)
    assert(value==session and operation>0)
    return json.encode({accepted=true})
  end,
}
''')
lua.execute(f'dofile([[{mod.as_posix()}/modules/native_service.lua]])')
lua.execute('''
local service=runtime.nativeService
assert(service.connect())
local first=assert(service.submit('query',{},function(status,result,id)
  assert(status=='complete' and result.value=='query' and id==1)
  received=received+1
end))
service.update(0.01)
assert(polls==0)
service.update(0.04)
assert(polls==1 and received==0 and service.pending[first].completed==2)
jobs[first].status='complete'
service.update(0.05)
assert(received==1 and service.pendingCount==0)
local canceled=assert(service.submit('refresh',{query='test'},function(status)
  assert(status=='canceled');received=received+1
end))
assert(service.cancel(canceled))
service.update(0.05)
assert(received==2)
local stale=assert(service.submit('read',{},function(status,result)
  assert(status=='failed' and result.error);received=received+1
end))
jobs[stale].session=session-1
service.update(0.05)
assert(received==3)
assert(service.submit('read',{},function() error('A closed-session callback ran') end))
service.close()
assert(service.pendingCount==0 and not service.available and service.reason~='')
assert(service.submit('query')==nil)
assert(service.connect())
for index=1,16 do assert(service.submit('query',{})) end
assert(service.submit('query',{})==nil and service.pendingCount==16)
for id,job in pairs(jobs) do job.status='complete' end
local before=polls
service.update(0.05)
assert(polls-before==4 and service.pendingCount==12)
service.close()
assert(service.connect())
local slow={}
for index=1,4 do slow[index]=assert(service.submit('read',{})) end
local ready=assert(service.submit('query',{},function(status) assert(status=='complete');received=received+1 end))
jobs[ready].status='complete'
local count=received
service.update(0.05)
service.update(0.05)
assert(received==count+1, 'Running jobs blocked a later completed result')
service.close()
Game.CPMNativeStatus=function() return json.encode({available=true,protocol=1,version='3.1.1'}) end
assert(not service.connect() and service.reason:find('do not match',1,true))
Game.CPMNativeStatus=nil
assert(not service.connect() and service.reason~='')
''')
lua.execute(f'dofile([[{mod.as_posix()}/modules/native_library.lua]])')
lua.execute('''
Game.CPMNativeStatus=function() return json.encode({available=true,protocol=1,version='3.1.2'}) end
local service,library=runtime.nativeService,runtime.nativeLibrary
assert(service.connect())
runtime.state={library={presets={old={}},folders={},selected='old'},cache={revision=0},trash={}}
local done=0
local function completed(ok,message) assert(ok and message==nil);done=done+1 end
local function page(id, revision, offset, folderOffset, rows, folders)
  jobs[id].status='complete'
  jobs[id].result={revision=revision,offset=offset,folderOffset=folderOffset,
    total=2,folderTotal=2,rows=rows,folderRows=folders,query='hair'}
end
library.requestView('hair','name',completed)
local first=library.pending
page(first,7,0,0,{{name='A/Hair',preset={entryCount=1},folder='A',matches=true}},
  {{name='A',count=1,matching=1,matches=false}})
service.update(0.05)
assert(done==0 and runtime.state.library.presets.old and library.busy)
local second=library.pending
assert(jobs[second].payload.revision==7 and jobs[second].payload.offset==1)
page(second,7,1,1,{{name='B/Eyes',preset={entryCount=2},folder='B',matches=false}},
  {{name='B',count=1,matching=0,matches=false}})
service.update(0.05)
assert(done==1 and not library.busy and library.revision==7)
assert(runtime.state.library.selected==nil and runtime.state.library.presets.old==nil)
assert(#runtime.state.cache.filteredPresetNames==1 and runtime.state.cache.matchedFolders.A)
assert(runtime.state.cache.presetsByFolder.B[1]=='B/Eyes')
assert(runtime.state.cache.folderPresetCounts.A==1 and runtime.state.cache.searchText=='hair')
local preserved=runtime.state.library.presets
library.requestView('new','name',function(ok,message) assert(not ok and message);done=done+1 end)
page(library.pending,8,0,0,{{name='A/Hair',preset={},folder='A',matches=true}},
  {{name='A',count=1,matching=1,matches=false}})
service.update(0.05)
page(library.pending,9,1,1,{{name='B/Eyes',preset={},folder='B',matches=true}},
  {{name='B',count=1,matching=1,matches=false}})
service.update(0.05)
assert(done==2 and runtime.state.library.presets==preserved and library.revision==7)
library.requestView('old query','name',function() error('Replaced search callback ran') end)
local stale=library.pending
library.requestView('current query','name',function(ok) assert(not ok);done=done+1 end)
local current=library.pending
page(stale,10,0,0,{}, {})
jobs[current].status='failed';jobs[current].result={error='Fixture failure'}
service.update(0.05)
assert(done==3 and runtime.state.library.presets==preserved)
library.requestView('closing','name',function() error('Closed session updated view') end)
service.close()
library.cancelView()
assert(not library.busy and library.pending==nil)
''')
for module in ['constants', 'options', 'native_appearance']:
    lua.execute(f'dofile([[{mod.as_posix()}/modules/{module}.lua]])')
lua.execute('''
LocKeyToString=function(value) return value end
NameToString=function(value) return value end
local service,appearance=runtime.nativeService,runtime.nativeAppearance
assert(service.connect())
runtime.state.app={inCustomization=true}
local options={{info={name='Hair',uiSlot='hair',options={{localizedName='A'},{localizedName='B'}}},
  currIndex=0,isActive=true,isEditable=true}}
local system={}
runtime.getOptions=function(fresh) assert(fresh);return system,options end
local preset={format=8,entries={{key='Hair',index=1,choice='options:B'}}}
local state={phase='apply',satisfied={}}
local received={}
local function callback(status,result,liveSystem,liveOptions)
  received[#received+1]=status
  if status=='ready' then assert(liveSystem==system and liveOptions==options) end
end
local function complete(id)
  local payload=jobs[id].payload
  jobs[id].status='complete'
  jobs[id].result={loadId=appearance.loadId or id,snapshot=payload.snapshot,
    outcome='change',state=payload.state,change={position=1,target=1}}
end
local id=assert(appearance.start(preset,options,state,callback))
assert(appearance.start(preset,options,state,callback)==nil)
assert(jobs[id].payload.options[1].choices.options[2]=='B')
preset.entries[1].index=3
assert(jobs[id].payload.preset.entries[1].index==1)
complete(id)
service.update(0.05)
assert(received[#received]=='ready' and appearance.loadId==id)
for _,field in ipairs({'choice','slot','current','active'}) do
  local nextId=assert(appearance.next(options,state,callback))
  if field=='choice' then options[1].info.options[1].localizedName='Changed'
  elseif field=='slot' then options[1].info.uiSlot='different'
  elseif field=='current' then options[1].currIndex=2
  else options[1].isActive=false end
  complete(nextId)
  service.update(0.05)
  assert(received[#received]=='stale' and appearance.loadId==id)
end
local cancel=assert(appearance.next(options,state,callback))
appearance.cancel()
assert(appearance.pending==cancel and appearance.start(preset,options,state,callback)==nil)
service.update(0.05)
assert(received[#received]=='canceled' and appearance.loadId==nil and not appearance.canceled)
id=assert(appearance.start(preset,options,state,callback))
jobs[id].status='failed';jobs[id].result={error='Fixture failure'}
service.update(0.05)
assert(received[#received]=='failed' and appearance.loadId==nil)
id=assert(appearance.start(preset,options,state,callback))
complete(id)
runtime.state.app.inCustomization=false
service.update(0.05)
assert(received[#received]=='canceled' and appearance.loadId==nil)
runtime.state.app.inCustomization=true
id=assert(appearance.start(preset,options,state,callback))
complete(id)
appearance.close()
service.update(0.05)
assert(received[#received]=='canceled' and appearance.loadId==nil)
id=assert(appearance.start(preset,options,state,callback))
local count=#received
service.close()
appearance.close()
assert(appearance.pending==nil and appearance.loadId==nil and #received==count)
''')
print('LuaJIT adapter tests passed: fair polling, library paging, stale revisions, immutable appearance snapshots, changed editor choices, cancellation, failed plans, and editor/session closure.')
