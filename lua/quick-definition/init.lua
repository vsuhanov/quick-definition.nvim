local M = {}
function dump(o)
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
function M.quick_definition()
  this_is_definition()
  vim.lsp.buf.definition({
    on_list = function(l)
      -- { [1] = { ["lnum"] = 1,["text"] = function this_is_second_level_function(),["col"] = 10,["filename"] = /Users/vitaly/projects/quick-definition.nvim/lua/quick-definition/example2.lua,} ,}
      -- print(dump(l["items"]))
      -- print("bufnr of the first item in the list" .. l.items[0].bufnr)
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
      -- vim.api.nvim_win_set_config(_G.quickDefinitionWindowHandle, {
      --   title = l["items"][1]["text"]
      -- })
      -- print("win id" .. win_id)
      -- print("stored quick definition window handle " .. _G.quickDefinitionWindowHandle);
      local autocmdGroup = vim.api.nvim_create_augroup("quick-definition-augroup", { clear = true })
      vim.api.nvim_create_autocmd("WinEnter", {
        group = autocmdGroup,
        callback = function()
          -- print("closing window, current window is " ..
            -- vim.api.nvim_get_current_win())
          if _G.quickDefinitionWindowHandle == nil then
            return
          end
          -- print("closing window");
          -- print("closing window, current window is " ..
          --   vim.api.nvim_get_current_win() .. " quick definition window handle " .. _G.quickDefinitionWindowHandle);
          if vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) then
            vim.api.nvim_win_close(_G.quickDefinitionWindowHandle, true)
          end
          _G.quickDefinitionWindowHandle = nil
        end
      })
    end
  })
end

function M.setup(opts)
  opts = opts or {}
  print("hello")

  vim.api.nvim_create_user_command("QuickDefinition", function()
    M.quick_definition()
  end, {})
  vim.keymap.set("n", "<leader>K", function() M.quick_definition() end, opts)
  vim.keymap.set("n", "<2-LeftMouse>", function() M.quick_definition() end, opts)
  vim.keymap.set("n", "<MiddleMouse>", function() vim.lsp.buf.definition() end, opts)
end

M.setup()
return M
