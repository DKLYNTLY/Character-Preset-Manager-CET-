local resultModel = require("modules/domain/operation_result")

local cet = {
  sort_name = {operation = "sort", section = "settings"},
  sort_modified = {operation = "sort", section = "settings"},
  backup_export = {operation = "backup_export", section = "backup"},
  backup_refresh = {operation = "backup_refresh", section = "backup"},
  backup_select = {operation = "backup_select", section = "backup"},
  backup_restore = {operation = "backup_restore", section = "backup"},
  backup_delete = {operation = "backup_delete", section = "backup"},
  bulk_filter = {operation = "filter", section = "bulk"},
  bulk_select_visible = {operation = "bulk_select_visible", section = "bulk"},
  bulk_clear = {operation = "bulk_clear", section = "bulk"},
  bulk_select = {operation = "bulk_select", section = "bulk"},
  bulk_location_root = {operation = "bulk_location", section = "bulk"},
  bulk_location = {operation = "bulk_location", section = "bulk"},
  bulk_move = {operation = "bulk_move", section = "bulk"},
  bulk_export = {operation = "bulk_export", section = "bulk"},
  bulk_trash = {operation = "bulk_trash", section = "bulk"},
  randomize = {operation = "randomize", section = "editor"},
  randomize_settings = {operation = "randomize_settings", section = "editor"},
  open_editor = {operation = "open_editor", section = "editor"},
  folder_root = {operation = "folder_select", section = "folder"},
  folder_select = {operation = "folder_select", section = "folder"},
  folder_create = {operation = "folder_create", section = "folder"},
  folder_rename = {operation = "folder_rename", section = "folder"},
  folder_duplicate = {operation = "folder_duplicate", section = "folder"},
  move = {operation = "move", section = "folder"},
  folder_remove = {operation = "folder_remove", section = "folder"},
  folder_trash = {operation = "folder_trash", section = "folder"},
  move_root = {operation = "move", section = "folder"},
  bundle_export = {operation = "bundle_export", section = "folder"},
  bundle_import = {operation = "bundle_import", section = "folder"},
  bundle_select = {operation = "bundle_select", section = "folder"},
  bundle_preview = {operation = "bundle_preview", section = "folder"},
  bundle_trash = {operation = "bundle_trash", section = "folder"},
  filter = {operation = "filter", section = "load"},
  clear_filter = {operation = "clear_filter", section = "load"},
  refresh = {operation = "refresh", section = "load"},
  refresh_options = {operation = "refresh_options", section = "load"},
  select = {operation = "select", section = "load"},
  load = {operation = "load", section = "load"},
  restore_previous = {operation = "restore_previous", section = "load"},
  restore_history = {operation = "restore_history", section = "load"},
  clear_history = {operation = "clear_history", section = "load"},
  compare = {operation = "compare", section = "load"},
  force_full = {operation = "force_full", section = "load"},
  favorite = {operation = "favorite", section = "load"},
  rename = {operation = "rename", section = "rename"},
  duplicate = {operation = "duplicate", section = "rename"},
  copy_path = {operation = "copy_path", section = "load"},
  metadata = {operation = "metadata", section = "rename"},
  name_changed = {operation = "name_changed", section = "create"},
  save = {operation = "save", section = "create"},
  save_location_root = {operation = "save_location", section = "create"},
  save_location = {operation = "save_location", section = "create"},
  delete = {operation = "delete", section = "delete"},
  trash_restore_group = {operation = "trash_restore_group", section = "delete"},
  trash_restore = {operation = "trash_restore", section = "delete"},
  trash_restore_bundle = {operation = "trash_restore_bundle", section = "delete"},
  trash_empty = {operation = "trash_empty", section = "delete"},
  sort = {operation = "sort", section = "settings"},
}

local native = {
  randomize = {operation = "randomize"},
  randomize_settings = {operation = "randomize_settings"},
  open = {operation = "open"},
  list = {operation = "filter"},
  select = {operation = "select"},
  select_load = {operation = "load"},
  toggle_folder = {operation = "toggle_folder"},
  cancel_save_confirmation = {operation = "cancel_save_confirmation"},
  save = {operation = "save"},
  replace = {operation = "save"},
  load = {operation = "load"},
  compare = {operation = "compare"},
  favorite = {operation = "favorite"},
  save_location = {operation = "save_location"},
  delete = {operation = "delete"},
  refresh = {operation = "refresh"},
  history = {operation = "history"},
  restore_history = {operation = "restore_history"},
  restore_previous = {operation = "restore_previous"},
  clear_history = {operation = "clear_history"},
  open_advanced = {operation = "open_advanced"},
  open_load_details = {operation = "open_load_details"},
}

local function blocked(name, context)
  if name == "load" then
    return not context.selected or not context.inCustomization or context.auto
  elseif name == "refresh_options" then
    return not context.inCustomization or context.auto or context.needsContinue or context.pendingChange
  elseif name == "restore_previous" then
    return not context.recoveryAvailable or not context.inCustomization or context.auto or context.needsContinue
  elseif name == "restore_history" then
    return not context.inCustomization or context.auto or context.needsContinue
  elseif name == "compare" then
    return not context.presetExists or not context.inCustomization or context.auto or context.needsContinue
  elseif name == "force_full" then
    return not context.presetExists or context.auto
  elseif name == "randomize" or name == "randomize_settings" then
    return not context.inCustomization or not context.hasEditor or context.auto
      or context.needsContinue or context.pendingChange or context.available == false
  elseif name == "open_editor" then
    return context.openPending or context.inCustomization or not context.hooksAvailable
  elseif name == "save" then
    return not context.inCustomization or not context.validPresetName
  elseif name == "rename" then
    return not context.presetExists or context.renameEmpty
  elseif name == "duplicate" or name == "metadata" or name == "copy_path" or name == "favorite" then
    return not context.presetExists
  elseif name == "folder_create" then
    return not context.validFolderName
  elseif name == "folder_rename" then
    return context.rootFolder or context.folderRenameEmpty
  elseif name == "folder_duplicate" or name == "folder_remove" or name == "bundle_export" then
    return context.rootFolder
  elseif name == "folder_trash" then
    return context.rootFolder or context.emptyFolder
  elseif name == "move" or name == "move_root" then
    return not context.selected or context.sameFolder
  elseif name == "backup_restore" or name == "backup_delete" then
    return not context.backupSelected
  elseif name == "bundle_preview" or name == "bundle_trash" then
    return not context.bundleSelected
  elseif name == "bulk_clear" or name == "bulk_move" or name == "bulk_export" or name == "bulk_trash" then
    return context.emptyBulk
  elseif name == "delete" then
    return not context.selected
  end
  return false
end

local function plan(origin, name, input, context)
  if origin == "cet" and blocked(name, context) then
    local rejected = resultModel.failure("")
    rejected.actions, rejected.disabled = {}, true
    return rejected
  end
  local definitions = origin == "cet" and cet or native
  local definition = definitions[name]
  if not definition and origin == "cet" then
    local rejected = resultModel.failure("")
    rejected.actions = {}
    return rejected
  end
  local result = resultModel.success("")
  result.operation = definition and definition.operation or "unsupported"
  result.section = definition and definition.section
  result.actions = {{name = definition and name or "unsupported", origin = origin}}
  if name == "save" then
    result.overwrite = origin == "cet"
      and context.pendingOverwriteName == input.pendingCreateName
      or origin ~= "cet" and context.pendingOverwriteName ~= nil
  elseif name == "clear_history" then
    result.confirm = origin == "cet" and context.pendingClear == true
      or origin ~= "cet" and input.payload == "confirm"
  end
  return result
end

local function complete(planResult, isError, message, warnings)
  local result = resultModel.new(not isError, message, warnings)
  result.operation = planResult.operation
  result.actions = planResult.actions
  return result
end

local function supports(origin, name)
  local definitions = origin == "cet" and cet or native
  return definitions[name] ~= nil
end

return {blocked = blocked, plan = plan, complete = complete, supports = supports}
