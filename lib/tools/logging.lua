-- Centralized logging module for firmo
-- Provides structured, configurable logging system

---@class logging
---@field _VERSION string Module version
---@field DEBUG number Debug log level (most verbose)
---@field INFO number Info log level
---@field WARN number Warning log level
---@field ERROR number Error log level (least verbose)
---@field get_logger fun(name: string): logger_instance Create a named logger instance
---@field configure fun(options: {level?: number|string, file?: string, format?: string, console?: boolean, max_file_size?: number, include_source?: boolean, include_timestamp?: boolean, include_level?: boolean, include_colors?: boolean, colors?: table<string, string>}): logging Configure the logging system
---@field configure_from_config fun(config_key: string): logging Configure logging from central config
---@field set_level fun(level: number|string): logging Set global log level
---@field reset fun(): logging Reset logging to defaults
---@field disable fun(): logging Disable all logging
---@field enable fun(): logging Re-enable logging
---@field is_enabled fun(): boolean Check if logging is enabled
---@field get_level fun(): number Get current log level
---@field get_current_config fun(): table Get current logging configuration
---@field formats table<string, string> Built-in formatting patterns
---@field register_formatter fun(name: string, formatter: fun(log_entry: table): string): boolean Register a custom formatter
---@field log fun(level: number, message: string, context?: table, source?: string): boolean Log a message with level
---@field debug fun(message: string, context?: table, source?: string): boolean Log a debug message
---@field info fun(message: string, context?: table, source?: string): boolean Log an info message
---@field warn fun(message: string, context?: table, source?: string): boolean Log a warning message
---@field error fun(message: string, context?: table, source?: string): boolean Log an error message
---@field search_logs fun(pattern: string, options?: table): table Search logs for a pattern
---@field flush fun(): boolean Flush pending log messages

---@class logger_instance
---@field debug fun(message: string, context?: table): boolean Log a debug message
---@field info fun(message: string, context?: table): boolean Log an info message
---@field warn fun(message: string, context?: table): boolean Log a warning message
---@field error fun(message: string, context?: table): boolean Log an error message
---@field is_debug_enabled fun(): boolean Check if debug logging is enabled
---@field is_info_enabled fun(): boolean Check if info logging is enabled
---@field is_warn_enabled fun(): boolean Check if warning logging is enabled
---@field is_error_enabled fun(): boolean Check if error logging is enabled
---@field set_level fun(level: number|string): logger_instance Set log level for this logger instance
---@field get_level fun(): number Get log level for this logger instance
---@field get_name fun(): string Get logger name
---@field configure fun(options: table): logger_instance Configure this logger instance
---@field log fun(level: number, message: string, context?: table): boolean Log a message with level
---@field with_context fun(context: table): logger_instance Create a logger with predefined context

local M = {}

-- Try to import filesystem module (might not be available during first load)
local fs
--- Get the filesystem module (lazy loading)
---@return table The filesystem module
local function get_fs()
  if not fs then
    fs = require("lib.tools.filesystem")
  end
  return fs
end

-- Load optional components (lazy loading to avoid circular dependencies)
local search_module, export_module, formatter_integration_module

--- Get the search module for log searching functionality (lazy loading)
---@return table|nil The search module or nil if not available
local function get_search()
  if not search_module then
    local success, module = pcall(require, "lib.tools.logging.search")
    if success then
      search_module = module
    end
  end
  return search_module
end

--- Get the export module for log exporting functionality (lazy loading)
---@return table|nil The export module or nil if not available
local function get_export()
  if not export_module then
    local success, module = pcall(require, "lib.tools.logging.export")
    if success then
      export_module = module
    end
  end
  return export_module
end

--- Get the formatter integration module (lazy loading)
---@return table|nil The formatter integration module or nil if not available
local function get_formatter_integration()
  if not formatter_integration_module then
    local success, module = pcall(require, "lib.tools.logging.formatter_integration")
    if success then
      formatter_integration_module = module
    end
  end
  return formatter_integration_module
end

-- Log levels
M.LEVELS = {
  FATAL = 0,
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
  TRACE = 5,
  VERBOSE = 5  -- for backward compatibility
}

-- Default configuration
local config = {
  global_level = M.LEVELS.INFO,  -- Default global level
  module_levels = {},            -- Per-module log levels
  timestamps = true,             -- Enable/disable timestamps
  use_colors = true,             -- Enable/disable colors
  output_file = nil,             -- Log to file (nil = console only)
  log_dir = "logs",              -- Directory to store log files
  silent = false,                -- Suppress all output when true
  max_file_size = 50 * 1024,     -- 50KB default size limit per log file (small for testing)
  max_log_files = 5,             -- Number of rotated log files to keep
  date_pattern = "%Y-%m-%d",     -- Date pattern for log filenames
  format = "text",               -- Default log format: "text" or "json"
  json_file = nil,               -- Separate JSON structured log file
  module_filter = nil,           -- Filter logs to specific modules (nil = all)
  module_blacklist = {},         -- List of modules to exclude from logging
  buffer_size = 0,               -- Buffer size (0 = no buffering)
  buffer_flush_interval = 5,     -- Seconds between auto-flush (if buffering)
  standard_metadata = {},        -- Standard metadata fields to include in all logs
}

-- ANSI color codes
local COLORS = {
  RESET = "\27[0m",
  RED = "\27[31m",
  BRIGHT_RED = "\27[91m",  
  GREEN = "\27[32m",
  YELLOW = "\27[33m",
  BLUE = "\27[34m",
  MAGENTA = "\27[35m",
  CYAN = "\27[36m",
  WHITE = "\27[37m",
}

-- Color mapping for log levels
local LEVEL_COLORS = {
  [M.LEVELS.FATAL] = COLORS.BRIGHT_RED,
  [M.LEVELS.ERROR] = COLORS.RED,
  [M.LEVELS.WARN] = COLORS.YELLOW,
  [M.LEVELS.INFO] = COLORS.BLUE,
  [M.LEVELS.DEBUG] = COLORS.CYAN,
  [M.LEVELS.TRACE] = COLORS.MAGENTA,
  [M.LEVELS.VERBOSE] = COLORS.MAGENTA, -- For backward compatibility
}

-- Level names for display
local LEVEL_NAMES = {
  [M.LEVELS.FATAL] = "FATAL",
  [M.LEVELS.ERROR] = "ERROR",
  [M.LEVELS.WARN] = "WARN",
  [M.LEVELS.INFO] = "INFO",
  [M.LEVELS.DEBUG] = "DEBUG",
  [M.LEVELS.TRACE] = "TRACE",
  [M.LEVELS.VERBOSE] = "VERBOSE", -- For backward compatibility
}

-- Message buffer
local buffer = {
  entries = {},
  count = 0,
  last_flush_time = os.time(),
}

--- Get current timestamp formatted for logs
---@return string The formatted timestamp
local function get_timestamp()
  return os.date("%Y-%m-%d %H:%M:%S")
end

--- Check if logging is enabled for a specific level and module
---@param level number The log level to check
---@param module_name? string The module name to check
---@return boolean Whether logging is enabled for this level and module
local function is_enabled(level, module_name)
  if config.silent then
    return false
  end
  
  -- Ensure level is a number
  if type(level) ~= "number" then
    return false
  end
  
  -- Check module filter/blacklist
  if module_name then
    -- Skip if module is blacklisted
    for _, blacklisted in ipairs(config.module_blacklist) do
      if module_name == blacklisted then
        return false
      end
      
      -- Support wildcard patterns at the end
      if type(blacklisted) == "string" and blacklisted:match("%*$") then
        local prefix = blacklisted:gsub("%*$", "")
        if module_name:sub(1, #prefix) == prefix then
          return false
        end
      end
    end
    
    -- If a module filter is specified, only allow matching modules
    if config.module_filter then
      local match = false
      
      -- Handle array of filters
      if type(config.module_filter) == "table" then
        for _, filter in ipairs(config.module_filter) do
          -- Support exact matches
          if module_name == filter then
            match = true
            break
          end
          
          -- Support wildcard patterns at the end
          if type(filter) == "string" and filter:match("%*$") then
            local prefix = filter:gsub("%*$", "")
            if module_name:sub(1, #prefix) == prefix then
              match = true
              break
            end
          end
        end
      -- Handle string filter (single module or pattern)
      elseif type(config.module_filter) == "string" then
        -- Support exact match
        if module_name == config.module_filter then
          match = true
        end
        
        -- Support wildcard pattern at the end
        if config.module_filter:match("%*$") then
          local prefix = config.module_filter:gsub("%*$", "")
          if module_name:sub(1, #prefix) == prefix then
            match = true
          end
        end
      end
      
      if not match then
        return false
      end
    end
  end
  
  -- Check module-specific level
  if module_name and config.module_levels[module_name] then
    local module_level = config.module_levels[module_name]
    -- Ensure module_level is a number
    if type(module_level) == "number" then
      return level <= module_level
    end
  end
  
  -- Fall back to global level
  return level <= config.global_level
end

--- Format a log message for text output
---@param level number The log level
---@param module_name? string The module name
---@param message string The log message
---@param params? table Additional parameters to include in the log
---@return string The formatted log message
local function format_log(level, module_name, message, params)
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
  
  -- Add parameters as a formatted string if provided
  if params and type(params) == "table" and next(params) ~= nil then
    local param_parts = {}
    for k, v in pairs(params) do
      local val_str
      if type(v) == "table" then
        val_str = "{...}"  -- Simplify table display in text format
      else
        val_str = tostring(v)
      end
      table.insert(param_parts, k .. "=" .. val_str)
    end
    
    local param_str = table.concat(param_parts, ", ")
    if config.use_colors then
      param_str = COLORS.CYAN .. param_str .. COLORS.RESET
    end
    table.insert(parts, "(" .. param_str .. ")")
  end
  
  -- Join all parts with separators
  return table.concat(parts, " | ")
end

-- Ensure the log directory exists
--- Ensure the log directory exists
---@return nil
local function ensure_log_dir()
  local fs = get_fs()
  if config.log_dir then
    local success, err = fs.ensure_directory_exists(config.log_dir)
    if not success then
      print("Warning: Failed to create log directory: " .. (err or "unknown error"))
    end
  end
end

--- Get the full path to the log file
---@return string|nil The full path to the log file or nil if not configured
local function get_log_file_path()
  if not config.output_file then return nil end
  
  -- If output_file is an absolute path, use it directly
  if config.output_file:sub(1, 1) == "/" then
    return config.output_file
  end
  
  -- Otherwise, construct path within log directory
  return config.log_dir .. "/" .. config.output_file
end

--- Rotate log files if needed based on size
---@return nil
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

-- Format a value as JSON
local function json_encode_value(val)
  local json_type = type(val)
  if json_type == "string" then
    return '"' .. val:gsub('\\', '\\\\')
                  :gsub('"', '\\"')
                  :gsub('\n', '\\n')
                  :gsub('\r', '\\r')
                  :gsub('\t', '\\t')
                  :gsub('\b', '\\b')
                  :gsub('\f', '\\f') .. '"'
  elseif json_type == "number" then
    -- Handle NaN and infinity
    if val ~= val then
      return '"NaN"'
    elseif val == 1/0 then
      return '"Infinity"'
    elseif val == -1/0 then
      return '"-Infinity"'
    else
      return tostring(val)
    end
  elseif json_type == "boolean" then
    return tostring(val)
  elseif json_type == "table" then
    -- Check if array or object
    local is_array = true
    local n = 0
    for k, _ in pairs(val) do
      n = n + 1
      if type(k) ~= "number" or k ~= n then
        is_array = false
        break
      end
    end
    
    local result = is_array and "[" or "{"
    local first = true
    
    -- Avoid processing tables that are too large
    local count = 0
    local max_items = 100
    
    if is_array then
      for _, v in ipairs(val) do
        count = count + 1
        if count > max_items then
          result = result .. (first and "" or ",") .. '"..."'
          break
        end
        
        if not first then result = result .. "," end
        result = result .. json_encode_value(v)
        first = false
      end
      result = result .. "]"
    else
      for k, v in pairs(val) do
        count = count + 1
        if count > max_items then
          result = result .. (first and "" or ",") .. '"...":"..."'
          break
        end
        
        if not first then result = result .. "," end
        result = result .. '"' .. tostring(k):gsub('"', '\\"') .. '":' .. json_encode_value(v)
        first = false
      end
      result = result .. "}"
    end
    
    return result
  elseif json_type == "nil" then
    return "null"
  else
    -- Function, userdata, thread, etc.
    return '"' .. tostring(val):gsub('"', '\\"') .. '"'
  end
end

-- Format a log entry as JSON
local function format_json(level, module_name, message, params)
  local timestamp = os.date("%Y-%m-%dT%H:%M:%S")
  local level_name = LEVEL_NAMES[level] or "UNKNOWN"
  
  -- Start with standard fields
  local json_parts = {
    '"timestamp":"' .. timestamp .. '"',
    '"level":"' .. level_name .. '"',
    '"module":"' .. (module_name or ""):gsub('"', '\\"') .. '"',
    '"message":"' .. (message or ""):gsub('"', '\\"') .. '"'
  }
  
  -- Add standard metadata fields
  for key, value in pairs(config.standard_metadata) do
    table.insert(json_parts, '"' .. key .. '":' .. json_encode_value(value))
  end
  
  -- Add parameters if provided
  if params and type(params) == "table" then
    for key, value in pairs(params) do
      -- Skip reserved keys
      if key ~= "timestamp" and key ~= "level" and key ~= "module" and key ~= "message" then
        table.insert(json_parts, '"' .. key .. '":' .. json_encode_value(value))
      end
    end
  end
  
  return "{" .. table.concat(json_parts, ",") .. "}"
end

-- Get JSON log file path
local function get_json_log_file_path()
  if not config.json_file then return nil end
  
  -- If json_file is an absolute path, use it directly
  if config.json_file:sub(1, 1) == "/" then
    return config.json_file
  end
  
  -- Otherwise, construct path within log directory
  return config.log_dir .. "/" .. config.json_file
end

-- Rotate JSON log files if needed
local function rotate_json_log_files()
  local fs = get_fs()
  local log_path = get_json_log_file_path()
  if not log_path then return end
  
  -- Check if we need to rotate
  if not fs.file_exists(log_path) then return end
  
  local size = fs.get_file_size(log_path)
  if not size or size < config.max_file_size then return end
  
  -- Rotate files
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

-- Flush the buffer to disk
local function flush_buffer()
  if buffer.count == 0 then
    return
  end
  
  local fs = get_fs()
  
  -- Regular log file
  if config.output_file then
    local log_path = get_log_file_path()
    
    -- Build content string
    local content = ""
    for _, entry in ipairs(buffer.entries) do
      content = content .. entry.text .. "\n"
    end
    
    -- Append to log file
    local success, err = fs.append_file(log_path, content)
    if not success then
      print("Warning: Failed to write to log file: " .. (err or "unknown error"))
    end
  end
  
  -- JSON log file
  if config.json_file then
    local json_log_path = get_json_log_file_path()
    
    -- Build JSON content string
    local json_content = ""
    for _, entry in ipairs(buffer.entries) do
      json_content = json_content .. entry.json .. "\n"
    end
    
    -- Append to JSON log file
    local success, err = fs.append_file(json_log_path, json_content)
    if not success then
      print("Warning: Failed to write to JSON log file: " .. (err or "unknown error"))
    end
  end
  
  -- Reset buffer
  buffer.entries = {}
  buffer.count = 0
  buffer.last_flush_time = os.time()
end

-- Lazy load error_handler module
local _error_handler
local function get_error_handler()
  if not _error_handler then
    local success, module = pcall(require, "lib.tools.error_handler")
    if success then
      _error_handler = module
    end
  end
  return _error_handler
end

-- Check with error_handler if the current test expects errors
local function current_test_expects_errors()
  local error_handler = get_error_handler()
  
  -- If error_handler is loaded and has the function, call it
  if error_handler and error_handler.current_test_expects_errors then
    return error_handler.current_test_expects_errors()
  end
  
  -- Default to false if we couldn't determine
  return false
end

-- Set a global debug flag if the --debug argument is present
-- This is only done once when the module loads
if not _G._firmo_debug_mode then
  _G._firmo_debug_mode = false
  
  -- Detect debug mode from command line arguments
  if arg then
    for _, v in ipairs(arg) do
      if v == "--debug" then
        _G._firmo_debug_mode = true
        break
      end
    end
  end
end

-- The core logging function
local function log(level, module_name, message, params)
  -- For expected errors in tests, either filter or log expected errors
  if level <= M.LEVELS.WARN then
    if current_test_expects_errors() then
      -- Prefix message to indicate this is an expected error
      message = "[EXPECTED] " .. message
      
      -- Store the error in the global error repository for potential debugging
      local error_handler = get_error_handler()
      if error_handler then
        _G._firmo_test_expected_errors = _G._firmo_test_expected_errors or {}
        table.insert(_G._firmo_test_expected_errors, {
          level = level,
          module = module_name,
          message = message,
          params = params,
          timestamp = os.time()
        })
      end
      
      -- In debug mode (--debug flag), make all expected errors visible regardless of module
      if _G._firmo_debug_mode then
        -- Override the level check below for expected errors
        -- Force immediate logging - we do this by keeping the original level (ERROR or WARN)
        -- but setting a special flag that skips the is_enabled() check
        params = params or {}
        params._expected_debug_override = true
      else
        -- Downgrade to DEBUG level - which may or may not be visible depending on module config
        level = M.LEVELS.DEBUG
      end
    end
  end
  
  -- Check if this log should be shown (unless it's an expected error with debug override)
  local has_debug_override = params and params._expected_debug_override
  if not has_debug_override and not is_enabled(level, module_name) then
    return
  end
  
  -- Remove internal flag from params if it exists
  if params and params._expected_debug_override then
    params._expected_debug_override = nil
  end
  
  -- In silent mode, don't output anything
  if config.silent then
    return
  end
  
  -- Format as text for console and regular log file
  local formatted_text = format_log(level, module_name, message, params)
  
  -- Format as JSON for structured logging
  local formatted_json = format_json(level, module_name, message, params)
  
  -- Output to console 
  print(formatted_text)
  
  -- If we're buffering, add to buffer
  if config.buffer_size > 0 then
    -- Check if we need to auto-flush due to time
    if os.time() - buffer.last_flush_time >= config.buffer_flush_interval then
      flush_buffer()
    end
    
    -- Add to buffer
    table.insert(buffer.entries, { 
      text = formatted_text, 
      json = formatted_json,
      level = level,
      module = module_name,
      message = message,
      params = params
    })
    buffer.count = buffer.count + 1
    
    -- Flush if buffer is full
    if buffer.count >= config.buffer_size then
      flush_buffer()
    end
    
    return
  end
  
  -- Direct file output (no buffering)
  local fs = get_fs()
  
  -- Output to regular text log file if configured
  if config.output_file then
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
    
    -- Append to the log file
    local success, err = fs.append_file(log_path, formatted_text .. "\n")
    if not success then
      print("Warning: Failed to write to log file: " .. (err or "unknown error"))
    end
  end
  
  -- Output to JSON log file if configured
  if config.json_file then
    local json_log_path = get_json_log_file_path()
    
    -- Ensure log directory exists
    ensure_log_dir()
    
    -- Check if we need to rotate the JSON log file
    if config.max_file_size and config.max_file_size > 0 then
      local size = fs.file_exists(json_log_path) and fs.get_file_size(json_log_path) or 0
      if size >= config.max_file_size then
        rotate_json_log_files()
      end
    end
    
    -- Append to the JSON log file
    local success, err = fs.append_file(json_log_path, formatted_json .. "\n")
    if not success then
      print("Warning: Failed to write to JSON log file: " .. (err or "unknown error"))
    end
  end
end

--- Configure the logging module
---@param options? table Options for configuring the logging module
---@return table The logging module for chaining
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
  
  -- JSON format options
  if options.format ~= nil then
    config.format = options.format
  end
  
  if options.json_file ~= nil then
    config.json_file = options.json_file
  end
  
  -- Module filtering options
  if options.module_filter ~= nil then
    config.module_filter = options.module_filter
  end
  
  if options.module_blacklist ~= nil then
    config.module_blacklist = options.module_blacklist
  end
  
  -- Buffering options
  if options.buffer_size ~= nil then
    config.buffer_size = options.buffer_size
    -- Reset buffer when size changes
    buffer.entries = {}
    buffer.count = 0
    buffer.last_flush_time = os.time()
  end
  
  if options.buffer_flush_interval ~= nil then
    config.buffer_flush_interval = options.buffer_flush_interval
  end
  
  -- Standard metadata
  if options.standard_metadata ~= nil then
    config.standard_metadata = options.standard_metadata
  end
  
  -- If log file is configured, ensure the directory exists
  if config.output_file or config.json_file then
    ensure_log_dir()
  end
  
  return M
end

-- Create a logger instance for a specific module
function M.get_logger(module_name)
  local logger = {}
  
  -- Create logging methods for each level
  logger.fatal = function(message, params)
    log(M.LEVELS.FATAL, module_name, message, params)
  end
  
  logger.error = function(message, params)
    log(M.LEVELS.ERROR, module_name, message, params)
  end
  
  logger.warn = function(message, params)
    log(M.LEVELS.WARN, module_name, message, params)
  end
  
  logger.info = function(message, params)
    log(M.LEVELS.INFO, module_name, message, params)
  end
  
  logger.debug = function(message, params)
    log(M.LEVELS.DEBUG, module_name, message, params)
  end
  
  logger.trace = function(message, params)
    log(M.LEVELS.TRACE, module_name, message, params)
  end
  
  -- For backward compatibility
  logger.verbose = function(message, params)
    log(M.LEVELS.VERBOSE, module_name, message, params)
  end
  
  -- Allow direct log level access
  logger.log = function(level, message, params)
    log(level, module_name, message, params)
  end
  
  -- Check if a specific level would be logged
  logger.would_log = function(level)
    if type(level) == "string" then
      local level_name = level:upper()
      for k, v in pairs(M.LEVELS) do
        if k == level_name then
          return is_enabled(v, module_name)
        end
      end
      return false
    elseif type(level) == "number" then
      return is_enabled(level, module_name)
    else
      return false
    end
  end
  
  -- Convenience methods for checking if specific levels are enabled
  logger.is_debug_enabled = function()
    return is_enabled(M.LEVELS.DEBUG, module_name)
  end
  
  logger.is_trace_enabled = function()
    return is_enabled(M.LEVELS.TRACE, module_name)
  end
  
  -- For backward compatibility
  logger.is_verbose_enabled = function()
    return is_enabled(M.LEVELS.VERBOSE, module_name)
  end
  
  -- Get current level
  logger.get_level = function()
    if config.module_levels[module_name] then
      return config.module_levels[module_name]
    end
    return config.global_level
  end
  
  return logger
end

-- Direct module-level logging
--- Log a fatal level message
---@param message string The message to log
---@param params? table Additional parameters to log
---@return nil
function M.fatal(message, params)
  log(M.LEVELS.FATAL, nil, message, params)
end

--- Log an error level message
---@param message string The message to log
---@param params? table Additional parameters to log
---@return nil
function M.error(message, params)
  log(M.LEVELS.ERROR, nil, message, params)
end

--- Log a warning level message
---@param message string The message to log
---@param params? table Additional parameters to log
---@return nil
function M.warn(message, params)
  log(M.LEVELS.WARN, nil, message, params)
end

--- Log an info level message
---@param message string The message to log
---@param params? table Additional parameters to log
---@return nil
function M.info(message, params)
  log(M.LEVELS.INFO, nil, message, params)
end

--- Log a debug level message
---@param message string The message to log
---@param params? table Additional parameters to log
---@return nil
function M.debug(message, params)
  log(M.LEVELS.DEBUG, nil, message, params)
end

--- Log a trace level message
---@param message string The message to log
---@param params? table Additional parameters to log
---@return nil
function M.trace(message, params)
  log(M.LEVELS.TRACE, nil, message, params)
end

--- Log a verbose level message (for backward compatibility)
---@param message string The message to log
---@param params? table Additional parameters to log
---@return nil
function M.verbose(message, params)
  log(M.LEVELS.VERBOSE, nil, message, params)
end

--- Flush buffered logs to output
---@return table The logging module for chaining
function M.flush()
  flush_buffer()
  return M
end

--- Check if a log at the specified level would be output
---@param level string|number The log level to check
---@param module_name? string The module name to check
---@return boolean Whether logging is enabled for this level and module
function M.would_log(level, module_name)
  if type(level) == "string" then
    local level_name = level:upper()
    for k, v in pairs(M.LEVELS) do
      if k == level_name then
        return is_enabled(v, module_name)
      end
    end
    return false
  elseif type(level) == "number" then
    return is_enabled(level, module_name)
  else
    return false
  end
end

--- Temporarily change log level for a module while executing a function
---@param module_name string The module name to change the level for
---@param level string|number The log level to use temporarily
---@param func function The function to execute with the temporary log level
---@return any The result from the executed function
function M.with_level(module_name, level, func)
  local original_level = config.module_levels[module_name]
  
  -- Set temporary level
  if type(level) == "string" then
    local level_name = level:upper()
    for k, v in pairs(M.LEVELS) do
      if k == level_name then
        M.set_module_level(module_name, v)
        break
      end
    end
  else
    M.set_module_level(module_name, level)
  end
  
  -- Run the function
  local success, result = pcall(func)
  
  -- Restore original level
  if original_level then
    M.set_module_level(module_name, original_level)
  else
    config.module_levels[module_name] = nil
  end
  
  -- Handle errors
  if not success then
    error(result)
  end
  
  return result
end

--- Set the log level for a specific module
---@param module_name string The name of the module
---@param level number The log level to set for the module
---@return table The logging module for chaining
function M.set_module_level(module_name, level)
  config.module_levels[module_name] = level
  return M
end

--- Set the global log level
---@param level number The log level to set globally
---@return table The logging module for chaining
function M.set_level(level)
  config.global_level = level
  return M
end

--- Configure module log level based on debug/verbose settings from options object
---@param module_name string The module name to configure
---@param options table The options object with debug/verbose flags
---@return number The configured log level
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

--- Configure logging for a module using the global config system
---@param module_name string The module name to configure
---@return number The configured log level
function M.configure_from_config(module_name)
  -- First try to load the global config
  local log_level = M.LEVELS.INFO
  local config_obj
  
  -- Try to load central_config module and get config
  local success, central_config = pcall(require, "lib.core.central_config")
  if success and central_config then
    config_obj = central_config.get()
    
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
      
      -- JSON format options
      if config_obj.logging.format then
        config.format = config_obj.logging.format
      end
      
      if config_obj.logging.json_file then
        config.json_file = config_obj.logging.json_file
      end
      
      -- Module filtering options
      if config_obj.logging.module_filter then
        config.module_filter = config_obj.logging.module_filter
      end
      
      if config_obj.logging.module_blacklist then
        config.module_blacklist = config_obj.logging.module_blacklist
      end
      
      -- Ensure log directory exists if output file is configured
      if config.output_file or config.json_file then
        ensure_log_dir()
      end
    end
  end
  
  -- Apply the log level
  M.set_module_level(module_name, log_level)
  return log_level
end

--- Add a module pattern to the module filter
---@param module_pattern string The module pattern to add to the filter
---@return table The logging module for chaining
function M.filter_module(module_pattern)
  if not config.module_filter then
    config.module_filter = {}
  end
  
  if type(config.module_filter) == "string" then
    -- Convert to table if currently a string
    config.module_filter = {config.module_filter}
  end
  
  -- Add to filter if not already present
  for _, pattern in ipairs(config.module_filter) do
    if pattern == module_pattern then
      return M -- Already filtered
    end
  end
  
  table.insert(config.module_filter, module_pattern)
  return M
end

--- Clear all module filters
---@return table The logging module for chaining
function M.clear_module_filters()
  config.module_filter = nil
  return M
end

--- Add a module pattern to the blacklist (these modules won't log)
---@param module_pattern string The module pattern to blacklist
---@return table The logging module for chaining
function M.blacklist_module(module_pattern)
  -- Make sure module_blacklist is initialized
  if not config.module_blacklist then
    config.module_blacklist = {}
  end
  
  -- Add to blacklist if not already present
  for _, pattern in ipairs(config.module_blacklist) do
    if pattern == module_pattern then
      return M -- Already blacklisted
    end
  end
  
  table.insert(config.module_blacklist, module_pattern)
  return M
end

--- Remove a module pattern from the blacklist
---@param module_pattern string The module pattern to remove from the blacklist
---@return table The logging module for chaining
function M.remove_from_blacklist(module_pattern)
  if config.module_blacklist then
    for i, pattern in ipairs(config.module_blacklist) do
      if pattern == module_pattern then
        table.remove(config.module_blacklist, i)
        return M
      end
    end
  end
  return M
end

--- Clear all module blacklist entries
---@return table The logging module for chaining
function M.clear_blacklist()
  config.module_blacklist = {}
  return M
end

--- Get current logging configuration (useful for debugging)
---@return table A copy of the current configuration
function M.get_config()
  -- Return a copy to prevent modification
  local copy = {}
  for k, v in pairs(config) do
    copy[k] = v
  end
  return copy
end

--- Log a debug message (compatibility with existing code)
---@param message string The message to log
---@param module_name? string The module name
---@return nil
function M.log_debug(message, module_name)
  log(M.LEVELS.DEBUG, module_name, message)
end

--- Log a verbose message (compatibility with existing code)
---@param message string The message to log
---@param module_name? string The module name
---@return nil
function M.log_verbose(message, module_name)
  log(M.LEVELS.VERBOSE, module_name, message)
end

--- Get the log search module for searching logs
---@return table The log search module
function M.search()
  local search = get_search()
  if not search then
    error("Log search module not available")
  end
  return search
end

--- Get the log export module for exporting logs
---@return table The log export module
function M.export()
  local export = get_export()
  if not export then
    error("Log export module not available")
  end
  return export
end

--- Get the formatter integration module
---@return table The formatter integration module
function M.formatter_integration()
  local formatter_integration = get_formatter_integration()
  if not formatter_integration then
    error("Formatter integration module not available")
  end
  return formatter_integration
end

--- Create a buffered logger for high-volume logging
---@param module_name string The module name for the logger
---@param options? table Options for the buffered logger
---@return table The buffered logger instance
function M.create_buffered_logger(module_name, options)
  options = options or {}
  
  -- Apply buffering configuration
  local buffer_size = options.buffer_size or 100
  local flush_interval = options.flush_interval or 5 -- seconds
  
  -- Configure a buffered logger
  local buffered_config = {
    buffer_size = buffer_size,
    buffer_flush_interval = flush_interval
  }
  
  -- If output_file specified, use it
  if options.output_file then
    buffered_config.output_file = options.output_file
  end
  
  -- Apply the configuration
  M.configure(buffered_config)
  
  -- Create a logger with the specified module name
  local logger = M.get_logger(module_name)
  
  -- Add flush method to this logger instance
  logger.flush = function()
    M.flush()
    return logger
  end
  
  -- Add auto-flush on shutdown
  local mt = getmetatable(logger) or {}
  mt.__gc = function()
    logger.flush()
  end
  setmetatable(logger, mt)
  
  return logger
end

return M
