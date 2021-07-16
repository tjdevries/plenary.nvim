local uv = vim.loop

local async = R "plenary.async"
local async_job = R "plenary.async_job"
local async_pipes = R "plenary.async_job.pipes"

local LinesPipe = async_pipes.LinesPipe
local ChunkPipe = async_pipes.ChunkPipe
local ErrorPipe = async_pipes.ErrorPipe

-- local Pipe = async_pipes.Pipe

-- local bufnr = 7
-- Append = function(...)
--   local text = table.concat({...}, "  ")
--   if not text then return end

--   async.api.nvim_buf_set_lines(bufnr, -1, -1, false, { text })
-- end
-- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

async.void(function()
  local start = uv.hrtime()

  -- local stdout = ChunkPipe()
  local stdout = LinesPipe()
  -- local stdout = Pipe()
  -- local stderr = ErrorPipe()

  -- local job = async_job.spawn { "rg", "--files", "/home/tjdevries/", stdout = stdout, }
  -- local job = async_job.spawn { "does_not_exist", stdout = stdout, stderr = stderr }
  local job = async_job.spawn { "./scratch/ajob/line_things.sh", stdout = stdout }

  local text = 0
  for val in stdout:iter() do
    text = text + 1
    print(val)
  end

  -- local text = 0
  -- for val in stdout:iter() do
  --   text = text + #val

  --   if text > 1000 then
  --     job:close()
  --   end
  -- end

  async.util.scheduler()
  print("Time Elapsed:", (uv.hrtime() - start) / 1e9, " // Total lines processed:", text)
end)()
