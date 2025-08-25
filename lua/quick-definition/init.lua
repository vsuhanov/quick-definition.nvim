local I = {}
local M = {}

I.dump = function(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. I.dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

-- Navigation functions
I.next_item = function()
  I.show_item_at_index(_G.quickDefinitionCurrentIndex + 1)
end

I.previous_item = function()
  I.show_item_at_index(_G.quickDefinitionCurrentIndex - 1)
end

I.create_or_get_buffernr = function(filename)
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

-- Global state
_G.quickDefinitionWindowHandle = nil
_G.quickDefinitionItems = {}           -- all collected items
_G.quickDefinitionCurrentIndex = 1     -- current position
_G.quickDefinitionProviders = {}       -- active providers
_G.quickDefinitionPendingProviders = 0 -- track async completion
_G.quickDefinitionConfig = {}          -- stored configuration

I.update_quick_def_window_title = function()
  if _G.quickDefinitionWindowHandle == nil then
    return
  end
  if vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) then
    local title
    if #_G.quickDefinitionItems == 0 then
      title = "Searching..."
    else
      local current_item = _G.quickDefinitionItems[_G.quickDefinitionCurrentIndex]
      if current_item then
        local relative_path = vim.fn.fnamemodify(current_item.filename, ':.')
        local provider_counts = {}
        for _, item in ipairs(_G.quickDefinitionItems) do
          provider_counts[item.provider] = (provider_counts[item.provider] or 0) + 1
        end
        local count_str = {}
        for provider, count in pairs(provider_counts) do
          table.insert(count_str, count .. " " .. provider)
        end
        title = string.format("%s (%d/%d: %s)", relative_path,
          _G.quickDefinitionCurrentIndex, #_G.quickDefinitionItems,
          table.concat(count_str, ", "))
      else
        title = "No results"
      end
    end
    vim.api.nvim_win_set_config(_G.quickDefinitionWindowHandle, {
      title = title
    })
  end
end

local buffers_with_configured_hotkeys = {}

-- Create temporary buffer for loading state
I.create_temp_buffer = function()
  local bufnr = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "",
    "  Searching for definitions...",
    "",
    "  Press 'q' or <Esc> to close",
    ""
  })
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  return bufnr
end

I.set_enter_exit_hotkeys = function(bufnr)
  if buffers_with_configured_hotkeys[bufnr] == true then return end
  buffers_with_configured_hotkeys[bufnr] = true
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local absolute_path = vim.fn.fnamemodify(filepath, ":p")

  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":q<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<esc>", ":q<cr>", { silent = true })

  -- Tab navigation
  vim.keymap.set("n", "<Tab>", function()
    I.next_item()
  end, { silent = true, buffer = bufnr })

  vim.keymap.set("n", "<S-Tab>", function()
    I.previous_item()
  end, { silent = true, buffer = bufnr })

  -- Enter to jump to location in original window
  vim.keymap.set("n", "<cr>", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_close(0, true)
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.api.nvim_win_set_cursor(0, cursor)
  end, { silent = true, buffer = bufnr })
end
-- Show item at specific index
I.show_item_at_index = function(index)
  if #_G.quickDefinitionItems == 0 then return end

  if index < 1 then
    index = #_G.quickDefinitionItems
  elseif index > #_G.quickDefinitionItems then
    index = 1
  end

  _G.quickDefinitionCurrentIndex = index
  local item = _G.quickDefinitionItems[index]

  if _G.quickDefinitionWindowHandle and vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) then
    local bufnr = I.create_or_get_buffernr(item.filename)
    vim.api.nvim_win_set_buf(_G.quickDefinitionWindowHandle, bufnr)
    local cursor = { item.lnum or 1, item.col or 0 }
    vim.api.nvim_win_set_cursor(_G.quickDefinitionWindowHandle, cursor)
    I.update_quick_def_window_title()

    -- Configure hotkeys for this buffer
    I.set_enter_exit_hotkeys(bufnr)
  end
end




I.configure_enter_exit_hotkeys = function()
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
    I.set_enter_exit_hotkeys(bufnr)
  end
end

-- Add items callback for providers
I.addItems = function(items, provider_name)
  print("addItems called with provider:" .. (provider_name or "unknown") .. ", items count:" .. #items)

  for _, item in ipairs(items) do
    -- Add provider info to each item
    item.provider = provider_name
    table.insert(_G.quickDefinitionItems, item)
    print("Added item from " .. item.filename .. ":" .. (item.lnum or "?"))
  end

  print("Total items now: " .. #_G.quickDefinitionItems)

  -- Create window if this is the first item and no window exists
  if #_G.quickDefinitionItems > 0 and _G.quickDefinitionWindowHandle == nil then
    print("Creating window for first results")
    local first_item = _G.quickDefinitionItems[1]
    local bufnr = I.create_or_get_buffernr(first_item.filename)

    _G.quickDefinitionWindowHandle = vim.api.nvim_open_win(bufnr, true, {
      width = _G.quickDefinitionWindowWidth,
      height = _G.quickDefinitionWindowHeight,
      relative = "cursor",
      row = 1,
      col = 1,
      border = "rounded"
    })

    -- Set cursor to the definition location
    local cursor = { first_item.lnum or 1, first_item.col or 0 }
    vim.api.nvim_win_set_cursor(_G.quickDefinitionWindowHandle, cursor)

    -- Configure hotkeys for this buffer
    I.set_enter_exit_hotkeys(bufnr)

    -- Update title
    I.update_quick_def_window_title()

    print("Window created and positioned")
  elseif #_G.quickDefinitionItems > 0 and _G.quickDefinitionWindowHandle and vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle) then
    print("Window exists, just updating title")
    -- Just update title to reflect new counts
    I.update_quick_def_window_title()
  else
    print("No items yet or window invalid. Items: " ..
      #_G.quickDefinitionItems ..
      ", window valid: " ..
      tostring(_G.quickDefinitionWindowHandle and vim.api.nvim_win_is_valid(_G.quickDefinitionWindowHandle)))
  end
end

I.remove_enter_exit_hotkeys = function()
  for bufnr, _ in pairs(buffers_with_configured_hotkeys) do
    local status, err = pcall(function()
      vim.api.nvim_buf_del_keymap(bufnr, "n", "q")
      vim.api.nvim_buf_del_keymap(bufnr, "n", "<esc>")
      vim.api.nvim_buf_del_keymap(bufnr, "n", "<cr>")
      vim.api.nvim_buf_del_keymap(bufnr, "n", "<Tab>")
      vim.api.nvim_buf_del_keymap(bufnr, "n", "<S-Tab>")
    end)
    if err then
      print("error while unsetting keymap" .. vim.inspect(err))
    end
  end
  buffers_with_configured_hotkeys = {}
end

_G.quickDefinitionWindowHeight = 35
_G.quickDefinitionWindowWidth = 100

-- Default provider configuration
local default_config = {
  providers = {
    lsp_definitions = function(context, addItems)
      print("lsp_definitions provider called")
      local clients = vim.lsp.get_active_clients({ bufnr = context.bufnr })
      print("Active LSP clients for buffer: " .. #clients)
      if #clients == 0 then
        print("No LSP clients available - calling addItems with empty list")
        addItems({}, "definitions")
        return
      end

      print("calling vim.ls.buf.definitions")
      vim.lsp.buf.definition({
        on_list = function(locations)
          print("lsp_definitions on_list called with " .. #(locations.items or {}) .. " items")
          addItems(locations.items or {}, "definitions")
        end
      })
    end,
    lsp_implementations = function(context, addItems)
      print("lsp_implementations provider called")
      local clients = vim.lsp.get_active_clients({ bufnr = context.bufnr })
      print("Active LSP clients for buffer: " .. #clients)
      if #clients == 0 then
        print("No LSP clients available for implementations - calling addItems with empty list")
        addItems({}, "implementations")
        return
      end

      vim.lsp.buf.implementation({
        on_list = function(locations)
          print("lsp_implementations on_list called with " .. #(locations.items or {}) .. " items")
          addItems(locations.items or {}, "implementations")
        end
      })
    end,
    lsp_references = function(context, addItems)
      vim.lsp.buf.references(nil, {
        on_list = function(locations)
          addItems(locations.items or {}, "references")
        end
      })
    end

  }
}
-- Convenience function for references only
function M.quick_references(opts)
  opts = opts or {}
  local references_config = {
    providers = {
      lsp_references = function(context, addItems)
        vim.lsp.buf.references(nil, {
          on_list = function(locations)
            addItems(locations.items or {}, "references")
          end
        })
      end
    }
  }
  opts = vim.tbl_deep_extend("force", references_config, opts)
  M.quick_definition(opts)
end

function M.quick_definition(opts)
  print("quick_definition called")
  opts = opts or {}

  -- Merge with stored config
  local config = vim.tbl_deep_extend("force", _G.quickDefinitionConfig, opts)
  print("Config merged. Provider count: " .. vim.tbl_count(config.providers or {}))

  -- Reset state
  _G.quickDefinitionItems = {}
  _G.quickDefinitionCurrentIndex = 1
  _G.quickDefinitionPendingProviders = 0

  -- Create context for providers
  local context = {
    cursor_word = vim.fn.expand('<cword>'),
    bufnr = vim.api.nvim_get_current_buf(),
    cursor_pos = vim.api.nvim_win_get_cursor(0),
    filename = vim.api.nvim_buf_get_name(0)
  }
  print("Context created for word: '" .. context.cursor_word .. "'")

  -- Don't open window yet - wait for first results
  -- Store original cursor position for window placement
  _G.quickDefinitionOriginalCursor = vim.api.nvim_win_get_cursor(0)
  print("Window creation delayed until first results arrive")

  -- Count and call all providers
  local provider_count = 0
  for name, provider_func in pairs(config.providers or {}) do
    provider_count = provider_count + 1
    print("Found provider: " .. name)
  end

  _G.quickDefinitionPendingProviders = provider_count
  print("Calling " .. provider_count .. " providers")

  -- Call all providers
  for name, provider_func in pairs(config.providers or {}) do
    print("Calling provider: " .. name)
    -- Call provider with context and addItems callback
    -- The provider function should start async operation and return immediately
    -- The addItems callback will be called later when async operation completes
    provider_func(context, function(items, provider_name)
      print("Provider " .. (provider_name or name) .. " async callback called with " .. #items .. " items")
      I.addItems(items, provider_name or name)
      _G.quickDefinitionPendingProviders = _G.quickDefinitionPendingProviders - 1
      print("Pending providers remaining: " .. _G.quickDefinitionPendingProviders)
    end)
    print("Provider " .. name .. " function returned (async operation started)")
  end

  -- Handle case where no providers are configured
  if provider_count == 0 then
    print("No providers configured")
  else
    -- Set a timeout to see if providers are responding
    vim.defer_fn(function()
      if _G.quickDefinitionPendingProviders > 0 then
        print("Warning: Some providers haven't responded yet. Pending: " .. _G.quickDefinitionPendingProviders)
        if #_G.quickDefinitionItems == 0 then
          print("No results received from any provider")
        end
      end
    end, 3000) -- 3 second timeout
  end
end

function M.setup(opts)
  opts = opts or {}

  -- Merge with default config and store
  _G.quickDefinitionConfig = vim.tbl_deep_extend("force", default_config, opts)

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
      I.update_quick_def_window_title()
      I.configure_enter_exit_hotkeys()
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
      I.remove_enter_exit_hotkeys()
    end
  })
  vim.api.nvim_create_user_command("QuickDefinition", function()
    M.quick_definition()
  end, {})

  vim.api.nvim_create_user_command("QuickReferences", function()
    M.quick_references()
  end, {})
end

M.setup()
return M
