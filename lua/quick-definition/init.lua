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
-- local t = this_is_definition
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

local function remove_enter_exit_hotkeys()
  if _G.quickDefinitionWindowHandle == nil then
    return
  end
  if vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) and vim.api.nvim_get_current_win() == _G.quickDefinitionWindowHandle then
    local bufnr = vim.api.nvim_get_current_buf()
    -- vim.api.nvim_buf_get_keymap
    print("setting up hotkeys for buf ".. bufnr);
    vim.api.nvim_buf_del_keymap(bufnr, "n", "q");
    vim.api.nvim_buf_del_keymap(bufnr, "n", "<esc>");
    vim.api.nvim_buf_del_keymap(bufnr, "n", "<cr>");
  end
end
local function configure_enter_exit_hotkeys()
  if _G.quickDefinitionWindowHandle == nil then
    return
  end
  if vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) and vim.api.nvim_get_current_win() == _G.quickDefinitionWindowHandle then
    local bufnr = vim.api.nvim_get_current_buf()
    -- vim.api.nvim_buf_get_keymap
    local filepath = vim.api.nvim_buf_get_name(bufnr);
    local absolute_path = vim.fn.fnamemodify(filepath, ":p");
    vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":wq<cr>", { silent = true });
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<esc>", ":wq<cr>", { silent = true });
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<cr>", ":wq<cr>:e " .. absolute_path .. "<cr>", { silent = true });
  end
end

function M.quick_definition()
  vim.lsp.buf.definition({
    on_list = function(l)
      -- { [1] = { ["lnum"] = 1,["text"] = function this_is_second_level_function(),["col"] = 10,["filename"] = /Users/vitaly/projects/quick-definition.nvim/lua/quick-definition/example2.lua,} ,}
      -- print(dump(l["items"]))

      local filename = l["items"][1]["filename"]
      local bufnr = create_or_get_buffernr(filename)
      local win_id = _G.quickDefinitionWindowHandle
      if _G.quickDefinitionWindowHandle == nil then
        win_id = vim.api.nvim_open_win(bufnr, true,
          { width = 80, height = 30, relative = "cursor", row = 1, col = 1, border = "rounded" })
        _G.quickDefinitionWindowHandle = win_id
      else
        vim.api.nvim_win_set_buf(_G.quickDefinitionWindowHandle, bufnr)
      end
      local cursor = { l["items"][1]["lnum"], l["items"][1]["col"] }
      vim.api.nvim_win_set_cursor(_G.quickDefinitionWindowHandle, cursor)
      update_quick_def_window_title()

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
        end
      })
      -- configure exit/enter hotkeys
      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = autocmdGroup,
        callback = function()
          configure_enter_exit_hotkeys()
        end
      })
      -- clear exit/enter hotkeys
      vim.api.nvim_create_autocmd("BufLeave", {
        group = autocmdGroup,
        callback = function()
          remove_enter_exit_hotkeys()
        end
      })
      -- BufLeave won't be triggered if closing the window leads to a window for the same buffer
      vim.api.nvim_create_autocmd("WinLeave", {
        group = autocmdGroup,
        callback = function()
          remove_enter_exit_hotkeys()
        end
      })
    end
  })
end

function M.setup(opts)
  opts = opts or {}
  vim.api.nvim_create_user_command("QuickDefinition", function()
    M.quick_definition()
  end, {})
end

M.setup()
return M
