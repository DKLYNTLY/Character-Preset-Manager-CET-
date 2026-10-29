local actions = {
  opened = {"clearCatalog", "disableWardrobe", "measureOpened", "resetLoad", "captureMenu",
    "enterCustomization", "invalidatePreflight", "connectBridge", "clearFallback", "logOpened"},
  closed = {"clearCatalog", "measureClosed", "resetLoad", "clearRandomize", "clearMenu",
    "leaveCustomization", "invalidatePreflight", "clearFallback", "clearLauncher", "restoreWardrobe"},
  shutdown = {"finishOverlay", "clearCatalog", "sessionAudit", "sessionSummary", "restoreWardrobe",
    "stopApp", "leaveNewGame", "clearConfirmations", "resetLoad", "clearRandomize", "clearMenu",
    "clearController", "stopOpening", "clearLauncher", "clearHooks", "clearFallback", "closeLog"},
  newGameEnter = {"enterNewGame"},
  newGameExit = {"leaveNewGame"},
  watchdog = {"stopOpening", "restoreWardrobe", "timeoutStatus"},
  none = {},
  puppet = {"setupPuppet"},
  puppetFailure = {"puppetFailureStatus", "clearLauncher", "restoreWardrobe", "originalPuppet"},
  puppetSuccess = {"puppetOpenedStatus"},
  launchFailure = {"clearPending", "restoreWardrobe", "launchFailureStatus"},
  launchSuccess = {"openingStatus"},
  hotkeyFailure = {"stopOpening", "restoreWardrobe", "hotkeyFailureStatus"},
  refreshChanged = {"measureChanged", "resetLoad", "invalidatePreflight", "clearInactiveMenu"},
  refreshSteady = {"clearInactiveMenu"},
}
local function launchGate(pending, hooksAvailable)
  if pending then return "pending" end
  if not hooksAvailable then return "unsupported" end
  return "inspect"
end
local function launchTarget(customization, controllerAvailable)
  if customization then return "active" end
  if not controllerAvailable then return "unavailable" end
  return "launch"
end
local function beginLaunch() return 0, true end
local function redirectPause(count) return count + 1, false, 0, true end
local function nextCount(count) return count + 1 end
local function watchdog(timer, elapsed, timeout)
  local nextTimer = timer + elapsed
  if nextTimer >= timeout then return nextTimer, actions.watchdog end
  return nextTimer, actions.none
end
local function cameraBlocked(customization, hold, auto, needsContinue)
  return customization and (hold or auto or needsContinue)
end
local function shouldMeasure(presetName, needsContinue, pending)
  return presetName and (needsContinue or pending)
end
local function wardrobeNeeded(disabled) return not disabled end
local function restoreNeeded(disabled) return disabled end
local function classify(newGame) return newGame and "character_creator" or "mirror" end
local function puppetPlan(newGame) return classify(newGame), actions.puppet end
local function hooksAvailable(controller, initialize, pause, puppet)
  return (controller or initialize) and pause and puppet
end
local function plan(event) return actions[event] end
local function launchResult(ok) return ok and actions.launchSuccess or actions.launchFailure end
local function puppetResult(ok) return ok and actions.puppetSuccess or actions.puppetFailure end
local function hotkeyResult(ok) return ok and actions.none or actions.hotkeyFailure end
local function pauseAction(pending) return pending and "redirect" or "original" end
local function refreshPlan(previous, current)
  return previous ~= current and actions.refreshChanged or actions.refreshSteady
end
local function clearInactiveMenu(customization) return not customization end
return {
  hooksAvailable=hooksAvailable, launchResult=launchResult, puppetResult=puppetResult, hotkeyResult=hotkeyResult,
  pauseAction=pauseAction, refreshPlan=refreshPlan, clearInactiveMenu=clearInactiveMenu,
  plan=plan, launchGate=launchGate, launchTarget=launchTarget, beginLaunch=beginLaunch,
  redirectPause=redirectPause, nextCount=nextCount, watchdog=watchdog, cameraBlocked=cameraBlocked,
  shouldMeasure=shouldMeasure,
  wardrobeNeeded=wardrobeNeeded, restoreNeeded=restoreNeeded, classify=classify, puppetPlan=puppetPlan,
}
