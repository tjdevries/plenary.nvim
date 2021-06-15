require('plenary.async_lib').tests.add_to_env()
local eq = assert.are.same
local uv = vim.loop
local Job = require("plenary.job_future").Job
local protected = a.util.protected

a.describe('Job', function()
  a.describe('echo', function()
    a.it('should work simple', function()
      local output = await(Job { "echo", [['hello world!']] }:output())
      assert(output:success())
    end)

    a.it('should allow raw read', function()
      local handle = Job { "echo", [['hello world!']] }:spawn { raw_read = true }
      local res = await(handle:raw_read("stdout"))
      assert(res:match('hello world!') ~= nil)
    end)

    a.it('should protect from raw read past eof', function()
      local handle = Job { "echo", [['hello world!']] }:spawn { raw_read = true }

      local hit_eof = false
      for i = 1, 10 do
        local stat, ret = await(protected(handle:raw_read("stdout")))
        eq(stat, not hit_eof)
        if ret == nil then
          hit_eof = true
        end
      end
    end)
  end)

  a.describe('cat', function()
    a.it('should work when interactive', function()
      local handle = Job { "cat", "-", interactive = true }:spawn()
      await(handle:write("hello world!"))
      local got = await(handle:read_stdout())
      assert(got, "hello world!")
      local output = await(handle:stop())
      assert(output:success())
    end)

    a.it('should error when stopping job when already dead', function()
      local handle = Job { "cat", "-", interactive = true }:spawn()
      await(handle:write("hello world!"))
      local got = await(handle:read_stdout())
      assert(got, "hello world!")
      local output = await(handle:stop())
      assert(output:success())

      local stat, ret = await(protected(handle:stop()))
      assert(not stat)

      local stat, ret = await(protected(handle:stop()))
      assert(not stat)
    end)
  end)

  a.describe('python', function()
    a.it('should work when interactive and capture stderr', function()
      local handle = Job { "python", "-i", interactive = true }:spawn()

      -- prelude
      assert(await(handle:read_stderr()):match("Python"))

      await(handle:write("1 + 1"))

      eq(await(handle:read_stdout()), "2\n")

      local output = await(handle:stop())
      assert(output:success())
    end)
  end)

  a.describe('long job', function()
    a.it('should close properly', function()
      local handle = Job { "sleep", "1000" }:spawn()
      local output = await(handle:stop())

      assert(output:success())
      eq(output.signal, 15)
    end)
  end)
end)
