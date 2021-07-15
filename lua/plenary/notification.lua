local api = vim.api
local popup = require('popup')

local function location_window(options)
    local default_options = {
        relative = "editor",
        style = "minimal",
        width = 30,
        height = 15,
        row = 2,
        col = 2,
        border = {
          {"╭", "Normal"},
          {"─", "Normal"},
          {"╮", "Normal"},
          {"│", "Normal"},
          {"╯", "Normal"},
          {"─", "Normal"},
          {"╰", "Normal"},
          {"│", "Normal"},
        },
    }
    options = vim.tbl_extend("keep", options, default_options)

    local bufnr = options.bufnr or api.nvim_create_buf(false, true)
    local win_id = api.nvim_open_win(bufnr, true, options)
    api.nvim_win_set_option(win_id, 'winhl', 'Normal:Normal')

    return {
        bufnr = bufnr,
        win_id = win_id,
    }
end

local notification_config = {
  icon = "",
  width = 20,
  height = 2
}

local function create_notification(sender, text)
  local win_stats = api.nvim_list_uis()[1]
  local win_width = win_stats.width

  local prev_win = api.nvim_get_current_win()

  if notification_config.height and notification_config.height < 2 then
    error("notification height must be at least 2")
  end
  if notification_config.width and notification_config.width < 10 then
    error("notification width must be at least 10")
  end

  -- TODO: position probably shouldn't done this way
  local info = location_window({
      width = notification_config.width or 20,
      height = notification_config.height or 2,
      row = 1,
      col = win_width - 25,
  })

  api.nvim_buf_set_lines(
      info.bufnr, 0, 5, false, { string.format("%s %s", notification_config.icon, sender), text }
  )
  api.nvim_set_current_win(prev_win)

  return {
    bufnr = info.bufnr,
    win_id = info.win_id
  }
end

NOTIFICAION_QUEUE = {}
-- I'm not sure if this is really needed, but it could be nice for users to
-- have a list of the notifications that've been sent (especially the way they
-- currently work with a queue) where they can dismiss them individually and
-- maybe they get auto-dismissed after a certain amount of time - definitely
-- when the nvim session ends.
SENT_NOTIFICATIONS = {}
Notification = {}

function Notification:new(sender, text, lifetime)
  local obj = {}

  obj.sender = sender
  obj.message = text
  obj.lifetime = lifetime
  return setmetatable(obj, Notification)
end

function Notification:render()
  local info = create_notification(self.sender, self.message)
  self.bufnr = info.bufnr
vim.defer_fn(CLOSE_NOTIFICATION, self.lifetime or 3000)
end

function Notification:close()
  if not self.bufnr then
    print('notification is not currently being rendered')
    return
  end

  api.nvim_buf_delete(self.bufnr, { force = true })
  self.bufnr = nil
end

function Notification:dismiss()
end

Notification.add_to_queue = function(...)
  local notifications = {...}
  for _, notification in pairs(notifications) do
    table.insert(NOTIFICAION_QUEUE, notification)
  end
end

-- TODO: (maybe?) add functionality to remove a notification from the queue
-- if it has not yet been rendered
Notification.remove_from_queue = function()
end

Notification.__index = Notification

-- TODO: interface to manage notifications (close, delete, reorder, etc.)
function NOTIFICATIONS()
  local bufnr = api.nvim_create_buf(false, false)
  local width = 60
  local height = 10
  local win_id, win = popup.create(bufnr, {
      title = "Messages",
      highlight = "Normal",
      line = math.floor(((vim.o.lines - height) / 2) - 1),
      col = math.floor((vim.o.columns - width) / 2),
      minwidth = width,
      minheight = height,
      borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  })

  vim.api.nvim_win_set_option(
      win.border.win_id,
      "winhl",
      "Normal:Normal"
  )

  local lines = {}
  for _, notification in pairs(NOTIFICAION_QUEUE) do
    table.insert(lines, string.format("%s :: %s", notification.sender, notification.message))
  end

  api.nvim_buf_set_lines(bufnr, 0, #lines, false, lines)

  return {
    win_id,
    win
  }
end

function CLOSE_NOTIFICATION()
  if #NOTIFICAION_QUEUE == 0 then
    print("no open notifications to close")
    return -1
  end

  local current_notification = NOTIFICAION_QUEUE[1]
  current_notification:close()

  table.insert(SENT_NOTIFICATIONS, current_notification)

  table.remove(NOTIFICAION_QUEUE, 1)
  if #NOTIFICAION_QUEUE ~= 0 then
    NOTIFICAION_QUEUE[1]:render()
  end
end

local n1 = Notification:new('test', 'hello', 3000)
local n2 = Notification:new('another', 'notification', 5000)
local n3 = Notification:new('third', 'notification', 3000)
Notification.add_to_queue(n1, n2, n3)
NOTIFICAION_QUEUE[1]:render()
