-- Centralized logging module for lust-next
local M = {}

-- Try to import filesystem module (might not be available during first load)
local fs
local function get_fs()
  if not fs then
    fs = require("lib.tools.filesystem")
  end
  return fs
end

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
  log_dir = "logs",              -- Directory to store log files
  silent = false,                -- Suppress all output when true
  max_file_size = 50 * 1024,     -- 50KB default size limit per log file (small for testing)
  max_log_files = 5,             -- Number of rotated log files to keep
  date_pattern = "%Y-%m-%d",     -- Date pattern for log filenames
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

-- Ensure the log directory exists
local function ensure_log_dir()
  local fs = get_fs()
  if config.log_dir then
    local success, err = fs.ensure_directory_exists(config.log_dir)
    if not success then
      print("Warning: Failed to create log directory: " .. (err or "unknown error"))
    end
  end
end

-- Get the full path to the log file
local function get_log_file_path()
  if not config.output_file then return nil end
  
  -- If output_file is an absolute path, use it directly
  if config.output_file:sub(1, 1) == "/" then
    return config.output_file
  end
  
  -- Otherwise, construct path within log directory
  return config.log_dir .. "/" .. config.output_file
end

-- Rotate log files if needed
local function rotate_log_files()
  local fs = get_fs()
  local log_path = get_log_file_path()
  if not log_path then return end
  
  -- Check if we need to rotate
  if not fs.file_exists(log_path) then return end
  
  local size = fs.get_file_size(log_path)
  if not size or size < config.max_file_size then return end
  
  -- Rotate files (move existing rotated logs)
  for i = config.max_log_files - 1, 1, -1 do
    local old_file = log_path .. "." .. i
    local new_file = log_path .. "." .. (i + 1)
    if fs.file_exists(old_file) then
      fs.move_file(old_file, new_file)
    end
  end
  
  -- Move current log to .1
  fs.move_file(log_path, log_path .. ".1")
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
    local fs = get_fs()
    local log_path = get_log_file_path()
    
    -- Ensure log directory exists
    ensure_log_dir()
    
    -- Check if we need to rotate the log file
    if config.max_file_size and config.max_file_size > 0 then
      local size = fs.file_exists(log_path) and fs.get_file_size(log_path) or 0
      if size >= config.max_file_size then
        rotate_log_files()
      end
    end
    
    -- Write to the log file
    local file = io.open(log_path, "a")
    if file then
      file:write(formatted .. "\n")
      file:close()
    else
      print("Warning: Failed to write to log file: " .. log_path)
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
  
  if options.log_dir ~= nil then
    config.log_dir = options.log_dir
  end
  
  if options.silent ~= nil then
    config.silent = options.silent
  end
  
  if options.max_file_size ~= nil then
    config.max_file_size = options.max_file_size
  end
  
  if options.max_log_files ~= nil then
    config.max_log_files = options.max_log_files
  end
  
  if options.date_pattern ~= nil then
    config.date_pattern = options.date_pattern
  end
  
  -- If log file is configured, ensure the directory exists
  if config.output_file then
    ensure_log_dir()
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

-- Configure module level based on debug/verbose settings from options object
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

-- Configure logging for a module using the global config system
-- This method directly accesses the core config module if available
function M.configure_from_config(module_name)
  -- First try to load the global config
  local log_level = M.LEVELS.INFO
  local config_obj
  
  -- Try to load config module and get config
  local success, core_config = pcall(require, "lib.core.config")
  if success and core_config then
    config_obj = core_config.get()
    
    -- Set log level based on global debug/verbose settings
    if config_obj and config_obj.debug then
      log_level = M.LEVELS.DEBUG
    elseif config_obj and config_obj.verbose then
      log_level = M.LEVELS.VERBOSE
    end
    
    -- Check for logging configuration
    if config_obj and config_obj.logging then
      -- Global logging configuration
      if config_obj.logging.level then
        config.global_level = config_obj.logging.level
      end
      
      -- Module-specific log levels
      if config_obj.logging.modules and config_obj.logging.modules[module_name] then
        log_level = config_obj.logging.modules[module_name]
      end
      
      -- Configure logging output options
      if config_obj.logging.output_file then
        config.output_file = config_obj.logging.output_file
      end
      
      if config_obj.logging.log_dir then
        config.log_dir = config_obj.logging.log_dir
      end
      
      if config_obj.logging.timestamps ~= nil then
        config.timestamps = config_obj.logging.timestamps
      end
      
      if config_obj.logging.use_colors ~= nil then
        config.use_colors = config_obj.logging.use_colors
      end
      
      -- Configure log rotation options
      if config_obj.logging.max_file_size then
        config.max_file_size = config_obj.logging.max_file_size
      end
      
      if config_obj.logging.max_log_files then
        config.max_log_files = config_obj.logging.max_log_files
      end
      
      if config_obj.logging.date_pattern then
        config.date_pattern = config_obj.logging.date_pattern
      end
      
      -- Ensure log directory exists if output file is configured
      if config.output_file then
        ensure_log_dir()
      end
    end
  end
  
  -- Apply the log level
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