-- lust-next codefix module
-- Implementation of code quality checking and fixing capabilities

local M = {}
local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("codefix")
logging.configure_from_config("codefix")

-- Try to load JSON module
local json
local ok, loaded_json = pcall(require, "lib.reporting.json")
if ok then
  json = loaded_json
else
  ok, loaded_json = pcall(require, "json")
  if ok then
    json = loaded_json
  end
end

-- Configuration options
M.config = {
  -- General options
  enabled = false,           -- Enable code fixing functionality
  verbose = false,           -- Enable verbose output
  debug = false,             -- Enable debug output
  
  -- StyLua options
  use_stylua = true,         -- Use StyLua for formatting
  stylua_path = "stylua",    -- Path to StyLua executable
  stylua_config = nil,       -- Path to StyLua config file
  
  -- Luacheck options
  use_luacheck = true,       -- Use Luacheck for linting
  luacheck_path = "luacheck", -- Path to Luacheck executable
  luacheck_config = nil,     -- Path to Luacheck config file
  
  -- Custom fixers
  custom_fixers = {
    trailing_whitespace = true,    -- Fix trailing whitespace in strings
    unused_variables = true,       -- Fix unused variables by prefixing with underscore
    string_concat = true,          -- Optimize string concatenation
    type_annotations = false,      -- Add type annotations (disabled by default)
    lua_version_compat = false,    -- Fix Lua version compatibility issues (disabled by default)
  },
  
  -- Input/output
  include = {"%.lua$"},       -- File patterns to include
  exclude = {"_test%.lua$", "_spec%.lua$", "test/", "tests/", "spec/"},   -- File patterns to exclude
  backup = true,              -- Create backup files when fixing
  backup_ext = ".bak",        -- Extension for backup files
}

-- Helper function to execute shell commands
local function execute_command(command)
  if M.config.debug then
    logger.debug("Executing command: " .. command)
  end

  local handle = io.popen(command .. " 2>&1", "r")
  if not handle then
    logger.error("Failed to execute command: " .. command)
    return nil, false, -1, "Failed to execute command: " .. command
  end
  
  local result = handle:read("*a")
  local success, reason, code = handle:close()
  code = code or 0
  
  if M.config.debug then
    logger.debug("Command: " .. command)
    logger.debug("Exit code: " .. tostring(code))
    logger.debug("Output: " .. (result or ""))
  end
  
  return result, success, code, reason
end

-- Get the operating system name
local function get_os()
  -- Use path separator to detect OS type (cross-platform approach)
  local is_windows = package.config:sub(1,1) == '\\'
  
  if is_windows then
    return "windows"
  else
    -- For Unix-like systems, we can differentiate further if needed
    -- but for most purposes, knowing it's not Windows is sufficient
    if fs then
      -- Try to use a non-io.popen method if possible
      local platform = fs._PLATFORM
      if platform then
        if platform:match("darwin") then
          return "macos"
        elseif platform:match("linux") then
          return "linux"
        elseif platform:match("bsd") then
          return "bsd"
        end
      end
    end
    
    -- Fall back to uname command for Unix-like systems
    local popen_cmd = "uname -s"
    local handle = io.popen(popen_cmd)
    if handle then
      local os_name = handle:read("*l"):lower()
      handle:close()
      
      if os_name:match("darwin") then
        return "macos"
      elseif os_name:match("linux") then
        return "linux"
      elseif os_name:match("bsd") then
        return "bsd"
      end
    end
  end
  
  -- Default to detecting based on path separator
  return is_windows and "windows" or "unix"
end

-- Logger functions - redirected to central logging system
local function log_info(msg)
  if M.config.verbose or M.config.debug then
    logger.info(msg)
  end
end

local function log_debug(msg)
  if M.config.debug then
    logger.debug(msg)
  end
end

local function log_warning(msg)
  logger.warn(msg)
end

local function log_error(msg)
  logger.error(msg)
end

local function log_success(msg)
  -- Log at info level
  logger.info(msg)
  -- Also print to console for user feedback with [SUCCESS] prefix
  io.write("[SUCCESS] " .. msg .. "\n")
end

-- Load the filesystem module
local fs = require("lib.tools.filesystem")
logger.debug("Filesystem module loaded successfully", {
  version = fs._VERSION
})

-- Check if a file exists
local function file_exists(path)
  return fs.file_exists(path)
end

-- Read a file into a string
local function read_file(path)
  return fs.read_file(path)
end

-- Write a string to a file
local function write_file(path, content)
  return fs.write_file(path, content)
end

-- Create a backup of a file
local function backup_file(path)
  if not M.config.backup then
    return true
  end
  
  logger.debug("Creating backup of file", {
    path = path,
    backup_ext = M.config.backup_ext
  })
  
  local backup_path = path .. M.config.backup_ext
  local success, err = fs.copy_file(path, backup_path)
  if not success then
    logger.error("Failed to create backup file", {
      path = path, 
      backup_path = backup_path,
      error = err
    })
    return false, err
  end
  
  logger.debug("Backup file created successfully", {
    path = backup_path
  })
  return true
end

-- Check if a command is available
local function command_exists(cmd)
  local os_name = get_os()
  local test_cmd
  
  if os_name == "windows" then
    test_cmd = string.format('where %s 2>nul', cmd)
  else
    test_cmd = string.format('command -v %s 2>/dev/null', cmd)
  end
  
  local result, success = execute_command(test_cmd)
  return success and result and result:len() > 0
end

-- Find a configuration file by searching up the directory tree
local function find_config_file(filename, start_dir)
  start_dir = start_dir or "."
  local current_dir = start_dir
  
  logger.debug("Searching for config file", {
    filename = filename,
    start_dir = start_dir
  })
  
  -- Use filesystem module's get_absolute_path if available
  if fs then
    current_dir = fs.get_absolute_path(current_dir) or current_dir
  else
    -- Convert to absolute path if needed
    if not current_dir:match("^/") and get_os() ~= "windows" then
      local pwd_result = execute_command("pwd")
      if pwd_result then
        current_dir = pwd_result:gsub("%s+$", "") .. "/" .. current_dir
      end
    end
  end
  
  logger.debug("Starting config file search from directory", {
    absolute_dir = current_dir
  })
  
  while current_dir and current_dir ~= "" do
    local config_path
    
    if fs then
      config_path = fs.join_paths(current_dir, filename)
    else
      config_path = current_dir .. "/" .. filename
    end
    
    if file_exists(config_path) then
      logger.debug("Found config file", {
        path = config_path
      })
      return config_path
    end
    
    -- Move up one directory
    local parent_dir
    
    if fs then
      parent_dir = fs.get_directory_name(current_dir)
    else
      parent_dir = current_dir:match("(.+)/[^/]+$")
    end
    
    if current_dir == parent_dir then
      break
    end
    current_dir = parent_dir
  end
  
  logger.debug("Config file not found", {
    filename = filename
  })
  return nil
end

-- Find files matching patterns
local function find_files(include_patterns, exclude_patterns, start_dir)
  start_dir = start_dir or "."
  
  logger.debug("Using filesystem module to find files", {
    directory = start_dir,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns
  })
  
  -- Normalize path
  start_dir = fs.normalize_path(start_dir)
  
  -- Get absolute path
  start_dir = fs.get_absolute_path(start_dir)
  
  logger.debug("Finding files in normalized directory", {
    directory = start_dir
  })
  
  -- Use filesystem discover_files function
  local files = fs.discover_files({start_dir}, include_patterns, exclude_patterns)
  
  logger.info("Found files using filesystem module", {
    file_count = #files,
    directory = start_dir
  })
  
  return files
end

-- Implementation of Lua-based file finding using filesystem module
local function find_files_lua(include_patterns, exclude_patterns, dir)
  logger.debug("Using filesystem module for Lua-based file discovery", {
    directory = dir,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns
  })
  
  -- Normalize directory path
  dir = fs.normalize_path(dir)
  
  -- Use scan_directory to get all files recursively
  local all_files = fs.scan_directory(dir, true)
  local files = {}
  
  -- Filter files using include and exclude patterns
  for _, file_path in ipairs(all_files) do
    local include_file = false
    
    -- Check include patterns
    for _, pattern in ipairs(include_patterns) do
      if file_path:match(pattern) then
        include_file = true
        break
      end
    end
    
    -- Check exclude patterns
    if include_file then
      for _, pattern in ipairs(exclude_patterns) do
        local rel_path = fs.get_relative_path(file_path, dir)
        if rel_path and rel_path:match(pattern) then
          include_file = false
          break
        end
      end
    end
    
    if include_file then
      logger.debug("Including file in results", {
        file = file_path
      })
      table.insert(files, file_path)
    end
  end
  
  logger.info("Found files using filesystem module Lua-based method", {
    file_count = #files,
    directory = dir
  })
  
  return files
end

-- Initialize module with configuration
function M.init(options)
  options = options or {}
  
  -- Apply custom options over defaults
  for k, v in pairs(options) do
    if type(v) == "table" and type(M.config[k]) == "table" then
      -- Merge tables
      for k2, v2 in pairs(v) do
        M.config[k][k2] = v2
      end
    else
      M.config[k] = v
    end
  end
  
  return M
end

----------------------------------
-- StyLua Integration Functions --
----------------------------------

-- Check if StyLua is available
function M.check_stylua()
  if not command_exists(M.config.stylua_path) then
    log_warning("StyLua not found at: " .. M.config.stylua_path)
    return false
  end
  
  log_debug("StyLua found at: " .. M.config.stylua_path)
  return true
end

-- Find StyLua configuration file
function M.find_stylua_config(dir)
  local config_file = M.config.stylua_config
  
  if not config_file then
    -- Try to find configuration files
    config_file = find_config_file("stylua.toml", dir) or
                  find_config_file(".stylua.toml", dir)
  end
  
  if config_file then
    log_debug("Found StyLua config at: " .. config_file)
  else
    log_debug("No StyLua config found")
  end
  
  return config_file
end

-- Run StyLua on a file
function M.run_stylua(file_path, config_file)
  if not M.config.use_stylua then
    log_debug("StyLua is disabled, skipping")
    return true
  end
  
  if not M.check_stylua() then
    return false, "StyLua not available"
  end
  
  config_file = config_file or M.find_stylua_config(file_path:match("(.+)/[^/]+$"))
  
  local cmd = M.config.stylua_path
  
  if config_file then
    cmd = cmd .. string.format(' --config-path "%s"', config_file)
  end
  
  -- Make backup before running
  if M.config.backup then
    local success, err = backup_file(file_path)
    if not success then
      log_warning("Failed to create backup for " .. file_path .. ": " .. (err or "unknown error"))
    end
  end
  
  -- Run StyLua
  cmd = cmd .. string.format(' "%s"', file_path)
  log_info("Running StyLua on " .. file_path)
  
  local result, success, code = execute_command(cmd)
  
  if not success or code ~= 0 then
    log_error("StyLua failed on " .. file_path .. ": " .. (result or "unknown error"))
    return false, result
  end
  
  log_success("StyLua formatted " .. file_path)
  return true
end

-----------------------------------
-- Luacheck Integration Functions --
-----------------------------------

-- Check if Luacheck is available
function M.check_luacheck()
  if not command_exists(M.config.luacheck_path) then
    log_warning("Luacheck not found at: " .. M.config.luacheck_path)
    return false
  end
  
  log_debug("Luacheck found at: " .. M.config.luacheck_path)
  return true
end

-- Find Luacheck configuration file
function M.find_luacheck_config(dir)
  local config_file = M.config.luacheck_config
  
  if not config_file then
    -- Try to find configuration files
    config_file = find_config_file(".luacheckrc", dir) or
                  find_config_file("luacheck.rc", dir)
  end
  
  if config_file then
    log_debug("Found Luacheck config at: " .. config_file)
  else
    log_debug("No Luacheck config found")
  end
  
  return config_file
end

-- Parse Luacheck output
function M.parse_luacheck_output(output)
  if not output then
    return {}
  end
  
  local issues = {}
  
  -- Parse each line
  for line in output:gmatch("[^\r\n]+") do
    -- Look for format: filename:line:col: (code) message
    local file, line, col, code, message = line:match("([^:]+):(%d+):(%d+): %(([%w_]+)%) (.*)")
    
    if file and line and col and code and message then
      table.insert(issues, {
        file = file,
        line = tonumber(line),
        col = tonumber(col),
        code = code,
        message = message
      })
    end
  end
  
  return issues
end

-- Run Luacheck on a file
function M.run_luacheck(file_path, config_file)
  if not M.config.use_luacheck then
    log_debug("Luacheck is disabled, skipping")
    return true
  end
  
  if not M.check_luacheck() then
    return false, "Luacheck not available"
  end
  
  config_file = config_file or M.find_luacheck_config(file_path:match("(.+)/[^/]+$"))
  
  local cmd = M.config.luacheck_path .. " --codes --no-color"
  
  -- Luacheck automatically finds .luacheckrc in parent directories
  -- We don't need to specify the config file explicitly
  
  -- Run Luacheck
  cmd = cmd .. string.format(' "%s"', file_path)
  log_info("Running Luacheck on " .. file_path)
  
  local result, success, code = execute_command(cmd)
  
  -- Parse the output
  local issues = M.parse_luacheck_output(result)
  
  -- Code 0 = no issues
  -- Code 1 = only warnings
  -- Code 2+ = errors
  if code > 1 then
    log_error("Luacheck found " .. #issues .. " issues in " .. file_path)
    return false, issues
  elseif code == 1 then
    log_warning("Luacheck found " .. #issues .. " warnings in " .. file_path)
    return true, issues
  end
  
  log_success("Luacheck verified " .. file_path)
  return true, issues
end

-----------------------------
-- Custom Fixer Functions --
-----------------------------

-- Fix trailing whitespace in multiline strings
function M.fix_trailing_whitespace(content)
  if not M.config.custom_fixers.trailing_whitespace then
    return content
  end
  
  log_debug("Fixing trailing whitespace in multiline strings")
  
  -- Find multiline strings with trailing whitespace
  local fixed_content = content:gsub("(%[%[.-([%s]+)\n.-]%])", function(match, spaces)
    return match:gsub(spaces .. "\n", "\n")
  end)
  
  return fixed_content
end

-- Fix unused variables by prefixing with underscore
function M.fix_unused_variables(file_path, issues)
  if not M.config.custom_fixers.unused_variables or not issues then
    return false
  end
  
  log_debug("Fixing unused variables in " .. file_path)
  
  local content, err = read_file(file_path)
  if not content then
    log_error("Failed to read file for unused variable fixing: " .. (err or "unknown error"))
    return false
  end
  
  local fixed = false
  local lines = {}
  
  -- Split content into lines
  for line in content:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  
  -- Look for unused variable issues
  for _, issue in ipairs(issues) do
    if issue.code == "212" or issue.code == "213" then -- Unused variable/argument codes
      local var_name = issue.message:match("unused variable '([^']+)'") or
                      issue.message:match("unused argument '([^']+)'")
      
      if var_name and issue.line and issue.line <= #lines then
        local line = lines[issue.line]
        -- Replace the variable only if it's not already prefixed with underscore
        if not line:match("_" .. var_name) then
          lines[issue.line] = line:gsub("([%s,%(])(" .. var_name .. ")([%s,%)%.])", 
                                      "%1_%2%3")
          fixed = true
        end
      end
    end
  end
  
  -- Only save if fixes were made
  if fixed then
    -- Reconstruct content
    local fixed_content = table.concat(lines, "\n")
    if fixed_content:sub(-1) ~= "\n" and content:sub(-1) == "\n" then
      fixed_content = fixed_content .. "\n"
    end
    
    local success, err = write_file(file_path, fixed_content)
    if not success then
      log_error("Failed to write fixed unused variables: " .. (err or "unknown error"))
      return false
    end
    
    log_success("Fixed unused variables in " .. file_path)
    return true
  end
  
  return false
end

-- Fix string concatenation (optimize .. operator usage)
function M.fix_string_concat(content)
  if not M.config.custom_fixers.string_concat then
    return content
  end
  
  log_debug("Optimizing string concatenation")
  
  -- Replace multiple consecutive string concatenations with a single one
  local fixed_content = content:gsub("(['\"])%s*%.%.%s*(['\"])", "%1%2")
  
  -- Replace concatenations of string literals with a single string
  fixed_content = fixed_content:gsub("(['\"])([^'\"]+)%1%s*%.%.%s*(['\"])([^'\"]+)%3", "%1%2%4%3")
  
  return fixed_content
end

-- Add type annotations in function documentation
function M.fix_type_annotations(content)
  if not M.config.custom_fixers.type_annotations then
    return content
  end
  
  log_debug("Adding type annotations to function documentation")
  
  -- This is a complex task that requires parsing function signatures and existing comments
  -- For now, we'll implement a basic version that adds annotations to functions without them
  
  -- Find function definitions without type annotations in comments
  local fixed_content = content:gsub(
    "([^\n]-function%s+[%w_:%.]+%s*%(([^%)]+)%)[^\n]-\n)",
    function(func_def, params)
      -- Skip if there's already a type annotation comment
      if func_def:match("%-%-%-.*@param") or func_def:match("%-%-.*@param") then
        return func_def
      end
      
      -- Parse parameters
      local param_list = {}
      for param in params:gmatch("([%w_]+)[%s,]*") do
        if param ~= "" then
          table.insert(param_list, param)
        end
      end
      
      -- Skip if no parameters
      if #param_list == 0 then
        return func_def
      end
      
      -- Generate annotation comment
      local annotation = "--- Function documentation\n"
      for _, param in ipairs(param_list) do
        annotation = annotation .. "-- @param " .. param .. " any\n"
      end
      annotation = annotation .. "-- @return any\n"
      
      -- Add annotation before function
      return annotation .. func_def
    end
  )
  
  return fixed_content
end

-- Fix code for Lua version compatibility issues
function M.fix_lua_version_compat(content, target_version)
  if not M.config.custom_fixers.lua_version_compat then
    return content
  end
  
  target_version = target_version or "5.1" -- Default to Lua 5.1 compatibility
  
  log_debug("Fixing Lua version compatibility issues for Lua " .. target_version)
  
  local fixed_content = content
  
  if target_version == "5.1" then
    -- Replace 5.2+ features with 5.1 compatible versions
    
    -- Replace goto statements with alternative logic (simple cases only)
    fixed_content = fixed_content:gsub("goto%s+([%w_]+)", "-- goto %1 (replaced for Lua 5.1 compatibility)")
    fixed_content = fixed_content:gsub("::([%w_]+)::", "-- ::%1:: (removed for Lua 5.1 compatibility)")
    
    -- Replace table.pack with a compatible implementation
    fixed_content = fixed_content:gsub(
      "table%.pack%s*(%b())",
      "({...}) -- table.pack replaced for Lua 5.1 compatibility"
    )
    
    -- Replace bit32 library with bit if available
    fixed_content = fixed_content:gsub(
      "bit32%.([%w_]+)%s*(%b())",
      "bit.%1%2 -- bit32 replaced with bit for Lua 5.1 compatibility"
    )
  end
  
  return fixed_content
end

-- Run all custom fixers on a file
function M.run_custom_fixers(file_path, issues)
  log_info("Running custom fixers on " .. file_path)
  
  local content, err = read_file(file_path)
  if not content then
    log_error("Failed to read file for custom fixing: " .. (err or "unknown error"))
    return false
  end
  
  -- Make backup before modifying
  if M.config.backup then
    local success, err = backup_file(file_path)
    if not success then
      log_warning("Failed to create backup for " .. file_path .. ": " .. (err or "unknown error"))
    end
  end
  
  -- Apply fixers in sequence
  local modified = false
  
  -- Fix trailing whitespace in multiline strings
  local fixed_content = M.fix_trailing_whitespace(content)
  if fixed_content ~= content then
    modified = true
    content = fixed_content
  end
  
  -- Fix string concatenation
  fixed_content = M.fix_string_concat(content)
  if fixed_content ~= content then
    modified = true
    content = fixed_content
  end
  
  -- Fix type annotations
  fixed_content = M.fix_type_annotations(content)
  if fixed_content ~= content then
    modified = true
    content = fixed_content
  end
  
  -- Fix Lua version compatibility issues
  fixed_content = M.fix_lua_version_compat(content)
  if fixed_content ~= content then
    modified = true
    content = fixed_content
  end
  
  -- Only save the file if changes were made
  if modified then
    local success, err = write_file(file_path, content)
    if not success then
      log_error("Failed to write fixed content: " .. (err or "unknown error"))
      return false
    end
    
    log_success("Applied custom fixes to " .. file_path)
  else
    log_info("No custom fixes needed for " .. file_path)
  end
  
  -- Fix unused variables (uses issues from Luacheck)
  local unused_fixed = M.fix_unused_variables(file_path, issues)
  if unused_fixed then
    modified = true
  end
  
  return modified
end

-- Main function to fix a file
function M.fix_file(file_path)
  if not M.config.enabled then
    log_debug("Codefix is disabled, skipping")
    return true
  end
  
  if not file_exists(file_path) then
    log_error("File does not exist: " .. file_path)
    return false
  end
  
  log_info("Fixing " .. file_path)
  
  -- Make backup before any modifications
  if M.config.backup then
    local success, err = backup_file(file_path)
    if not success then
      log_warning("Failed to create backup for " .. file_path .. ": " .. (err or "unknown error"))
    end
  end
  
  -- Run Luacheck first to get issues
  local luacheck_success, issues = M.run_luacheck(file_path)
  
  -- Run custom fixers
  local fixers_modified = M.run_custom_fixers(file_path, issues)
  
  -- Run StyLua after custom fixers
  local stylua_success = M.run_stylua(file_path)
  
  -- Run Luacheck again to verify fixes
  if fixers_modified or not stylua_success then
    log_info("Verifying fixes with Luacheck")
    luacheck_success, issues = M.run_luacheck(file_path)
  end
  
  return stylua_success and luacheck_success
end

-- Fix multiple files
function M.fix_files(file_paths)
  if not M.config.enabled then
    log_debug("Codefix is disabled, skipping")
    return true
  end
  
  if type(file_paths) ~= "table" or #file_paths == 0 then
    log_warning("No files provided to fix")
    return false
  end
  
  log_info(string.format("Fixing %d files", #file_paths))
  
  local success_count = 0
  local failure_count = 0
  local results = {}
  
  for i, file_path in ipairs(file_paths) do
    log_info(string.format("Processing file %d/%d: %s", i, #file_paths, file_path))
    
    -- Check if file exists before attempting to fix
    if not file_exists(file_path) then
      log_error(string.format("File does not exist: %s", file_path))
      failure_count = failure_count + 1
      table.insert(results, {
        file = file_path,
        success = false,
        error = "File not found"
      })
    else
      local success = M.fix_file(file_path)
      
      if success then
        success_count = success_count + 1
        table.insert(results, {
          file = file_path,
          success = true
        })
      else
        failure_count = failure_count + 1
        table.insert(results, {
          file = file_path,
          success = false,
          error = "Failed to fix file"
        })
      end
    end
    
    -- Provide progress update for large batches
    if #file_paths > 10 and (i % 10 == 0 or i == #file_paths) then
      log_info(string.format("Progress: %d/%d files processed (%.1f%%)", 
        i, #file_paths, (i / #file_paths) * 100))
    end
  end
  
  -- Generate summary
  log_info(string.rep("-", 40))
  log_info(string.format("Fix summary: %d successful, %d failed, %d total", 
    success_count, failure_count, #file_paths))
  
  if success_count > 0 then
    log_success(string.format("Successfully fixed %d files", success_count))
  end
  
  if failure_count > 0 then
    log_warning(string.format("Failed to fix %d files", failure_count))
  end
  
  return failure_count == 0, results
end

-- Find and fix Lua files
function M.fix_lua_files(directory, options)
  directory = directory or "."
  options = options or {}
  
  if not M.config.enabled then
    log_debug("Codefix is disabled, skipping")
    return true
  end
  
  -- Allow for custom include/exclude patterns
  local include_patterns = options.include or M.config.include
  local exclude_patterns = options.exclude or M.config.exclude
  
  log_info("Finding Lua files in " .. directory)
  
  local files = find_files(include_patterns, exclude_patterns, directory)
  
  log_info(string.format("Found %d Lua files to fix", #files))
  
  if #files == 0 then
    log_warning("No matching files found in " .. directory)
    return true
  end
  
  -- Allow for limiting the number of files processed
  if options.limit and options.limit > 0 and options.limit < #files then
    log_info(string.format("Limiting to %d files (out of %d found)", options.limit, #files))
    local limited_files = {}
    for i = 1, options.limit do
      table.insert(limited_files, files[i])
    end
    files = limited_files
  end
  
  -- Sort files by modification time if requested
  if options.sort_by_mtime then
    log_info("Sorting files by modification time")
    local file_times = {}
    
    for _, file in ipairs(files) do
      local mtime
      local os_name = get_os()
      
      if os_name == "windows" then
        local result = execute_command(string.format('dir "%s" /TC /B', file))
        if result then
          mtime = result:match("(%d+/%d+/%d+%s+%d+:%d+%s+%a+)")
        end
      else
        local result = execute_command(string.format('stat -c "%%Y" "%s"', file))
        if result then
          mtime = tonumber(result:match("%d+"))
        end
      end
      
      mtime = mtime or 0
      table.insert(file_times, {file = file, mtime = mtime})
    end
    
    table.sort(file_times, function(a, b) return a.mtime > b.mtime end)
    
    files = {}
    for _, entry in ipairs(file_times) do
      table.insert(files, entry.file)
    end
  end
  
  -- Run the file fixing
  local success, results = M.fix_files(files)
  
  -- Generate a detailed report if requested
  if options.generate_report and json then
    local report = {
      timestamp = os.time(),
      directory = directory,
      total_files = #files,
      successful = 0,
      failed = 0,
      results = results
    }
    
    for _, result in ipairs(results) do
      if result.success then
        report.successful = report.successful + 1
      else
        report.failed = report.failed + 1
      end
    end
    
    local report_file = options.report_file or "codefix_report.json"
    local json_content = json.encode(report)
    
    logger.debug("Generating report file", {
      report_file = report_file,
      report_size = #json_content,
      successful_files = report.successful,
      failed_files = report.failed
    })
    
    local success, err = fs.write_file(report_file, json_content)
    if success then
      log_info("Wrote detailed report to " .. report_file)
    else
      log_error("Failed to write report to " .. report_file .. ": " .. (err or "unknown error"))
    end
  end
  
  return success, results
end

-- Command line interface
function M.run_cli(args)
  args = args or {}
  
  -- Enable module
  M.config.enabled = true
  
  -- Parse arguments
  local command = args[1] or "fix"
  local target = nil
  local options = {
    include = M.config.include,
    exclude = M.config.exclude,
    limit = 0,
    sort_by_mtime = false,
    generate_report = false,
    report_file = "codefix_report.json",
    include_patterns = {},
    exclude_patterns = {}
  }
  
  -- Extract target and options from args
  for i = 2, #args do
    local arg = args[i]
    
    -- Skip flags when looking for target
    if not arg:match("^%-") and not target then
      target = arg
    end
    
    -- Handle flags
    if arg == "--verbose" or arg == "-v" then
      M.config.verbose = true
    elseif arg == "--debug" or arg == "-d" then
      M.config.debug = true
      M.config.verbose = true
    elseif arg == "--no-backup" or arg == "-nb" then
      M.config.backup = false
    elseif arg == "--no-stylua" or arg == "-ns" then
      M.config.use_stylua = false
    elseif arg == "--no-luacheck" or arg == "-nl" then
      M.config.use_luacheck = false
    elseif arg == "--sort-by-mtime" or arg == "-s" then
      options.sort_by_mtime = true
    elseif arg == "--generate-report" or arg == "-r" then
      options.generate_report = true
    elseif arg == "--limit" or arg == "-l" then
      if args[i+1] and tonumber(args[i+1]) then
        options.limit = tonumber(args[i+1])
      end
    elseif arg == "--report-file" then
      if args[i+1] then
        options.report_file = args[i+1]
      end
    elseif arg == "--include" or arg == "-i" then
      if args[i+1] and not args[i+1]:match("^%-") then
        table.insert(options.include_patterns, args[i+1])
      end
    elseif arg == "--exclude" or arg == "-e" then
      if args[i+1] and not args[i+1]:match("^%-") then
        table.insert(options.exclude_patterns, args[i+1])
      end
    end
  end
  
  -- Set default target if not specified
  target = target or "."
  
  -- Apply custom include/exclude patterns if specified
  if #options.include_patterns > 0 then
    options.include = options.include_patterns
  end
  
  if #options.exclude_patterns > 0 then
    options.exclude = options.exclude_patterns
  end
  
  -- Run the appropriate command
  if command == "fix" then
    -- Check if target is a directory or file
    if target:match("%.lua$") and file_exists(target) then
      return M.fix_file(target)
    else
      return M.fix_lua_files(target, options)
    end
  elseif command == "check" then
    -- Only run checks, don't fix
    M.config.use_stylua = false
    
    if target:match("%.lua$") and file_exists(target) then
      return M.run_luacheck(target)
    else
      -- Allow checking multiple files without fixing
      options.check_only = true
      local files = find_files(options.include, options.exclude, target)
      
      if #files == 0 then
        log_warning("No matching files found")
        return true
      end
      
      log_info(string.format("Checking %d files...", #files))
      
      local issues_count = 0
      for _, file in ipairs(files) do
        local _, issues = M.run_luacheck(file)
        if issues and #issues > 0 then
          issues_count = issues_count + #issues
        end
      end
      
      log_info(string.format("Found %d issues in %d files", issues_count, #files))
      return issues_count == 0
    end
  elseif command == "find" then
    -- Just find and list matching files
    local files = find_files(options.include, options.exclude, target)
    
    if #files == 0 then
      log_warning("No matching files found")
    else
      log_info(string.format("Found %d matching files:", #files))
      for _, file in ipairs(files) do
        -- Log at debug level, but use direct io.write for console output
        logger.debug("Found matching file", {path = file})
        io.write(file .. "\n")
      end
    end
    
    return true
  elseif command == "help" then
    logger.debug("Displaying codefix help text")
    
    -- Use the logging module's info function for consistent help text display
    logging.info("lust-next codefix usage:")
    logging.info("  fix [directory or file] - Fix Lua files")
    logging.info("  check [directory or file] - Check Lua files without fixing")
    logging.info("  find [directory] - Find Lua files matching patterns")
    logging.info("  help - Show this help message")
    logging.info("")
    logging.info("Options:")
    logging.info("  --verbose, -v       - Enable verbose output")
    logging.info("  --debug, -d         - Enable debug output")
    logging.info("  --no-backup, -nb    - Disable backup files")
    logging.info("  --no-stylua, -ns    - Disable StyLua formatting")
    logging.info("  --no-luacheck, -nl  - Disable Luacheck verification")
    logging.info("  --sort-by-mtime, -s - Sort files by modification time (newest first)")
    logging.info("  --generate-report, -r - Generate a JSON report file")
    logging.info("  --report-file FILE  - Specify report file name (default: codefix_report.json)")
    logging.info("  --limit N, -l N     - Limit processing to N files")
    logging.info("  --include PATTERN, -i PATTERN - Add file pattern to include (can be used multiple times)")
    logging.info("  --exclude PATTERN, -e PATTERN - Add file pattern to exclude (can be used multiple times)")
    logging.info("")
    logging.info("Examples:")
    logging.info("  fix src/ --no-stylua")
    logging.info("  check src/ --include \"%.lua$\" --exclude \"_spec%.lua$\"")
    logging.info("  fix . --sort-by-mtime --limit 10")
    logging.info("  fix . --generate-report --report-file codefix_results.json")
    return true
  else
    log_error("Unknown command: " .. command)
    return false
  end
end

-- Module interface with lust-next
function M.register_with_lust(lust)
  if not lust then
    return
  end
  
  -- Add codefix configuration to lust
  lust.codefix_options = M.config
  
  -- Add codefix functions to lust
  lust.fix_file = M.fix_file
  lust.fix_files = M.fix_files
  lust.fix_lua_files = M.fix_lua_files
  
  -- Add the full codefix module as a namespace for advanced usage
  lust.codefix = M
  
  -- Add CLI commands
  lust.commands = lust.commands or {}
  lust.commands.fix = function(args)
    return M.run_cli(args)
  end
  
  lust.commands.check = function(args)
    table.insert(args, 1, "check")
    return M.run_cli(args)
  end
  
  lust.commands.find = function(args)
    table.insert(args, 1, "find")
    return M.run_cli(args)
  end
  
  -- Register a custom reporter for code quality
  if lust.register_reporter then
    lust.register_reporter("codefix", function(results, options)
      options = options or {}
      
      -- Check if codefix should be run
      if not options.codefix then
        return
      end
      
      logger.debug("Codefix reporter initialized", {
        test_count = #results.tests,
        options = options
      })
      
      -- Find all source files in the test files
      local test_files = {}
      for _, test in ipairs(results.tests) do
        if test.source_file and not test_files[test.source_file] then
          test_files[test.source_file] = true
          logger.debug("Found source file in test results", {
            source_file = test.source_file
          })
        end
      end
      
      -- Convert to array
      local files_to_fix = {}
      for file in pairs(test_files) do
        table.insert(files_to_fix, file)
      end
      
      -- Run codefix on all test files
      if #files_to_fix > 0 then
        io.write(string.format("\nRunning codefix on %d source files...\n", #files_to_fix))
        M.config.enabled = true
        M.config.verbose = options.verbose or false
        
        logger.info("Running codefix on test source files", {
          file_count = #files_to_fix,
          verbose = M.config.verbose
        })
        
        local success, fix_results = M.fix_files(files_to_fix)
        
        if success then
          logger.info("All files fixed successfully", {
            file_count = #files_to_fix
          })
          io.write("✅ All files fixed successfully\n")
        else
          -- Count successful and failed files
          local successful = 0
          local failed = 0
          
          for _, result in ipairs(fix_results or {}) do
            if result.success then
              successful = successful + 1
            else
              failed = failed + 1
            end
          end
          
          logger.warn("Some files could not be fixed", {
            total_files = #files_to_fix,
            successful_files = successful,
            failed_files = failed
          })
          io.write("⚠️ Some files could not be fixed\n")
        end
      end
    end)
  end
  
  -- Register a custom fixer with codefix
  function M.register_custom_fixer(name, options)
    if not options or not options.fix or not options.name then
      log_error("Custom fixer requires a name and fix function")
      return false
    end
    
    -- Add to custom fixers table
    if type(options.fix) == "function" then
      -- Register as a named function
      M.config.custom_fixers[name] = options.fix
    else
      -- Register as an object with metadata
      M.config.custom_fixers[name] = options
    end
    
    log_info("Registered custom fixer: " .. options.name)
    return true
  end
  
  -- Try to load and register the markdown module
  local ok, markdown = pcall(require, "lib.tools.markdown")
  if ok and markdown then
    markdown.register_with_codefix(M)
    if M.config.verbose then
      logger.info("Registered markdown fixing capabilities")
    end
  end

  return M
end

-- Return the module
return M