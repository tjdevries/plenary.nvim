local uv = vim.loop

local Object = require("plenary.class")
local async = require("plenary.async")
local channel = require("plenary.async").control.channel

local M = {}

---@class uv_pipe_t
--- A pipe handle from libuv
---@field read_start function: Start reading
---@field read_stop function: Stop reading
---@field close function: Close the handle
---@field is_closing function: Whether handle is currently closing
---@field is_active function: Whether the handle is currently reading

---@class BasePipe
---@field super Object: Always available
---@field handle uv_pipe_t: A pipe handle
---@field extend function: Extend
local BasePipe = Object:extend()

function BasePipe:new()
  self.eof_tx, self.eof_rx = channel.oneshot()
end

function BasePipe:close(force)
  if force == nil then force = true end

  assert(self.handle, "Must have a pipe to close. Otherwise it's weird!")

  if self.handle:is_closing() then
    return
  end

  -- If we're not forcing the stop, allow waiting for eof
  -- This ensures that we don't end up with weird race conditions
  if not force then
    self.eof_rx()
  end

  self.handle:read_stop()
  if not self.handle:is_closing() then
    self.handle:close()
  end

  self._closed = true
end


---@class LinesPipe : BasePipe
local LinesPipe = BasePipe:extend()

function LinesPipe:new()
  LinesPipe.super.new(self)
  self.handle = uv.new_pipe(false)
end

function LinesPipe:read()
  local read_tx, read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    assert(not err, err)
    self.handle:read_stop()

    read_tx(data)
    if data == nil then
      self.eof_tx()
    end
  end)

  return read_rx()
end

function LinesPipe:iter(schedule)
  if schedule == nil then
    schedule = true
  end

  local text = nil
  local index = nil

  local get_next_text = function(previous)
    index = nil

    local read = self:read()
    if previous == nil and read == nil then
      return
    end

    return (previous or '') .. (read or '')
  end

  local next_value = nil
  next_value = function()
    if schedule then
      async.util.scheduler()
    end

    if text == nil or (text == "" and index == nil) then
      return nil
    end

    local start = index
    index = string.find(text, "\n", index, true)

    if index == nil then
      text = get_next_text(string.sub(text, start or 1))
      return next_value()
    end

    index = index + 1

    return string.sub(text, start or 1, index - 2)
  end

  text = get_next_text()

  return function()
    return next_value()
  end
end


---@class NullPipe : BasePipe
local NullPipe = BasePipe:extend()

function NullPipe:new()
  NullPipe.super.new(self)
  self.start = function() end
  self.read_start = function() end
  self.close = function() end

  -- This always has eof tx done, so can just call it now
  self.eof_tx()
end

---@class ChunkPipe : BasePipe
local ChunkPipe = BasePipe:extend()

function ChunkPipe:new()
  ChunkPipe.super.new(self)
  self.handle = uv.new_pipe(false)
end

function ChunkPipe:read()
  local read_tx, read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    assert(not err, err)
    self.handle:read_stop()

    read_tx(data)
    if data == nil then
      self.eof_tx()
    end
  end)

  return read_rx()
end

function ChunkPipe:iter()
  return function()
    if self._closed then
      return nil
    end

    return self:read()
  end
end

---@class ErrorPipe : BasePipe
local ErrorPipe = BasePipe:extend()

function ErrorPipe:new()
  ErrorPipe.super.new(self)
  self.handle = uv.new_pipe(false)
end

function ErrorPipe:start()
  self.handle:read_start(function(err, data)
    if not err and not data then
      return
    end

    self.handle:read_stop()
    self.handle:close()

    error(string.format("Err: %s, Data: '%s'", err, data))
  end)
end

M.NullPipe = NullPipe
M.LinesPipe = LinesPipe
M.ChunkPipe = ChunkPipe
M.ErrorPipe = ErrorPipe

return M
