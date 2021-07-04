# plenary.nvim

All the lua functions I don't want to write twice.

> plenary:
>
>     full; complete; entire; absolute; unqualified.

Note that this library is useless outside of Neovim since it requires Neovim functions. It should be usable with any recent version of Neovim though.

At the moment, it is very much in pre-alpha :smile: Expect changes to the way some functions are structured. I'm hoping to finish some document generators to provide better documentation for people to use and consume and then at some point we'll stabilize on a few more stable APIs.

## Installation

```vim
Plug 'nvim-lua/plenary.nvim'
```

## Modules

- `plenary.job`
- `plenary.path`
- `plenary.scandir`
- `plenary.context_manager`
- `plenary.test_harness`
- `plenary.filetype`
- `plenary.strings`

### plenary.job

A Lua module to interactive with system processes. Pass in your `command`, the desired `args`, `env` and `cwd`.
Define optional callbacks for `on_stdout`, `on_stderr` and `on_exit` and `start` your Job.

Note: Each job has an empty environment.

```lua
local Job = require'plenary.job'

Job:new({
  command = 'rg',
  args = { '--files' },
  cwd = '/usr/bin',
  env = { ['a'] = 'b' },
  on_exit = function(j, return_val)
    print(return_val)
    print(j:result())
  end,
}):sync() -- or start()
```

### plenary.path

A Lua module that implements a bunch of the things from `pathlib` from Python, so that paths are easy to work with.

### plenary.scandir

`plenery.scandir` is fast recursive file operations. It is similar to unix `find` or `fd` in that it can do recursive scan over a given directory, or a set of directories.

It offers a wide range of opts for limiting the depth, show hidden and more. `plenary.scan_dir` can be ran synchronously and asynchronously and offers `on_insert(file, typ)` and `on_exit(files)` callbacks. `on_insert(file, typ)` is available for both while `on_exit(files)` is only available for async.

```lua
local scan = require'plenary.scandir`
scan.scan_dir('.', { hidden = true, depth = 2 })
```

This module also offers `ls -la` sync and async functions that will return a formated string for all files in the directory.
Why? Just for fun

### plenary.context_manager

Implements `with` and `open` just like in Python. For example:

```lua
local with = context_manager.with
local open = context_manager.open

local result = with(open("README.md"), function(reader)
  return reader:read()
end)

assert(result == "# plenary.nvim")
```


### plenary.test_harness

Supports (simple) busted-style testing. It implements a mock-ed busted interface, that will allow you to run simple
busted style tests in separate neovim instances.

To run the current spec file in a floating window, you can use the keymap `<Plug>PlenaryTestFile`. For example:

```
nmap <leader>t <Plug>PlenaryTestFile
```

To run a whole directory from the command line, you could do something like:

```
nvim --headless -c "PlenaryBustedDirectory tests/plenary/ {minimal_init = 'tests/minimal_init.vim'}"
```

Where the first argument is the directory you'd like to test. It will search for files with
the pattern `*_spec.lua` and execute them in parallel in separate neovim instances.

The second argument is an optional init.vim to specify so that you can make reproducible tests!

The exit code is 0 when success and 1 when fail, so you can use it easily in a `Makefile`!


NOTE:

So far, the only supported busted items are:

- `describe`
- `it`
- `pending`
- `before_each`
- `after_each`
- `clear`
- `assert.*` etc. (from luassert, which is bundled)

OTHER NOTE:

We used to support `luaunit` and original `busted` but it turns out it was way too hard and not worthwhile
for the difficulty of getting them setup, particularly on other platforms or in CI. Now, we have a dep free
(or at least, no other installation steps necessary) `busted` implementation that can be used more easily.

Please take a look at the new APIs and make any issues for things that aren't clear. I am happy to fix them
and make it work well :)

OTHER OTHER NOTE:
Take a look at some test examples [here](TESTS_README.md).

#### Colors
To have "Success" in green and "Failed" in red, you need [nvim-terminal.lua](https://github.com/norcalli/nvim-terminal.lua).
In order for it to work, make sure to run the setup function in your config.
For `init.vim`:
```vim
lua require('terminal').setup()
```
For `init.lua`:
```lua
require('terminal').setup()
```

### plenary.filetype

Will detect the filetype based on `extension`/`special filename`/`shebang` or `modeline`

- `require'plenary.filetype'.detect(filepath, opts)` is a function that does all of above and exits as soon as a filetype is found
- `require'plenary.filetype'.detect_from_extension(filepath)`
- `require'plenary.filetype'.detect_from_name(filepath)`
- `require'plenary.filetype'.detect_from_modeline(filepath)`
- `require'plenary.filetype'.detect_from_shebang(filepath)`

Add filetypes by creating a new file named `~/.config/nvim/data/plenary/filetypes/foo.lua` and register that file with
`:lua require'plenary.filetype'.add_file('foo')`. Content of the file should look like that:
```lua
return {
  extension = {
    -- extension = filetype
    -- example:
    ['jl'] = 'julia',
  },
  file_name = {
    -- special filenames, likes .bashrc
    -- we provide a decent amount
    -- name = filetype
    -- example:
    ['.bashrc'] = 'bash',
  },
  shebang = {
    -- Shebangs are supported as well. Currently we provide
    -- sh, bash, zsh, python, perl with different prefixes like
    -- /usr/bin, /bin/, /usr/bin/env, /bin/env
    -- shebang = filetype
    -- example:
    ['/usr/bin/node'] = 'javascript',
  }
}
```

### plenary.strings

Re-implement VimL funcs to use them in Lua loop.

* `strings.strdisplaywidth`
* `strings.strcharpart`

And some other funcs are here to deal with common problems.

* `strings.truncate`
* `strings.align_str`
* `strings.dedent`

### plenary.profile

Thin wrapper around LuaJIT's [`jit.p` profiler](https://blast.hk/moonloader/luajit/ext_profiler.html).

```lua
require'plenary.profile'.start("profile.log")

-- code to be profiled

require'plenary.profile'.stop()
```

You can use `start("profile.log", {flame = true})` to output the log in a
flamegraph-compatible format. A flamegraph can be created from this using
https://github.com/jonhoo/inferno via
```
inferno-flamegraph profile.log > flame.svg
```
The resulting interactive SVG file can be viewed in any browser.

Status: WIP

### plenary.popup

`popup_*` clone of Vim's commands. If it gets good enough, will submit PR to Neovim and write C wrappers
to provide compatibility layer for Neovim.

Status: WIP

### plenary.window

Window helper functions to wrap some of the more difficult cases. Particularly for floating windows.

Status: WIP

### plenary.collections

Contains pure lua implementations for various standard collections.

```lua
local List = require 'plenary.collections.py_list'

local myList = List { 9, 14, 32, 5 }

for i, v in myList:iter() do
    print(i, v)
end

```

Status: WIP

### Troubleshooting

If you're having trouble / things are hanging / other problems:

```
$ export DEBUG_PLENARY=true
```

This will enable debuggin for the plugin.

### plenary.neorocks

DELETED: Please use packer.nvim or other lua-rocks wrapper instead. This no longer exists.
