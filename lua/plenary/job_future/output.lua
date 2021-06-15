local Output = {}
Output.__index = Output

function Output.from_handle(handle)
  return setmetatable({
    stdout_data = handle.stdout_data,
    stderr_data = handle.stderr_data,
    exit_code = handle.exit_code,
    signal = handle.signal,
  }, Output)
end

function Output:stdout_lines()
  return vim.split(self.stdout_data, '\n', true)
end

function Output:stderr_lines()
  return vim.split(self.stderr_data, '\n', true)
end

function Output:success()
  return self.exit_code == 0
end

function Output:closed_normally()
  return self.signal == 0
end

return Output
