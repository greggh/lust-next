# Codefix Module Usage Examples

This document provides practical examples of using the Firmo codefix module to improve code quality in Lua projects. The examples cover common usage scenarios and demonstrate the different capabilities of the module.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Working with Multiple Files](#working-with-multiple-files)
- [Custom Configuration](#custom-configuration)
- [StyLua Integration](#stylua-integration)
- [Luacheck Integration](#luacheck-integration)
- [Custom Fixers](#custom-fixers)
- [Command Line Interface](#command-line-interface)
- [Creating Hooks and Pre-commit Checks](#creating-hooks-and-pre-commit-checks)
- [Complete Workflow Example](#complete-workflow-example)

## Basic Usage

### Example 1: Fixing a Single File

```lua
-- Import firmo
local firmo = require("firmo")

-- Enable codefix
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.enabled = true

-- Fix a single file
local success = firmo.fix_file("src/calculator.lua")

-- Check the result
if success then
  print("✅ File fixed successfully")
else
  print("❌ Failed to fix file")
end
```

### Example 2: Basic Configuration

```lua
local firmo = require("firmo")

-- Configure codefix with basic options
firmo.codefix_options = {
  enabled = true,
  verbose = true,
  backup = true,
  backup_ext = ".bak",
  use_stylua = true,
  use_luacheck = true
}

-- Fix a file with verbose output
local success = firmo.fix_file("src/utils.lua")
```

## Working with Multiple Files

### Example 3: Fixing Multiple Specific Files

```lua
local firmo = require("firmo")

-- List of files to fix
local files = {
  "src/models/user.lua",
  "src/models/profile.lua",
  "src/utils/string.lua",
  "src/utils/table.lua"
}

-- Fix all files
local success, results = firmo.fix_files(files)

-- Process results
if success then
  print("✅ All files fixed successfully")
else
  print("⚠️ Some files had issues:")
  
  for _, result in ipairs(results) do
    if not result.success then
      print(" - " .. result.file .. ": " .. (result.error or "Unknown error"))
    end
  end
end
```

### Example 4: Fixing All Lua Files in a Directory

```lua
local firmo = require("firmo")
local fs = require("lib.tools.filesystem")

-- Configure codefix
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.enabled = true
firmo.codefix_options.verbose = true

-- Fix all Lua files in the src directory
local success, results = firmo.fix_lua_files("src")

-- Print summary
local count = results and #results or 0
print(string.format("Processed %d files", count))

-- Optionally, list all processed files
if results then
  for i, result in ipairs(results) do
    local status = result.success and "✓" or "✗"
    print(string.format("%s %s", status, result.file))
  end
end
```

## Custom Configuration

### Example 5: Custom Include and Exclude Patterns

```lua
local firmo = require("firmo")

-- Set custom patterns for file discovery
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.include = {
  "%.lua$",          -- All Lua files
  "%.luax$"          -- Custom extension
}
firmo.codefix_options.exclude = {
  "_test%.lua$",     -- Test files
  "_spec%.lua$",     -- Spec files
  "vendor/",         -- Vendor directory
  "third_party/"     -- Third-party code
}

-- Fix files with custom patterns
local success, results = firmo.fix_lua_files("src")
print(string.format("Found and processed %d files", #results))
```

### Example 6: Configuring Specific Fixers

```lua
local firmo = require("firmo")

-- Configure which fixers are enabled
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.custom_fixers = {
  trailing_whitespace = true,     -- Enable trailing whitespace fixer
  unused_variables = true,        -- Enable unused variables fixer
  string_concat = false,          -- Disable string concatenation fixer
  type_annotations = false,       -- Disable type annotations fixer
  lua_version_compat = true       -- Enable Lua version compatibility fixer
}

-- Fix files with selected fixers
local success = firmo.fix_file("src/module.lua")
```

## StyLua Integration

### Example 7: Configuring StyLua

```lua
local firmo = require("firmo")
local codefix = require("lib.tools.codefix")

-- Configure StyLua integration
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.use_stylua = true
firmo.codefix_options.stylua_path = "/usr/local/bin/stylua"  -- Custom path

-- Find StyLua config file
local config_file = codefix.find_stylua_config("src")
if config_file then
  print("Found StyLua config at: " .. config_file)
  firmo.codefix_options.stylua_config = config_file
else
  print("No StyLua config found, using defaults")
end

-- Run StyLua on a specific file
local success, err = codefix.run_stylua("src/module.lua")
if not success and err then
  print("StyLua error: " .. err)
end
```

### Example 8: Using StyLua Only

```lua
local firmo = require("firmo")

-- Configure to use only StyLua, not Luacheck or custom fixers
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.enabled = true
firmo.codefix_options.use_stylua = true
firmo.codefix_options.use_luacheck = false

-- Disable all custom fixers
for fixer in pairs(firmo.codefix_options.custom_fixers or {}) do
  firmo.codefix_options.custom_fixers[fixer] = false
end

-- Format files with StyLua only
local files = {
  "src/models/user.lua",
  "src/models/profile.lua"
}
local success = firmo.fix_files(files)
```

## Luacheck Integration

### Example 9: Configuring Luacheck

```lua
local firmo = require("firmo")
local codefix = require("lib.tools.codefix")

-- Configure Luacheck integration
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.use_luacheck = true
firmo.codefix_options.luacheck_path = "luacheck"  -- Default path

-- Find Luacheck config file
local config_file = codefix.find_luacheck_config(".")
if config_file then
  print("Found Luacheck config at: " .. config_file)
end

-- Run Luacheck on a specific file and analyze issues
local success, issues = codefix.run_luacheck("src/module.lua")

-- Print issues in a formatted way
if issues and #issues > 0 then
  print(string.format("Found %d issues:", #issues))
  for i, issue in ipairs(issues) do
    print(string.format("[%d] %s:%d:%d: (%s) %s", 
      i, issue.file, issue.line, issue.col, issue.code, issue.message))
  end
end
```

### Example 10: Using Luacheck Only for Analysis

```lua
local firmo = require("firmo")
local codefix = require("lib.tools.codefix")

-- Configure to use only Luacheck
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.enabled = true
firmo.codefix_options.use_stylua = false
firmo.codefix_options.use_luacheck = true

-- Enable only the unused variables fixer which works with Luacheck
for fixer in pairs(firmo.codefix_options.custom_fixers or {}) do
  firmo.codefix_options.custom_fixers[fixer] = (fixer == "unused_variables")
end

-- Check and fix Lua files
local success, results = firmo.fix_lua_files("src")
```

## Custom Fixers

### Example 11: Applying a Specific Custom Fixer

```lua
local firmo = require("firmo")
local codefix = require("lib.tools.codefix")
local fs = require("lib.tools.filesystem")

-- Read a file
local file_path = "src/module.lua"
local content, err = fs.read_file(file_path)
if not content then
  print("Error reading file: " .. (err or "unknown error"))
  return
end

-- Apply just the trailing whitespace fixer
local fixed_content = codefix.fix_trailing_whitespace(content)

-- Apply string concatenation optimization
fixed_content = codefix.fix_string_concat(fixed_content)

-- Write the fixed content back
local success, err = fs.write_file(file_path, fixed_content)
if not success then
  print("Error writing file: " .. (err or "unknown error"))
end
```

### Example 12: Creating a Custom Fixer

```lua
local firmo = require("firmo")
local codefix = require("lib.tools.codefix")

-- Creating a custom fixer to replace print with logger
codefix.register_custom_fixer("print_to_logger", {
  name = "Replace print with logger",
  fix = function(content, file_path)
    -- Add logger import if not present
    if not content:match("local%s+logger%s*=%s*require%(['\"]lib%.tools%.logging['\"]%)") then
      content = "local logger = require(\"lib.tools.logging\")\n" .. content
    end
    
    -- Replace print statements with logger.info
    content = content:gsub("print%s*(%b())", function(args)
      return "logger.info" .. args
    end)
    
    return content
  end
})

-- Enable the custom fixer
firmo.codefix_options = firmo.codefix_options or {}
firmo.codefix_options.custom_fixers = firmo.codefix_options.custom_fixers or {}
firmo.codefix_options.custom_fixers.print_to_logger = true

-- Apply the custom fixer
local success = firmo.fix_file("src/module.lua")
```

## Command Line Interface

### Example 13: Basic CLI Usage

```lua
local codefix = require("lib.tools.codefix")

-- Fix all Lua files in a directory
codefix.run_cli({"fix", "src"})

-- Check files without fixing them
codefix.run_cli({"check", "src"})

-- Find Lua files matching pattern
codefix.run_cli({"find", "src", "--include", "model_.+%.lua$"})

-- Show help information
codefix.run_cli({"help"})
```

### Example 14: Advanced CLI Options

```lua
local codefix = require("lib.tools.codefix")

-- Fix files with various options
codefix.run_cli({
  "fix",                  -- Command: fix files
  "src",                  -- Target directory
  "--verbose",            -- Enable verbose output
  "--no-stylua",          -- Disable StyLua formatting
  "--sort-by-mtime",      -- Sort files by modification time
  "--limit", "5",         -- Only process 5 files
  "--include", "%.lua$",  -- Include pattern
  "--exclude", "_test%.lua$", -- Exclude pattern
  "--generate-report",    -- Generate a report file
  "--report-file", "codefix-report.json" -- Custom report file
})
```

## Creating Hooks and Pre-commit Checks

### Example 15: Creating a Pre-commit Hook

```lua
local firmo = require("firmo")
local codefix = require("lib.tools.codefix")

-- Function to get staged Lua files from git
local function get_staged_lua_files()
  local cmd = "git diff --cached --name-only | grep '\\.lua$'"
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  
  local files = {}
  for file in result:gmatch("([^\n]+)") do
    table.insert(files, file)
  end
  
  return files
end

-- Pre-commit hook function
local function pre_commit_hook()
  print("Running pre-commit codefix check...")
  
  -- Get staged Lua files
  local files = get_staged_lua_files()
  if #files == 0 then
    print("No Lua files staged for commit")
    return true
  end
  
  print(string.format("Found %d Lua files to check", #files))
  
  -- Configure codefix
  firmo.codefix_options = firmo.codefix_options or {}
  firmo.codefix_options.enabled = true
  firmo.codefix_options.backup = true
  
  -- Fix files
  local success, results = firmo.fix_files(files)
  
  -- Stage fixed files
  if success then
    print("✅ All files fixed successfully")
    for _, file in ipairs(files) do
      os.execute("git add " .. file)
    end
    return true
  else
    print("❌ Some files could not be fixed")
    for _, result in ipairs(results) do
      if not result.success then
        print(" - " .. result.file)
      end
    end
    return false
  end
end

-- Run the pre-commit hook
local success = pre_commit_hook()
if not success then
  os.exit(1)
end
```

### Example 16: Project-Wide Code Quality Check

```lua
local firmo = require("firmo")
local codefix = require("lib.tools.codefix")

-- Function to check code quality across the project
local function check_project_quality()
  print("Running project-wide code quality check...")
  
  -- Configure codefix
  firmo.codefix_options = firmo.codefix_options or {}
  firmo.codefix_options.enabled = true
  firmo.codefix_options.verbose = true
  firmo.codefix_options.use_stylua = true
  firmo.codefix_options.use_luacheck = true
  
  -- Set up custom include/exclude patterns
  firmo.codefix_options.include = { "%.lua$" }
  firmo.codefix_options.exclude = {
    "_test%.lua$",
    "_spec%.lua$",
    "test/",
    "tests/",
    "vendor/",
    "third_party/"
  }
  
  -- Check all Lua files without fixing
  local options = {
    generate_report = true,
    report_file = "quality_report.json"
  }
  
  -- Run the CLI in check mode
  codefix.run_cli({"check", ".", "--generate-report", "--report-file", "quality_report.json"})
  
  print("Quality check complete. See quality_report.json for details")
end

-- Run the quality check
check_project_quality()
```

## Complete Workflow Example

### Example 17: Full Project Integration

```lua
local firmo = require("firmo")
local codefix = require("lib.tools.codefix")
local fs = require("lib.tools.filesystem")

-- Configure logging
local logging = require("lib.tools.logging")
local logger = logging.get_logger("codefix_workflow")

-- Function to initialize codefix with project-specific configuration
local function init_codefix()
  logger.info("Initializing codefix module")
  
  -- Look for project config file
  local config_file = "firmo-codefix.lua"
  local config = {}
  
  if fs.file_exists(config_file) then
    logger.info("Loading config from " .. config_file)
    local chunk, err = loadfile(config_file)
    if chunk then
      local success, result = pcall(chunk)
      if success and type(result) == "table" then
        config = result
        logger.info("Loaded custom configuration")
      else
        logger.warn("Failed to execute config file", {
          error = tostring(result)
        })
      end
    else
      logger.warn("Failed to load config file", {
        error = err
      })
    end
  end
  
  -- Apply configuration with defaults
  firmo.codefix_options = firmo.codefix_options or {}
  
  -- General options
  firmo.codefix_options.enabled = true
  firmo.codefix_options.verbose = config.verbose or false
  firmo.codefix_options.debug = config.debug or false
  
  -- Tool options
  firmo.codefix_options.use_stylua = config.use_stylua ~= nil and config.use_stylua or true
  firmo.codefix_options.use_luacheck = config.use_luacheck ~= nil and config.use_luacheck or true
  firmo.codefix_options.stylua_path = config.stylua_path or "stylua"
  firmo.codefix_options.luacheck_path = config.luacheck_path or "luacheck"
  
  -- Custom fixers
  firmo.codefix_options.custom_fixers = firmo.codefix_options.custom_fixers or {}
  if config.custom_fixers then
    for name, enabled in pairs(config.custom_fixers) do
      firmo.codefix_options.custom_fixers[name] = enabled
    end
  end
  
  -- File patterns
  if config.include then
    firmo.codefix_options.include = config.include
  end
  
  if config.exclude then
    firmo.codefix_options.exclude = config.exclude
  end
  
  -- Backup options
  firmo.codefix_options.backup = config.backup ~= nil and config.backup or true
  firmo.codefix_options.backup_ext = config.backup_ext or ".bak"
  
  logger.info("Codefix module initialized")
  
  return true
end

-- Function to fix all project files
local function fix_project()
  logger.info("Starting project-wide code fix")
  
  -- Initialize codefix
  if not init_codefix() then
    logger.error("Failed to initialize codefix")
    return false
  end
  
  -- Create options for fixing
  local options = {
    sort_by_mtime = true,           -- Fix newest files first
    generate_report = true,         -- Generate a report
    report_file = "codefix-report.json"
  }
  
  -- Find and fix all Lua files
  logger.info("Finding and fixing Lua files")
  local success, results = firmo.fix_lua_files(".", options)
  
  -- Generate summary
  if results then
    local total = #results
    local fixed = 0
    local failed = 0
    
    for _, result in ipairs(results) do
      if result.success then
        fixed = fixed + 1
      else
        failed = failed + 1
      end
    end
    
    logger.info("Fix summary", {
      total = total,
      fixed = fixed,
      failed = failed
    })
    
    -- Print summary
    print(string.format("Processed %d files total", total))
    print(string.format("- %d files fixed successfully", fixed))
    print(string.format("- %d files failed to fix", failed))
    
    if options.generate_report then
      print(string.format("Report saved to %s", options.report_file))
    end
    
    return failed == 0
  else
    logger.error("Failed to fix project files")
    return false
  end
end

-- Execute the workflow
local success = fix_project()
if not success then
  logger.error("Project fix completed with errors")
  os.exit(1)
else
  logger.info("Project fix completed successfully")
end
```

These examples demonstrate the main features and usage patterns of the codefix module. You can find a working example in the [codefix_example.lua](codefix_example.lua) file, which creates sample files with issues and fixes them using the codefix module.