-- lust-next reporting module
-- Centralized module for all report generation and file output

local M = {}

-- Load the JSON module if available
local json_module
local ok, mod = pcall(require, "lib.reporting.json")
if ok then
  json_module = mod
else
  -- Simple fallback JSON encoder if module isn't available
  json_module = {
    encode = function(t)
      if type(t) ~= "table" then return tostring(t) end
      local s = "{"
      local first = true
      for k, v in pairs(t) do
        if not first then s = s .. "," else first = false end
        if type(k) == "string" then
          s = s .. '"' .. k .. '":'
        else
          s = s .. "[" .. tostring(k) .. "]:"
        end
        if type(v) == "table" then
          s = s .. json_module.encode(v)
        elseif type(v) == "string" then
          s = s .. '"' .. v .. '"'
        elseif type(v) == "number" or type(v) == "boolean" then
          s = s .. tostring(v)
        else
          s = s .. '"' .. tostring(v) .. '"'
        end
      end
      return s .. "}"
    end
  }
end

-- Helper function to escape XML special characters
local function escape_xml(str)
  if type(str) ~= "string" then
    return tostring(str or "")
  end
  
  return str:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub("\"", "&quot;")
            :gsub("'", "&apos;")
end

---------------------------
-- REPORT DATA STRUCTURES
---------------------------

-- Standard data structures that modules should return

-- Coverage report data structure
-- Modules should return this structure instead of directly generating reports
M.CoverageData = {
  -- Example structure that modules should follow:
  -- files = {}, -- Data per file (line execution, function calls)
  -- summary = {  -- Overall statistics
  --   total_files = 0,
  --   covered_files = 0,
  --   total_lines = 0,
  --   covered_lines = 0,
  --   total_functions = 0,
  --   covered_functions = 0,
  --   line_coverage_percent = 0,
  --   function_coverage_percent = 0, 
  --   overall_percent = 0
  -- }
}

-- Quality report data structure
-- Modules should return this structure instead of directly generating reports
M.QualityData = {
  -- Example structure that modules should follow:
  -- level = 0, -- Achieved quality level (0-5)
  -- level_name = "", -- Level name (e.g., "basic", "standard", etc.)
  -- tests = {}, -- Test data with assertions, patterns, etc.
  -- summary = {
  --   tests_analyzed = 0,
  --   tests_passing_quality = 0,
  --   quality_percent = 0,
  --   assertions_total = 0,
  --   assertions_per_test_avg = 0,
  --   issues = {}
  -- }
}

-- Test results data structure for JUnit XML and other test reporters
M.TestResultsData = {
  -- Example structure that modules should follow:
  -- name = "TestSuite", -- Name of the test suite
  -- timestamp = "2023-01-01T00:00:00", -- ISO 8601 timestamp
  -- tests = 0, -- Total number of tests
  -- failures = 0, -- Number of failed tests
  -- errors = 0, -- Number of tests with errors
  -- skipped = 0, -- Number of skipped tests
  -- time = 0, -- Total execution time in seconds
  -- test_cases = { -- Array of test case results
  --   {
  --     name = "test_name",
  --     classname = "test_class", -- Usually module/file name
  --     time = 0, -- Execution time in seconds
  --     status = "pass", -- One of: pass, fail, error, skipped, pending
  --     failure = { -- Only present if status is fail
  --       message = "Failure message",
  --       type = "Assertion",
  --       details = "Detailed failure information"
  --     },
  --     error = { -- Only present if status is error
  --       message = "Error message",
  --       type = "RuntimeError", 
  --       details = "Stack trace or error details"
  --     }
  --   }
  -- }
}

---------------------------
-- REPORT FORMATTERS
---------------------------

-- Formatter registries for built-in and custom formatters
local formatters = {
  coverage = {},     -- Coverage report formatters
  quality = {},      -- Quality report formatters
  results = {}       -- Test results formatters
}

-- Load and register all formatter modules
local ok, formatter_registry = pcall(require, "lib.reporting.formatters.init")
if ok then
  formatter_registry.register_all(formatters)
else
  print("WARNING: Failed to load formatter registry. Using fallback formatters.")
  -- Fallback formatter for coverage reports
  formatters.coverage.summary = function(coverage_data)
    return {
      files = coverage_data and coverage_data.files or {},
      total_files = 0,
      covered_files = 0,
      files_pct = 0,
      total_lines = 0,
      covered_lines = 0,
      lines_pct = 0,
      overall_pct = 0
    }
  end
end

-- Local references to formatter registries
local coverage_formatters = formatters.coverage
local quality_formatters = formatters.quality
local results_formatters = formatters.results

---------------------------
-- CUSTOM FORMATTER REGISTRATION
---------------------------

-- Register a custom coverage report formatter
function M.register_coverage_formatter(name, formatter_fn)
  if type(name) ~= "string" then
    error("Formatter name must be a string")
  end
  
  if type(formatter_fn) ~= "function" then
    error("Formatter must be a function")
  end
  
  -- Register the formatter
  formatters.coverage[name] = formatter_fn
  
  return true
end

-- Register a custom quality report formatter
function M.register_quality_formatter(name, formatter_fn)
  if type(name) ~= "string" then
    error("Formatter name must be a string")
  end
  
  if type(formatter_fn) ~= "function" then
    error("Formatter must be a function")
  end
  
  -- Register the formatter
  formatters.quality[name] = formatter_fn
  
  return true
end

-- Register a custom test results formatter
function M.register_results_formatter(name, formatter_fn)
  if type(name) ~= "string" then
    error("Formatter name must be a string")
  end
  
  if type(formatter_fn) ~= "function" then
    error("Formatter must be a function")
  end
  
  -- Register the formatter
  formatters.results[name] = formatter_fn
  
  return true
end

-- Load formatters from a module (table with format functions)
function M.load_formatters(formatter_module)
  if type(formatter_module) ~= "table" then
    error("Formatter module must be a table")
  end
  
  local registered = 0
  
  -- Register coverage formatters
  if type(formatter_module.coverage) == "table" then
    for name, fn in pairs(formatter_module.coverage) do
      if type(fn) == "function" then
        M.register_coverage_formatter(name, fn)
        registered = registered + 1
      end
    end
  end
  
  -- Register quality formatters
  if type(formatter_module.quality) == "table" then
    for name, fn in pairs(formatter_module.quality) do
      if type(fn) == "function" then
        M.register_quality_formatter(name, fn)
        registered = registered + 1
      end
    end
  end
  
  -- Register test results formatters
  if type(formatter_module.results) == "table" then
    for name, fn in pairs(formatter_module.results) do
      if type(fn) == "function" then
        M.register_results_formatter(name, fn)
        registered = registered + 1
      end
    end
  end
  
  return registered
end

-- Get list of available formatters for each type
function M.get_available_formatters()
  local available = {
    coverage = {},
    quality = {},
    results = {}
  }
  
  -- Collect formatter names
  for name, _ in pairs(formatters.coverage) do
    table.insert(available.coverage, name)
  end
  
  for name, _ in pairs(formatters.quality) do
    table.insert(available.quality, name)
  end
  
  for name, _ in pairs(formatters.results) do
    table.insert(available.results, name)
  end
  
  -- Sort for consistent results
  table.sort(available.coverage)
  table.sort(available.quality)
  table.sort(available.results)
  
  return available
end

---------------------------
-- FORMAT OUTPUT FUNCTIONS
---------------------------

-- Format coverage data
function M.format_coverage(coverage_data, format)
  format = format or "summary"
  
  -- Use the appropriate formatter
  if formatters.coverage[format] then
    return formatters.coverage[format](coverage_data)
  else
    -- Default to summary if format not supported
    return formatters.coverage.summary(coverage_data)
  end
end

-- Format quality data
function M.format_quality(quality_data, format)
  format = format or "summary"
  
  -- Use the appropriate formatter
  if formatters.quality[format] then
    return formatters.quality[format](quality_data)
  else
    -- Default to summary if format not supported
    return formatters.quality.summary(quality_data)
  end
end

-- Format test results data
function M.format_results(results_data, format)
  format = format or "junit"
  
  -- Use the appropriate formatter
  if formatters.results[format] then
    return formatters.results[format](results_data)
  else
    -- Default to JUnit if format not supported
    return formatters.results.junit(results_data)
  end
end

---------------------------
-- FILE I/O FUNCTIONS
---------------------------

-- Utility function to create directory if it doesn't exist
local function ensure_directory(dir_path)
  -- Extract directory part (trying different approaches for reliability)
  if type(dir_path) ~= "string" then 
    print("ERROR [Reporting] Invalid directory path: " .. tostring(dir_path))
    return false, "Invalid directory path" 
  end
  
  -- Skip if it's just a filename with no directory component
  if not dir_path:match("[/\\]") then 
    print("DEBUG [Reporting] No directory component in path: " .. dir_path)
    return true 
  end
  
  local last_separator = dir_path:match("^(.*)[\\/][^\\/]*$")
  if not last_separator then 
    print("DEBUG [Reporting] No directory part found in: " .. dir_path)
    return true 
  end
  
  print("DEBUG [Reporting] Extracted directory part: " .. last_separator)
  
  -- Check if directory already exists
  local test_cmd = package.config:sub(1,1) == "\\" and
    "if exist \"" .. last_separator .. "\\*\" (exit 0) else (exit 1)" or
    "test -d \"" .. last_separator .. "\""
  
  local dir_exists = os.execute(test_cmd)
  if dir_exists == true or dir_exists == 0 then
    print("DEBUG [Reporting] Directory already exists: " .. last_separator)
    return true
  end
  
  -- Create the directory
  print("DEBUG [Reporting] Creating directory: " .. last_separator)
  
  -- Use platform appropriate command
  local command = package.config:sub(1,1) == "\\" and
    "mkdir \"" .. last_separator .. "\"" or
    "mkdir -p \"" .. last_separator .. "\""
  
  print("DEBUG [Reporting] Running mkdir command: " .. command)
  local result = os.execute(command)
  
  -- Check result
  local success = (result == true or result == 0 or result == 1)
  if success then
    print("DEBUG [Reporting] Successfully created directory: " .. last_separator)
  else
    print("ERROR [Reporting] Failed to create directory: " .. last_separator .. " (result: " .. tostring(result) .. ")")
  end
  
  return success, success and nil or "Failed to create directory: " .. last_separator
end

-- Write content to a file
function M.write_file(file_path, content)
  print("DEBUG [Reporting] Writing file: " .. file_path)
  print("DEBUG [Reporting] Content length: " .. (content and #content or 0) .. " bytes")
  
  -- Create directory if needed
  print("DEBUG [Reporting] Ensuring directory exists...")
  local dir_ok, dir_err = ensure_directory(file_path)
  if not dir_ok then
    print("ERROR [Reporting] Failed to create directory: " .. tostring(dir_err))
    -- Try direct mkdir as fallback
    local dir_path = file_path:match("^(.*)[\\/][^\\/]*$")
    if dir_path then
      print("DEBUG [Reporting] Attempting direct mkdir -p: " .. dir_path)
      os.execute("mkdir -p \"" .. dir_path .. "\"")
    end
  end
  
  -- Open the file for writing
  print("DEBUG [Reporting] Opening file for writing...")
  local file, err = io.open(file_path, "w")
  if not file then
    print("ERROR [Reporting] Could not open file for writing: " .. tostring(err))
    return false, "Could not open file for writing: " .. tostring(err)
  end
  
  -- Write content and close
  print("DEBUG [Reporting] Writing content...")
  local write_ok, write_err = pcall(function()
    -- Make sure content is a string
    if type(content) == "table" then
      content = json_module.encode(content)
    end
    
    -- If still not a string, convert to string
    if type(content) ~= "string" then
      content = tostring(content)
    end
    
    file:write(content)
    file:close()
  end)
  
  if not write_ok then
    print("ERROR [Reporting] Error writing to file: " .. tostring(write_err))
    return false, "Error writing to file: " .. tostring(write_err)
  end
  
  print("DEBUG [Reporting] Successfully wrote file: " .. file_path)
  return true
end

-- Save a coverage report to file
function M.save_coverage_report(file_path, coverage_data, format)
  format = format or "html"
  
  -- Format the coverage data
  local content = M.format_coverage(coverage_data, format)
  
  -- Write to file
  return M.write_file(file_path, content)
end

-- Save a quality report to file
function M.save_quality_report(file_path, quality_data, format)
  format = format or "html"
  
  -- Format the quality data
  local content = M.format_quality(quality_data, format)
  
  -- Write to file
  return M.write_file(file_path, content)
end

-- Save a test results report to file
function M.save_results_report(file_path, results_data, format)
  format = format or "junit"
  
  -- Format the test results data
  local content = M.format_results(results_data, format)
  
  -- Write to file
  return M.write_file(file_path, content)
end

-- Auto-save reports to configured locations
-- Options can be:
-- - string: base directory (backward compatibility)
-- - table: configuration with properties:
--   * report_dir: base directory for reports (default: "./coverage-reports")
--   * report_suffix: suffix to add to all report filenames (optional)
--   * coverage_path_template: path template for coverage reports (optional)
--   * quality_path_template: path template for quality reports (optional)
--   * results_path_template: path template for test results reports (optional)
--   * timestamp_format: format string for timestamps in templates (default: "%Y-%m-%d")
--   * verbose: enable verbose logging (default: false)
function M.auto_save_reports(coverage_data, quality_data, results_data, options)
  -- Handle both string (backward compatibility) and table options
  local config = {}
  
  if type(options) == "string" then
    config.report_dir = options
  elseif type(options) == "table" then
    config = options
  end
  
  -- Set defaults for missing values
  config.report_dir = config.report_dir or "./coverage-reports"
  config.report_suffix = config.report_suffix or ""
  config.timestamp_format = config.timestamp_format or "%Y-%m-%d"
  config.verbose = config.verbose or false
  
  local base_dir = config.report_dir
  local results = {}
  
  -- Helper function for path templates
  local function process_template(template, format, type)
    -- If no template provided, use default filename pattern
    if not template then
      return base_dir .. "/" .. type .. "-report" .. config.report_suffix .. "." .. format
    end
    
    -- Get current timestamp
    local timestamp = os.date(config.timestamp_format)
    local datetime = os.date("%Y-%m-%d_%H-%M-%S")
    
    -- Replace placeholders in template
    local path = template:gsub("{format}", format)
                        :gsub("{type}", type)
                        :gsub("{date}", timestamp)
                        :gsub("{datetime}", datetime)
                        :gsub("{suffix}", config.report_suffix)
    
    -- If path doesn't start with / or X:\ (absolute), prepend base_dir
    if not path:match("^[/\\]") and not path:match("^%a:[/\\]") then
      path = base_dir .. "/" .. path
    end
    
    -- If path doesn't have an extension and format is provided, add extension
    if format and not path:match("%.%w+$") then
      path = path .. "." .. format
    end
    
    return path
  end
  
  -- Debug output for troubleshooting
  if config.verbose then
    print("DEBUG [Reporting] auto_save_reports called with:")
    print("  base_dir: " .. base_dir)
    print("  coverage_data: " .. (coverage_data and "present" or "nil"))
    if coverage_data then
      print("    total_files: " .. (coverage_data.summary and coverage_data.summary.total_files or "unknown"))
      print("    total_lines: " .. (coverage_data.summary and coverage_data.summary.total_lines or "unknown"))
      
      -- Print file count to help diagnose data flow issues
      local file_count = 0
      if coverage_data.files then
        for file, _ in pairs(coverage_data.files) do
          file_count = file_count + 1
          if file_count <= 5 then -- Just print first 5 files for brevity
            print("    - File: " .. file)
          end
        end
        print("    Total files tracked: " .. file_count)
      else
        print("    No files tracked in coverage data")
      end
    end
    print("  quality_data: " .. (quality_data and "present" or "nil"))
    if quality_data then
      print("    tests_analyzed: " .. (quality_data.summary and quality_data.summary.tests_analyzed or "unknown"))
    end
    print("  results_data: " .. (results_data and "present" or "nil"))
    if results_data then
      print("    tests: " .. (results_data.tests or "unknown"))
      print("    failures: " .. (results_data.failures or "unknown"))
    end
  end
  
  -- Try different directory creation methods to ensure success
  if config.verbose then
    print("DEBUG [Reporting] Ensuring directory exists using multiple methods...")
  end
  
  -- First, try the standard ensure_directory function
  local dir_ok, dir_err = ensure_directory(base_dir)
  if not dir_ok then
    if config.verbose then
      print("WARNING [Reporting] Standard directory creation failed: " .. tostring(dir_err))
      print("DEBUG [Reporting] Trying direct mkdir -p command...")
    end
    
    -- Try direct mkdir command as fallback
    os.execute('mkdir -p "' .. base_dir .. '"')
    
    -- Verify directory exists after fallback
    local test_cmd = package.config:sub(1,1) == "\\" and
      'if exist "' .. base_dir .. '\\*" (exit 0) else (exit 1)' or
      'test -d "' .. base_dir .. '"'
    
    local exists = os.execute(test_cmd)
    if exists == true or exists == 0 then
      if config.verbose then
        print("DEBUG [Reporting] Directory created successfully with fallback method")
      end
      dir_ok = true
    else
      if config.verbose then
        print("ERROR [Reporting] Failed to create directory with all methods")
      end
      dir_ok = false
    end
  elseif config.verbose then
    print("DEBUG [Reporting] Directory exists or was created: " .. base_dir)
  end
  
  -- Always save coverage reports in multiple formats if coverage data is provided
  if coverage_data then
    -- Save reports in multiple formats
    local formats = {"html", "json", "lcov", "cobertura"}
    
    for _, format in ipairs(formats) do
      local path = process_template(config.coverage_path_template, format, "coverage")
      
      if config.verbose then
        print("DEBUG [Reporting] Saving " .. format .. " report to: " .. path)
      end
      
      local ok, err = M.save_coverage_report(path, coverage_data, format)
      results[format] = {
        success = ok,
        error = err,
        path = path
      }
      
      if config.verbose then
        print("DEBUG [Reporting] " .. format .. " save result: " .. (ok and "success" or "failed: " .. tostring(err)))
      end
    end
  end
  
  -- Save quality reports if quality data is provided
  if quality_data then
    -- Save reports in multiple formats
    local formats = {"html", "json"}
    
    for _, format in ipairs(formats) do
      local path = process_template(config.quality_path_template, format, "quality")
      
      if config.verbose then
        print("DEBUG [Reporting] Saving quality " .. format .. " report to: " .. path)
      end
      
      local ok, err = M.save_quality_report(path, quality_data, format)
      results["quality_" .. format] = {
        success = ok,
        error = err,
        path = path
      }
      
      if config.verbose then
        print("DEBUG [Reporting] Quality " .. format .. " save result: " .. (ok and "success" or "failed: " .. tostring(err)))
      end
    end
  end
  
  -- Save test results in multiple formats if results data is provided
  if results_data then
    -- Test results formats
    local formats = {
      junit = { ext = "xml", name = "JUnit XML" },
      tap = { ext = "tap", name = "TAP" },
      csv = { ext = "csv", name = "CSV" }
    }
    
    for format, info in pairs(formats) do
      local path = process_template(config.results_path_template, info.ext, "test-results")
      
      if config.verbose then
        print("DEBUG [Reporting] Saving " .. info.name .. " report to: " .. path)
      end
      
      local ok, err = M.save_results_report(path, results_data, format)
      results[format] = {
        success = ok,
        error = err,
        path = path
      }
      
      if config.verbose then
        print("DEBUG [Reporting] " .. info.name .. " save result: " .. (ok and "success" or "failed: " .. tostring(err)))
      end
    end
  end
  
  return results
end

-- Return the module
return M