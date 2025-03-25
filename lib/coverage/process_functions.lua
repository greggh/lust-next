---@class coverage.process_functions
---@field process_functions_from_file fun(file_path: string, source_text?: string): {functions: {name: string, line: number, end_line: number}[], functions_identified: number} | nil, table? Process functions from a file
---@field process_all_functions fun(): boolean | nil, table? Process functions from all tracked files
---@field enhance_report_data fun(report_data: table): boolean | nil, table? Enhance report data with function statistics
---@field get_function_stats fun(): {total_functions: number, executed_functions: number, covered_functions: number, function_coverage_percent: number, functions_by_file: table<string, {total: number, executed: number, coverage_percent: number}>} Get function statistics from debug_hook and other sources

--- Function processing module for coverage system
--- Analyzes source code to identify functions and their locations, and processes
--- function execution data for reporting.
---
--- @author Firmo Team
--- @version 1.0.0
local M = {}

local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("coverage.process_functions")

-- Internal state
local debug_hook -- Will be imported when needed

--- Process functions from a file to identify their names and locations
---@param file_path string The path to the file to process
---@param source_text? string Optional source text (if already loaded)
---@return {name: string, line: number, end_line: number}[] | nil functions List of functions found in the file
---@return table | nil error Error information if processing failed
function M.process_functions_from_file(file_path, source_text)
  -- Get source text if not provided
  if not source_text then
    local success, result, err = error_handler.try(function()
      return fs.read_file(file_path)
    end)
    
    if not success then
      return nil, error_handler.io_error(
        "Failed to read file for function processing",
        {
          file_path = file_path,
          error = error_handler.format_error(result)
        }
      )
    end
    
    source_text = result
  end
  
  -- Simple function pattern for all Lua files
  local functions = {}
  
  -- Process all files consistently - no special cases
  
  -- Process the source text to find functions
  -- This is a simple pattern matching approach that works for basic cases
  -- Consider using a proper Lua parser for more complex analysis
  
  -- Regular patterns for function declarations
  local patterns = {
    -- Function name = function(...) pattern
    "([%w_%.]+)%s*=%s*function%s*%([^%)]*%)",
    -- function name(...) pattern
    "function%s+([%w_%.]+)%s*%([^%)]*%)",
    -- local function name(...) pattern
    "local%s+function%s+([%w_%.]+)%s*%([^%)]*%)"
  }
  
  -- Extract line numbers and function names
  for i, pattern in ipairs(patterns) do
    local pos = 1
    while true do
      local start_pos, end_pos, func_name = source_text:find(pattern, pos)
      if not start_pos then break end
      
      -- Calculate line number
      local line_num = 1
      for _ in source_text:sub(1, start_pos):gmatch("\n") do
        line_num = line_num + 1
      end
      
      -- Calculate end line (approximate)
      local end_line = line_num
      local nested_level = 0
      local search_pos = end_pos
      
      -- Scan for function end by looking for balanced 'end' tokens
      while search_pos < #source_text do
        -- Look for 'function' keyword that increases nesting
        local function_start = source_text:find("function", search_pos + 1)
        local end_token = source_text:find("end", search_pos + 1)
        
        -- No more end tokens found
        if not end_token then break end
        
        -- Found nested function before end
        if function_start and function_start < end_token then
          nested_level = nested_level + 1
          search_pos = function_start
        else
          -- Found end token
          if nested_level == 0 then
            -- This is our function's end
            -- Calculate end line
            for _ in source_text:sub(1, end_token):gmatch("\n") do
              end_line = end_line + 1
            end
            break
          else
            -- This ends a nested function
            nested_level = nested_level - 1
            search_pos = end_token
          end
        end
      end
      
      -- Store function info
      table.insert(functions, {
        name = func_name,
        line = line_num,
        end_line = end_line
      })
      
      -- Continue search from end of this match
      pos = end_pos + 1
    end
  end
  
  -- Extract basename manually since fs.basename may not be available
  local basename = file_path:match("([^/\\]+)$") or file_path
  
  logger.debug("Processed functions from file", {
    file_path = basename,
    function_count = #functions
  })
  
  -- Return functions with additional statistics
  return {
    functions = functions,
    functions_identified = #functions
  }
end

--- Process functions from all tracked files
---@return boolean | nil success Whether the operation was successful
---@return table | nil error Error information if processing failed
function M.process_all_functions()
  -- Lazy load debug_hook
  if not debug_hook then
    local success, result = pcall(require, "lib.coverage.debug_hook")
    if not success then
      return nil, error_handler.runtime_error(
        "Failed to load debug_hook module",
        {
          error = tostring(result),
          operation = "process_all_functions"
        }
      )
    end
    debug_hook = result
  end
  
  -- Get coverage data
  local success, result, err = error_handler.try(function()
    return debug_hook.get_coverage_data()
  end)
  
  if not success then
    return nil, error_handler.runtime_error(
      "Failed to get coverage data",
      {
        error = error_handler.format_error(result),
        operation = "process_all_functions"
      }
    )
  end
  
  local data = result
  
  -- Process each file
  for file_path, file_data in pairs(data.files or {}) do
    -- Skip files without source text
    if not file_data.source_text then
      logger.debug("Skipping file without source text", {
        file_path = file_path
      })
      goto continue
    end
    
    -- Process functions
    local functions, err = M.process_functions_from_file(file_path, file_data.source_text)
    if not functions then
      logger.warn("Failed to process functions from file: " .. error_handler.format_error(err), {
        file_path = file_path
      })
      goto continue
    end
    
    -- Save functions to debug_hook data
    for _, func_info in ipairs(functions) do
      -- Create function tracking structures if needed
      data.functions = data.functions or {}
      data.functions.all = data.functions.all or {}
      data.functions.all[file_path] = data.functions.all[file_path] or {}
      
      -- Store function info
      data.functions.all[file_path][func_info.line] = func_info.name
    end
    
    -- No special handling for any specific files
    
    ::continue::
  end
  
  return true
end

--- Get function statistics from debug_hook
---@return {total_functions: number, executed_functions: number, covered_functions: number, function_coverage_percent: number, functions_by_file: table<string, {total: number, executed: number, coverage_percent: number}>} stats Function statistics
function M.get_function_stats()
  -- Lazy load debug_hook
  if not debug_hook then
    local success, result = pcall(require, "lib.coverage.debug_hook")
    if not success then
      logger.warn("Failed to load debug_hook module: " .. tostring(result))
      return {
        total_functions = 0,
        executed_functions = 0,
        covered_functions = 0,
        function_coverage_percent = 0,
        functions_by_file = {}
      }
    end
    debug_hook = result
  end
  
  -- Get coverage data
  local success, result = error_handler.try(function()
    return debug_hook.get_coverage_data()
  end)
  
  if not success then
    logger.warn("Failed to get coverage data: " .. error_handler.format_error(result))
    return {
      total_functions = 0,
      executed_functions = 0,
      covered_functions = 0,
      function_coverage_percent = 0,
      functions_by_file = {}
    }
  end
  
  local data = result
  
  -- Initialize stats
  local stats = {
    total_functions = 0,
    executed_functions = 0,
    covered_functions = 0,
    function_coverage_percent = 0,
    functions_by_file = {}
  }
  
  -- Process function data
  if data.functions then
    -- Process all functions
    for file_path, funcs in pairs(data.functions.all or {}) do
      -- Initialize file stats
      stats.functions_by_file[file_path] = {
        total = 0,
        executed = 0,
        coverage_percent = 0
      }
      
      -- Count total functions
      for line, func_name in pairs(funcs) do
        stats.total_functions = stats.total_functions + 1
        stats.functions_by_file[file_path].total = stats.functions_by_file[file_path].total + 1
        
        -- Check if the function is executed by looking at the function's starting line
        -- First check direct function execution tracking
        local executed = data.functions.executed and 
                        data.functions.executed[file_path] and 
                        data.functions.executed[file_path][line]
        
        -- Then check if its starting line was executed (line coverage)
        if not executed and data.files and data.files[file_path] and 
           data.files[file_path]._executed_lines and 
           data.files[file_path]._executed_lines[line] then
          executed = true
          
          -- Also mark function as executed in function tracking
          data.functions.executed = data.functions.executed or {}
          data.functions.executed[file_path] = data.functions.executed[file_path] or {}
          data.functions.executed[file_path][line] = true
        end
        
        if executed then
          stats.executed_functions = stats.executed_functions + 1
          stats.functions_by_file[file_path].executed = stats.functions_by_file[file_path].executed + 1
          
          -- CRITICAL FIX: Always mark executed functions as covered
          -- This ensures consistency with line coverage behavior
          
          -- Ensure the covered table exists and is updated
          data.functions.covered = data.functions.covered or {}
          data.functions.covered[file_path] = data.functions.covered[file_path] or {}
          data.functions.covered[file_path][line] = true
          
          -- Count it as covered
          stats.covered_functions = stats.covered_functions + 1
        else
          -- Check existing covered status (from assertions or other sources)
          local already_covered = (data.functions.covered and 
                           data.functions.covered[file_path] and 
                           data.functions.covered[file_path][line])
                           
          if already_covered then
            stats.covered_functions = stats.covered_functions + 1
          end
        end
      end
      
      -- Calculate file coverage percentage
      if stats.functions_by_file[file_path].total > 0 then
        -- Track covered functions per file
        stats.functions_by_file[file_path].covered = 0
        
        -- Count covered functions for this file
        if data.functions.covered and data.functions.covered[file_path] then
          for line, _ in pairs(data.functions.covered[file_path]) do
            stats.functions_by_file[file_path].covered = stats.functions_by_file[file_path].covered + 1
          end
        end
        
        -- Use covered functions (not executed) for coverage percentage
        stats.functions_by_file[file_path].coverage_percent = 
          stats.functions_by_file[file_path].covered / stats.functions_by_file[file_path].total * 100
      end
    end
    
    -- Calculate overall coverage percentage
    if stats.total_functions > 0 then
      stats.function_coverage_percent = stats.covered_functions / stats.total_functions * 100
    end
  end
  
  return stats
end

--- Function to ensure executed functions are properly marked as covered
---@param report_data table The report data to process
---@return boolean success Whether the operation was successful
function M.ensure_function_coverage_consistency(report_data)
  if not report_data or not report_data.files then
    return true
  end
  
  -- For each file in the report
  for file_path, file_data in pairs(report_data.files) do
    -- Skip files without function data
    if not file_data.functions then
      goto continue
    end
    
    -- Count executed vs covered functions
    local total_functions = 0
    local executed_functions = 0
    local covered_functions = 0
    
    -- Ensure all executed functions are marked as covered
    for line_num, func_data in pairs(file_data.functions) do
      total_functions = total_functions + 1
      
      -- Check if the function was executed
      if func_data.executed then
        executed_functions = executed_functions + 1
        
        -- CRITICAL FIX: Always mark executed functions as covered
        func_data.covered = true
        covered_functions = covered_functions + 1
      end
    end
    
    -- Update file's function coverage statistics
    file_data.total_functions = total_functions
    file_data.executed_functions = executed_functions
    file_data.covered_functions = covered_functions
    file_data.function_coverage_percent = 
      total_functions > 0 and (covered_functions / total_functions * 100) or 0
    
    ::continue::
  end
  
  return true
end

--- Enhance report data with function statistics
---@param report_data table The report data to enhance
---@return boolean | nil success Whether the operation was successful
---@return table | nil error Error information if enhancement failed
function M.enhance_report_data(report_data)
  if not report_data then
    return nil, error_handler.validation_error(
      "Report data must be provided",
      {operation = "enhance_report_data"}
    )
  end
  
  -- Ensure executed functions are consistently marked as covered
  M.ensure_function_coverage_consistency(report_data)
  
  -- Get function statistics
  local function_stats = M.get_function_stats()
  
  -- Update report summary with function statistics
  report_data.summary = report_data.summary or {}
  report_data.summary.total_functions = function_stats.total_functions
  report_data.summary.covered_functions = function_stats.covered_functions
  report_data.summary.function_coverage_percent = function_stats.function_coverage_percent
  
  -- Process all files to ensure line coverage data is consistent
  for file_path, file_data in pairs(report_data.files or {}) do
    -- Initialize or update file stats
    file_data.stats = file_data.stats or {
      total = 0,
      covered = 0,
      executable = 0,
      percentage = 0
    }
    
    -- Count executed and executable lines
    local executable_lines = 0
    local covered_lines = 0
    
    -- Mark any executed lines as both executable and covered
    if file_data._executed_lines then
      for line_num, _ in pairs(file_data._executed_lines) do
        -- Initialize lines table if needed
        file_data.lines = file_data.lines or {}
        file_data.lines[line_num] = file_data.lines[line_num] or {}
        
        -- Mark the line as executable, executed, and covered
        file_data.lines[line_num].executable = true
        file_data.lines[line_num].covered = true
        file_data.lines[line_num].executed = true
        
        executable_lines = executable_lines + 1
        covered_lines = covered_lines + 1
      end
      
      -- Update file stats
      file_data.stats.total = executable_lines
      file_data.stats.covered = covered_lines
      file_data.stats.executable = executable_lines
      file_data.stats.percentage = executable_lines > 0 and (covered_lines / executable_lines * 100) or 0
      
      -- Also update the global summary
      report_data.summary.total_lines = (report_data.summary.total_lines or 0) + executable_lines
      report_data.summary.covered_lines = (report_data.summary.covered_lines or 0) + covered_lines
      report_data.summary.line_coverage_percent = 
        report_data.summary.total_lines > 0 and 
        (report_data.summary.covered_lines / report_data.summary.total_lines * 100) or 0
    end
  end
  
  -- Update individual files with function statistics
  for file_path, file_stats in pairs(function_stats.functions_by_file or {}) do
    if report_data.files[file_path] then
      report_data.files[file_path].total_functions = file_stats.total
      report_data.files[file_path].covered_functions = file_stats.covered
      report_data.files[file_path].function_coverage_percent = file_stats.coverage_percent
    end
  end
  
  return true
end

return M