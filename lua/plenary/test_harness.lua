local Path = require("plenary.path")
local Job = require("plenary.job")

local f = require("plenary.functional")
local log = require("plenary.log")
local win_float = require("plenary.window.float")

local headless = require("plenary.nvim_meta").is_headless

local harness = {}

local print_output = vim.schedule_wrap(function(_, ...)
  for _, v in ipairs({...}) do
    io.stdout:write(tostring(v))
    io.stdout:write("\n")
  end

  vim.cmd [[mode]]
end)

local nvim_output = vim.schedule_wrap(function(bufnr, ...)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  for _, v in ipairs({...}) do
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {v})
  end
end)

function harness.test_directory_command(command)
  local split_string = vim.split(command, " ")
  local directory = table.remove(split_string, 1)

  local opts = assert(loadstring('return ' .. table.concat(split_string, " ")))()

  return harness.test_directory(directory, opts)
end

function harness.test_directory(directory, opts)
  print("Starting...")
  opts = vim.tbl_deep_extend('force', {winopts = {winblend = 3}}, opts or {})

  local res = {}
  if not headless then
    res = win_float.percentage_range_window(0.95, 0.70, opts.winopts)

    vim.api.nvim_buf_set_keymap(res.bufnr, "n", "q", ":q<CR>", {})
    vim.api.nvim_buf_set_option(res.bufnr, 'filetype', 'terminal')

    vim.api.nvim_win_set_option(res.win_id, 'winhl', 'Normal:Normal')
    vim.api.nvim_win_set_option(res.win_id, 'conceallevel', 3)
    vim.api.nvim_win_set_option(res.win_id, 'concealcursor', 'n')

    if res.border_win_id then
      vim.api.nvim_win_set_option(res.border_win_id, 'winhl', 'Normal:Normal')
    end
    vim.cmd('mode')
  end

  local outputter = headless and print_output or nvim_output

  local paths = harness._find_files_to_run(directory)
  for _, p in ipairs(paths) do
    outputter(res.bufnr, "Scheduling: " .. p.filename)
  end

  local path_len = #paths

  local jobs = vim.tbl_map(
    function(p)
      local args = {
        '--headless',
        '-c',
        string.format('lua require("plenary.busted").run("%s")', p:absolute())
      }

      if opts.minimal ~= nil then
        table.insert(args, '--noplugin')
      elseif opts.minimal_init ~= nil then
        table.insert(args, '--noplugin')

        table.insert(args, '-u')
        table.insert(args, opts.minimal_init)
      end

      return Job:new {
        command = vim.v.progpath,
        args = args,

        -- Can be turned on to debug
        on_stdout = function(_, data)
          if path_len == 1 then
            outputter(res.bufnr, data)
          end
        end,

        on_stderr = function(_, data)
          if path_len == 1 then
            outputter(res.bufnr, data)
          end
        end,

        on_exit = vim.schedule_wrap(function(j_self, _, _)
          if path_len ~= 1 then
            outputter(res.bufnr, unpack(j_self:stderr_result()))
            outputter(res.bufnr, unpack(j_self:result()))
          end

          vim.cmd('mode')
        end)
      }
    end,
    paths
  )

  log.debug("Running...")
  for i, j in ipairs(jobs) do
    j:start()
    log.debug("... Completed job number", i)
  end

  -- TODO: Probably want to let people know when we've completed everything.
  if not headless then
    return
  end

  table.insert(jobs, 50000)
  log.debug("...Waiting")
  Job.join(unpack(jobs))
  table.remove(jobs, table.getn(jobs))
  vim.wait(100)
  log.debug("Done...")

  if headless then
    if f.any(function(_, v) return v.code ~= 0 end, jobs) then
      os.exit(1)
    end

    os.exit(0)
  end
end

function harness._find_files_to_run(directory)
  local finder = Job:new {
    command = 'find',
    args = {directory, '-type', 'f', '-name', '*_spec.lua'},
  }

  return vim.tbl_map(Path.new, finder:sync())
end

function harness._run_path(test_type, directory)
  local paths = harness._find_files_to_run(directory)

  local bufnr = 0
  local win_id = 0

  for _, p in pairs(paths) do
    print(" ")
    print("Loading Tests For: ", p:absolute(), "\n")

    local ok, _ = pcall(function() dofile(p:absolute()) end)

    if not ok then
      print("Failed to load file")
    end
  end

  harness:run(test_type, bufnr, win_id)
  vim.cmd("qa!")

  return paths
end

return harness
