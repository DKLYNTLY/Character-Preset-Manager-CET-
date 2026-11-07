local function summary(reason, confirmed, unresolved)
  local total = confirmed + unresolved
  if reason == "complete" and unresolved == 0 then
    return ("Loaded all %d saved choices."):format(total), "success", "complete"
  end
  if reason == "complete" then
    return ("Loaded %d of %d saved choices. %d could not be confirmed. Open the Activity Log for details.")
      :format(confirmed, total, unresolved), "warning", "partial"
  end
  local explanation = {
    timeout="Loading timed out.",
    unstable="The editor did not settle before verification.",
    failure="Loading stopped after an error.",
    ["write-failed"]="The game rejected a saved choice.",
    ["editor-closed"]="Loading stopped when the editor closed.",
    shutdown="Loading stopped when the game shut down.",
  }
  return ("%s Confirmed %d of %d saved choices. Open the Activity Log for details.")
    :format(explanation[reason] or "Loading stopped.",confirmed,total), "error", reason
end

return {summary=summary}
