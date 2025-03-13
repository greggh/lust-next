-- LCOV formatter for coverage reports
local M = {}

local logging = require("lib.tools.logging")
local logger = logging.get_logger("Reporting:LCOV")

-- Configure module logging
logging.configure_from_config("Reporting:LCOV")

-- Define default configuration
local DEFAULT_CONFIG = {
  normalize_paths = true,        -- Convert absolute paths to relative paths
  include_function_lines = true, -- Include function line information
  use_actual_execution_counts = false, -- Use actual execution count instead of binary 0/1
  include_checksums = false,     -- Include checksums in line records
  exclude_patterns = {}          -- Patterns for files to exclude from report
}

-- Get configuration for this formatter
local function get_config()
  -- Try reporting module first
  local ok, reporting = pcall(require, "lib.reporting")
  if ok and reporting.get_formatter_config then
    local formatter_config = reporting.get_formatter_config("lcov")
    if formatter_config then return formatter_config end
  end
  
  -- Try central_config directly
  local success, central_config = pcall(require, "lib.core.central_config")
  if success then
    local formatter_config = central_config.get("reporting.formatters.lcov")
    if formatter_config then return formatter_config end
  end
  
  -- Fall back to defaults
  return DEFAULT_CONFIG
end

-- Helper function to normalize path based on configuration
local function normalize_path(path, config)
  if not config.normalize_paths then
    return path
  end
  
  -- Implements basic path normalization to convert absolute paths to relative ones
  -- Remove common path prefixes like "/home/user/project/" 
  -- to create relative paths more suitable for LCOV consumers
  local normalized = path:gsub("^/home/[^/]+/[^/]+/", "")
  
  return normalized
end

-- Helper function to check if a file should be included in the report
local function should_include_file(filename, config)
  if not config.exclude_patterns or #config.exclude_patterns == 0 then
    return true
  end
  
  for _, pattern in ipairs(config.exclude_patterns) do
    if filename:match(pattern) then
      return false
    end
  end
  
  return true
end

-- Generate an LCOV format coverage report (used by many CI tools)
function M.format_coverage(coverage_data)
  local config = get_config()
  
  -- Count files in a safer way
  local files_count = 0
  if coverage_data and coverage_data.files then
    for _ in pairs(coverage_data.files) do
      files_count = files_count + 1
    end
  end
  
  logger.debug("Generating LCOV format coverage report", {
    has_data = coverage_data ~= nil,
    has_files = coverage_data and coverage_data.files ~= nil,
    files_count = files_count,
    config = config
  })
  
  -- Validate the input data to prevent runtime errors
  if not coverage_data or not coverage_data.files then
    logger.warn("Missing or invalid coverage data for LCOV report, returning empty report")
    return ""
  end
  
  local lcov_lines = {}
  
  -- Process each file
  for filename, file_data in pairs(coverage_data.files) do
    -- Skip files that match exclude patterns
    if not should_include_file(filename, config) then
      logger.debug("Skipping excluded file", { file = filename })
      goto continue
    end
    
    local normalized_filename = normalize_path(filename, config)
    
    -- Add file record
    table.insert(lcov_lines, "SF:" .. normalized_filename)
    
    -- Add function records (if available)
    if file_data.functions and config.include_function_lines then
      local fn_idx = 1
      for fn_name, is_covered in pairs(file_data.functions) do
        -- Extract line number from function if available
        local line_num = 1  -- Default to line 1
        if file_data.functions_info and file_data.functions_info[fn_name] and 
           file_data.functions_info[fn_name].line then
          line_num = file_data.functions_info[fn_name].line
        end
        
        -- FN:<line>,<function name>
        table.insert(lcov_lines, "FN:" .. line_num .. "," .. fn_name)
        
        -- FNDA:<execution count>,<function name>
        if config.use_actual_execution_counts and 
           file_data.functions_info and 
           file_data.functions_info[fn_name] and 
           file_data.functions_info[fn_name].execution_count then
          local exec_count = file_data.functions_info[fn_name].execution_count
          table.insert(lcov_lines, "FNDA:" .. exec_count .. "," .. fn_name)
        else
          table.insert(lcov_lines, "FNDA:" .. (is_covered and "1" or "0") .. "," .. fn_name)
        end
        
        fn_idx = fn_idx + 1
      end
      
      -- FNF:<number of functions found>
      local fn_count = 0
      for _ in pairs(file_data.functions) do fn_count = fn_count + 1 end
      table.insert(lcov_lines, "FNF:" .. fn_count)
      
      -- FNH:<number of functions hit>
      local fn_hit = 0
      for _, is_covered in pairs(file_data.functions) do
        if is_covered then fn_hit = fn_hit + 1 end
      end
      table.insert(lcov_lines, "FNH:" .. fn_hit)
    end
    
    -- Add line records
    if file_data.lines then
      for line_num, is_covered in pairs(file_data.lines) do
        if type(line_num) == "number" then
          -- DA:<line number>,<execution count>[,<checksum>]
          local line_output = "DA:" .. line_num .. ","
          
          -- Determine execution count
          if config.use_actual_execution_counts and 
             file_data.execution_counts and 
             file_data.execution_counts[line_num] then
            line_output = line_output .. file_data.execution_counts[line_num]
          else
            line_output = line_output .. (is_covered and "1" or "0")
          end
          
          -- Add checksum if configured
          if config.include_checksums and file_data.source and file_data.source[line_num] then
            local checksum = tostring(#(file_data.source[line_num] or ""))  -- Simple length-based checksum
            line_output = line_output .. "," .. checksum
          end
          
          table.insert(lcov_lines, line_output)
        end
      end
      
      -- LF:<number of lines found>
      local line_count = 0
      for k, _ in pairs(file_data.lines) do
        if type(k) == "number" then line_count = line_count + 1 end
      end
      table.insert(lcov_lines, "LF:" .. line_count)
      
      -- LH:<number of lines hit>
      local line_hit = 0
      for k, is_covered in pairs(file_data.lines) do
        if type(k) == "number" and is_covered then line_hit = line_hit + 1 end
      end
      table.insert(lcov_lines, "LH:" .. line_hit)
    end
    
    -- End of record
    table.insert(lcov_lines, "end_of_record")
    
    ::continue::
  end
  
  return table.concat(lcov_lines, "\n")
end

-- Register formatter
return function(formatters)
  formatters.coverage.lcov = M.format_coverage
end