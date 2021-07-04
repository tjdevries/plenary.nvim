---@brief [[
--- NOTE: This API is still under construction.
---         It may change in the future :)
---@brief ]]

local exports = require('plenary.async.async')
exports.uv = require('plenary.async.uv_async')
exports.util = require('plenary.async.util')
exports.lsp = require('plenary.async.lsp')
exports.api = require('plenary.async.api')
exports.tests = require('plenary.async.tests')
exports.control = require('plenary.async.control')

exports.tests.add_globals = function()
  a = exports
  async = exports.async
  await = exports.await
  await_all = exports.await_all

  -- must prefix with a or stack overflow, plenary.test harness already added it
  a.describe = exports.tests.describe
  -- must prefix with a or stack overflow
  a.it = exports.tests.it
end

exports.tests.add_to_env = function()
  local env = getfenv(2)

  env.a = exports
  env.async = exports.async
  env.await = exports.await
  env.await_all = exports.await_all

  -- must prefix with a or stack overflow, plenary.test harness already added it
  env.a.describe = exports.tests.describe
  -- must prefix with a or stack overflow
  env.a.it = exports.tests.it

  setfenv(2, env)
end

return exports
