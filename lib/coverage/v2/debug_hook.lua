---@class CoverageDebugHook
---@field start fun(coverage_data: table): boolean Starts the debug hook
---@field stop fun(): boolean Stops the debug hook
---@field is_running fun(): boolean Checks if the debug hook is running
---@field get_coverage_data fun(): table|nil Returns the current coverage data
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local data_structure = require("lib.coverage.v2.data_structure")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")

-- Version
M._VERSION = "0.1.0"

-- Module state
local hook_active = false
local original_hook = nil
local coverage_data = nil
local file_cache = {}
local tracked_files_log = nil

-- Default configuration used when central_config is not available
local default_config = {
  coverage = {
    track_all_executed = true,
    include = {"**/*.lua"},
    exclude = {}
  }
}

-- Configuration cache to avoid repetitive warnings
local config_cache = nil

--- Gets configuration settings safely, falling back to defaults if needed
---@return table config The configuration table
local function get_safe_config()
  -- Return cached config if available
  if config_cache then
    return config_cache
  end
  
  -- Try to get configuration from central_config
  local success, result = pcall(function() 
    if central_config and type(central_config.get_config) == "function" then
      return central_config.get_config() 
    end
    return nil
  end)
  
  -- If successful and returned a table, use it
  if success and type(result) == "table" then
    config_cache = result
    return result
  end
  
  -- Log warning once (not cached, so will only log once)
  if not config_cache then
    logger.warn("Failed to load central configuration, using default settings", {
      error = success and "No configuration returned" or tostring(result)
    })
    -- Cache the default to avoid repeated warnings
    config_cache = default_config
  end
  
  return default_config
end

--- Determines if a file should be tracked for coverage
---@param file_path string The file path to check
---@return boolean should_track Whether the file should be tracked
local function should_track_file(file_path)
  if not file_path then
    return false
  end
  
  -- Normalize the path
  local normalized_path = data_structure.normalize_path(file_path)
  
  -- Get configuration safely
  local config = get_safe_config()
  
  -- For basic tests, accept most Lua files
  if normalized_path:match("%.lua$") then
    -- Always exclude vendor and framework files
    if normalized_path:match("/lib/tools/vendor/") or
       normalized_path:match("/lib/tools/test_helper%.lua$") or
       normalized_path:match("/test%.lua$") or
       normalized_path:match("/scripts/runner%.lua$") then
      return false
    end
    
    -- If track_all_executed is enabled, accept all other Lua files
    if config.coverage and config.coverage.track_all_executed then
      return true
    end
    
    -- Otherwise check include/exclude patterns if available
    if config.coverage then
      -- Check include patterns
      local should_include = false
      if type(config.coverage.include) == "table" then
        for _, pattern in ipairs(config.coverage.include) do
          -- Convert glob patterns to Lua patterns
          local lua_pattern = pattern:gsub("%*%*", ".*"):gsub("%*", "[^/]*"):gsub("%-", "%%-"):gsub("%(", "%%("):gsub("%)", "%%)")
          if normalized_path:match(lua_pattern) then
            should_include = true
            break
          end
        end
      end
      
      -- If not included by any pattern, don't track
      if not should_include then
        return false
      end
      
      -- Check exclude patterns
      if type(config.coverage.exclude) == "table" then
        for _, pattern in ipairs(config.coverage.exclude) do
          -- Convert glob patterns to Lua patterns
          local lua_pattern = pattern:gsub("%*%*", ".*"):gsub("%*", "[^/]*"):gsub("%-", "%%-"):gsub("%(", "%%("):gsub("%)", "%%)")
          if normalized_path:match(lua_pattern) then
            return false
          end
        end
      end
      
      -- If we've reached here, the file should be tracked
      return should_include
    end
  end
  
  -- By default, don't track
  return false
end

--- Gets the source code for a file, caching the result
---@param file_path string The file path
---@return string|nil source_code The source code content or nil if not found
---@return table|nil error Error information if failed
local function get_file_source(file_path)
  -- Check cache first
  if file_cache[file_path] then
    return file_cache[file_path]
  end
  
  -- Read the file content
  local content, err = error_handler.safe_io_operation(
    function() return fs.read_file(file_path) end,
    file_path,
    {operation = "read_source_file"}
  )
  
  if not content then
    logger.warn("Failed to read source file", {
      file_path = file_path,
      error = error_handler.format_error(err)
    })
    return nil, err
  end
  
  -- Cache the content
  file_cache[file_path] = content
  
  return content
end

--- Initializes coverage for a file if not already tracked
---@param file_path string The file path
---@return boolean success Whether initialization succeeded
local function ensure_file_tracked(file_path)
  if not file_path or not should_track_file(file_path) then
    return false
  end
  
  -- Normalize the path
  local normalized_path = data_structure.normalize_path(file_path)
  
  -- Check if file is already initialized
  if data_structure.get_file_data(coverage_data, normalized_path) then
    return true
  end
  
  -- Get the source code
  local source_code, err = get_file_source(file_path)
  if not source_code then
    logger.warn("Failed to initialize coverage for file", {
      file_path = normalized_path,
      error = err and error_handler.format_error(err) or "Unknown error"
    })
    return false
  end
  
  -- Initialize coverage data for the file
  data_structure.initialize_file(coverage_data, normalized_path, source_code)
  
  logger.debug("Initialized coverage tracking for file", {
    file_path = normalized_path
  })
  
  return true
end

-- Map to track active functions 
local active_functions = {}

--- The debug hook function that tracks line executions and function calls
---@param event string The debug event (e.g., "line", "call", "return")
---@param line number The line number for line events
local function debug_hook_function(event, line)
  -- Call the original hook if it exists
  if original_hook then
    original_hook(event, line)
  end
  
  -- Get information about the current execution
  local info = debug.getinfo(2, "Sln") -- 'S' for source, 'l' for line info, 'n' for name
  if not info or not info.source then
    return
  end
  
  -- Skip files loaded from memory (no actual file path)
  if info.source:sub(1, 1) ~= "@" then
    return
  end
  
  -- Extract the file path
  local file_path = info.source:sub(2)  -- Remove the leading "@"
  
  -- Record file paths for debugging
  if event == "line" and not tracked_files_log then
    local debug_file = io.open("coverage_debug.log", "w")
    if debug_file then
      debug_file:write("Debug Hook Tracking Information\n")
      debug_file:write("==============================\n\n")
      debug_file:close()
      tracked_files_log = {}
    end
  end
  
  -- Track unique files for debugging
  if event == "line" and tracked_files_log and not tracked_files_log[file_path] then
    tracked_files_log[file_path] = true
    local track_status = should_track_file(file_path) and "YES" or "NO"
    local debug_file = io.open("coverage_debug.log", "a")
    if debug_file then
      debug_file:write(string.format("File: %s\n", file_path))
      debug_file:write(string.format("Should track: %s\n", track_status))
      debug_file:write(string.format("Current event: %s\n", event))
      debug_file:write(string.format("Current line: %d\n\n", line))
      debug_file:close()
    end
  end
  
  -- Skip files that shouldn't be tracked
  if not should_track_file(file_path) then
    return
  end
  
  -- Ensure file is initialized in coverage data
  if not ensure_file_tracked(file_path) then
    return
  end
  
  -- Process based on event type
  if event == "line" then
    -- Debug line execution tracking
    local debug_file = io.open("coverage_execution.log", "a")
    if debug_file then
      debug_file:write(string.format("EXECUTING: %s:%d\n", file_path, line))
      debug_file:close()
    end
    
    -- Mark the current line as executed
    data_structure.mark_line_executed(coverage_data, file_path, line)
    
  elseif event == "call" then
    -- Extract function information
    local name = info.name or "anonymous"
    local func_type = data_structure.FUNCTION_TYPES.ANONYMOUS
    
    -- Determine function type
    if info.name then
      if info.namewhat == "global" then
        func_type = data_structure.FUNCTION_TYPES.GLOBAL
      elseif info.namewhat == "local" then
        func_type = data_structure.FUNCTION_TYPES.LOCAL
      elseif info.namewhat == "method" then
        func_type = data_structure.FUNCTION_TYPES.METHOD
      else
        func_type = data_structure.FUNCTION_TYPES.CLOSURE
      end
    end
    
    -- Create a function ID for tracking
    local start_line = info.linedefined
    local end_line = info.lastlinedefined
    local func_id = name .. ":" .. start_line .. "-" .. end_line
    
    -- Register the function if not already registered
    data_structure.register_function(
      coverage_data,
      file_path,
      name,
      start_line,
      end_line,
      func_type
    )
    
    -- Mark function as executed and track it as active
    data_structure.mark_function_executed(coverage_data, file_path, func_id)
    
    -- Remember this function is active at this level
    local level = 2  -- The function that was called (skipping the debug hook itself)
    active_functions[level] = {
      file_path = file_path,
      func_id = func_id
    }
    
  elseif event == "return" then
    -- Function is returning, remove from active functions
    local level = 2  -- The function that's returning
    active_functions[level] = nil
  end
end

--- Starts the debug hook for coverage tracking
---@param initial_data table Optional existing coverage data to continue from
---@return boolean success Whether the hook was successfully started
function M.start(initial_data)
  -- Check if hook is already running
  if hook_active then
    logger.warn("Debug hook is already running")
    return false
  end
  
  -- Initialize coverage data
  if initial_data and type(initial_data) == "table" then
    coverage_data = initial_data
  else
    coverage_data = data_structure.create()
  end
  
  -- Store the original hook if any
  original_hook = debug.gethook()
  
  -- Set our debug hook to track lines, calls, and returns
  debug.sethook(debug_hook_function, "lcr")
  
  -- Mark as active
  hook_active = true
  
  logger.info("Started coverage debug hook")
  return true
end

--- Stops the debug hook and returns the collected data
---@return boolean success Whether the hook was successfully stopped
function M.stop()
  -- Check if hook is running
  if not hook_active then
    logger.warn("Debug hook is not running")
    return false
  end
  
  -- Restore the original hook if any
  if original_hook then
    debug.sethook(original_hook, "clr") -- Ensure we pass the mode
  else
    debug.sethook() -- This clears the hook
  end
  
  -- Mark as inactive first to prevent hook from firing during validation
  hook_active = false
  
  -- Calculate coverage summary using the central data structure
  if coverage_data then
    -- Let the data_structure module handle all calculations
    -- Just use calculate_summary, which will ensure consistency
    data_structure.calculate_summary(coverage_data)
  end
  
  logger.info("Stopped coverage debug hook")
  return true
end

--- Checks if the debug hook is currently running
---@return boolean is_running Whether the hook is running
function M.is_running()
  return hook_active
end

--- Returns the current coverage data
---@return table|nil coverage_data The current coverage data or nil if not available
function M.get_coverage_data()
  if not coverage_data then
    return nil
  end
  
  -- Recalculate summary to ensure it's up to date
  data_structure.calculate_summary(coverage_data)
  
  return coverage_data
end

--- Resets the coverage data to a clean state
---@return boolean success Whether the reset was successful
function M.reset()
  if hook_active then
    logger.warn("Cannot reset coverage data while debug hook is running")
    return false
  end
  
  coverage_data = data_structure.create()
  file_cache = {}
  
  logger.info("Reset coverage data")
  return true
end

return M