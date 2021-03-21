local tbl = {}

function tbl.apply_defaults(original, defaults)
  if original == nil then
    original = {}
  end

  original = vim.deepcopy(original)

  for k, v in pairs(defaults) do
    if original[k] == nil then
      original[k] = v
    end
  end

  return original
end

function tbl.map_inplace(t, func)
  for key, value in pairs(t) do
    tbl[key] = func(value)
  end
end

return tbl
