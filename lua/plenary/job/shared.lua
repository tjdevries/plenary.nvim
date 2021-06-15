local uv = vim.loop

local shared = {}

shared.get_command_and_args = function(opts)
  local command = opts.command
  if not command then
    if opts[1] then
      command = opts[1]
    else
      error(debug.traceback("'command' is required for Job:new"))
    end
  elseif opts[1] then
    error(debug.traceback("Cannot pass both 'command' and array args"))
  end

  local args = opts.args
  if not args then
    if #opts > 1 then
      args = {select(2, unpack(opts))}
    end
  end

  return command, args
end

shared.expand = function(path)
  -- TODO: Probably want to check that this is valid here... otherwise that's weird.
  if vim.in_fast_event() then
    return assert(uv.fs_realpath(path), string.format("Path must be valid: %s", path))
  else
    return vim.fn.expand(path, true)
  end
end

function shared.create_uv_options(job)
  local options = {}

  options.command = job.command
  options.args = job.args
  options.stdio = { job.stdin, job.stdout, job.stderr }

  if job._raw_cwd then options.cwd = shared.expand(job._raw_cwd) end
  if job.env then options.env = job.env end

  return options
end

function shared.get_stdin(writer, is_job, open_stdin)
  if writer then
    if is_job then
      writer:_prepare_pipes()
      return writer.stdout
    elseif writer.write then
      return writer
    end
  end

  if not open_stdin then
    return nil
  end

  return uv.new_pipe(false)
end

return shared
