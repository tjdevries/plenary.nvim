local a = require("plenary.async_lib")
local async, await, await_all = a.async, a.await, a.await_all
local uv = vim.loop
local Condvar = a.util.Condvar
local channel = a.util.channel
local Output = require('plenary.job_future.output')

local Handle = {}
Handle.__index = Handle

function Handle.new(spawn_opts)
  local exit_tx, exit_rx = channel.oneshot()
  local stdout_eof_tx, stdout_eof_rx = channel.oneshot()
  local stderr_eof_tx, stderr_eof_rx = channel.oneshot()

  local buf_read = not spawn_opts.raw_read

  local self = setmetatable({
    -- data that was received
    stdout_data = buf_read and "",
    stderr_data = buf_read and "",

    -- control flow
    exit_tx = exit_tx,
    exit_rx = exit_rx,
    stdout_eof_tx = buf_read and stdout_eof_tx,
    stdout_eof_rx  = buf_read and stdout_eof_rx,
    stderr_eof_tx = buf_read and stderr_eof_tx,
    stderr_eof_rx = buf_read and stderr_eof_rx,

    -- data condvars
    stdout_data_condvar = buf_read and Condvar.new(),
    stderr_data_condvar = buf_read and Condvar.new(),

    -- lock
    dead = false,

    spawn_opts = spawn_opts,
  }, Handle)

  return self
end

function Handle:get_pipe(name)
  assert(name == "stdout" or name == "stdin" or name == "stderr", "Not a correct pipe name")
  return self.spawn_opts[name]
end

function Handle:check_dead()
  assert(not self.dead, "The handle is not running anymore")
end

Handle.write = async(function(self, stuff)
  await(a.uv.write(self.spawn_opts.stdin, stuff .. '\n'))
end)

Handle.read_stdout = async(function(self)
  assert(not self.spawn_opts.raw_read, "Raw read cannot be enabled to call this method")

  if self.stdout_data == "" then
    await(self.stdout_data_condvar:wait())
  end

  local stdout_data = self.stdout_data
  self.stdout_data = ""
  return stdout_data
end)

Handle.read_all_stdout = async(function(self)
  assert(not self.spawn_opts.raw_read, "Raw read cannot be enabled to call this method")

  await(self.stdout_eof_rx())

  local stdout_data = self.stdout_data
  self.stdout_data = ""
  return stdout_data
end)

Handle.read_all_stderr = async(function(self)
  assert(not self.spawn_opts.raw_read, "Raw read cannot be enabled to call this method")

  await(self.stderr_eof_rx())

  local stderr_data = self.stderr_data
  self.stderr_data = ""
  return stderr_data
end)

Handle.read_stderr = async(function(self)
  assert(not self.spawn_opts.raw_read, "Raw read cannot be enabled to call this method")

  if self.stderr_data == "" then
    await(self.stderr_data_condvar:wait())
  end

  local stderr_data = self.stderr_data
  self.stderr_data = ""
  return stderr_data
end)

Handle.wait_done = async(function(self)
  self:check_dead()

  return await(self.exit_rx())
end)

do
  local hit_eof = {
    stdout = false,
    stderr = false,
  }

  Handle.raw_read = async(function(self, pipe_name)
    assert(self.spawn_opts.raw_read == true, "Raw read must be enabled")
    if hit_eof[pipe_name] then
      error(string.format("Pipe with name %s hit eof", pipe_name))
    end

    local pipe = self:get_pipe(pipe_name)

    local tx, rx = channel.oneshot()

    pipe:read_start(function(err, data)
      pipe:read_stop()

      assert(not err, err)

      if data == nil then
        hit_eof[pipe_name] = true
      end

      tx(data or false)
    end)

    local res = await(rx())

    if res == false then
      return nil
    else
      return res
    end
  end)
end

-- safety: when the process is killed, all read_start callbacks will be called with data == nil which means that eof has been hit
-- each callback will check for this and close the proper pipe
-- this means that pipes will always be closed properly and there will be no closing pipes while there is still output
-- which can lead to a broken pipe error in the process
-- if the process is not killed and stops naturally, eof will be hit naturally and the same process above happens
-- this means that if there are multiple queued reads it will not close before everything is finished
---if force is true, will stop it with sigkill
Handle.stop = async(function(self, force)
  self:check_dead()

  local signal = force and "sigkill" or "sigterm"
  self.process_handle:kill(signal)

  self.exit_code, self.signal = await(self.exit_rx())

  return Output.from_handle(self)
end)

function Handle:_raw_spawn(uv_opts, spawn_opts)
  self.process_handle, self.pid = uv.spawn(uv_opts.command, uv_opts, function(code, signal)
    local fn = async(function()
      await_all {
        a.uv.close(self.process_handle),
        a.uv.close(spawn_opts.stdin),
      }

      self.dead = true

      self.exit_tx(code, signal)
    end)

    a.run(fn())
  end)
end

function Handle:_read_start_stdout(spawn_opts)
  uv.read_start(spawn_opts.stdout, function(err, data)
    local fn = async(function()
      assert(not err, err)

      if data == nil then
        self.stdout_eof_tx(true)
        await(a.uv.close(spawn_opts.stdout))
      else
        -- first update the data
        self.stdout_data = self.stdout_data .. data

        -- then notify everyone that is waiting on our data that it is ready
        self.stdout_data_condvar:notify_all()
      end
    end)

    a.run(fn())
  end)
end

function Handle:_read_start_stderr(spawn_opts)
  -- this is the same as for stdout but for stderr
  uv.read_start(spawn_opts.stderr, function(err, data)
    local fn = async(function()
      assert(not err, err)

      if data == nil then
        self.stderr_eof_tx(true)
        await(a.uv.close(spawn_opts.stderr))
      else
        self.stderr_data = self.stderr_data .. data

        self.stderr_data_condvar:notify_all()
      end
    end)

    a.run(fn())
  end)
end

return Handle
