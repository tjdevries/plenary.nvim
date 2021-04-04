-- vim:sw=2
local List = {}

setmetatable(List, List)

function List:__call(tbl)
  if type(tbl) == 'table' then
    local len = #tbl
    local obj = setmetatable(tbl, self)
    self.__index = self
    obj._len = len
    return obj
  end
  error 'List constructor must be called with table argument'
end

function List:__tostring()
  if rawequal(self, List) then return '<List class>' end
  if #self == 0 then return '[]' end
  local result = {'['}
  for _, v in ipairs(self) do
    local repr = tostring(v)
    if type(v) == 'string' then repr = '"' .. repr .. '"' end
    result[#result + 1] = repr
    result[#result + 1] = ', '
  end
  result[#result] = ']'
  return table.concat(result)
end

function List:__eq(other)
  if #self ~= #other then return false end
  for i = 1, #self do if self[i] ~= other[i] then return false end end
  return true
end

function List:__mul(other)
  local result = List {}
  for i = 1, other do result[i] = self end
  return result
end

function List:__len()
  return self._len
end

function List:__concat(other)
  local result = List {}
  for _, v in ipairs(self) do result[#result + 1] = v end
  for _, v in ipairs(other) do result[#result + 1] = v end
  return result
end

function List:append(other)
  self[#self + 1] = other
  self._len = self._len + 1
end

function List:index(other)
  for i, v in ipairs(self) do if v == other then return i end end
  return -1
end

function List:pop(i)
  i = i or #self
  local result = table.remove(self, i)
  self._len = self._len - 1
  return result
end

function List:remove(e)
  local i = self:index(e)
  if i == -1 then
    error(('Element not found: %s'):format(e))
  else
    self:pop(i)
  end
end

function List:contains(e)
  for _, v in ipairs(self) do if v == e then return true end end
  return false
end

function List:count(e)
  local n = 0
  for _, v in ipairs(self) do if v == e then n = n + 1 end end
  return n
end

function List:equal(other)
  return self:__eq(other)
end

function List:slice(a, b)
  return List(vim.list_slice(self, a, b))
end

function List:copy()
  return self:slice(1, #self)
end

function List:extend(other)
  if type(other) == 'table' and vim.tbl_islist(other) then
    vim.list_extend(self, other)
  else
    error 'Argument must be a List or list-like table'
  end
end

function List:reverse()
  local n = #self
  local i = 1
  while i < n do
    self[i], self[n] = self[n], self[i]
    i = i + 1
    n = n - 1
  end
  return self
end

function List:iter()
  local i = 0
  return function()
    i = i + 1
    if i <= #self then return self[i], i end
  end
end

function List:riter()
  local i = #self + 1
  return function()
    i = i - 1
    if i > 0 then return self[i], i end
  end
end

return List
