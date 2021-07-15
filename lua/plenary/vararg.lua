local v = {}

function v.nth(n, ...)
  local x = select(n, ...)
  return x
end

function v.select_only(n)
  return function(...)
    return v.nth(n, ...)
  end
end

v.first = v.select_only(1)
v.second = v.select_only(2)
v.third = v.select_only(3)

function v.len(...)
  return select('#', ...)
end

function v.last(...)
  local len = v.len(...)
  local x = select(len, ...)
  return x
end

---flips binary arguments
function v.flip(a, b)
  return b, a
end

return v
