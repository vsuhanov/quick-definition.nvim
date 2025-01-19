local M = {}

local function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

local function create_or_get_buffernr(filename)
  local escaped_filename = vim.fn.fnameescape(filename)
  local bufnr = vim.fn.bufnr(escaped_filename)

  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(bufnr, escaped_filename)
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd('edit ' .. escaped_filename)
    end)
  end
  return bufnr
end

require("quick-definition.example")
_G.quickDefinitionWindowHandle = nil

local function update_quick_def_window_title()
  if _G.quickDefinitionWindowHandle == nil then
    return
  end
  if vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) and vim.api.nvim_get_current_win() == _G.quickDefinitionWindowHandle then
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local relative_path = vim.fn.fnamemodify(filepath, ':.')
    vim.api.nvim_win_set_config(_G.quickDefinitionWindowHandle, {
      title = relative_path
    })
  end
end

local buffers_with_configured_hotkeys = {}

local function set_enter_exit_hotkeys(bufnr)
  if buffers_with_configured_hotkeys[bufnr] == true then return end
  buffers_with_configured_hotkeys[bufnr] = true
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local absolute_path = vim.fn.fnamemodify(filepath, ":p")
  -- print("going to configure local keymap for bufnr " .. bufnr)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":q<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<esc>", ":q<cr>", { silent = true })
  vim.keymap.set("n", "<cr>", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    -- print("command to execute " .. ":wq<cr>:e " .. absolute_path .. "<cr>")
    vim.api.nvim_win_close(0, true)
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.api.nvim_win_set_cursor(0, cursor)
  end, { silent = true, buffer = bufnr })
end

local function configure_enter_exit_hotkeys()
  -- print "configure_enter_exit_hotkeys is called"
  -- print("current win " ..
  -- vim.api.nvim_get_current_win() ..
  -- " quickDefinitionWindowHandle " .. (_G.quickDefinitionWindowHandle ~= nil and _G.quickDefinitionWindowHandle or "nil"))
  if _G.quickDefinitionWindowHandle == nil then
    return
  end
  if vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) and vim.api.nvim_get_current_win() == _G.quickDefinitionWindowHandle then
    local bufnr = vim.api.nvim_get_current_buf()
    -- don't set up hotkeys multiple times
    set_enter_exit_hotkeys(bufnr)
  end
end

local function remove_enter_exit_hotkeys()
  -- print(dump(buffers_with_configured_hotkeys))
  -- print(dump(pairs(buffers_with_configured_hotkeys)))
  for bufnr, _ in pairs(buffers_with_configured_hotkeys) do
    -- print("removing hotkeys for buf " .. bufnr);
    local status, err = pcall(function()
      vim.api.nvim_buf_del_keymap(bufnr, "n", "q");
      vim.api.nvim_buf_del_keymap(bufnr, "n", "<esc>");
      vim.api.nvim_buf_del_keymap(bufnr, "n", "<cr>");
    end)
    if err then
      print("error while unsetting keymap" .. vim.inspect(err))
    end
  end
  buffers_with_configured_hotkeys = {}
end

_G.quickDefinitionWindowHeight = 30
_G.quickDefinitionWindowWidth = 80
function M.quick_definition()
  vim.lsp.buf.definition({
    on_list = function(locations)
      local filename = locations["items"][1]["filename"]
      local bufnr = create_or_get_buffernr(filename)
      if _G.quickDefinitionWindowHandle == nil then
        _G.quickDefinitionWindowHandle = vim.api.nvim_open_win(bufnr, true,
          {
            width = _G.quickDefinitionWindowWidth,
            height = _G.quickDefinitionWindowHeight,
            relative = "cursor",
            row = 1,
            col = 1,
            border =
            "rounded"
          })
        -- print("right after window is created")
        -- can't find an event to which attach, have to call the juice of the event handler because event handler checks for quickDefinitionWindowHandle
        set_enter_exit_hotkeys(bufnr);
      else
        vim.api.nvim_win_set_buf(_G.quickDefinitionWindowHandle, bufnr)
      end
      local cursor = { locations["items"][1]["lnum"], locations["items"][1]["col"] }
      vim.api.nvim_win_set_cursor(_G.quickDefinitionWindowHandle, cursor)
      update_quick_def_window_title()
    end
  })
end

function M.setup(opts)
  opts = opts or {}
  local autocmdGroup = vim.api.nvim_create_augroup("quick-definition-augroup", { clear = true })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = autocmdGroup,
    callback = function()
      if _G.quickDefinitionWindowHandle == nil then
        return
      end
      if vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) then
        vim.api.nvim_win_close(_G.quickDefinitionWindowHandle, true)
      end
      _G.quickDefinitionWindowHandle = nil
    end
  })

  -- change the title if the buffer changes in the current window
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = autocmdGroup,
    callback = function()
      update_quick_def_window_title()
      configure_enter_exit_hotkeys()
    end
  })
  -- -- configure exit/enter hotkeys on WinEnter, BufWinEnter won't be triggered if it's the same buffer
  -- vim.api.nvim_create_autocmd("WinEnter", {
  --   group = autocmdGroup,
  --   callback = function()
  --     print("WinEnter for configure_enter_exit_hotkeys is triggered")
  --     configure_enter_exit_hotkeys()
  --   end
  -- })
  -- BufLeave won't be triggered if closing the window leads to a window for the same buffer


  vim.api.nvim_create_autocmd("WinResized", {
    group = autocmdGroup,
    callback = function()
      if _G.quickDefinitionWindowHandle == nil then return end
      _G.quickDefinitionWindowWidth = vim.api.nvim_win_get_width(0)
      _G.quickDefinitionWindowHeight = vim.api.nvim_win_get_height(0)
    end,
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = autocmdGroup,
    callback = function()
      remove_enter_exit_hotkeys()
    end
  })
  vim.api.nvim_create_user_command("QuickDefinition", function()
    M.quick_definition()
  end, {})
end

M.setup()
return M
