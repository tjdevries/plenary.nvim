local Job = require("plenary.job_future").Job
local a = require('plenary.async_lib')
local async, await = a.async, a.await

local fn = async(function()
  print('start')
  local output = await(Job { "echo", [['hello world!']] }:output())
  assert(output:success())
  dump(output)
  print('end')
end)

a.run(fn())
