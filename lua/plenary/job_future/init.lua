local a = require("plenary.async_lib")
local async, await = a.async, a.await
local uv = vim.loop
local Output = require('plenary.job_future.output')
local Handle = require('plenary.job_future.handle')
local tbl = require('plenary.tbl')

local shared = require('plenary.job.shared')

local Job = {}
Job.__index = Job
Job.__concat = function(lhs, rhs)
  local new_job = Job.new(rhs.opts)
  new_job.writer = lhs
  return new_job
end

function Job.new(opts)
  local command, args = shared.get_command_and_args(opts)

  local interactive = opts.interactive
  if interactive == nil then interactive = false end

  return setmetatable({
    command = command,
    args = args,
    writer = opts.writer,
    interactive = interactive,

    _raw_cd = opts.cwd,
    _opts = opts,
  }, Job)
end

-- TODO: add support for piping jobs to each other
---Thin wrapper around Job:spawn
Job.output = async(function(self)
  -- assert(not self.interactive, "Cannot get the output of an interactive job")

  local handle = self:spawn()

  local stdout_data = await(handle:read_all_stdout())
  local stderr_data = await(handle:read_all_stderr())

  local exit_code, signal = await(handle:wait_done())

  return setmetatable({
    stdout_data = stdout_data,
    stderr_data = stderr_data,
    exit_code = exit_code,
    signal = signal,
  }, Output)
end)

-- TODO: allow pipes to be confirgurable
Job.spawn = function(self, spawn_opts)
  assert(not (self.writer and spawn_opts.stdin), "Cannot pass both writer and stdin")

  spawn_opts = tbl.copy_one_level(spawn_opts or {})
  spawn_opts.stdin = spawn_opts.stdin or shared.get_stdin(self.writer, false, true)
  spawn_opts.stdout = spawn_opts.stdout or uv.new_pipe(false)
  spawn_opts.stderr = spawn_opts.stderr or uv.new_pipe(false)

  local uv_opts = shared.create_uv_options(self)
  uv_opts.stdio = { spawn_opts.stdin, spawn_opts.stdout, spawn_opts.stderr }

  local job_handle = Handle.new(spawn_opts)
  job_handle:_raw_spawn(uv_opts, spawn_opts)

  if spawn_opts.raw_read == true then
    return job_handle
  end

  job_handle:_read_start_stdout(spawn_opts)
  job_handle:_read_start_stderr(spawn_opts)

  return job_handle
end

return {
  Job = function(opts) return Job.new(opts) end,
}
