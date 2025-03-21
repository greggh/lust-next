---@class LCOVFormatter
---@field _VERSION string Module version
---@field format_coverage fun(coverage_data: {files: table<string, {lines: table<number, {executable: boolean, executed: boolean, covered: boolean, source: string}>, stats: {total: number, covered: number, executable: number, percentage: number}}>, summary: {total_lines: number, executed_lines: number, covered_lines: number, coverage_percentage: number}}): string|nil, table? Format coverage data as LCOV format
---@field get_config fun(): LCOVFormatterConfig Get current formatter configuration
---@field set_config fun(config: table): boolean Set formatter configuration options
---@field normalize_path fun(path: string): string Normalize file paths for LCOV format
---@field validate_coverage fun(coverage_data: table): boolean, string? Validate coverage data before formatting
---@field calculate_checksums fun(file_path: string): string|nil, table? Calculate checksum for a file
-- LCOV formatter for coverage reports
-- Creates output compatible with the LCOV format used by lcov/genhtml tools
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:LCOV")
local error_handler = require("lib.tools.error_handler")

-- Configure module logging
logging.configure_from_config("Reporting:LCOV")

---@class LCOVFormatterConfig
---@field normalize_paths boolean Whether to convert absolute paths to relative paths
---@field include_function_lines boolean Whether to include function line information
---@field use_actual_execution_counts boolean Whether to use actual execution count instead of binary 0/1
---@field include_checksums boolean Whether to include checksums in line records
---@field exclude_patterns string[] Patterns for files to exclude from report
---@field include_branch_data boolean Whether to include branch coverage data
---@field include_uncovered_lines boolean Whether to include lines that weren't covered
---@field root_dir? string Optional root directory for path normalization
---@field checksum_algorithm? string Algorithm for checksums (md5, sha1)
---@field max_line_length? number Maximum length for source lines
---@field include_source boolean Whether to include source filenames
---@field break_by_file boolean Whether to add separator between files
---@field include_test_name boolean Whether to include test name in output
---@field skip_empty_files boolean Whether to skip files with no executable lines

-- Define default configuration
---@type LCOVFormatterConfig
local DEFAULT_CONFIG = {
  normalize_paths = true,        -- Convert absolute paths to relative paths
  include_function_lines = true, -- Include function line information
  use_actual_execution_counts = false, -- Use actual execution count instead of binary 0/1
  include_checksums = false,     -- Include checksums in line records
  exclude_patterns = {}          -- Patterns for files to exclude from report
}

---@private
---@return LCOVFormatterConfig config The configuration for the LCOV formatter
-- Get configuration for this formatter
local function get_config()
  local formatter_config
  
  -- Try reporting module first
  local success, result = error_handler.try(function()
    local reporting = require("lib.reporting")
    if reporting.get_formatter_config then
      return reporting.get_formatter_config("lcov")
    end
    return nil
  end)
  
  if success and result then
    return result
  end
  
  -- Try central_config directly
  success, result = error_handler.try(function()
    local central_config = require("lib.core.central_config")
    return central_config.get("reporting.formatters.lcov")
  end)
  
  if success and result then
    return result
  end
  
  -- Fall back to defaults
  logger.debug("Using default configuration for LCOV formatter", {
    reason = "No custom configuration found in reporting or central_config"
  })
  return DEFAULT_CONFIG
end

---@private
---@param path string File path to normalize
---@param config LCOVFormatterConfig|nil Formatter configuration
---@return string normalized_path Normalized path based on configuration
-- Helper function to normalize path based on configuration
local function normalize_path(path, config)
  -- Validate inputs
  if type(path) ~= "string" then
    local err = error_handler.validation_error(
      "Path must be a string for normalization",
      {operation = "normalize_path", provided_type = type(path)}
    )
    logger.warn(err.message, err.context)
    return path or ""
  end
  
  -- Skip normalization if disabled in config
  if not config or not config.normalize_paths then
    return path
  end
  
  local normalized
  local success, result = error_handler.try(function()
    -- Implements basic path normalization to convert absolute paths to relative ones
    -- Remove common path prefixes like "/home/user/project/" 
    -- to create relative paths more suitable for LCOV consumers
    return path:gsub("^/home/[^/]+/[^/]+/", "")
  end)
  
  if success then
    normalized = result
  else
    logger.warn("Failed to normalize path, using original", {
      path = path,
      error = error_handler.format_error(result)
    })
    normalized = path
  end
  
  return normalized
end

---@private
---@param filename string File name to check
---@param config LCOVFormatterConfig|nil Formatter configuration
---@return boolean should_include Whether the file should be included in the report
-- Helper function to check if a file should be included in the report
local function should_include_file(filename, config)
  -- Validate inputs
  if type(filename) ~= "string" then
    local err = error_handler.validation_error(
      "Filename must be a string",
      {operation = "should_include_file", provided_type = type(filename)}
    )
    logger.warn(err.message, err.context)
    return true -- Default to including the file on error
  end
  
  if not config or not config.exclude_patterns or type(config.exclude_patterns) ~= "table" then
    return true
  end
  
  if #config.exclude_patterns == 0 then
    return true
  end
  
  -- Check against each exclude pattern with error handling
  for _, pattern in ipairs(config.exclude_patterns) do
    local success, match_result = error_handler.try(function()
      return filename:match(pattern) ~= nil
    end)
    
    if success and match_result then
      logger.debug("Excluding file based on pattern", {
        file = filename,
        pattern = pattern
      })
      return false
    end
  end
  
  return true
end

---@private
---@param tbl table|any Table to count entries in
---@return number count Number of entries in the table, 0 if not a table
-- Safe function to count table entries
local function safe_count(tbl)
  if type(tbl) ~= "table" then
    return 0
  end
  
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

---@private
---@param lcov_lines table Table of LCOV lines to add to
---@param record string Line to add to the LCOV output
---@return boolean success Whether the record was successfully added
-- Safe function to add a record to the LCOV output
local function add_record(lcov_lines, record)
  if not lcov_lines or type(lcov_lines) ~= "table" then
    return false
  end
  
  if not record or type(record) ~= "string" then
    return false
  end
  
  local success = error_handler.try(function()
    table.insert(lcov_lines, record)
    return true
  end)
  
  return success
end

---@private
---@param lcov_lines table Table of LCOV lines to add to
---@param file_data table File coverage data
---@param config LCOVFormatterConfig Formatter configuration
---@return boolean success Whether function data was successfully processed
-- Safe function to process function data
local function process_functions(lcov_lines, file_data, config)
  if not file_data.functions or not config.include_function_lines then
    return true -- No functions to process or not configured to include them
  end
  
  local success = true
  local fn_count = 0
  local fn_hit = 0
  
  -- Process each function with error handling
  for fn_name, is_covered in pairs(file_data.functions) do
    -- Skip non-string function names
    if type(fn_name) ~= "string" then
      logger.warn("Skipping function with non-string name", {
        name_type = type(fn_name)
      })
      goto continue_function
    end
    
    -- Extract line number with fallback
    local line_num = 1  -- Default to line 1
    if file_data.functions_info and 
       type(file_data.functions_info) == "table" and
       file_data.functions_info[fn_name] and 
       file_data.functions_info[fn_name].line then
      line_num = file_data.functions_info[fn_name].line
    end
    
    -- Validate line number
    if type(line_num) ~= "number" then
      logger.warn("Invalid line number for function", {
        function_name = fn_name,
        line_type = type(line_num)
      })
      line_num = 1 -- Fallback to line 1
    end
    
    -- Add function line entry (FN) with error handling
    local fn_success = add_record(lcov_lines, "FN:" .. line_num .. "," .. fn_name)
    if not fn_success then
      logger.warn("Failed to add function line entry", {
        function_name = fn_name,
        line = line_num
      })
      success = false
    end
    
    -- Add function execution count entry (FNDA)
    local execution_count = "0"
    if is_covered then
      execution_count = "1"
      fn_hit = fn_hit + 1
    end
    
    -- Try to get actual execution count if configured
    if config.use_actual_execution_counts and 
       file_data.functions_info and 
       file_data.functions_info[fn_name] and 
       file_data.functions_info[fn_name].execution_count then
      
      local ec_success, exec_count = error_handler.try(function()
        return tostring(file_data.functions_info[fn_name].execution_count)
      end)
      
      if ec_success then
        execution_count = exec_count
      else
        logger.warn("Failed to get execution count for function", {
          function_name = fn_name,
          error = error_handler.format_error(exec_count)
        })
      end
    end
    
    -- Add the FNDA entry
    fn_success = add_record(lcov_lines, "FNDA:" .. execution_count .. "," .. fn_name)
    if not fn_success then
      logger.warn("Failed to add function execution count entry", {
        function_name = fn_name,
        execution_count = execution_count
      })
      success = false
    end
    
    fn_count = fn_count + 1
    ::continue_function::
  end
  
  -- Add function count summaries
  success = add_record(lcov_lines, "FNF:" .. fn_count) and success
  success = add_record(lcov_lines, "FNH:" .. fn_hit) and success
  
  return success
end

---@private
---@param lcov_lines table Table of LCOV lines to add to
---@param file_data table File coverage data
---@param config LCOVFormatterConfig Formatter configuration
---@return boolean success Whether line data was successfully processed
-- Safe function to process line data
local function process_lines(lcov_lines, file_data, config)
  if not file_data.lines then
    return true -- No lines to process
  end
  
  local success = true
  local line_count = 0
  local line_hit = 0
  
  -- Process each line with error handling
  for line_num, is_covered in pairs(file_data.lines) do
    -- Skip non-numeric lines
    if type(line_num) ~= "number" then
      goto continue_line
    end
    
    -- Create the line entry with error handling
    local line_output_success, line_output = error_handler.try(function()
      local output = "DA:" .. line_num .. ","
      
      -- Determine execution count
      if config.use_actual_execution_counts and 
         file_data.execution_counts and 
         file_data.execution_counts[line_num] then
        output = output .. tostring(file_data.execution_counts[line_num])
      else
        output = output .. (is_covered and "1" or "0")
      end
      
      -- Add checksum if configured
      if config.include_checksums and file_data.source and file_data.source[line_num] then
        local source_line = file_data.source[line_num] or ""
        local checksum = tostring(#source_line)  -- Simple length-based checksum
        output = output .. "," .. checksum
      end
      
      return output
    end)
    
    if line_output_success then
      success = add_record(lcov_lines, line_output) and success
    else
      logger.warn("Failed to create line entry", {
        line = line_num,
        error = error_handler.format_error(line_output)
      })
      -- Add a minimal valid entry as fallback
      success = add_record(lcov_lines, "DA:" .. line_num .. ",0") and success
    end
    
    line_count = line_count + 1
    if is_covered then
      line_hit = line_hit + 1
    end
    
    ::continue_line::
  end
  
  -- Add line count summaries
  success = add_record(lcov_lines, "LF:" .. line_count) and success
  success = add_record(lcov_lines, "LH:" .. line_hit) and success
  
  return success
end

---@private
---@param lcov_lines table Table of LCOV lines to add to
---@param filename string File name
---@param file_data table File coverage data
---@param config LCOVFormatterConfig Formatter configuration
---@return boolean success Whether file data was successfully processed
-- Safe function to create a file entry
local function process_file(lcov_lines, filename, file_data, config)
  if not lcov_lines or not filename or not file_data then
    logger.warn("Missing required parameters for LCOV file entry", {
      has_lines = lcov_lines ~= nil,
      has_filename = filename ~= nil,
      has_file_data = file_data ~= nil
    })
    return false
  end
  
  -- Skip files that match exclude patterns
  if not should_include_file(filename, config) then
    logger.debug("Skipping excluded file", { file = filename })
    return true -- Successfully skipped (not an error)
  end
  
  local normalized_filename = normalize_path(filename, config)
  
  -- Add file record with error handling
  local success = add_record(lcov_lines, "SF:" .. normalized_filename)
  if not success then
    logger.warn("Failed to add file entry to LCOV report", { file = normalized_filename })
    return false
  end
  
  -- Process functions
  success = process_functions(lcov_lines, file_data, config)
  
  -- Process lines
  success = process_lines(lcov_lines, file_data, config) and success
  
  -- End the record
  success = add_record(lcov_lines, "end_of_record") and success
  
  return success
end

---@param coverage_data table|nil Coverage data from the coverage module
---@return string lcov_report LCOV format representation of the coverage data
-- Generate an LCOV format coverage report (used by many CI tools)
function M.format_coverage(coverage_data)
  -- Input validation
  if not coverage_data then
    logger.warn("Missing coverage data for LCOV report", {
      has_data = false
    })
    return "" -- Return empty string as fallback
  end
  
  local config
  local success, result = error_handler.try(function()
    return get_config()
  end)
  
  if success then
    config = result
  else
    logger.warn("Failed to get configuration, using defaults", {
      error = error_handler.format_error(result)
    })
    config = DEFAULT_CONFIG
  end
  
  -- Count files in a safer way
  local files_count = safe_count(coverage_data.files)
  
  logger.debug("Generating LCOV format coverage report", {
    has_data = coverage_data ~= nil,
    has_files = coverage_data and coverage_data.files ~= nil,
    files_count = files_count,
    config = config
  })
  
  -- Validate the input data to prevent runtime errors
  if not coverage_data.files or type(coverage_data.files) ~= "table" then
    logger.warn("Missing or invalid coverage data files for LCOV report", {
      has_files = coverage_data.files ~= nil,
      files_type = type(coverage_data.files)
    })
    return ""
  end
  
  local lcov_lines = {}
  local valid_report = false
  
  -- Process each file with proper error handling
  for filename, file_data in pairs(coverage_data.files) do
    local file_success
    
    -- Skip invalid files
    if type(filename) ~= "string" or type(file_data) ~= "table" then
      logger.warn("Skipping invalid file entry", {
        filename_type = type(filename),
        file_data_type = type(file_data)
      })
      goto continue
    end
    
    -- Process the file with error boundaries
    success, file_success = error_handler.try(function()
      return process_file(lcov_lines, filename, file_data, config)
    end)
    
    if success and file_success then
      valid_report = true
    else
      logger.warn("Error processing file for LCOV report", {
        file = filename,
        error = success and "Processing failed" or error_handler.format_error(file_success)
      })
    end
    
    ::continue::
  end
  
  -- Create a minimal valid report if all processing failed
  if not valid_report and #lcov_lines == 0 then
    logger.warn("Failed to create any valid LCOV entries, generating minimal valid report")
    add_record(lcov_lines, "SF:empty.lua")
    add_record(lcov_lines, "FNF:0")
    add_record(lcov_lines, "FNH:0")
    add_record(lcov_lines, "LF:0")
    add_record(lcov_lines, "LH:0")
    add_record(lcov_lines, "end_of_record")
  end
  
  -- Final assembly with error handling
  success, result = error_handler.try(function()
    return table.concat(lcov_lines, "\n")
  end)
  
  if success then
    return result
  else
    logger.error("Failed to generate LCOV report", {
      error = error_handler.format_error(result)
    })
    return "" -- Return empty string as ultimate fallback
  end
end

---@param formatters table Table of formatter registries
---@return boolean success True if registration was successful
---@return table|nil error Error object if registration failed
-- Register formatter
return function(formatters)
  -- Input validation
  if not formatters then
    local err = error_handler.validation_error(
      "Missing formatters registry for LCOV formatter registration",
      {operation = "lcov_formatter_registration"}
    )
    logger.error(err.message, err.context)
    return
  end
  
  -- Ensure coverage table exists
  if not formatters.coverage then
    local err = error_handler.validation_error(
      "Missing coverage section in formatters registry",
      {operation = "lcov_formatter_registration"}
    )
    logger.error(err.message, err.context)
    return
  end
  
  -- Register formatter with error handling
  local success, err = error_handler.try(function()
    formatters.coverage.lcov = M.format_coverage
    return true
  end)
  
  if not success then
    logger.error("Failed to register LCOV formatter", {
      error = error_handler.format_error(err)
    })
  else
    logger.debug("Successfully registered LCOV formatter")
  end
end
