local function new(ports)
  local api={}
  function api.begin(options,action,context)
    if not context.editorOpen then return nil,"The character editor closed before Undo was prepared." end
    local signature=ports.signature(options)
    if not signature then return nil,"The current appearance could not be checked safely." end
    local preset,canonical=ports.capture(options,action)
    if not preset then return nil,"The current appearance could not be saved for Undo." end
    return {stage="compare",preset=preset,canonical=canonical,signature=signature,name=context.name,
      session=context.session,generation=context.generation,body=context.body,source=context.source,started=context.now}
  end
  function api.step(job,options,context)
    if not context.editorOpen or context.name~=job.name or context.session~=job.session
        or context.body~=job.body or context.generation~=job.generation or context.source~=job.source then
      return "error","The editor changed while preparing Undo. Load the preset again."
    end
    if context.now-job.started>=5 then return "error","Preparing Undo took too long. Loading stopped." end
    if ports.signature(options)~=job.signature then
      return "error","The appearance changed while preparing Undo. Load the preset again."
    end
    if job.stage=="compare" then
      local previous,expected,reason=ports.previous()
      if reason then return "error",reason end
      job.expected=expected
      if previous and ports.same(job.preset,previous,job.canonical) then job.stage="ready";job.preset=nil
      else job.stage="encode" end
      job.canonical=nil
    elseif job.stage=="encode" then
      job.prepared=ports.encode(job.preset)
      if not job.prepared then return "error","The Undo snapshot could not be validated. Loading stopped." end
      job.preset=nil
      job.stage="write"
    elseif job.stage=="write" then
      if not ports.write(job.prepared,job.expected) then
        return "error","The Undo snapshot could not be saved. The previous copy was kept and loading stopped."
      end
      ports.installed(job.prepared.preset)
      job.expected=nil
      job.stage="ready"
    elseif job.stage=="ready" then
      if ports.ready and not ports.ready(job.prepared,job.expected) then
        return "error","The Undo file changed before loading. No appearance changes were made."
      end
      return "ready"
    end
    return "pending"
  end
  return api
end
return {new=new}
