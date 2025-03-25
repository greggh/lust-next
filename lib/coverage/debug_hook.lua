---@class CoverageDebugHook
---@field start fun(coverage_data: table): boolean Starts the debug hook
---@field stop fun(): boolean Stops the debug hook
---@field is_running fun(): boolean Checks if the debug hook is running
---@field get_coverage_data fun(): table|nil Returns the current coverage data
---@field fix_block_relationships fun(): {files_processed: number, relationships_fixed: number, pending_relationships_resolved: number} Fixes inconsistent parent-child relationships in block tracking
---@field set_auto_fix_block_relationships fun(enabled: boolean): boolean Sets whether to automatically fix block relationships on stop
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local data_structure = require("lib.coverage.data_structure")
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
local auto_fix_block_relationships = true -- Enabled by default
local last_executed_line = {} -- Track the most recent line executed in each file
local original_error = error -- Store the original error function for our error tracking

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
  
  -- Always track test files - this makes debugging coverage easier
  if normalized_path:match("/tests/") and normalized_path:match("_test%.lua$") then
    return true
  end
  
  -- Get configuration safely
  local config = get_safe_config()
  
  -- Check if the file should be tracked based on configuration
  if config.coverage then
    -- If track_all_executed is enabled, check file extension
    if config.coverage.track_all_executed and normalized_path:match("%.lua$") then
      -- Check exclude patterns first
      local should_exclude = false
      if type(config.coverage.exclude) == "table" then
        for _, pattern in ipairs(config.coverage.exclude) do
          -- Convert glob patterns to Lua patterns
          local lua_pattern = pattern:gsub("%*%*", ".*"):gsub("%*", "[^/]*"):gsub("%-", "%%-"):gsub("%(", "%%("):gsub("%)", "%%)")
          if normalized_path:match(lua_pattern) then
            should_exclude = true
            break
          end
        end
      end
      
      -- If excluded, don't track
      if should_exclude then
        return false
      end
      
      -- Not excluded and track_all_executed is enabled, so include
      return true
    end
    
    -- Otherwise check include/exclude patterns if available
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
    
    -- Track the most recent line for each file to help with error line tracking
    last_executed_line[file_path] = line
    
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
    
    -- Fix block relationships if auto-fix is enabled
    if auto_fix_block_relationships then
      local stats = M.fix_block_relationships()
      logger.debug("Auto-fixed block relationships", {
        files_processed = stats.files_processed,
        relationships_fixed = stats.relationships_fixed,
        pending_relationships_resolved = stats.pending_relationships_resolved
      })
    end
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

--- Sets whether to automatically fix block relationships when stopping coverage
---@param enabled boolean Whether to enable automatic fixing
---@return boolean success Always returns true
function M.set_auto_fix_block_relationships(enabled)
  auto_fix_block_relationships = enabled
  logger.debug("Auto-fix block relationships " .. (enabled and "enabled" or "disabled"))
  return true
end

--- Fixes inconsistent parent-child relationships in the block tracking data
--- This ensures that all parent-child references are bi-directional and consistent
---@return {files_processed: number, relationships_fixed: number, pending_relationships_resolved: number} Statistics about the fix operation
function M.fix_block_relationships()
  -- Initialize statistics
  local stats = {
    files_processed = 0,
    relationships_fixed = 0,
    pending_relationships_resolved = 0
  }
  
  -- Check if coverage data exists
  if not coverage_data or not coverage_data.files then
    logger.debug("No coverage data available for block relationship fixing")
    return stats
  end
  
  -- Process each file
  for file_path, file_data in pairs(coverage_data.files) do
    stats.files_processed = stats.files_processed + 1
    
    -- Check if the file has block data
    if not file_data.logical_chunks then
      goto continue
    end
    
    -- Process pending relationships first
    if file_data._pending_child_blocks then
      for parent_id, child_blocks in pairs(file_data._pending_child_blocks) do
        -- Check if the parent block now exists
        if file_data.logical_chunks[parent_id] then
          -- Parent exists, add all children
          file_data.logical_chunks[parent_id].children = file_data.logical_chunks[parent_id].children or {}
          
          for _, child_id in ipairs(child_blocks) do
            -- Check if child exists
            if file_data.logical_chunks[child_id] then
              -- Update child's parent_id
              file_data.logical_chunks[child_id].parent_id = parent_id
              
              -- Add to parent's children array if not already there
              local already_child = false
              for _, existing_child_id in ipairs(file_data.logical_chunks[parent_id].children) do
                if existing_child_id == child_id then
                  already_child = true
                  break
                end
              end
              
              if not already_child then
                table.insert(file_data.logical_chunks[parent_id].children, child_id)
                stats.pending_relationships_resolved = stats.pending_relationships_resolved + 1
              end
            end
          end
        end
      end
      
      -- Clear pending relationships
      file_data._pending_child_blocks = {}
    end
    
    -- Build a map of blocks by ID for efficient access
    local block_map = {}
    local orphaned_blocks = {}
    
    -- Initialize block map and identify orphaned blocks
    for block_id, block_data in pairs(file_data.logical_chunks) do
      block_map[block_id] = block_data
      
      -- Initialize children array if it doesn't exist
      block_data.children = block_data.children or {}
      
      -- Check for orphaned blocks (has parent_id but parent doesn't exist)
      if block_data.parent_id and block_data.parent_id ~= "root" and not file_data.logical_chunks[block_data.parent_id] then
        table.insert(orphaned_blocks, block_id)
      end
    end
    
    -- Process all block relationships to ensure consistency
    for block_id, block_data in pairs(file_data.logical_chunks) do
      -- Skip the root block
      if block_id == "root" then goto next_block end
      
      -- If block has a parent, ensure parent has this block as a child
      if block_data.parent_id and block_data.parent_id ~= "root" then
        local parent = file_data.logical_chunks[block_data.parent_id]
        
        if parent then
          -- Ensure parent has children array
          parent.children = parent.children or {}
          
          -- Check if block is already in parent's children
          local already_child = false
          for _, child_id in ipairs(parent.children) do
            if child_id == block_id then
              already_child = true
              break
            end
          end
          
          -- Add to parent's children if not already there
          if not already_child then
            table.insert(parent.children, block_id)
            stats.relationships_fixed = stats.relationships_fixed + 1
          end
        end
      end
      
      -- If block has children, ensure each child has this block as parent
      if block_data.children then
        for _, child_id in ipairs(block_data.children) do
          local child = file_data.logical_chunks[child_id]
          
          if child and child.parent_id ~= block_id then
            child.parent_id = block_id
            stats.relationships_fixed = stats.relationships_fixed + 1
          end
        end
      end
      
      ::next_block::
    end
    
    -- Handle orphaned blocks - connect them to the root
    for _, block_id in ipairs(orphaned_blocks) do
      local block = file_data.logical_chunks[block_id]
      if block then
        -- Set parent to root
        block.parent_id = "root"
        stats.relationships_fixed = stats.relationships_fixed + 1
        
        -- Add to root's children
        if not file_data.logical_chunks["root"] then
          file_data.logical_chunks["root"] = {
            id = "root",
            type = "root",
            children = {}
          }
        end
        
        -- Ensure root has children array
        file_data.logical_chunks["root"].children = file_data.logical_chunks["root"].children or {}
        
        -- Add orphaned block to root's children
        table.insert(file_data.logical_chunks["root"].children, block_id)
      end
    end
    
    ::continue::
  end
  
  -- Log results
  if stats.relationships_fixed > 0 or stats.pending_relationships_resolved > 0 then
    logger.info("Block relationships fixed", {
      files_processed = stats.files_processed,
      relationships_fixed = stats.relationships_fixed,
      pending_relationships_resolved = stats.pending_relationships_resolved
    })
  else
    logger.debug("No block relationships needed fixing", {
      files_processed = stats.files_processed
    })
  end
  
  return stats
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

--- Track error lines by overriding the standard error function
--- This enables us to mark lines with error() calls as covered during tests
local function setup_error_line_tracking()
  -- Only setup if we haven't already done so
  if _G.error ~= original_error then
    return
  end
  
  -- Override the global error function to track error lines
  _G.error = function(message, level)
    -- Default level is 1 (caller of error)
    level = level or 1
    
    -- Get information about the caller
    local info = debug.getinfo(level + 1, "Sl") -- +1 to skip this function
    if info and info.source and info.currentline and hook_active then
      -- Extract the file path (remove leading '@')
      local file_path = info.source:sub(2)
      
      -- Check if we should track this file
      if should_track_file(file_path) then
        -- Ensure file is initialized in coverage data
        if ensure_file_tracked(file_path) then
          -- Mark the error line as executed
          logger.debug("Marking error line as executed", {
            file_path = file_path,
            line = info.currentline
          })
          data_structure.mark_line_executed(coverage_data, file_path, info.currentline)
        end
      end
    end
    
    -- Call the original error function to continue normal error behavior
    return original_error(message, level + 1)
  end
  
  logger.debug("Error line tracking enabled")
end

--- Enhance the start function to initialize error line tracking
local original_start = M.start
M.start = function(initial_data)
  local result = original_start(initial_data)
  if result then
    -- Setup error line tracking
    setup_error_line_tracking()
  end
  return result
end

--- Remove our error line tracking when stopping coverage
local original_stop = M.stop
M.stop = function()
  -- Restore the original error function
  if _G.error ~= original_error then
    _G.error = original_error
    logger.debug("Restored original error function")
  end
  
  -- Call the original stop function
  return original_stop()
end

return M