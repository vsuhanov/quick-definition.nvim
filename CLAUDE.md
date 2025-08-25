# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin called `quick-definition.nvim` that provides a floating window to quickly view LSP definitions without leaving your current context. The plugin opens definitions in a resizable floating window with convenient keybindings for navigation and editing.

## Architecture

### Core Structure
- `lua/quick-definition/init.lua` - Main plugin module containing the core functionality
- `plugin/quick-definition.lua` - Plugin entry point (currently empty)
- `lua/quick-definition/example.lua` and `lua/quick-definition/example2.lua` - Test files for development

### Key Components

**Main Module (`init.lua`)**:
- `M.quick_definition()` - Main function that calls LSP definition and displays results in floating window
- `M.setup()` - Plugin setup function that creates autocommands and user commands
- Global state management via `_G.quickDefinitionWindowHandle`, `_G.quickDefinitionWindowHeight`, `_G.quickDefinitionWindowWidth`
- Buffer and keymap management for floating window interactions

**Floating Window Management**:
- Creates/reuses floating windows positioned relative to cursor
- Tracks window dimensions and restores them across sessions
- Automatically closes floating window when switching to other windows

**Keymap System**:
- Dynamically sets buffer-local keymaps (`q`, `<esc>`, `<cr>`) for floating windows
- Tracks which buffers have configured hotkeys to avoid duplication
- Cleans up keymaps on window leave to prevent conflicts

**Autocommand Events**:
- `WinEnter` - Closes floating window when entering other windows
- `BufWinEnter` - Updates window title and configures hotkeys
- `WinResized` - Stores new window dimensions
- `WinLeave` - Cleans up hotkeys

## Development

### No Build System
This is a pure Lua Neovim plugin with no build, test, or lint commands. Development involves:
1. Editing Lua files directly
2. Testing within Neovim by sourcing/reloading the plugin
3. Using the example files for testing definition jumping

### Plugin Loading
The plugin auto-calls `M.setup()` at the end of `init.lua`, so it's ready to use immediately when loaded by a plugin manager.

### Testing Approach
Use the example files to test functionality:
- `example.lua` calls `this_is_definition()` which is defined in the same file
- `example2.lua` contains `this_is_second_level_function()` which is called from `example.lua`
- Position cursor on function calls and use `:QuickDefinition` to test

### Global State
The plugin uses global variables for state management:
- `_G.quickDefinitionWindowHandle` - Reference to the floating window
- `_G.quickDefinitionWindowHeight/Width` - Remembers window dimensions

### Key Features in Development
According to TODO.md, active development focuses on:
- Configurable keymaps for exit/enter actions
- Auto-save functionality for quick-definition buffer changes  
- Multiple definition support with multiple floating windows
- Fallback to file search when no LSP definition found