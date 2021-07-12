local shebang_prefixes = { '/usr/bin/', '/bin/', '/usr/bin/env ', '/bin/env ' }
local shebang_fts = {
  ['sh'] = 'sh',
  ['bash'] = 'sh',
  ['zsh'] = 'zsh',
  ['fish'] = 'fish',
  ['python'] = 'python',
  ['python2'] = 'python',
  ['python3'] = 'python',
  ['perl'] = 'perl',
}

local shebang = {}
for _, prefix in ipairs(shebang_prefixes) do
  for k, v in pairs(shebang_fts) do
    shebang[prefix .. k] = v
  end
end

return {
  extension = {
    ['ex'] = 'elixir',
    ['exs'] = 'elixir',
    ['plist'] = 'xml',
    ['gradle'] = 'groovy',
    ['kt'] = 'kotlin',
    ['dart'] = 'dart',
    ['fnl'] = 'fennel',
    ['janet'] = 'janet',
    ['jsx'] = 'javascriptreact',
    ['tsx'] = 'typescriptreact',
    ['jl'] = 'julia',
    ['coffee'] = 'coffee',
    ['_coffee'] = 'coffee',
    ['nix'] = 'nix',
    ['erb'] = 'eruby',
    ['hbs'] = 'handlebars',
    ['graphql'] = 'graphql',
    ['gql'] = 'graphql',
  },
  file_name = {
    ['cakefile'] = 'coffee',
  },
  shebang = shebang
}
