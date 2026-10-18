import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
from time import monotonic, sleep

from lupa.luajit21 import LuaRuntime

root = Path(__file__).resolve().parents[2]
mod = root / 'source/raw/bin/x64/plugins/cyber_engine_tweaks/mods/Character Preset Manager (CET)'
json_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('D:/SteamLibrary/steamapps/common/Cyberpunk 2077/bin/x64/plugins/cyber_engine_tweaks/scripts/json/json.lua')

with TemporaryDirectory(prefix='cpm-workflows-') as directory:
    workspace = Path(directory)
    manager = workspace / 'mods/Character Preset Manager (CET)'
    (manager / 'Character Presets').mkdir(parents=True)
    original = b'LocKey#9:2\n'
    (manager / 'Character Presets/Zed.preset').write_bytes(original)
    acu = workspace / 'mods/AppearanceChangeUnlocker/character-presets'
    acu.mkdir(parents=True)
    acu_bytes = json.dumps({'options': [{'name': 'Hair', 'value': 1, 'is_active': True}]}).encode()
    (acu / 'From ACU.preset').write_bytes(acu_bytes)
    server = subprocess.Popen([root / 'native/build-vs18/Release/CharacterPresetManagerOperationServer.exe', manager],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding='utf-8')

    def rpc(request):
        server.stdin.write(request + '\n')
        server.stdin.flush()
        result = server.stdout.readline()
        assert result, 'Native operation server stopped.'
        return result

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().rpc = rpc
    lua.execute(f'json=dofile([[{json_path.as_posix()}]])')
    lua.execute(f'package.path=[[{mod.as_posix()}/?.lua;]]..package.path')
    lua.execute('''
registered={}
function registerForEvent(name, callback) registered[name]=callback end
function registerInput() end
function Observe() end
function Override() end
function GetMod() end
function ToCName(value) return value end
function LocKeyToString(value) return value end
function NameToString(value) return value end
function GetLocalizedTextByKey(value) return value end
function dir() return {} end
local enum=setmetatable({}, {__index=function() return 0 end})
ImGuiCol=enum;ImGuiCond=enum;ImGuiStyleVar=enum;ImGuiWindowFlags=enum
ImGui=setmetatable({}, {__index=function() return function() return false end end})
bit32={bor=function() return 0 end}
bridge={sequence=0,action='',payload='',responses={},updates={}}
function bridge:SetLuaReady() return true end
function bridge:GetRequestSequence() return self.sequence end
function bridge:GetRequestAction() return self.action end
function bridge:GetRequestPayload() return self.payload end
function bridge:HasPanels() return true end
function bridge:SetBusy() end
function bridge:Sync(kind,payload) self.updates[kind]=payload end
function bridge:Respond(sequence,kind,payload) self.responses[sequence]={kind=kind,payload=payload} end
Game={
  GetPlayer=function() end,
  GetScriptableSystemsContainer=function() return {Get=function() return bridge end} end,
  CPMNativeStatus=function() return rpc(json.encode({method='status'})) end,
  CPMNativeBegin=function() return json.decode(rpc(json.encode({method='begin'}))).session end,
  CPMNativeClose=function(session) return json.decode(rpc(json.encode({method='close',session=session}))).accepted end,
  CPMNativeSubmit=function(session,action,payload)
    return rpc(json.encode({method='submit',session=session,action=action,payload=payload}))
  end,
  CPMNativePoll=function(session,operation,consume)
    return rpc(json.encode({method='poll',session=session,operation=operation,consume=consume}))
  end,
  CPMNativeCancel=function(session,operation)
    return rpc(json.encode({method='cancel',session=session,operation=operation}))
  end,
  CPMNativeEndAppearance=function(session,operation)
    return rpc(json.encode({method='end',session=session,operation=operation}))
  end,
}
local open=io.open
io.open=function(path,...)
  assert(not tostring(path):find('Character Presets',1,true),'Lua tried to read or write a preset file')
  return nil
end
''')
    lua.execute(f'dofile([[{mod.as_posix()}/init.lua]])')
    lua.execute('''
r=require('modules/runtime')
messages={}
r.log=function(message,level)
  assert(not message:find('[NATIVE SERVICE]',1,true),message)
  messages[#messages+1]={message=message,level=level}
end
r.helpers.archiveLogForNewSession=function() return true end
registered.onInit()
r.state.app.inCustomization=true
live={
  {info={name='Hair',uiSlot='hair',options={{localizedName='A'},{localizedName='B'},{localizedName='C'},{localizedName='D'}}},currIndex=0,isActive=true,isEditable=true},
  {info={name='Eyes',uiSlot='eyes',options={{localizedName='A'},{localizedName='B'},{localizedName='C'},{localizedName='D'}}},currIndex=1,isActive=true,isEditable=true},
}
system={ApplyChangeToOption=function(self,option,target) option.currIndex=target end}
r.getOptions=function() return system,live end
r.refreshCustomizationUi=function() return true end
function idle()
  return r.nativeService.pendingCount==0 and not r.nativeLibrary.busy and not r.nativeManager.writing
    and not r.nativeManager.refreshing and not r.nativeManager.preparingLoad
    and not r.nativeManager.importingBundles and not r.state.load.auto
end
function panel(action,payload)
  bridge.sequence=bridge.sequence+1;bridge.action=action;bridge.payload=payload or ''
end
''')

    def pump():
        deadline = monotonic() + 30
        while monotonic() < deadline:
            lua.globals().registered.onUpdate(0.1)
            if lua.globals().idle():
                return
            sleep(0.001)
        raise AssertionError(lua.eval("r.state.status.sections.load.message"))

    def action(code, check=None):
        lua.execute(code)
        pump()
        if check:
            lua.execute(check)

    try:
        pump()
        lua.execute("assert(r.state.library.presets.Zed and r.state.library.presets['ACU Presets/From ACU']);assert(r.readPresetFile==nil and r.writePresetPath==nil)")
        action("r.state.library.folderName='Looks';assert(r.createFolder())", "assert(r.state.library.folders.Looks)")
        action("r.state.library.folderName='Empty';assert(r.createFolder())", "assert(r.state.library.folders['Looks/Empty'])")
        action("r.state.library.selectedFolder='';r.state.library.folderName='Target';assert(r.createFolder())")
        action("r.state.library.selectedFolder='Looks';r.state.library.newName='Hero';r.state.library.presetNotes='My notes';r.state.library.presetTags='hair';assert(r.savePreset())",
            "assert(r.state.library.presets['Looks/Hero'].format==8 and r.state.library.presets['Looks/Hero'].entryCount==2)")
        action("r.selectPreset('Looks/Hero');assert(r.toggleSelectedPresetFavorite())", "assert(r.state.library.presets['Looks/Hero'].favorite)")
        action("r.state.library.presetNotes='Updated notes';assert(r.savePresetMetadata())", "assert(r.state.library.presets['Looks/Hero'].notes=='Updated notes')")
        action("assert(r.duplicatePreset())", "assert(r.state.library.selected=='Looks/Hero Copy')")
        action("r.state.library.renameName='Hero Renamed';assert(r.renamePreset())")
        action("r.state.library.selectedFolder='Target';assert(r.movePresetToSelectedFolder())", "assert(r.state.library.presets['Target/Hero Renamed'])")
        action("r.state.trash.bulkSelected={['Looks/Hero']=true,['Target/Hero Renamed']=true};r.state.trash.bulkSelectionDirty=true;r.state.trash.bulkTargetFolder='Looks';assert(r.moveSelectedBulkPresetsToFolder())",
            "assert(r.state.library.presets['Looks/Hero Renamed'])")
        action("r.state.library.selectedFolder='Looks';r.state.library.folderRenameName='Styles';assert(r.renameFolder())",
            "assert(r.state.library.presets['Styles/Hero'] and r.state.library.folders['Styles/Empty'])")
        action("assert(r.duplicateFolder())", "assert(r.state.library.folders['Styles Copy/Empty'])")
        action("assert(not r.removeVirtualFolder());assert(r.removeVirtualFolder())",
            "assert(r.state.library.presets.Hero and r.state.library.folders.Empty and not r.state.library.folders['Styles Copy'])")
        action("r.state.library.selectedFolder='Styles';assert(r.exportSelectedFolderBundle())",
            "assert(#r.folderBundleFiles()==1);r.state.library.selectedBundleFile=r.baseName(r.folderBundleFiles()[1])")
        action("assert(r.viewSelectedFolderBundleContents())", "assert(#r.state.library.folderBundlePreview.presets==2)")
        action("assert(r.trashSelectedFolderBundle())", "assert(#r.folderBundleFiles()==0 and #r.state.trash.cachedBundleNames==1)")
        action("assert(r.restoreTrashBundle(r.state.trash.cachedBundleNames[1]))", "assert(#r.folderBundleFiles()==1)")
        action("assert(r.exportLibraryBackup())", "assert(#r.libraryBackupFiles()==1);r.state.backup.selectedFile=r.libraryBackupFiles()[1]")
        action("assert(r.importLibraryBackup())", "assert(r.state.library.folders['Imported Library'])")
        action("assert(r.deleteSelectedLibraryBackup())", "assert(r.state.backup.pendingDeleteFile)")
        action("assert(r.deleteSelectedLibraryBackup())", "assert(#r.libraryBackupFiles()==0)")
        action("assert(r.importAvailableFolderBundles())", "assert(not r.nativeManager.importingBundles)")
        count = lua.eval("#r.state.cache.presetNames")
        action("assert(r.importAvailableFolderBundles())")
        assert lua.eval("#r.state.cache.presetNames") == count, 'Unchanged shared folder was imported twice.'
        action("r.selectPreset('Hero');assert(not r.trashPreset());assert(r.trashPreset())", "assert(not r.state.library.presets.Hero)")
        action("local filename;for name,item in pairs(r.state.trash.items) do if item.original=='Hero' then filename=name end end;assert(filename);assert(r.restoreTrashPreset(filename))",
            "assert(r.state.library.presets.Hero)")
        action("local names=r.bulkPresetNamesInFolder('Styles');assert(not r.requestBulkTrash(names,'Styles'));assert(r.requestBulkTrash(names,'Styles'))",
            "assert(not r.state.library.folders.Styles and #r.state.trash.cachedGroupIds==1)")
        action("assert(r.restoreTrashGroup(r.state.trash.cachedGroupIds[1]))", "assert(r.state.library.folders['Styles/Empty'])")
        action("r.selectPreset('Styles/Hero');live[1].currIndex=3;panel('compare')")
        lua.execute("assert(r.state.load.comparison and r.state.load.comparison.changing==1);assert(bridge.updates.comparison)")
        action("r.resetLoadState();r.state.load.resetBefore=true;r.loadPreset()",
            "assert(live[1].currIndex==0 and not r.state.load.needsContinue and #r.state.history.entries>0)")
        action("assert(r.restoreAppearanceHistory(1))", "assert(live[1].currIndex==3)")
        action("assert(not r.clearAppearanceHistory(false));assert(r.clearAppearanceHistory(true))",
            "assert(#r.state.history.entries==0 and not r.state.load.recoverySnapshotAvailable)")
        action("r.setPresetSortPreference('modified')", "assert(r.state.preferences.presetSort=='modified')")
        action("r.selectPreset('Hero');r.trashPreset();assert(r.trashPreset())")
        action("assert(not r.emptyTrash());assert(r.emptyTrash())", "assert(#r.state.trash.cachedNames==0 and #r.state.trash.cachedGroupIds==0)")
        assert (manager / 'Character Presets/Zed.preset').read_bytes() == original, 'An older preset was rewritten by discovery or reading.'
        assert (acu / 'From ACU.preset').read_bytes() == acu_bytes, 'ACU source bytes changed.'
        lua.execute("r.nativeService.close();assert(not r.savePreset());assert(type(r.drawHelpPanel)=='function')")
        print('Complete native manager workflows passed: startup/import, metadata, all folder actions, bulk moves, sharing, backups, Trash, comparison, staged loading, history, settings, and missing-service handling.')
    finally:
        server.stdin.close()
        server.wait(timeout=10)
