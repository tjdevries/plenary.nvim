local Path = require('plenary.path')

local dirname = function(p)
  return vim.fn.fnamemodify(p, ":h")
end

local function get_trace(element, level, msg)

  local function trimTrace(info)
    local start_index = info.traceback:find('/')
    local end_index = info.traceback:find(': in')
    info.traceback = info.traceback:sub(start_index, end_index)

    return info
  end

  level = level or  3

  local thisdir = dirname(debug.getinfo(1, 'Sl').source)
  local info = debug.getinfo(level, 'Sl')
  while info.what == 'C' or info.short_src:match('luassert[/\\].*%.lua$') or
    (info.source:sub(1,1) == '@' and thisdir == dirname(info.source)) do
    level = level + 1
    info = debug.getinfo(level, 'Sl')
  end

  info.traceback = debug.traceback('', level)
  info.message = msg

  -- local file = busted.getFile(element)
  -- local file = false
  -- local file = false
  -- return file and file.getTrace(file.name, info) or trimTrace(info)
  return trimTrace(info)
end

local function get_file_and_line_number()

  local function trimTrace(trace)
    local start_index = trace:find('/')
    local end_index = trace:find(': in')
    trace = trace:sub(start_index, end_index)

    local split_str = vim.split(trace, ':')
    local spec = {}
    spec.file = split_str[1]
    spec.linenumber = split_str[2]

    return spec
  end

  local level = 3

  local thisdir = dirname(debug.getinfo(1, 'Sl').source)
  local info = debug.getinfo(level, 'Sl')
  while info.what == 'C' or info.short_src:match('luassert[/\\].*%.lua$') or
    (info.source:sub(1,1) == '@' and thisdir == dirname(info.source)) do
    level = level + 1
    info = debug.getinfo(level, 'Sl')
  end

  local trace = debug.traceback('', level)

  return trimTrace(trace)
end

--[[ is_headless is always true
-- running in nvim or in terminal --]]
local is_headless = require('plenary.nvim_meta').is_headless

local print = function(...)
  for _, v in ipairs({...}) do
    io.stdout:write(tostring(v))
    io.stdout:write("\t")
  end

  io.stdout:write("\r\n")
end

local mod = {}

local results = {}
local current_description = {}
local current_before_each = {}
local current_after_each = {}

local add_description = function(desc)
  table.insert(current_description, desc)

  return vim.deepcopy(current_description)
end

local pop_description = function()
  current_description[#current_description] = nil
end

local add_new_each = function()
  current_before_each[current_description[#current_description]] = {}
  current_after_each[current_description[#current_description]] = {}
end

local clear_last_each = function()
  current_before_each[current_description[#current_description]] = nil
  current_after_each[current_description[#current_description]] = nil
end

local call_inner = function(desc, func)
  local desc_stack = add_description(desc)
  add_new_each()
  local ok, msg = xpcall(func, function(msg)
    local trace = get_trace(nil, 3, msg)
    -- return trace.message .. "\n" .. trace.traceback
    return trace.message
  end)
  clear_last_each()
  pop_description()

  return ok, msg, desc_stack
end

local ansi_color_table = {
  cyan = 36,
  magenta = 35,
  yellow = 33,
  green = 32,
  red = 31,
}

local color_string = function(color, str)
  if not is_headless then
    -- This is never being called
    return str
  end

  return string.format("%s[%sm%s%s[%sm",
  string.char(27),
  ansi_color_table[color] or 0,
  str,
  string.char(27),
  0
  )
end

local bold_string = function(str)
  local ansi_bold = "\027[1m"
  local ansi_clear = "\027[0m"

  return ansi_bold .. str .. ansi_clear
end

-- local SUCCESS = color_string("green", "Success")
local FAIL = color_string("red", "Failure")
local SUCCESS = color_string("green", "Success")
local PENDING = color_string("yellow", "Pending")

local HORIZONTALRULER = string.rep("─", 80)

mod.format_results = function(result)

  local num_pass = color_string("green", #result.pass)
  local num_fail = color_string("red", #result.fail)
  local num_errs = color_string("magenta", #result.errs)

  print(string.format(" %s successes /  %s failures / %s errors", num_pass, num_fail, num_errs))
end

mod.describe = function(desc, func)
  results.pass = {}
  results.fail = {}
  results.errs = {}

  print("\n" .. HORIZONTALRULER .."\n ")
  -- print("Testing: ", debug.getinfo(2, 'Sl').source)
  describe = mod.inner_describe
  local ok, msg = call_inner(desc, func)
  describe = mod.describe

  table.insert(results.fatal, msg)
end

mod.inner_describe = function(desc, func)
  local ok, msg, desc_stack = call_inner(desc, func)

  if not ok then
    table.insert(results.errs, {
      descriptions = desc_stack,
      msg = msg
    })
  end
end

mod.before_each = function(fn)
  table.insert(current_before_each[current_description[#current_description]], fn)
end

mod.after_each = function(fn)
  table.insert(current_after_each[current_description[#current_description]], fn)
end

mod.clear = function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
end

local indent = function(msg, spaces)
  if spaces == nil then
    spaces = 4
  end

  local prefix = string.rep(" ", spaces)
  return prefix .. msg:gsub("\n", "\n" .. prefix)

end

local run_each = function(tbl)
  for _, v in pairs(tbl) do
    for _, w in ipairs(v) do
      if type(w) == 'function' then w() end
    end
  end
end

mod.it = function(desc, func)
  run_each(current_before_each)
  local ok, msg, desc_stack = call_inner(desc, func)
  run_each(current_after_each)

  local test_result = {
    descriptions = desc_stack,
    msg = nil,
  }

  -- TODO: We should figure out how to determine whether
  -- and assert failed or whether it was an error...
  local to_insert, printed
  if not ok then
    to_insert = results.fail
    test_result.msg = msg

    --     print(FAIL, " → " .. color_string("cyan", "spec/foo/bar_spec.lua @ 7") .. "\n")

    print("{SPEC: FAIL}")
    local spec = get_file_and_line_number()

    print(FAIL, " → " .. color_string("cyan", spec.file) .. " @ " .. color_string("cyan", spec.linenumber) .. "\n")

    print(bold_string(table.concat(test_result.descriptions)))
    print(indent("\n" .. msg, 7))

    print("{ENDOFSPEC}")

  else
    print("{SPEC: SUCCESS}")
    print(SUCCESS, " → ", table.concat(test_result.descriptions, " "))
    print("{ENDOFSPEC}")
  end

  table.insert(to_insert, test_result)
end

mod.pending = function(desc, func)
  local curr_stack = vim.deepcopy(current_description)
  table.insert(curr_stack, desc)
  print(PENDING, "||", table.concat(curr_stack, " "))
end

_PlenaryBustedOldAssert = _PlenaryBustedOldAssert or assert


describe = mod.describe
it = mod.it
pending = mod.pending
before_each = mod.before_each
after_each = mod.after_each
clear = mod.clear
assert = require("luassert")

mod.run = function(file)
  -- print("Testing: ", file)

  local ok, msg = pcall(dofile, file)

  if not ok then
    print(HORIZONTALRULER)
    print("FAILED TO LOAD FILE")
    print(color_string("red", msg))
    print(HORIZONTALRULER)

    os.exit(2)
    if is_headless then
      os.exit(2)
    else
      return
    end
  end

  -- If nothing runs (empty file without top level describe)
  if not results.pass then
    if is_headless then
      os.exit(0)
    else
      return
    end
  end

  mod.format_results(results)

  if #results.fatal ~= 0 then
    print("We had an unexpected error: ", vim.inspect(results.fatal), vim.inspect(results))
    if is_headless then
      os.exit(2)
    end
  elseif #results.fail > 0 then
    print("Tests Failed. Exit: 1")

    if is_headless then
      os.exit(1)
    end
  else
    if is_headless then
      os.exit(0)
    end
  end
end

return mod
