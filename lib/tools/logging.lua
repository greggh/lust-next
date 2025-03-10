-- Centralized logging module for lust-next
local M = {}

-- Log levels
M.LEVELS = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
  VERBOSE = 5
}

-- Default configuration
local config = {
  global_level = M.LEVELS.INFO,  -- Default global level
  module_levels = {},            -- Per-module log levels
  timestamps = false,            -- Enable/disable timestamps
  use_colors = true,             -- Enable/disable colors
  output_file = nil,             -- Log to file (nil = console only)
  silent = false,                -- Suppress all output when true
}

-- ANSI color codes
local COLORS = {
  RESET = "\27[0m",
  RED = "\27[31m",
  GREEN = "\27[32m",
  YELLOW = "\27[33m",
  BLUE = "\27[34m",
  MAGENTA = "\27[35m",
  CYAN = "\27[36m",
  WHITE = "\27[37m",
}

-- Color mapping for log levels
local LEVEL_COLORS = {
  [M.LEVELS.ERROR] = COLORS.RED,
  [M.LEVELS.WARN] = COLORS.YELLOW,
  [M.LEVELS.INFO] = COLORS.BLUE,
  [M.LEVELS.DEBUG] = COLORS.CYAN,
  [M.LEVELS.VERBOSE] = COLORS.MAGENTA,
}

-- Level names for display
local LEVEL_NAMES = {
  [M.LEVELS.ERROR] = "ERROR",
  [M.LEVELS.WARN] = "WARN",
  [M.LEVELS.INFO] = "INFO",
  [M.LEVELS.DEBUG] = "DEBUG",
  [M.LEVELS.VERBOSE] = "VERBOSE",
}

-- Get current timestamp
local function get_timestamp()
  return os.date("%Y-%m-%d %H:%M:%S")
end

-- Check if logging is enabled for a specific level and module
local function is_enabled(level, module_name)
  if config.silent then
    return false
  end
  
  -- Check module-specific level first
  if module_name and config.module_levels[module_name] then
    return level <= config.module_levels[module_name]
  end
  
  -- Fall back to global level
  return level <= config.global_level
end

-- Format a log message
local function format_log(level, module_name, message)
  local parts = {}
  
  -- Add timestamp if enabled
  if config.timestamps then
    table.insert(parts, get_timestamp())
  end
  
  -- Add level with color if enabled
  local level_str = LEVEL_NAMES[level] or "UNKNOWN"
  if config.use_colors then
    level_str = (LEVEL_COLORS[level] or "") .. level_str .. COLORS.RESET
  end
  table.insert(parts, level_str)
  
  -- Add module name if provided
  if module_name then
    if config.use_colors then
      table.insert(parts, COLORS.GREEN .. module_name .. COLORS.RESET)
    else
      table.insert(parts, module_name)
    end
  end
  
  -- Add the message
  table.insert(parts, message or "")
  
  -- Join all parts with separators
  return table.concat(parts, " | ")
end

-- The core logging function
local function log(level, module_name, message)
  if not is_enabled(level, module_name) then
    return
  end
  
  local formatted = format_log(level, module_name, message)
  
  -- Output to console
  print(formatted)
  
  -- Output to file if configured
  if config.output_file then
    local file = io.open(config.output_file, "a")
    if file then
      file:write(formatted .. "\n")
      file:close()
    end
  end
end

-- Configure the logging module
function M.configure(options)
  options = options or {}
  
  -- Apply configuration options
  if options.level ~= nil then
    config.global_level = options.level
  end
  
  if options.module_levels then
    for module, level in pairs(options.module_levels) do
      config.module_levels[module] = level
    end
  end
  
  if options.timestamps ~= nil then
    config.timestamps = options.timestamps
  end
  
  if options.use_colors ~= nil then
    config.use_colors = options.use_colors
  end
  
  if options.output_file ~= nil then
    config.output_file = options.output_file
  end
  
  if options.silent ~= nil then
    config.silent = options.silent
  end
  
  return M
end

-- Create a logger instance for a specific module
function M.get_logger(module_name)
  local logger = {}
  
  -- Create logging methods for each level
  logger.error = function(message)
    log(M.LEVELS.ERROR, module_name, message)
  end
  
  logger.warn = function(message)
    log(M.LEVELS.WARN, module_name, message)
  end
  
  logger.info = function(message)
    log(M.LEVELS.INFO, module_name, message)
  end
  
  logger.debug = function(message)
    log(M.LEVELS.DEBUG, module_name, message)
  end
  
  logger.verbose = function(message)
    log(M.LEVELS.VERBOSE, module_name, message)
  end
  
  -- Allow direct log level access
  logger.log = function(level, message)
    log(level, module_name, message)
  end
  
  -- Convenience methods for checking if a level is enabled
  logger.is_debug_enabled = function()
    return is_enabled(M.LEVELS.DEBUG, module_name)
  end
  
  logger.is_verbose_enabled = function()
    return is_enabled(M.LEVELS.VERBOSE, module_name)
  end
  
  return logger
end

-- Direct module-level logging
function M.error(message)
  log(M.LEVELS.ERROR, nil, message)
end

function M.warn(message)
  log(M.LEVELS.WARN, nil, message)
end

function M.info(message)
  log(M.LEVELS.INFO, nil, message)
end

function M.debug(message)
  log(M.LEVELS.DEBUG, nil, message)
end

function M.verbose(message)
  log(M.LEVELS.VERBOSE, nil, message)
end

-- Set the log level for a specific module
function M.set_module_level(module_name, level)
  config.module_levels[module_name] = level
  return M
end

-- Set the global log level
function M.set_level(level)
  config.global_level = level
  return M
end

-- Configure module level based on debug/verbose settings
function M.configure_from_options(module_name, options)
  local log_level = M.LEVELS.INFO
  if options.debug then
    log_level = M.LEVELS.DEBUG
  elseif options.verbose then
    log_level = M.LEVELS.VERBOSE
  end
  M.set_module_level(module_name, log_level)
  return log_level
end

-- Compatibility with existing code
function M.log_debug(message, module_name)
  log(M.LEVELS.DEBUG, module_name, message)
end

function M.log_verbose(message, module_name)
  log(M.LEVELS.VERBOSE, module_name, message)
end

return M