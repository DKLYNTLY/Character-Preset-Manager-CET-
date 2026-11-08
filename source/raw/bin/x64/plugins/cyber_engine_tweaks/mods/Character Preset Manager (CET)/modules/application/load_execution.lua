local function new(order, parents, timeout, quietTime)
  local pending, outcomes, hasChildren = {}, {}, {}
  for _, dependencies in pairs(parents) do
    for parent in pairs(dependencies) do hasChildren[parent] = true end
  end
  for _, position in ipairs(order) do pending[position] = true end
  return {order=order, parents=parents, pending=pending, outcomes=outcomes, hasChildren=hasChildren,
    timeout=timeout, quietTime=quietTime}
end

local function stop(job, reason)
  job.stopped, job.waiting, job.pending = reason, nil, {}
  return {kind="finished", reason=reason}
end

local function step(job, event)
  if job.stopped then return {kind="finished", reason=job.stopped} end
  if event.cancel or not event.editorOpen then return stop(job, event.cancel or "editor-closed") end
  if event.writeFailed then return stop(job, "write-failed") end
  if not job.started then
    job.started, job.deadline = event.now, event.now + job.timeout
  end
  if event.now >= job.deadline then return stop(job, "timeout") end
  local waiting = job.waiting
  if waiting then
    if event.writeFailed then return stop(job, "write-failed") end
    if not event.matching or event.generation ~= waiting.generation then
      waiting.quietAt, waiting.generation = event.now, event.generation
    elseif event.now - waiting.quietAt >= job.quietTime then
      job.outcomes[waiting.position] = "confirmed"
      job.pending[waiting.position] = nil
      job.waiting = nil
      return {kind="refresh"}
    end
    return {kind="wait", position=waiting.position}
  end
  if not job.cursor then job.cursor = 1 end
  local position = job.order[job.cursor]
  if not position then return stop(job, "complete") end
  if not job.pending[position] then
    job.cursor = job.cursor + 1
    return {kind="continue"}
  end
  for parent in pairs(job.parents[position] or {}) do
    if job.outcomes[parent] ~= "confirmed" then
      job.pending[position], job.outcomes[position] = nil, "dependency-unresolved"
      job.cursor = job.cursor + 1
      return {kind="warn", position=position, reason="dependency-unresolved"}
    end
  end
  if event.position ~= position then return {kind="resolve", position=position} end
  if event.status == "matching" then
    job.pending[position], job.outcomes[position] = nil, "confirmed"
    job.cursor = job.cursor + 1
    return {kind="continue"}
  end
  if event.status ~= "ready" then
    job.pending[position], job.outcomes[position] = nil, event.status or "unresolved"
    job.cursor = job.cursor + 1
    return {kind="warn", position=position, reason=job.outcomes[position]}
  end
  if job.hasChildren[position] and job.quietTime > 0 then
    job.waiting = {position=position, quietAt=event.now, generation=event.generation}
  else
    job.pending[position], job.outcomes[position] = nil, job.hasChildren[position] and "confirmed" or "applied"
    job.cursor = job.cursor + 1
  end
  return {kind="write", position=position, target=event.target}
end

return {new=new, step=step}
