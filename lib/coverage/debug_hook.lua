---@class coverage.debug_hook
---@field debug_hook fun(event: string, line: number) Debug hook function for Lua's debug.sethook
---@field should_track_file fun(file_path: string): boolean Determine if a file should be tracked
---@field set_config fun(new_config: {exclude?: string[], include?: string[], source_dirs?: string[], should_track_example_files?: boolean}): boolean Set configuration options
---@field track_line fun(file_path: string, line_num: number, options?: {is_executable?: boolean, is_covered?: boolean, operation?: string}): boolean|nil, table? Track a line execution
---@field set_line_executed fun(file_path: string, line_num: number, is_executed: boolean): boolean|nil, table? Mark a line as executed
---@field set_line_covered fun(file_path: string, line_num: number, is_covered: boolean): boolean|nil, table? Mark a line as covered
---@field set_line_executable fun(file_path: string, line_num: number, is_executable: boolean): boolean|nil, table? Mark a line as executable
---@field mark_line_covered fun(file_path: string, line_num: number): boolean|nil, table? Mark a line as covered (used by assertions)
---@field was_line_executed fun(file_path: string, line_num: number): boolean Check if a line was executed
---@field was_line_covered fun(file_path: string, line_num: number): boolean Check if a line was covered
---@field track_function fun(file_path: string, line_num: number, func_name: string): boolean|nil, table? Track a function execution
---@field track_block fun(file_path: string, line_num: number, block_id: string, block_type: string): boolean|nil, table? Track a block execution
---@field initialize_file fun(file_path: string, options?: table): table|nil, table? Initialize file tracking
---@field activate_file fun(file_path: string): boolean|nil, table? Mark a file as active for reporting
---@field has_file fun(file_path: string): boolean Check if a file is being tracked
---@field get_file_data fun(file_path: string): table|nil, table? Get data for a tracked file
---@field get_coverage_data fun(): {files: table, lines: table, executed_lines: table, covered_lines: table, functions: {all: table, executed: table, covered: table}, blocks: {all: table, executed: table, covered: table}, conditions: {all: table, executed: table, true_outcome: table, false_outcome: table, fully_covered: table}} Get all coverage data
---@field get_active_files fun(): table<string, boolean> Get list of active files
---@field get_performance_metrics fun(): {hook_calls: number, hook_execution_time: number, hook_errors: number, last_call_time: number, average_call_time: number, max_call_time: number, line_events: number, call_events: number, return_events: number} Get performance metrics
---@field reset fun() Reset all coverage data
---@field visualize_line_classification fun(file_path: string): table|nil, string? Visualize line classification for debugging

--- Firmo coverage debug hook module
--- This module implements the core debug hook and data management functionality for the coverage
--- system. It uses Lua's debug hooks to track line execution, function calls, and code blocks
--- during program execution.
---
--- Key features:
--- - Line execution tracking with Lua's debug hook
--- - Distinction between execution and validation coverage
--- - Function and block tracking
--- - Performance metrics collection
--- - File tracking with include/exclude patterns
--- - Integration with static analysis
---
--- The debug hook module serves as the foundation for the coverage system, providing the
--- fundamental tracking mechanisms that other coverage components build upon.
---
--- @author Firmo Team
--- @version 1.0.0
local M = {}
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")
-- Error handler is a required module for proper error handling throughout the codebase
local error_handler = require("lib.tools.error_handler")
local static_analyzer -- Lazily loaded when used
local config = {}
local tracked_files = {}
local active_files = {} -- Keep track of files that should be included in reporting

local processing_hook = false -- Flag to prevent recursive hook calls
-- Enhanced data structure with clear separation between execution and coverage
local coverage_data = {
  files = {},                   -- File metadata and content
  lines = {},                   -- Legacy structure for backward compatibility
  executed_lines = {},          -- All lines that were executed (raw execution data)
  covered_lines = {},           -- Lines that are both executed and executable (coverage data)
  functions = {
    all = {},                   -- All functions (legacy structure)
    executed = {},              -- Functions that were executed
    covered = {}                -- Functions that are considered covered (executed + assertions)
  },
  blocks = {
    all = {},                   -- All blocks (legacy structure)
    executed = {},              -- Blocks that were executed
    covered = {}                -- Blocks that are considered covered (execution + assertions)
  },
  conditions = {
    all = {},                   -- All conditions (legacy structure)
    executed = {},              -- Conditions that were executed
    true_outcome = {},          -- Conditions that executed the true path
    false_outcome = {},         -- Conditions that executed the false path
    fully_covered = {}          -- Conditions where both outcomes were executed
  }
}

-- Performance metrics tracking
local performance_metrics = {
  hook_calls = 0,               -- Total number of debug hook calls
  hook_execution_time = 0,      -- Total execution time across all hook calls
  hook_errors = 0,              -- Count of errors encountered in the hook
  last_call_time = 0,           -- Execution time of the last hook call
  average_call_time = 0,        -- Average execution time per hook call
  max_call_time = 0,            -- Maximum execution time for a single hook call
  line_events = 0,              -- Count of line events
  call_events = 0,              -- Count of call events
  return_events = 0             -- Count of return events
}

-- Create a logger for this module
local logger = logging.get_logger("CoverageHook")

--- Determine if a file should be tracked by the coverage system.
--- This function checks if a given file should be included in coverage tracking
--- based on configured include/exclude patterns and other rules. The decision is
--- cached for improved performance on subsequent checks for the same file.
---
--- The function applies these rules in order:
--- 1. Files already in the tracking cache use the cached decision
--- 2. Example files are tracked based on configuration
--- 3. Files matching exclude patterns are not tracked
--- 4. Files matching include patterns are tracked
--- 5. Files in configured source directories are tracked
---
--- @usage
--- -- Check if a file should be tracked
--- local should_track = debug_hook.should_track_file("/path/to/file.lua")
--- 
--- -- Use in a filter function
--- local function filter_files(files)
---   local tracked_files = {}
---   for _, file_path in ipairs(files) do
---     if debug_hook.should_track_file(file_path) then
---       table.insert(tracked_files, file_path)
---     end
---   end
---   return tracked_files
--- end
---
--- @param file_path string Path to the file to check
--- @return boolean Should the file be tracked by the coverage system
function M.should_track_file(file_path)
  -- Safely normalize file path
  local normalized_path, err = error_handler.safe_io_operation(
    function() return fs.normalize_path(file_path) end,
    file_path,
    {operation = "debug_hook.should_track_file"}
  )
  
  if not normalized_path then
    logger.debug("Failed to normalize path: " .. error_handler.format_error(err), {
      file_path = file_path,
      operation = "should_track_file"
    })
    return false
  end
  
  -- Quick lookup for already-decided files
  if tracked_files[normalized_path] ~= nil then
    return tracked_files[normalized_path]
  end
  
  -- Special case for example files (always track them)
  if config.should_track_example_files and normalized_path:match("/examples/") then
    tracked_files[normalized_path] = true
    return true
  end
  
  -- Apply exclude patterns (fast reject) with error handling
  for _, pattern in ipairs(config.exclude or {}) do
    local success, matches, err = error_handler.try(function()
      return fs.matches_pattern(normalized_path, pattern)
    end)
    
    if not success then
      logger.debug("Pattern matching error: " .. error_handler.format_error(matches), {
        file_path = normalized_path,
        pattern = pattern,
        operation = "should_track_file.exclude"
      })
      goto continue_exclude
    end
    
    if matches then
      tracked_files[normalized_path] = false
      return false
    end
    
    ::continue_exclude::
  end
  
  -- Check for invalid patterns in include patterns
  for _, pattern in ipairs(config.include or {}) do
    -- Test if the pattern is valid by trying to match anything with it
    local success, _, err = error_handler.try(function()
      return fs.matches_pattern("test", pattern)
    end)
    
    if not success then
      logger.debug("Invalid pattern detected: " .. error_handler.format_error(err), {
        pattern = pattern,
        operation = "should_track_file.include"
      })
      tracked_files[normalized_path] = false
      return false
    end
  end
  
  -- Apply include patterns with error handling
  for _, pattern in ipairs(config.include or {}) do
    local success, matches, err = error_handler.try(function()
      return fs.matches_pattern(normalized_path, pattern)
    end)
    
    if not success then
      logger.debug("Pattern matching error: " .. error_handler.format_error(matches), {
        file_path = normalized_path,
        pattern = pattern,
        operation = "should_track_file.include"
      })
      goto continue_include
    end
    
    if matches then
      tracked_files[normalized_path] = true
      return true
    end
    
    ::continue_include::
  end
  
  -- Check source directories
  for _, dir in ipairs(config.source_dirs or {"."}) do
    local normalized_dir = fs.normalize_path(dir)
    if normalized_path:sub(1, #normalized_dir) == normalized_dir then
      tracked_files[normalized_path] = true
      return true
    end
  end
  
  
  -- Default decision based on file extension
  local is_lua = normalized_path:match("%.lua$") ~= nil
  tracked_files[normalized_path] = is_lua
  return is_lua
end

---@param file_path string Path to the file to initialize for tracking
---@param options? table Optional configuration parameters for initialization
---@return table|nil file_data The initialized file data object or nil if initialization failed
---@return table|nil error Error object if initialization failed
-- Initialize tracking for a file - exposed as public API for other components to use
function M.initialize_file(file_path, options)
  -- Validate parameters
  if file_path == nil then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "initialize_file", provided_type = "nil"}
    )
  end
  
  if type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "initialize_file", provided_type = type(file_path)}
    )
  end
  
  if file_path == "" then
    return nil, error_handler.validation_error(
      "file_path cannot be empty",
      {operation = "initialize_file"}
    )
  end
  
  local normalized_path = fs.normalize_path(file_path)
  options = options or {}
  
  -- Skip if already initialized and not forced
  if coverage_data.files[normalized_path] and not options.force then
    return coverage_data.files[normalized_path]
  end
  
  -- Count lines in file and store them as an array
  local line_count = 0
  local source_text = options.source_text or fs.read_file(file_path)
  local source_lines = {}
  
  if source_text then
    for line in (source_text .. "\n"):gmatch("([^\r\n]*)[\r\n]") do
      line_count = line_count + 1
      source_lines[line_count] = line
    end
  end
  
  -- Create or update file data
  coverage_data.files[normalized_path] = {
    lines = options.lines or {},                      -- Lines validated by tests (covered)
    _executed_lines = options._executed_lines or {},  -- All executed lines (execution tracking)
    functions = options.functions or {},              -- Function execution tracking
    line_count = line_count,
    source = source_lines,
    source_text = source_text,
    executable_lines = options.executable_lines or {}, -- Whether each line is executable
    logical_chunks = options.logical_chunks or {},     -- Store code blocks information
    code_map = options.code_map,                       -- Static analysis code map if available
    ast = options.ast,                                 -- AST if available
    discovered = options.discovered                    -- Whether this file was discovered rather than executed
  }
  
  if logger.is_debug_enabled() then
    logger.debug({
      message = "Initialized file for tracking",
      file_path = normalized_path,
      operation = "initialize_file",
      source = options.source_text and "provided_content" or "filesystem"
    })
  end
  
  return coverage_data.files[normalized_path]
end

---@param file_path string Path to the file to initialize
---@return table|nil file_data The initialized file data or nil if initialization failed
---@private
-- Private function for internal use that calls the public API
local function initialize_file(file_path)
  return M.initialize_file(file_path)
end

---@param file_path string Path to the file to check
---@param line number Line number to check for executability
---@return boolean is_executable Whether the line is executable
---@private
-- Check if a line is executable in a file - delegated to static_analyzer
-- Enhanced function to check if a line is executable with detailed context
-- @param file_path string Path to the file
-- @param line number Line number to check
-- @param options? table Optional settings {use_enhanced_classification?: boolean, track_multiline_context?: boolean}
-- @return boolean is_executable Whether the line is executable
-- @return table? context Additional context information about the classification
local function is_line_executable(file_path, line, options)
  -- Apply default options
  options = options or {}
  if options.use_enhanced_classification == nil then
    options.use_enhanced_classification = true -- Default to enhanced classification
  end
  if options.track_multiline_context == nil then
    options.track_multiline_context = true -- Default to tracking multiline context
  end

  -- Ensure static_analyzer is loaded
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Check if we have static analysis data for this file
  local normalized_path = fs.normalize_path(file_path)
  local file_data = coverage_data.files[normalized_path]
  
  if file_data and file_data.code_map then
    -- Use existing static analysis data with enhanced options
    local is_exec, context = static_analyzer.is_line_executable(file_data.code_map, line, options)
    
    -- Store classification context in file data if requested
    if options.track_multiline_context and context then
      file_data.line_classification = file_data.line_classification or {}
      file_data.line_classification[line] = context
    end
    
    -- Verbose output for specific test files or when debug is enabled
    if (config.verbose and file_path:match("examples/minimal_coverage.lua") and logger.is_verbose_enabled()) or 
       (config.debug and logger.is_debug_enabled()) then
      local line_type = "unknown"
      if file_data.code_map.lines and file_data.code_map.lines[line] then
        line_type = file_data.code_map.lines[line].type or "unknown"
      end
      
      logger.verbose("Line classification", {
        file_path = file_path,
        line = line,
        executable = is_exec,
        type = line_type,
        context = context and context.content_type or "unknown",
        source = "static_analyzer.is_line_executable"
      })
    end
    
    return is_exec, context
  end
  
  -- If we don't have a code map but we have the source text, try to obtain one
  -- via the static analyzer on-demand with enhanced features
  if file_data and file_data.source_text and not file_data.code_map_attempted then
    file_data.code_map_attempted = true -- Mark that we've tried to get a code map
    
    -- Try to parse the source and get a code map with enhanced options
    local ast, code_map, _, parsing_context = static_analyzer.parse_content(
      file_data.source_text, 
      file_path,
      {
        track_multiline_constructs = options.track_multiline_context,
        enhanced_comment_detection = options.use_enhanced_classification
      }
    )
    
    if ast and code_map then
      file_data.code_map = code_map
      file_data.ast = ast
      file_data.parsing_context = parsing_context
      
      -- Get executable lines map with enhanced detection
      file_data.executable_lines = static_analyzer.get_executable_lines(code_map, {
        use_enhanced_detection = options.use_enhanced_classification
      })
      
      -- Now that we have a code map, we can check if the line is executable with enhanced options
      return static_analyzer.is_line_executable(code_map, line, options)
    end
  end
  
  -- If we can't generate a code map, use the enhanced classify_line_simple_with_context
  if options.use_enhanced_classification then
    local source_line = file_data and file_data.source and file_data.source[line]
    local line_type, context = static_analyzer.classify_line_simple_with_context(file_path, line, source_line, options)
    
    -- Store classification context in file data if requested
    if options.track_multiline_context and file_data then
      file_data.line_classification = file_data.line_classification or {}
      file_data.line_classification[line] = context
    end
    
    local is_executable = (
      line_type == static_analyzer.LINE_TYPES.EXECUTABLE or
      line_type == static_analyzer.LINE_TYPES.FUNCTION or
      line_type == static_analyzer.LINE_TYPES.BRANCH
    )
    
    return is_executable, context
  else
    -- Fallback to original simple classification without context
    return static_analyzer.classify_line_simple(file_data and file_data.source[line], config)
  end
end

--- Main debug hook function for capturing code execution.
--- This function is registered with Lua's debug.sethook() and is called for line, call,
--- and return events during program execution. It tracks which lines of code are executed, 
--- which functions are called, and collects coverage data.
---
--- The debug hook is the primary mechanism for execution tracking in the coverage system.
--- It handles:
--- - Filtering files based on include/exclude patterns
--- - Recording line execution
--- - Tracking function calls and returns
--- - Collecting performance metrics
--- - Preventing recursive hook calls
--- - Special handling for coverage module files
---
--- This function is designed to be as lightweight as possible while still collecting
--- comprehensive coverage data. It includes safeguards against recursion and performance
--- monitoring.
---
--- @usage
--- -- Register the debug hook with Lua's debug system
--- debug.sethook(debug_hook.debug_hook, "clr")  -- Track calls, lines, and returns
--- 
--- -- Register with limited scope
--- debug.sethook(debug_hook.debug_hook, "l")    -- Track only lines
---
--- @param event string The debug event type ('line', 'call', 'return', etc.)
--- @param line number The line number where the event occurred
function M.debug_hook(event, line)
  -- Record start time for performance monitoring
  local start_time
  if config.debug then
    start_time = os.clock()
  end
  
  -- Increment call count for performance tracking
  performance_metrics.hook_calls = performance_metrics.hook_calls + 1
  
  -- Skip if we're already processing a hook to prevent recursion
  if processing_hook then
    return
  end
  
  -- Track event type for metrics
  if event == "line" then
    performance_metrics.line_events = performance_metrics.line_events + 1
  elseif event == "call" then
    performance_metrics.call_events = performance_metrics.call_events + 1
  elseif event == "return" then
    performance_metrics.return_events = performance_metrics.return_events + 1
  end
  
  -- Skip if the line is missing, negative, or zero (special internal Lua events)
  if not line or line <= 0 then
    return
  end
  
  -- Set flag to prevent recursion
  processing_hook = true
  
  -- Main hook logic with protected call
  local success, result, err = error_handler.try(function()
    if event == "line" then
      local info = debug.getinfo(2, "S")
      if not info or not info.source or info.source:sub(1, 1) ~= "@" then
        processing_hook = false
        return
      end
      
      local file_path = info.source:sub(2)  -- Remove @ prefix
      
      -- Identify coverage module files and test files for special handling
      local is_coverage_file = file_path:find("lib/coverage", 1, true) or 
                              file_path:find("lib/tools/parser", 1, true) or
                              file_path:find("lib/tools/vendor", 1, true)
                              
      -- Identify test files for special handling
      local is_test_file = file_path:match("_test%.lua$") or 
                           file_path:match("_spec%.lua$") or
                           file_path:match("/tests/") or
                           file_path:match("/test/") or
                           file_path:match("test_.*%.lua$")
      
      -- Special handling for coverage module and test files
      if is_coverage_file then
        -- Always record execution data for self-coverage regardless of config
        -- This helps us see what parts of the coverage system itself are running
        M.track_line(file_path, line, {
          is_executable = true,    -- Assume all lines in coverage code are executable for simplicity
          is_covered = false,      -- But don't mark as covered to prevent skewing metrics
          track_blocks = false,    -- Skip block tracking for coverage files
          track_conditions = false -- Skip condition tracking for coverage files
        })
        
        -- Debug output for specific self-coverage files if debug is enabled
        if file_path:match("examples/execution_vs_coverage") and logger.is_debug_enabled() then
          logger.debug("Self-tracking execution in coverage module", {
            file = file_path:match("([^/]+)$") or file_path,
            line = line,
            type = "coverage_module"
          })
        end
        
        -- Don't continue with normal coverage processing to avoid recursion
        processing_hook = false
        return
      end
      
      -- Check cached tracked_files first for performance
      local should_track = tracked_files[file_path]
      
      -- If not in cache, determine if we should track
      if should_track == nil then
        should_track = M.should_track_file(file_path)
      end
      
      if should_track then
        local normalized_path = fs.normalize_path(file_path)
        
        -- Initialize file data if needed - use coverage_data.files directly
        if not coverage_data.files[normalized_path] then
          initialize_file(file_path)
          
          -- Debug output for file initialization 
          logger.debug("Initialized file for tracking", {
            file_path = normalized_path
          })
          
          -- Generate code map for better line classification
          if not static_analyzer then
            static_analyzer = require("lib.coverage.static_analyzer")
          end
          
          if coverage_data.files[normalized_path].source_text then
            local ast, code_map = static_analyzer.parse_content(
              coverage_data.files[normalized_path].source_text, 
              file_path
            )
            
            if ast and code_map then
              coverage_data.files[normalized_path].code_map = code_map
              coverage_data.files[normalized_path].ast = ast
              coverage_data.files[normalized_path].code_map_attempted = true
              
              -- Get executable lines map
              coverage_data.files[normalized_path].executable_lines = 
                static_analyzer.get_executable_lines(code_map)
              
              logger.debug("Generated code map", {
                file_path = normalized_path,
                has_blocks = code_map.blocks ~= nil,
                has_functions = code_map.functions ~= nil,
                has_conditions = code_map.conditions ~= nil
              })
            end
          end
        end
        
        -- Check if this line is executable BEFORE tracking
        local is_executable = is_line_executable(file_path, line)
        
        -- Determine if this is a test file - affects coverage classification
        -- Test files are tracked for execution but not necessarily covered
        -- This prevents test assertions from being counted in coverage metrics
        local is_test_file = file_path:match("_test%.lua$") or 
                             file_path:match("_spec%.lua$") or
                             file_path:match("/tests/") or
                             file_path:match("/test/") or
                             file_path:match("test_.*%.lua$")
        
        -- Identify example files - these should be tracked normally
        local is_example_file = file_path:match("/examples/")
        
        -- Identify if this is a file we want detailed debug info for
        local is_debug_file = file_path:match("examples/minimal_coverage.lua") or
                              file_path:match("examples/simple_multiline_comment_test.lua") or
                              file_path:match("examples/execution_vs_coverage") or
                              file_path:match("validator_coverage_test.lua")
        
        -- By default, we assume lines are both executed and covered
        -- This preserves backward compatibility with existing coverage behavior
        local is_covered = true
        
        -- For test files, we only mark as covered if explicitly configured to do so
        if is_test_file and not config.cover_test_files then
          is_covered = false
        end
        
        -- IMPORTANT: Lines are only considered "covered" if they are:
        -- 1. Executed (passed through during runtime)
        -- 2. Executable (actual code, not comments)
        -- 3. Validated by tests (asserted or has a specific coverage marker)
        -- 
        -- For the debug hook, we mark all executed lines as covered by default,
        -- but explicit tracking through M.track_line() can override this.
        
        -- Use our enhanced track_line function instead of direct data manipulation
        -- This ensures consistent tracking and data structure initialization
        M.track_line(file_path, line, {
          is_executable = is_executable,  -- Whether this line is executable
          is_covered = is_covered,        -- Whether this line should be marked as covered
          from_debug_hook = true          -- Track source of tracking for debugging
        })
        
        -- Verbose output for execution tracking
        if config.verbose and is_debug_file and logger.is_verbose_enabled() then
          logger.verbose("Debug hook line execution", {
            file_path = normalized_path:match("([^/]+)$") or normalized_path,
            line = line,
            is_executable = is_executable,
            is_covered = is_covered,
            file_type = is_test_file and "test" or (is_example_file and "example" or "source")
          })
        end
      end
    end
  end)
  
  -- Clear flag after processing
  processing_hook = false
  
  -- Performance tracking
  if config.debug and start_time then
    local execution_time = os.clock() - start_time
    performance_metrics.hook_execution_time = performance_metrics.hook_execution_time + execution_time
    performance_metrics.last_call_time = execution_time
    performance_metrics.average_call_time = performance_metrics.hook_execution_time / performance_metrics.hook_calls
    
    -- Track maximum call time
    if execution_time > performance_metrics.max_call_time then
      performance_metrics.max_call_time = execution_time
    end
    
    -- Log performance data if significant time was spent
    if execution_time > 0.001 and logger.is_debug_enabled() then
      logger.debug("Debug hook performance", {
        event = event,
        line = line,
        execution_time = execution_time,
        average_time = performance_metrics.average_call_time
      })
    end
  end
  
  -- Report errors but don't crash
  if not success then
    -- Track error count
    performance_metrics.hook_errors = performance_metrics.hook_errors + 1
    
    logger.debug("Debug hook error", {
      error = error_handler.format_error(result),
      location = "debug_hook.line_hook",
      hook_errors = performance_metrics.hook_errors
    })
  end
  
  -- Handle call events
  if event == "call" then
    -- Skip if we're already processing a hook to prevent recursion
    if processing_hook then
      return
    end
    
    -- Set flag to prevent recursion
    processing_hook = true
    
    -- Main hook logic with protected call
    local success, result, err = error_handler.try(function()
      local info = debug.getinfo(2, "Sn")
      if not info or not info.source or info.source:sub(1, 1) ~= "@" then
        processing_hook = false
        return
      end
      
      local file_path = info.source:sub(2)
      
      -- Identify coverage module files and test files for special handling
      local is_coverage_file = file_path:find("lib/coverage", 1, true) or 
                              file_path:find("lib/tools/parser", 1, true) or
                              file_path:find("lib/tools/vendor", 1, true)
                              
      -- Identify test files for special handling
      local is_test_file = file_path:match("_test%.lua$") or 
                           file_path:match("_spec%.lua$") or
                           file_path:match("/tests/") or
                           file_path:match("/test/") or
                           file_path:match("test_.*%.lua$")
      
      -- Special handling for coverage module and test files
      if is_coverage_file or is_test_file then
        -- We still want to track function executions for visualization purposes
        local normalized_path = fs.normalize_path(file_path)
        
        -- Initialize file data if not already done
        if not coverage_data.files[normalized_path] then
          initialize_file(file_path)
        end
        
        -- Record function execution data for visualization only
        if coverage_data.files[normalized_path] and info.linedefined and info.linedefined > 0 then
          -- Create unique function key
          local func_key = info.linedefined .. ":function:" .. (info.name or "anonymous")
          local func_name = info.name or ("function_at_line_" .. info.linedefined)
          
          -- Track this function
          coverage_data.files[normalized_path].functions = coverage_data.files[normalized_path].functions or {}
          coverage_data.files[normalized_path].functions[func_key] = {
            name = func_name,
            line = info.linedefined,
            executed = true,
            calls = 1,
            dynamically_detected = true
          }
          
          -- Also mark function's lines as executed
          coverage_data.files[normalized_path]._executed_lines = coverage_data.files[normalized_path]._executed_lines or {}
          coverage_data.files[normalized_path]._executed_lines[info.linedefined] = true
        end
        
        -- Don't continue with normal coverage processing to avoid recursion
        processing_hook = false
        return
      end
      
      if M.should_track_file(file_path) then
        local normalized_path = fs.normalize_path(file_path)
        
        -- Initialize file data if needed
        if not coverage_data.files[normalized_path] then
          initialize_file(file_path)
        end
        
        -- IMPORTANT: Make sure we have a valid line number for the function
        if not info.linedefined or info.linedefined <= 0 then
          processing_hook = false
          return
        end
        
        -- Create unique function key - include explicit type identifier for easier lookup
        local func_key = info.linedefined .. ":function:" .. (info.name or "anonymous")
        local func_name = info.name or ("function_at_line_" .. info.linedefined)
        
        -- Add additional information to help with debugging
        local func_info = {
          name = func_name,
          line = info.linedefined,
          executed = true, -- Mark as executed immediately
          calls = 1,
          dynamically_detected = true,
          name_from_debug = info.name, -- Store original name from debug.getinfo
          what = info.what,            -- Store function type (Lua, C, main)
          source = info.source         -- Store source information
        }
        
        -- Check if this function was already registered by static analysis
        -- More robust matching using line number as the primary key
        local found = false
        for existing_key, func_data in pairs(coverage_data.files[normalized_path].functions) do
          -- Match on line number since that's most reliable
          if func_data.line == info.linedefined then
            -- Function found, mark as executed
            coverage_data.files[normalized_path].functions[existing_key].executed = true
            coverage_data.files[normalized_path].functions[existing_key].calls = 
              (coverage_data.files[normalized_path].functions[existing_key].calls or 0) + 1
            found = true
            
            -- Use the existing key for global tracking
            coverage_data.functions[normalized_path .. ":" .. existing_key] = true
            
            -- Verbose output for function execution
            if config.verbose and logger.is_verbose_enabled() then
              logger.verbose("Executed function", {
                name = coverage_data.files[normalized_path].functions[existing_key].name,
                line = info.linedefined,
                file_path = normalized_path,
                calls = coverage_data.files[normalized_path].functions[existing_key].calls
              })
            end
            
            break
          end
        end
        
        -- If not found in registered functions, add it
        if not found then
          coverage_data.files[normalized_path].functions[func_key] = func_info
          coverage_data.functions[normalized_path .. ":" .. func_key] = true
          
          -- Verbose output for new functions
          if config.verbose and logger.is_verbose_enabled() then
            logger.verbose("Tracked new function", {
              name = func_name,
              line = info.linedefined,
              file_path = normalized_path,
              function_type = info.what or "unknown"
            })
          end
        end
      end
    end)
    
    -- Clear flag after processing
    processing_hook = false
    
    -- Report errors but don't crash
    if not success then
      logger.debug("Debug hook error", {
        error = error_handler.format_error(result),
        location = "debug_hook.call_hook"
      })
    end
  end
end

---@param new_config table Configuration options for the debug hook module
---@return boolean|nil success True if configuration was successful, nil if failed
---@return table|nil error Error object if configuration failed
-- Set configuration
--- Configure the debug hook module with new settings.
--- This function sets configuration options for the debug hook system, controlling
--- which files are tracked, how they're tracked, and other behavioral settings.
--- It validates the provided configuration and resets any cached file tracking
--- decisions.
---
--- Configuration options include:
--- - exclude: Patterns for files to exclude from tracking
--- - include: Patterns for files to include in tracking
--- - source_dirs: Directories containing source files to track
--- - should_track_example_files: Whether to track files in examples directory
---
--- When configuration changes, the module immediately applies the new settings.
--- Any previously cached file tracking decisions are cleared.
---
--- @usage
--- -- Configure with basic options
--- debug_hook.set_config({
---   exclude = {"vendor/.*", "test/.*"},
---   include = {"src/.*", "lib/.*"},
---   source_dirs = {"src", "lib"}
--- })
--- 
--- -- Enable tracking of example files
--- debug_hook.set_config({
---   should_track_example_files = true,
---   source_dirs = {"src", "lib", "examples"}
--- })
---
--- @param new_config {exclude?: string[], include?: string[], source_dirs?: string[], should_track_example_files?: boolean} Configuration options
--- @return boolean|nil success True if configuration was applied successfully, nil on error
--- @return table|nil error Error information if configuration failed
function M.set_config(new_config)
  -- Validate config parameter
  if new_config == nil then
    return nil, error_handler.validation_error(
      "Config must be a table",
      {operation = "set_config", provided_type = "nil"}
    )
  end
  
  if type(new_config) ~= "table" then
    return nil, error_handler.validation_error(
      "Config must be a table",
      {operation = "set_config", provided_type = type(new_config)}
    )
  end
  
  -- Set configuration
  config = new_config
  tracked_files = {}  -- Reset cached decisions
  
  -- Configure module logging level
  logging.configure_from_config("CoverageHook")
  
  return true
end

-- Coverage Data Accessor Functions --

---@return table coverage_data Complete coverage data structure
-- Get entire coverage data (legacy function maintained for backward compatibility)
function M.get_coverage_data()
  return coverage_data
end

---@return table active_files Table of active files (normalized path as key, true as value)
-- Get active files list
function M.get_active_files()
  return active_files
end

---@return table files Table of all tracked files and their data
-- Get all files in coverage data
function M.get_files()
  return coverage_data.files
end

---@param file_path string Path to the file to get data for
---@return table|nil file_data Coverage data for the specified file or nil if not found
-- Get specific file data
function M.get_file_data(file_path)
  if not file_path then
    return nil
  end
  
  -- Normalize the file path for consistency
  local normalized_path = fs.normalize_path(file_path)
  if not normalized_path then
    normalized_path = file_path:gsub("//", "/"):gsub("\\", "/")
  end
  return coverage_data.files[normalized_path]
end

---@param file_path string Path to check if tracked
---@return boolean exists Whether the file exists in the coverage data
-- Check if file exists in coverage data
function M.has_file(file_path)
  local normalized_path = fs.normalize_path(file_path)
  return coverage_data.files[normalized_path] ~= nil
end

---@param file_path string Path to the file to activate for reporting
---@return boolean|nil success True if the file was activated successfully, nil if failed
---@return table|nil error Error object if activation failed
-- Mark a file as active for reporting
function M.activate_file(file_path)
  -- Validate parameters
  if file_path == nil then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "activate_file", provided_type = "nil"}
    )
  end
  
  if type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "file_path must be a string", 
      {operation = "activate_file", provided_type = type(file_path)}
    )
  end
  
  -- Normalize the file path for consistency
  local normalized_path = fs.normalize_path(file_path)
  if not normalized_path then
    normalized_path = file_path:gsub("//", "/"):gsub("\\", "/")
  end
  
  -- Mark file as active
  active_files[normalized_path] = true
  
  -- Ensure file is initialized
  if not coverage_data.files[normalized_path] then
    M.initialize_file(normalized_path)
  end
  
  -- Mark as discovered
  if coverage_data.files[normalized_path] then
    coverage_data.files[normalized_path].discovered = true
    coverage_data.files[normalized_path].active = true
    
    -- Add debug log output
    logger.debug("File activated for coverage reporting", {
      file_path = normalized_path,
      discovered = true,
      active = true
    })
  end
  
  return true
end

---@param file_path string Path to the file
---@return table|nil source_lines Table of source lines or nil if file not found
-- Get file's source lines
function M.get_file_source(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil
  end
  return coverage_data.files[normalized_path].source
end

---@param file_path string Path to the file
---@return string|nil source_text Full source text or nil if file not found
-- Get file's source text
function M.get_file_source_text(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil
  end
  return coverage_data.files[normalized_path].source_text
end

---@param file_path string Path to the file
---@return table covered_lines Table of covered lines (line number as key, true as value)
-- Get covered lines for a file
function M.get_file_covered_lines(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].lines or {}
end

---@param file_path string Path to the file
---@return table executed_lines Table of executed lines (line number as key, true as value)
-- Get executed lines for a file
function M.get_file_executed_lines(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path]._executed_lines or {}
end

---@param file_path string Path to the file
---@return table executable_lines Table of executable lines (line number as key, true as value)
-- Get executable lines for a file
function M.get_file_executable_lines(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].executable_lines or {}
end

---@param file_path string Path to the file
---@return table functions Table of function data for the file
-- Get function data for a file
function M.get_file_functions(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].functions or {}
end

---@param file_path string Path to the file
---@return table logical_chunks Table of logical code blocks for the file
-- Get logical chunks (blocks) for a file
function M.get_file_logical_chunks(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].logical_chunks or {}
end

---@param file_path string Path to the file
---@return table logical_conditions Table of logical conditions for the file
-- Get logical conditions for a file
function M.get_file_logical_conditions(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return {}
  end
  return coverage_data.files[normalized_path].logical_conditions or {}
end

---@param file_path string Path to the file
---@return table|nil code_map Static analysis code map or nil if not available
-- Get code map for a file
function M.get_file_code_map(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil
  end
  return coverage_data.files[normalized_path].code_map
end

---@param file_path string Path to the file
---@return table|nil ast Abstract syntax tree or nil if not available
-- Get AST for a file
function M.get_file_ast(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil
  end
  return coverage_data.files[normalized_path].ast
end

---@param file_path string Path to the file
---@return number line_count Number of lines in the file (0 if file not found)
-- Get line count for a file
function M.get_file_line_count(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return 0
  end
  return coverage_data.files[normalized_path].line_count or 0
end

---@param file_path string Path to the file
---@param line_num number Line number to mark as covered
---@param covered? boolean Whether the line is covered (defaults to true)
---@return boolean|nil success True if the line was marked successfully, nil if failed
---@return table|nil error Error object if operation failed
-- Set or update a covered line in a file
function M.set_line_covered(file_path, line_num, covered)
  -- Validate parameters
  if file_path == nil then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "set_line_covered", provided_type = "nil"}
    )
  end
  
  if type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "set_line_covered", provided_type = type(file_path)}
    )
  end
  
  if line_num == nil then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "set_line_covered", provided_type = "nil"}
    )
  end
  
  if type(line_num) ~= "number" then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "set_line_covered", provided_type = type(line_num)}
    )
  end
  
  if covered ~= nil and type(covered) ~= "boolean" then
    return nil, error_handler.validation_error(
      "covered must be a boolean",
      {operation = "set_line_covered", provided_type = type(covered)}
    )
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure lines table exists
  if not coverage_data.files[normalized_path].lines then
    coverage_data.files[normalized_path].lines = {}
  end
  
  -- Set the line coverage value
  if covered == nil then
    covered = true
  end
  
  coverage_data.files[normalized_path].lines[line_num] = covered
  
  -- Update global tracking
  if covered then
    coverage_data.lines[normalized_path .. ":" .. line_num] = true
  else
    coverage_data.lines[normalized_path .. ":" .. line_num] = nil
  end
  
  return covered
end

---@param file_path string Path to the file
---@param line_num number Line number to mark as executed
---@param executed? boolean Whether the line was executed (defaults to true)
---@return boolean Was the line marked as executed
-- Set or update an executed line in a file
function M.set_line_executed(file_path, line_num, executed)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure _executed_lines table exists
  if not coverage_data.files[normalized_path]._executed_lines then
    coverage_data.files[normalized_path]._executed_lines = {}
  end
  
  -- Set the line execution value
  if executed == nil then
    executed = true
  end
  
  coverage_data.files[normalized_path]._executed_lines[line_num] = executed
  
  return executed
end

---@param file_path string Path to the file
---@param line_num number Line number to mark as executable
---@param executable boolean Whether the line is executable
---@return boolean|nil success True if the line was marked successfully, nil if failed
---@return table|nil error Error object if operation failed
-- Set executable status for a line
function M.set_line_executable(file_path, line_num, executable)
  -- Validate parameters
  if file_path == nil then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "set_line_executable", provided_type = "nil"}
    )
  end
  
  if type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "set_line_executable", provided_type = type(file_path)}
    )
  end
  
  if line_num == nil then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "set_line_executable", provided_type = "nil"}
    )
  end
  
  if type(line_num) ~= "number" then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "set_line_executable", provided_type = type(line_num)}
    )
  end
  
  if type(executable) ~= "boolean" then
    return nil, error_handler.validation_error(
      "executable must be a boolean",
      {operation = "set_line_executable", provided_type = type(executable)}
    )
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure executable_lines table exists
  if not coverage_data.files[normalized_path].executable_lines then
    coverage_data.files[normalized_path].executable_lines = {}
  end
  
  -- Set the line executability value
  if executable == nil then
    executable = true
  end
  
  coverage_data.files[normalized_path].executable_lines[line_num] = executable
  
  return executable
end

---@param file_path string Path to the file containing the function
---@param func_key string Unique key identifying the function
---@param executed? boolean Whether the function was executed (defaults to true)
---@return boolean|false success True if function was marked, false if function not found
-- Set a function's executed status
function M.set_function_executed(file_path, func_key, executed)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure functions table exists
  if not coverage_data.files[normalized_path].functions then
    coverage_data.files[normalized_path].functions = {}
  end
  
  -- Check if the function exists
  if not coverage_data.files[normalized_path].functions[func_key] then
    return false
  end
  
  -- Set the function execution value
  if executed == nil then
    executed = true
  end
  
  coverage_data.files[normalized_path].functions[func_key].executed = executed
  
  -- Update global tracking
  if executed then
    coverage_data.functions[normalized_path .. ":" .. func_key] = true
  else
    coverage_data.functions[normalized_path .. ":" .. func_key] = nil
  end
  
  return executed
end

---@param file_path string Path to the file containing the function
---@param func_key string Unique key identifying the function
---@param func_data table Function metadata and tracking information
---@return table func_data The function data that was added
-- Add a new function to the coverage data
function M.add_function(file_path, func_key, func_data)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure functions table exists
  if not coverage_data.files[normalized_path].functions then
    coverage_data.files[normalized_path].functions = {}
  end
  
  -- Add the function data
  coverage_data.files[normalized_path].functions[func_key] = func_data
  
  -- Update global tracking if executed
  if func_data.executed then
    coverage_data.functions[normalized_path .. ":" .. func_key] = true
  end
  
  return func_data
end

---@param file_path string Path to the file containing the block
---@param block_id string Unique ID of the block
---@param executed? boolean Whether the block was executed (defaults to true)
---@return boolean|false success True if block was marked, false if block not found
-- Set a block's executed status
function M.set_block_executed(file_path, block_id, executed)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure logical_chunks table exists
  if not coverage_data.files[normalized_path].logical_chunks then
    coverage_data.files[normalized_path].logical_chunks = {}
  end
  
  -- Check if the block exists
  if not coverage_data.files[normalized_path].logical_chunks[block_id] then
    return false
  end
  
  -- Set the block execution value
  if executed == nil then
    executed = true
  end
  
  coverage_data.files[normalized_path].logical_chunks[block_id].executed = executed
  
  -- Update global tracking
  if executed then
    coverage_data.blocks[normalized_path .. ":" .. block_id] = true
  else
    coverage_data.blocks[normalized_path .. ":" .. block_id] = nil
  end
  
  return executed
end

---@param file_path string Path to the file containing the block
---@param block_id string Unique ID of the block
---@param block_data table Block metadata and tracking information
---@return table block_data The block data that was added
-- Add a new block to the coverage data
function M.add_block(file_path, block_id, block_data)
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure logical_chunks table exists
  if not coverage_data.files[normalized_path].logical_chunks then
    coverage_data.files[normalized_path].logical_chunks = {}
  end
  
  -- Add the block data
  coverage_data.files[normalized_path].logical_chunks[block_id] = block_data
  
  -- Update global tracking if executed
  if block_data.executed then
    coverage_data.blocks[normalized_path .. ":" .. block_id] = true
  end
  
  return block_data
end

---@param file_path string Path to the file
---@param line_num number Line number to check
---@return boolean was_executed Whether the line was executed during coverage tracking
-- Check if a specific line was executed (important for fixing incorrectly marked lines)
function M.was_line_executed(file_path, line_num)
  -- Check if we have data for this file
  if not M.has_file(file_path) then
    return false
  end
  
  -- Get executed lines for this file
  local executed_lines = M.get_file_executed_lines(file_path)
  if executed_lines and executed_lines[line_num] then
    return true
  end
  
  -- Fall back to covered lines table if _executed_lines doesn't exist or is empty
  local covered_lines = M.get_file_covered_lines(file_path)
  return covered_lines and covered_lines[line_num] == true
end

---@param file_path string Path to the file containing the function
---@param line_num number Line number where the function is defined
---@param func_name string|nil Name of the function (can be nil for anonymous functions)
---@return boolean|nil success True if function tracking was successful, nil if failed
---@return table|nil error Error object if tracking failed
-- Track function execution for instrumentation
function M.track_function(file_path, line_num, func_name)
  -- Validate parameters
  if file_path == nil then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "track_function", provided_type = "nil"}
    )
  end
  
  if type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "track_function", provided_type = type(file_path)}
    )
  end
  
  if line_num == nil then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "track_function", provided_type = "nil"}
    )
  end
  
  if type(line_num) ~= "number" then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "track_function", provided_type = type(line_num)}
    )
  end
  
  if func_name == nil then
    return nil, error_handler.validation_error(
      "func_name must be a string",
      {operation = "track_function", provided_type = "nil"}
    )
  end
  
  if type(func_name) ~= "string" then
    return nil, error_handler.validation_error(
      "func_name must be a string",
      {operation = "track_function", provided_type = type(func_name)}
    )
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Track function with proper error handling
  local success, err = error_handler.try(function()
    local file_data = coverage_data.files[normalized_path]
    if file_data then
      -- Initialize function tracking
      file_data.functions = file_data.functions or {}
      
      -- Create or update function data
      local func_id = func_name or ("anonymous_" .. line_num)
      file_data.functions[func_id] = file_data.functions[func_id] or {
        name = func_name or "anonymous",
        line = line_num,
        calls = 0,
        executed = false,
        covered = false
      }
      
      -- Increment call count
      file_data.functions[func_id].calls = file_data.functions[func_id].calls + 1
      file_data.functions[func_id].executed = true
      file_data.functions[func_id].covered = true
      
      -- Also track the declaration line
      M.set_line_executed(file_path, line_num, true)
      M.set_line_covered(file_path, line_num, true)
      
      -- Mark line as executable
      M.set_line_executable(file_path, line_num, true)
      
      -- Update global tracking
      coverage_data.functions[normalized_path .. ":" .. func_id] = true
      
      -- Verbose logging
      if config.verbose and logger.is_verbose_enabled() then
        logger.verbose("Function execution tracked", {
          file_path = normalized_path,
          line_num = line_num,
          func_name = func_name or "anonymous",
          calls = file_data.functions[func_id].calls
        })
      end
    end
    
    return true
  end)
  
  if not success then
    logger.debug("Error tracking function execution", {
      file_path = normalized_path,
      line_num = line_num,
      func_name = func_name or "anonymous",
      error = err and err.message or "unknown error"
    })
    return nil, err
  end
  
  return true
end

---@param file_path string Path to the file containing the block
---@param line_num number Line number where the block starts
---@param block_id string Unique identifier for the block
---@param block_type string Type of the block (e.g., "if", "for", "while", etc.)
---@return boolean|nil success True if block tracking was successful, nil if failed
---@return table|nil error Error object if tracking failed
-- Track block execution for instrumentation
function M.track_block(file_path, line_num, block_id, block_type)
  -- Validate parameters
  if file_path == nil then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "track_block", provided_type = "nil"}
    )
  end
  
  if type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "track_block", provided_type = type(file_path)}
    )
  end
  
  if line_num == nil then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "track_block", provided_type = "nil"}
    )
  end
  
  if type(line_num) ~= "number" then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "track_block", provided_type = type(line_num)}
    )
  end
  
  if block_id == nil then
    return nil, error_handler.validation_error(
      "block_id must be a string",
      {operation = "track_block", provided_type = "nil"}
    )
  end
  
  if type(block_id) ~= "string" then
    return nil, error_handler.validation_error(
      "block_id must be a string",
      {operation = "track_block", provided_type = type(block_id)}
    )
  end
  
  if block_type == nil then
    return nil, error_handler.validation_error(
      "block_type must be a string",
      {operation = "track_block", provided_type = "nil"}
    )
  end
  
  if type(block_type) ~= "string" then
    return nil, error_handler.validation_error(
      "block_type must be a string",
      {operation = "track_block", provided_type = type(block_type)}
    )
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Track block with proper error handling
  local success, err = error_handler.try(function()
    local file_data = coverage_data.files[normalized_path]
    if file_data then
      -- Ensure logical_chunks table exists
      if not file_data.logical_chunks then
        file_data.logical_chunks = {}
      end
      
      -- Create or update block data
      local block_key = block_id .. "_" .. line_num
      file_data.logical_chunks[block_key] = file_data.logical_chunks[block_key] or {
        id = block_key,
        type = block_type or "Block",
        start_line = line_num,
        end_line = line_num,
        executed = false,
        execution_count = 0
      }
      
      -- Increment execution count
      file_data.logical_chunks[block_key].execution_count = 
        (file_data.logical_chunks[block_key].execution_count or 0) + 1
      file_data.logical_chunks[block_key].executed = true
      
      -- Also track the declaration line
      M.set_line_executed(file_path, line_num, true)
      M.set_line_covered(file_path, line_num, true)
      
      -- Mark line as executable
      M.set_line_executable(file_path, line_num, true)
      
      -- Update global tracking
      coverage_data.blocks[normalized_path .. ":" .. block_key] = true
      
      -- Verbose logging
      if config.verbose and logger.is_verbose_enabled() then
        logger.verbose("Block execution tracked", {
          file_path = normalized_path,
          line_num = line_num,
          block_id = block_id,
          block_type = block_type or "Block",
          executions = file_data.logical_chunks[block_key].execution_count
        })
      end
    end
    
    return true
  end)
  
  if not success then
    logger.debug("Error tracking block execution", {
      file_path = normalized_path,
      line_num = line_num,
      block_id = block_id,
      block_type = block_type or "Block",
      error = err and err.message or "unknown error"
    })
    return nil, err
  end
  
  return true
end

---@param file_path string Path to the file
---@param line_num number Line number to check
---@return boolean was_covered Whether the line was covered by test assertions
-- Check if a specific line was covered (validated by assertions)
function M.was_line_covered(file_path, line_num)
  -- Check if we have data for this file
  if not M.has_file(file_path) then
    return false
  end
  
  -- Get covered lines for this file (these are validated by test assertions)
  local covered_lines = M.get_file_covered_lines(file_path)
  return covered_lines and covered_lines[line_num] == true
end

---@param file_path string Path to the file
---@param line_num number Line number to mark as covered
---@return boolean success True if the line was marked as covered
-- Mark a line as covered (validated by assertions)
-- This is a key function for improving the distinction between execution and coverage
function M.mark_line_covered(file_path, line_num)
  -- Skip if file path is missing
  if not file_path then
    return false
  end
  
  -- Get normalized path
  local normalized_path = fs.normalize_path(file_path)
  
  -- Initialize file data if needed
  if not coverage_data.files[normalized_path] then
    M.initialize_file(file_path)
  end
  
  -- Ensure tables exist
  coverage_data.files[normalized_path].lines = coverage_data.files[normalized_path].lines or {}
  
  -- Mark line as covered
  coverage_data.files[normalized_path].lines[line_num] = true
  
  -- Also mark in global covered lines table
  local line_key = normalized_path .. ":" .. line_num
  coverage_data.covered_lines[line_key] = true
  
  -- Ensure this line is also marked as executed (it must have been executed to be covered)
  coverage_data.files[normalized_path]._executed_lines = coverage_data.files[normalized_path]._executed_lines or {}
  if not coverage_data.files[normalized_path]._executed_lines[line_num] then
    coverage_data.files[normalized_path]._executed_lines[line_num] = true
    coverage_data.executed_lines[line_key] = true
  end
  
  -- Verbose logging
  if config.verbose and logger.is_verbose_enabled() then
    logger.verbose("Marked line as covered", {
      file_path = normalized_path,
      line_num = line_num,
      source = "mark_line_covered",
      operation = "assertion_validation"
    })
  end
  
  return true
end

---@param file_path string Path to the file
---@param line_num number Line number to track
---@param options? table Additional options: is_executable, is_covered, track_blocks, track_conditions
---@return boolean|nil success True if tracking was successful, nil if failed
---@return table|nil error Error object if tracking failed
-- Track a line execution from instrumentation
-- This function is a critical part of the robust tracking approach
-- It provides a reliable way to track line execution that doesn't depend on debug.sethook()
--- Track a line's execution with optional coverage marking.
--- This function records that a specific line in a file has been executed and optionally
--- marks it as covered (validated by assertions). It's the primary tracking function used
--- by the coverage system for both execution and coverage tracking.
---
--- The function handles:
--- - Recording that a line was executed
--- - Optionally marking the line as covered (validated by assertions)
--- - Marking the line as executable if specified
--- - Updating global tracking data structures
---
--- The options parameter allows specifying:
--- - is_executable: Whether the line is considered executable code
--- - is_covered: Whether the line is considered covered by assertions
--- - operation: A string identifying the operation for logging/debugging
---
--- @usage
--- -- Track simple line execution
--- debug_hook.track_line("/path/to/file.lua", 42)
--- 
--- -- Track line and mark as covered (validated)
--- debug_hook.track_line("/path/to/file.lua", 42, {
---   is_executable = true,
---   is_covered = true
--- })
--- 
--- -- Track with operation name for debugging
--- debug_hook.track_line("/path/to/file.lua", 42, {
---   operation = "assertion_tracking"
--- })
---
--- @param file_path string The path to the file containing the line
--- @param line_num number The line number to track
--- @param options? {is_executable?: boolean, is_covered?: boolean, operation?: string} Optional tracking options
--- @return boolean|nil success True if tracking was successful, nil on error
--- @return table|nil error Error information if tracking failed
function M.track_line(file_path, line_num, options)
  -- Validate parameters
  if file_path == nil then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "track_line", provided_type = "nil"}
    )
  end
  
  if type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "file_path must be a string",
      {operation = "track_line", provided_type = type(file_path)}
    )
  end
  
  if line_num == nil then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "track_line", provided_type = "nil"}
    )
  end
  
  if type(line_num) ~= "number" then
    return nil, error_handler.validation_error(
      "line_num must be a number",
      {operation = "track_line", provided_type = type(line_num)}
    )
  end
  
  if line_num <= 0 then
    return nil, error_handler.validation_error(
      "line_num must be a positive number",
      {operation = "track_line", provided_value = line_num}
    )
  end
  
  -- Ensure file is initialized
  local file_data = M.get_file_data(file_path)
  if not file_data then
    return nil, error_handler.validation_error(
      "File not initialized",
      {operation = "track_line", file_path = file_path}
    )
  end
  
  -- Check if the file data is valid (a table, not a string or other type)
  if type(file_data) ~= "table" then
    return nil, error_handler.runtime_error(
      "Invalid file data structure", 
      {operation = "track_line", file_path = file_path}
    )
  end
  
  -- Handle with proper error handling
  local success, result = error_handler.try(function()
    local normalized_path, err = fs.normalize_path(file_path)
    if not normalized_path then
      -- Only show as warning if this isn't a test file path
      local is_test_file = file_path and file_path:match("/tests/") ~= nil
      
      if is_test_file then
        -- For test files, use debug level to reduce noise
        logger.debug("Failed to normalize test file path", {
          file_path = file_path,
          error = err and err.message or "unknown error",
          operation = "track_line"
        })
      else
        -- For non-test files, this could be a real issue
        logger.warn("Failed to normalize path", {
          file_path = file_path,
          error = err and err.message or "unknown error",
          operation = "track_line"
        })
      end
      normalized_path = file_path -- Fallback to original path
    end
    
    -- Initialize file data if needed
    if not coverage_data.files[normalized_path] then
      M.initialize_file(file_path)
    end
    
    -- Make sure all data structures exist
    coverage_data.files[normalized_path]._executed_lines = coverage_data.files[normalized_path]._executed_lines or {}
    coverage_data.files[normalized_path].lines = coverage_data.files[normalized_path].lines or {}
    coverage_data.files[normalized_path].executable_lines = coverage_data.files[normalized_path].executable_lines or {}
    
    -- Always mark this line as executed - reliable execution tracking
    coverage_data.files[normalized_path]._executed_lines[line_num] = true
    
    -- Track in global executed lines table
    local line_key = normalized_path .. ":" .. line_num
    coverage_data.executed_lines[line_key] = true
    
    -- Additional execution information
    if options and options.execution_count then
      -- Track execution count if provided
      coverage_data.files[normalized_path]._execution_counts = coverage_data.files[normalized_path]._execution_counts or {}
      coverage_data.files[normalized_path]._execution_counts[line_num] = 
        (coverage_data.files[normalized_path]._execution_counts[line_num] or 0) + 1
    end
    
    -- Determine if this line is executable - use the most accurate method available
    local is_executable = true
    local classification_context = nil
    
    -- Method 1: Use provided executability flag if available (most reliable)
    if options and options.is_executable ~= nil then
      is_executable = options.is_executable
    -- Method 2: Use enhanced classification with our improved is_line_executable function
    else
      -- Prepare classification options
      local classification_options = {
        use_enhanced_classification = options and options.use_enhanced_classification ~= false or true,
        track_multiline_context = options and options.track_multiline_context ~= false or true
      }
      
      -- Call our enhanced is_line_executable with options
      is_executable, classification_context = is_line_executable(
        file_path, 
        line_num, 
        classification_options
      )
      
      -- Store line classification context if available
      if classification_context and coverage_data.files[normalized_path] then
        coverage_data.files[normalized_path].line_classification = 
          coverage_data.files[normalized_path].line_classification or {}
        
        coverage_data.files[normalized_path].line_classification[line_num] = classification_context
      end
      
      -- Debug output for classification if requested
      if config.debug and logger.is_debug_enabled() and classification_context then
        logger.debug("Line classification from track_line", {
          file = normalized_path:match("([^/]+)$") or normalized_path,
          line = line_num,
          is_executable = is_executable,
          content_type = classification_context.content_type or "unknown",
          reasons = table.concat(classification_context.reasons or {}, ", "),
          from_debug_hook = options and options.from_debug_hook or false
        })
      end
    end
    
    -- Store executable state
    coverage_data.files[normalized_path].executable_lines[line_num] = is_executable
    
    -- Only mark executable lines as covered (for coverage reports)
    if is_executable then
      -- Check if we should mark this as covered
      local mark_covered = true
      
      -- If explicit coverage flag is provided, use it
      if options and options.is_covered ~= nil then
        mark_covered = options.is_covered
      end
      
      if mark_covered then
        -- Mark this line as covered
        coverage_data.files[normalized_path].lines[line_num] = true
        
        -- Track in global covered lines table
        coverage_data.covered_lines[line_key] = true
      end
    end
    
    -- Verbose logging
    if config.verbose and logger.is_verbose_enabled() then
      logger.verbose("Tracked line execution", {
        file_path = normalized_path,
        line_num = line_num,
        is_executable = is_executable,
        is_covered = coverage_data.files[normalized_path].lines[line_num] == true,
        source = "track_line",
        has_options = options ~= nil
      })
    end
    
    -- Track blocks and conditions if enabled
    if config.track_blocks and (not options or options.track_blocks ~= false) then
      M.track_blocks_for_line(file_path, line_num)
    end
    
    if config.track_conditions and (not options or options.track_conditions ~= false) then
      M.track_conditions_for_line(file_path, line_num)
    end
    
    return true
  end)
  
  if not success then
    logger.debug("Error tracking line execution", {
      file_path = file_path,
      line_num = line_num,
      error = result and result.message or "unknown error"
    })
    return nil, result
  end
  
  return true
end

---@param file_path string Path to the file
---@param line_num number Line number to track blocks for
---@return table|nil blocks Array of tracked blocks or nil if tracking failed
-- Enhanced block tracking with better parent-child relationship handling
function M.track_blocks_for_line(file_path, line_num)
  -- Skip if block tracking is disabled
  if not config.track_blocks then
    return nil
  end
  
  local start_time
  if config.debug then
    start_time = os.clock()
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Skip if we don't have file data or code map
  if not M.has_file(file_path) then
    return nil
  end
  
  local code_map = M.get_file_code_map(file_path)
  if not code_map then
    return nil
  end
  
  -- Ensure we have the static analyzer
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Use the static analyzer to find which blocks contain this line
  local blocks_for_line = static_analyzer.get_blocks_for_line(code_map, line_num)
  
  -- Track the blocks that were found
  local tracked_blocks = {}
  
  -- Process each block
  for _, block in ipairs(blocks_for_line) do
    local block_data = M.track_block_execution(file_path, block)
    if block_data then
      table.insert(tracked_blocks, block_data)
    end
  end
  
  -- Performance tracking
  if config.debug and start_time then
    local execution_time = os.clock() - start_time
    logger.debug("Block tracking performance", {
      file_path = normalized_path,
      line_num = line_num,
      blocks_count = #tracked_blocks,
      execution_time = execution_time
    })
  end
  
  return tracked_blocks
end

---@param file_path string Path to the file
---@param block table Block data with id, type, start/end line, etc.
---@return table|nil block_data Updated block data with execution information
-- Process a single block's execution with complete metadata
function M.track_block_execution(file_path, block)
  local normalized_path = fs.normalize_path(file_path)
  local logical_chunks = M.get_file_logical_chunks(file_path)
  
  -- Get or create block record
  local block_copy = logical_chunks[block.id]
  
  if not block_copy then
    -- Create a new block record with all needed metadata
    block_copy = {
      id = block.id,
      type = block.type,
      start_line = block.start_line,
      end_line = block.end_line,
      parent_id = block.parent_id,
      branches = {},
      conditions = {},
      executed = true,
      execution_count = 1,
      last_executed = os.time() -- Track when this block was last executed
    }
    
    -- Copy branches array if it exists
    if block.branches then
      for _, branch_id in ipairs(block.branches) do
        table.insert(block_copy.branches, branch_id)
      end
    end
    
    -- Copy conditions array if it exists
    if block.conditions then
      for _, condition_id in ipairs(block.conditions) do
        table.insert(block_copy.conditions, condition_id)
      end
    end
  else
    -- Update existing block record
    block_copy.executed = true
    block_copy.execution_count = (block_copy.execution_count or 0) + 1
    block_copy.last_executed = os.time()
  end
  
  -- Store the block in the file's logical_chunks
  M.add_block(file_path, block.id, block_copy)
  
  -- Add to the global tracking with clear distinction between execution and coverage
  local block_key = normalized_path .. ":" .. block.id
  coverage_data.blocks.all[block_key] = true
  coverage_data.blocks.executed[block_key] = true
  
  -- If the block has assertions in it, consider it covered
  if block_copy.has_assertions then
    coverage_data.blocks.covered[block_key] = true
  end
  
  -- Process parent blocks to ensure proper parent-child relationships
  if block_copy.parent_id and block_copy.parent_id ~= "root" then
    local code_map = M.get_file_code_map(file_path)
    if code_map then
      -- Find the parent block in the code map
      local parent_block
      for _, b in ipairs(code_map.blocks or {}) do
        if b.id == block_copy.parent_id then
          parent_block = b
          break
        end
      end
      
      -- If parent found, track its execution too
      if parent_block then
        local parent_data = M.track_block_execution(file_path, parent_block)
        
        -- Verbose logging for parent tracking
        if parent_data and config.verbose and logger.is_verbose_enabled() then
          logger.verbose("Tracked parent block", {
            block_id = parent_data.id,
            child_id = block_copy.id,
            file_path = normalized_path,
            execution_count = parent_data.execution_count
          })
        end
      else
        -- Get parent from current logical_chunks if not found in code map
        local parent_chunk = logical_chunks[block_copy.parent_id]
        if parent_chunk then
          parent_chunk.executed = true
          parent_chunk.execution_count = (parent_chunk.execution_count or 0) + 1
          parent_chunk.last_executed = os.time()
          M.add_block(file_path, block_copy.parent_id, parent_chunk)
          
          -- Update execution tracking
          local parent_key = normalized_path .. ":" .. block_copy.parent_id
          coverage_data.blocks.all[parent_key] = true
          coverage_data.blocks.executed[parent_key] = true
        end
      end
    end
  end
  
  -- Verbose output for block execution
  if config.verbose and logger.is_verbose_enabled() then
    logger.verbose("Executed block", {
      block_id = block.id,
      type = block.type,
      start_line = block.start_line,
      end_line = block.end_line,
      file_path = normalized_path,
      execution_count = block_copy.execution_count,
      parent_id = block.parent_id,
      operation = "track_block_execution"
    })
  end
  
  return block_copy
end

---@param file_path string Path to the file
---@param line_num number Line number to track conditions for
---@param execution_context? table Optional context with outcome information
---@return table|nil conditions Array of tracked conditions or nil if tracking failed
-- New function for tracking conditions with better outcome detection
function M.track_conditions_for_line(file_path, line_num, execution_context)
  -- Skip if condition tracking is disabled
  if not config.track_conditions then
    return nil
  end
  
  local start_time
  if config.debug then
    start_time = os.clock()
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Skip if we don't have file data or code map
  if not M.has_file(file_path) then
    return nil
  end
  
  local code_map = M.get_file_code_map(file_path)
  if not code_map then
    return nil
  end
  
  -- Ensure we have the static analyzer
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Use the static analyzer to find which conditions contain this line
  local conditions_for_line = static_analyzer.get_conditions_for_line(code_map, line_num)
  
  -- Track the conditions that were found
  local tracked_conditions = {}
  
  -- Process each condition
  for _, condition in ipairs(conditions_for_line) do
    local condition_data = M.track_condition_execution(file_path, condition, execution_context)
    if condition_data then
      table.insert(tracked_conditions, condition_data)
    end
  end
  
  -- Performance tracking
  if config.debug and start_time then
    local execution_time = os.clock() - start_time
    logger.debug("Condition tracking performance", {
      file_path = normalized_path,
      line_num = line_num,
      conditions_count = #tracked_conditions,
      execution_time = execution_time
    })
  end
  
  return tracked_conditions
end

---@param file_path string Path to the file
---@param condition table Condition data with id, type, start/end line, etc.
---@param execution_context? table Optional context with outcome information
---@return table|nil condition_data Updated condition data with execution information
-- Process a single condition's execution with outcome tracking
function M.track_condition_execution(file_path, condition, execution_context)
  local normalized_path = fs.normalize_path(file_path)
  local logical_conditions = M.get_file_logical_conditions(file_path)
  
  -- Get or create condition record
  local condition_copy = logical_conditions[condition.id]
  
  -- Determine outcome based on execution context if provided
  local outcome = execution_context and execution_context.outcome
  
  if not condition_copy then
    -- Create a new condition record with all needed metadata
    condition_copy = {
      id = condition.id,
      type = condition.type,
      start_line = condition.start_line,
      end_line = condition.end_line,
      parent_id = condition.parent_id,
      is_compound = condition.is_compound,
      operator = condition.operator,
      components = {},
      executed = true,
      executed_true = outcome == true,
      executed_false = outcome == false,
      execution_count = 1,
      true_count = outcome == true and 1 or 0,
      false_count = outcome == false and 1 or 0,
      last_executed = os.time(), -- Track when this condition was last executed
      last_outcome = outcome -- Track the last outcome
    }
    
    -- Copy components array if it exists
    if condition.components then
      for _, comp_id in ipairs(condition.components) do
        table.insert(condition_copy.components, comp_id)
      end
    end
  else
    -- Update existing condition record
    condition_copy.executed = true
    condition_copy.execution_count = (condition_copy.execution_count or 0) + 1
    condition_copy.last_executed = os.time()
    
    -- Update outcome tracking if outcome is known
    if outcome ~= nil then
      condition_copy.last_outcome = outcome
      if outcome == true then
        condition_copy.executed_true = true
        condition_copy.true_count = (condition_copy.true_count or 0) + 1
      elseif outcome == false then
        condition_copy.executed_false = true
        condition_copy.false_count = (condition_copy.false_count or 0) + 1
      end
    end
  end
  
  -- Store the condition in the file's logical_conditions
  if not coverage_data.files[normalized_path].logical_conditions then
    coverage_data.files[normalized_path].logical_conditions = {}
  end
  coverage_data.files[normalized_path].logical_conditions[condition.id] = condition_copy
  
  -- Add to the global tracking with clear distinction between execution and coverage
  local condition_key = normalized_path .. ":" .. condition.id
  coverage_data.conditions.all[condition_key] = true
  coverage_data.conditions.executed[condition_key] = true
  
  -- Track outcome coverage
  if condition_copy.executed_true then
    coverage_data.conditions.true_outcome[condition_key] = true
  end
  
  if condition_copy.executed_false then
    coverage_data.conditions.false_outcome[condition_key] = true
  end
  
  -- Track full coverage (both outcomes)
  if condition_copy.executed_true and condition_copy.executed_false then
    coverage_data.conditions.fully_covered[condition_key] = true
  end
  
  -- Process component conditions if this is a compound condition
  if condition.is_compound and condition.components and #condition.components > 0 then
    -- Get the components from the code map
    local code_map = M.get_file_code_map(file_path)
    if code_map and code_map.conditions then
      for _, comp_id in ipairs(condition.components) do
        -- Find the component condition
        local component
        for _, c in ipairs(code_map.conditions) do
          if c.id == comp_id then
            component = c
            break
          end
        end
        
        -- If component found, track its execution with inferred outcome
        if component then
          -- For AND, if the parent is true, both components must be true
          -- If the parent is false, at least one component is false
          if condition.operator == "and" then
            local component_outcome
            if outcome == true then
              component_outcome = true -- Both must be true for AND to be true
            elseif outcome == false and logical_conditions[comp_id] then
              -- For false AND, we need to check if previous execution has determined this component's outcome
              if logical_conditions[comp_id].last_outcome ~= nil then
                component_outcome = logical_conditions[comp_id].last_outcome
              end
              -- If not, we can't determine which component caused the false result
            end
            
            -- Track component with determined outcome if possible
            if component_outcome ~= nil then
              M.track_condition_execution(file_path, component, {outcome = component_outcome})
            else
              -- Otherwise just track execution without outcome
              M.track_condition_execution(file_path, component, nil)
            end
          -- For OR, if parent is true, at least one component is true
          -- If parent is false, both components must be false
          elseif condition.operator == "or" then
            local component_outcome
            if outcome == false then
              component_outcome = false -- Both must be false for OR to be false
            elseif outcome == true and logical_conditions[comp_id] then
              -- For true OR, we need to check if previous execution has determined this component's outcome
              if logical_conditions[comp_id].last_outcome ~= nil then
                component_outcome = logical_conditions[comp_id].last_outcome
              end
              -- If not, we can't determine which component caused the true result
            end
            
            -- Track component with determined outcome if possible
            if component_outcome ~= nil then
              M.track_condition_execution(file_path, component, {outcome = component_outcome})
            else
              -- Otherwise just track execution without outcome
              M.track_condition_execution(file_path, component, nil)
            end
          end
        end
      end
    end
  end
  
  -- Handle parent condition updates
  if condition.parent_id and condition.parent_id ~= "root" and logical_conditions[condition.parent_id] then
    local parent_condition = logical_conditions[condition.parent_id]
    parent_condition.executed = true
    parent_condition.execution_count = (parent_condition.execution_count or 0) + 1
    parent_condition.last_executed = os.time()
    
    -- Update parent outcome based on this component's outcome and the parent's operator
    if outcome ~= nil and parent_condition.operator then
      if parent_condition.operator == "and" then
        -- In an AND operation, if any component is false, the parent is false
        if outcome == false then
          parent_condition.executed_false = true
          parent_condition.false_count = (parent_condition.false_count or 0) + 1
          parent_condition.last_outcome = false
        end
        -- We can't determine parent is true unless all components are known true
      elseif parent_condition.operator == "or" then
        -- In an OR operation, if any component is true, the parent is true
        if outcome == true then
          parent_condition.executed_true = true
          parent_condition.true_count = (parent_condition.true_count or 0) + 1
          parent_condition.last_outcome = true
        end
        -- We can't determine parent is false unless all components are known false
      end
    end
    
    -- Store updated parent condition
    coverage_data.files[normalized_path].logical_conditions[parent_condition.id] = parent_condition
    
    -- Update global tracking for parent
    local parent_key = normalized_path .. ":" .. parent_condition.id
    coverage_data.conditions.all[parent_key] = true
    coverage_data.conditions.executed[parent_key] = true
    
    if parent_condition.executed_true then
      coverage_data.conditions.true_outcome[parent_key] = true
    end
    
    if parent_condition.executed_false then
      coverage_data.conditions.false_outcome[parent_key] = true
    end
    
    if parent_condition.executed_true and parent_condition.executed_false then
      coverage_data.conditions.fully_covered[parent_key] = true
    end
  end
  
  -- Verbose output for condition execution
  if config.verbose and logger.is_verbose_enabled() then
    logger.verbose("Executed condition", {
      condition_id = condition.id,
      type = condition.type,
      start_line = condition.start_line,
      end_line = condition.end_line,
      file_path = normalized_path,
      execution_count = condition_copy.execution_count,
      executed_true = condition_copy.executed_true or false,
      executed_false = condition_copy.executed_false or false,
      outcome = outcome,
      parent_id = condition.parent_id,
      operation = "track_condition_execution"
    })
  end
  
  return condition_copy
end

---@return coverage.debug_hook The reset debug hook module
-- Reset coverage data with enhanced structure
function M.reset()
  -- Reset coverage data with enhanced structure
  coverage_data = {
    files = {},                   -- File metadata and content
    lines = {},                   -- Legacy structure for backward compatibility
    executed_lines = {},          -- All lines that were executed (raw execution data)
    covered_lines = {},           -- Lines that are both executed and executable (coverage data)
    functions = {
      all = {},                   -- All functions (legacy structure)
      executed = {},              -- Functions that were executed
      covered = {}                -- Functions that are considered covered (executed + assertions)
    },
    blocks = {
      all = {},                   -- All blocks (legacy structure)
      executed = {},              -- Blocks that were executed
      covered = {}                -- Blocks that are considered covered (execution + assertions)
    },
    conditions = {
      all = {},                   -- All conditions (legacy structure)
      executed = {},              -- Conditions that were executed
      true_outcome = {},          -- Conditions that executed the true path
      false_outcome = {},         -- Conditions that executed the false path
      fully_covered = {}          -- Conditions where both outcomes were executed
    }
  }
  
  -- Reset tracking data
  tracked_files = {}
  
  -- Reset performance metrics
  performance_metrics = {
    hook_calls = 0,
    hook_execution_time = 0,
    hook_errors = 0,
    last_call_time = 0,
    average_call_time = 0,
    max_call_time = 0,
    line_events = 0,
    call_events = 0,
    return_events = 0
  }
  
  logger.debug("Debug hook reset", {
    operation = "reset",
    timestamp = os.time()
  })
  
  return M
end

--- Visualize line classification for a file
--- This function creates a detailed visualization of line classification for debugging purposes.
--- It shows execution status, coverage status, and classification details for each line.
---
--- @param file_path string Path to the file to visualize
--- @return table|nil lines Array of line data records or nil if file not tracked
--- @return string|nil error Error message if visualization failed
function M.visualize_line_classification(file_path)
  -- Validate file path
  if not file_path or type(file_path) ~= "string" then
    return nil, "File path must be a string"
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Check if file is being tracked
  if not coverage_data.files[normalized_path] then
    return nil, "File is not being tracked"
  end
  
  local file_data = coverage_data.files[normalized_path]
  local lines = {}
  
  -- Ensure static_analyzer is loaded
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Process each line in the file
  for i = 1, file_data.line_count do
    local is_executed = file_data._executed_lines[i] or false
    local is_covered = file_data.lines[i] or false
    local is_executable = file_data.executable_lines[i] or false
    
    -- Get detailed classification information
    local line_type = "unknown"
    local classification = {}
    
    -- Try to get line type from various sources
    if file_data.line_classification and file_data.line_classification[i] then
      -- Use stored classification from enhanced tracking
      classification = file_data.line_classification[i]
      if classification.content_type then
        line_type = classification.content_type
      end
    elseif file_data.code_map and file_data.code_map.lines and file_data.code_map.lines[i] then
      -- Use code map line type if available
      line_type = file_data.code_map.lines[i].type or "unknown"
    elseif file_data.code_map and file_data.code_map.line_types and file_data.code_map.line_types[i] then
      -- Fallback to code map line types
      line_type = file_data.code_map.line_types[i]
    end
    
    -- Get the source line text
    local source = file_data.source[i] or ""
    
    -- Determine coverage status
    local coverage_status = "not_executable"
    if is_executable then
      if is_covered then
        coverage_status = "covered"
      elseif is_executed then
        coverage_status = "executed_not_covered"
      else
        coverage_status = "executable_not_executed"
      end
    end
    
    -- Collect all data for this line
    table.insert(lines, {
      line_num = i,
      source = source,
      executed = is_executed,
      covered = is_covered,
      executable = is_executable,
      type = line_type,
      classification = classification,
      coverage_status = coverage_status,
      -- Add additional info for debugging
      execution_count = file_data._execution_counts and file_data._execution_counts[i] or 0,
      in_multiline_comment = file_data.parsing_context and 
                             file_data.parsing_context.multiline_comments and 
                             file_data.parsing_context.multiline_comments[i] or false,
      in_multiline_string = file_data.parsing_context and 
                            file_data.parsing_context.multiline_strings and 
                            file_data.parsing_context.multiline_strings[i] and
                            file_data.parsing_context.multiline_strings[i].in_string or false
    })
  end
  
  return lines
end

---@return table metrics Performance metrics for the debug hook
-- Get performance metrics
function M.get_performance_metrics()
  return {
    hook_calls = performance_metrics.hook_calls,
    line_events = performance_metrics.line_events,
    call_events = performance_metrics.call_events,
    return_events = performance_metrics.return_events,
    execution_time = performance_metrics.hook_execution_time,
    average_call_time = performance_metrics.average_call_time,
    max_call_time = performance_metrics.max_call_time,
    last_call_time = performance_metrics.last_call_time,
    error_count = performance_metrics.hook_errors
  }
end

return M