
local M = {}

M.convert_opts = function(o)
  if not o then
    error(debug.traceback("Options are required for Job:new"))
  end

  local command = o.command
  if not command then
    if o[1] then
      command = o[1]
    else
      error(debug.traceback("'command' is required for Job:new"))
    end
  elseif o[1] then
    error(debug.traceback("Cannot pass both 'command' and array args"))
  end

  local args = o.args
  if not args then
    if #o > 1 then
      args = {select(2, unpack(o))}
    end
  end

  local ok, is_exe = pcall(vim.fn.executable, command)
  if not o.skip_validation and ok and 1 ~= is_exe then
    error(debug.traceback(command..": Executable not found"))
  end

  local obj = {}

  obj.args = args

  return command, obj
end

return M
