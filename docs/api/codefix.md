# Codefix API
The codefix module in lust-next provides comprehensive code quality checking and fixing capabilities. It integrates with external tools like StyLua and Luacheck while also providing custom fixers for issues that neither tool handles well.

## Overview
The codefix module can:

1. Format Lua code using StyLua
2. Lint Lua code using Luacheck
3. Apply custom fixes for common issues
4. Provide a unified API for all code quality operations
5. Be used through a simple CLI interface

## Configuration Options
The codefix module can be configured through the `lust.codefix_options` table:

```lua
lust.codefix_options = {
  enabled = true,            -- Enable code fixing functionality
  verbose = true,            -- Enable verbose output
  debug = false,             -- Enable debug output (more detailed logs)

  -- StyLua options
  use_stylua = true,         -- Use StyLua for formatting
  stylua_path = "stylua",    -- Path to StyLua executable
  stylua_config = nil,       -- Path to StyLua config file (optional)

  -- Luacheck options
  use_luacheck = true,       -- Use Luacheck for linting
  luacheck_path = "luacheck", -- Path to Luacheck executable
  luacheck_config = nil,     -- Path to Luacheck config file (optional)

  -- Custom fixers
  custom_fixers = {
    trailing_whitespace = true,    -- Fix trailing whitespace in multiline strings
    unused_variables = true,       -- Fix unused variables by prefixing with underscore
    string_concat = true,          -- Optimize string concatenation
    type_annotations = false,      -- Add type annotations (disabled by default)
    lua_version_compat = false,    -- Fix Lua version compatibility issues (disabled by default)
  },

  -- Input/output
  include = {"%.lua$"},            -- File patterns to include
  exclude = {"_test%.lua$", "_spec%.lua$", "test/", "tests/", "spec/"}, -- File patterns to exclude
  backup = true,                   -- Create backup files when fixing
  backup_ext = ".bak",             -- Extension for backup files
}

```text

## Basic Usage

### In Lua Scripts

```lua
local lust = require("lust-next")
-- Enable codefix
lust.codefix_options.enabled = true
-- Fix a specific file
local success = lust.fix_file("path/to/file.lua")
-- Fix multiple files
local success = lust.fix_files({
  "path/to/file1.lua",
  "path/to/file2.lua"
})
-- Find and fix Lua files in a directory
local success = lust.fix_lua_files("path/to/directory")

```text

### From Command Line

```bash

# Fix a specific file
lua lust-next.lua --fix path/to/file.lua

# Fix all Lua files in a directory
lua lust-next.lua --fix path/to/directory

# Check a file without fixing
lua lust-next.lua --check path/to/file.lua

```text

## API Reference

### `lust.fix_file(file_path)`
Fixes a single Lua file by applying StyLua, Luacheck, and custom fixers.
**Parameters:**

- `file_path` (string): Path to the Lua file to fix
**Returns:**

- `success` (boolean): Whether the fix was successful
**Example:**

```lua
local success = lust.fix_file("src/module.lua")
if success then
  print("File fixed successfully")
else
  print("Failed to fix file")
end

```text

### `lust.fix_files(file_paths)`
Fixes multiple Lua files.
**Parameters:**

- `file_paths` (table): Array of file paths to fix
**Returns:**

- `success` (boolean): Whether all fixes were successful
**Example:**

```lua
local files = {
  "src/module1.lua",
  "src/module2.lua",
  "src/module3.lua"
}
local success = lust.fix_files(files)

```text

### `lust.fix_lua_files(directory)`
Finds and fixes all Lua files in a directory that match the include/exclude patterns.
**Parameters:**

- `directory` (string): Directory to search for Lua files
**Returns:**

- `success` (boolean): Whether all fixes were successful
**Example:**

```lua
local success = lust.fix_lua_files("src")

```text

## Custom Fixers
The codefix module includes several custom fixers for issues that StyLua and Luacheck don't handle well:

### 1. Trailing Whitespace in Multiline Strings
Fixes trailing whitespace in multiline strings, which StyLua doesn't modify.
**Before:**

```lua
local str = [[
  This string has trailing whitespace   
  on multiple lines   
]]

```text
**After:**

```lua
local str = [[
  This string has trailing whitespace
  on multiple lines
]]

```text

### 2. Unused Variables
Prefixes unused variables with underscore to indicate they're intentionally unused.
**Before:**

```lua
local function process(data, options, callback)
  -- Only uses data
  return data.value
end

```text
**After:**

```lua
local function process(data, _options, _callback)
  -- Only uses data
  return data.value
end

```text

### 3. String Concatenation
Optimizes string concatenation patterns.
**Before:**

```lua
local greeting = "Hello " .. "there " .. name .. "!"

```text
**After:**

```lua
local greeting = "Hello there " .. name .. "!"

```text

### 4. Type Annotations (Optional)
Adds type annotations to function documentation.
**Before:**

```lua
function calculate(x, y)
  return x * y
end

```text
**After:**

```lua
--- Function documentation
-- @param x any
-- @param y any
-- @return any
function calculate(x, y)
  return x * y
end

```text

### 5. Lua Version Compatibility (Optional)
Fixes Lua version compatibility issues.
**Before:**

```lua
local packed = table.pack(...)  -- Lua 5.2+ feature

```text
**After:**

```lua
local packed = {...}  -- table.pack replaced for Lua 5.1 compatibility

```text

## Integration with hooks-util
The codefix module is designed to integrate seamlessly with the hooks-util framework:

1. It can be used in pre-commit hooks to ensure code quality
2. It shares configuration with hooks-util's existing StyLua and Luacheck integration
3. It provides additional fixing capabilities beyond what hooks-util currently offers

## Examples
See the [codefix_example.lua](../../examples/codefix_example.lua) file for a complete example of using the codefix module.

