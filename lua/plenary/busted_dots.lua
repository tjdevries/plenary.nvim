local ansi_color_table = {
   cyan = 36,
   magenta = 35,
   yellow = 33,
   green = 32,
   red = 31,
}

local color_string = function(color, str)
  return string.format("%s[%sm%s%s[%sm",
  string.char(27),
  ansi_color_table[color] or 0,
  str,
  string.char(27),
  0
  )
end

local successDot = color_string('green', '●')
local failureDot = color_string('red', '◼')
local errorDot   = color_string('magenta', '✱')
local pendingDot = color_string('yellow', '◌')

local function generate_dots(results, status_str, dot)
  local dot_count = 0
  for _, spec in pairs(results) do
    if spec.status == status_str then
      io.stdout:write(dot)
      dot_count = dot_count + 1
    end
  end
  return dot_count
end

local function generate_score(n_succ, n_fail, n_err, n_pend)

  local success = n_succ == 1 and ' success' or ' successes'
  local fail = n_fail == 1 and ' failure' or ' failures'
  local error = n_err == 1 and ' error' or ' errors'

  local score =
  color_string('green', n_succ) .. success .. ' / ' ..
  color_string('red', n_fail) .. fail .. ' / ' ..
  color_string('magenta', n_err) .. error .. ' / ' ..
  color_string('yellow', n_pend) .. ' pending'

  io.stdout:write(score)
end

local Score = {}

function Score.draw(results)

  local n_pend = generate_dots(results, 'pending', pendingDot)
  local n_err = generate_dots(results, 'error', errorDot)
  local n_fail = generate_dots(results, 'failed', failureDot)
  local n_succ = generate_dots(results, 'success', successDot)

  io.stdout:write('\n')
  generate_score(n_succ, n_fail, n_err, n_pend)
  io.stdout:write('\n\n')
end

return Score
