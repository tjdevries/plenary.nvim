local uv = vim.loop

local log = require("plenary.log")
local async = require("plenary.async")

local NullPipe = require('plenary.async_job.pipes').NullPipe

local j_utils = require('plenary.async_job.util')

local M = {}

local AsyncJob = {}
AsyncJob.__index = AsyncJob

-- function AsyncJob:new(opts)
--   return setmetatable({}, self)
-- end

function AsyncJob.new(opts)
  local self = setmetatable({}, AsyncJob)

  self.command, self.uv_opts = j_utils.convert_opts(opts)

  self.stdin = opts.stdin or NullPipe()
  self.stdout = opts.stdout or NullPipe()
  self.stderr = opts.stderr or NullPipe()

  if opts.cwd then
    -- TODO: not vim.fn
    self.uv_opts.cwd = vim.fn.expand(opts.cwd)
  end

  self.uv_opts.stdio = {
    self.stdin.handle,
    self.stdout.handle,
    self.stderr.handle,
  }

  return self
end

function AsyncJob:_for_each_pipe(f, ...)
  for _, pipe in ipairs({self.stdin, self.stdout, self.stderr}) do
    f(pipe, ...)
  end
end

function AsyncJob:close(force)
  if force == nil then force = true end

  self:_for_each_pipe(function(p) p:close(force) end)
  if not self.handle:is_closing() then
    self.handle:close()
  end

  log.debug("[async_job] closed")
end

M.spawn = function(opts)
  local self = AsyncJob.new(opts)

  self.handle = uv.spawn(self.command, self.uv_opts, async.void(function()
    self:close(false)
  end))

  return self
end

return M
