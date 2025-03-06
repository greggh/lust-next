-- lust-next reporting module
-- Centralized module for all report generation and file output

local M = {}

-- Load the JSON module if available
local json_module
local ok, mod = pcall(require, "src.json")
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

---------------------------
-- REPORT FORMATTERS
---------------------------

-- Coverage report formatters
local coverage_formatters = {}

-- Generate a summary coverage report from coverage data
coverage_formatters.summary = function(coverage_data)
  -- Validate the input data to prevent runtime errors
  if not coverage_data then
    print("ERROR [Reporting] Missing coverage data")
    return {
      files = {},
      total_files = 0,
      covered_files = 0,
      files_pct = 0,
      total_lines = 0,
      covered_lines = 0,
      lines_pct = 0,
      total_functions = 0,
      covered_functions = 0,
      functions_pct = 0,
      overall_pct = 0
    }
  end
  
  -- Make sure we have summary data
  local summary = coverage_data.summary or {
    total_files = 0,
    covered_files = 0,
    total_lines = 0,
    covered_lines = 0,
    total_functions = 0,
    covered_functions = 0,
    line_coverage_percent = 0,
    function_coverage_percent = 0,
    overall_percent = 0
  }
  
  -- Debug output for troubleshooting
  print("DEBUG [Reporting] Formatting coverage data with:")
  print("  Total files: " .. (summary.total_files or 0))
  print("  Covered files: " .. (summary.covered_files or 0))
  print("  Total lines: " .. (summary.total_lines or 0))
  print("  Covered lines: " .. (summary.covered_lines or 0))
  
  local report = {
    files = coverage_data.files or {},
    total_files = summary.total_files or 0,
    covered_files = summary.covered_files or 0,
    files_pct = summary.total_files > 0 and 
                ((summary.covered_files or 0) / summary.total_files * 100) or 0,
    
    total_lines = summary.total_lines or 0,
    covered_lines = summary.covered_lines or 0,
    lines_pct = summary.total_lines > 0 and 
               ((summary.covered_lines or 0) / summary.total_lines * 100) or 0,
    
    total_functions = summary.total_functions or 0,
    covered_functions = summary.covered_functions or 0,
    functions_pct = summary.total_functions > 0 and 
                   ((summary.covered_functions or 0) / summary.total_functions * 100) or 0,
    
    overall_pct = summary.overall_percent or 0,
  }
  
  return report
end

-- Generate a JSON coverage report
coverage_formatters.json = function(coverage_data)
  local report = coverage_formatters.summary(coverage_data)
  return json_module.encode(report)
end

-- Generate an HTML coverage report
coverage_formatters.html = function(coverage_data)
  local report = coverage_formatters.summary(coverage_data)
  
  -- Generate HTML header
  local html = [[
<!DOCTYPE html>
<html>
<head>
  <title>Lust-Next Coverage Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    .summary { margin: 20px 0; background: #f5f5f5; padding: 10px; border-radius: 5px; }
    .progress { background-color: #e0e0e0; border-radius: 5px; height: 20px; }
    .progress-bar { height: 20px; border-radius: 5px; background-color: #4CAF50; }
    .low { background-color: #f44336; }
    .medium { background-color: #ff9800; }
    .high { background-color: #4CAF50; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) { background-color: #f9f9f9; }
  </style>
</head>
<body>
  <h1>Lust-Next Coverage Report</h1>
  <div class="summary">
    <h2>Summary</h2>
    <p>Overall Coverage: ]].. string.format("%.2f%%", report.overall_pct) ..[[</p>
    <div class="progress">
      <div class="progress-bar ]].. (report.overall_pct < 50 and "low" or (report.overall_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, report.overall_pct) ..[[%;"></div>
    </div>
    <p>Lines: ]].. report.covered_lines ..[[ / ]].. report.total_lines ..[[ (]].. string.format("%.2f%%", report.lines_pct) ..[[)</p>
    <p>Functions: ]].. report.covered_functions ..[[ / ]].. report.total_functions ..[[ (]].. string.format("%.2f%%", report.functions_pct) ..[[)</p>
    <p>Files: ]].. report.covered_files ..[[ / ]].. report.total_files ..[[ (]].. string.format("%.2f%%", report.files_pct) ..[[)</p>
  </div>
  <table>
    <tr>
      <th>File</th>
      <th>Lines</th>
      <th>Line Coverage</th>
      <th>Functions</th>
      <th>Function Coverage</th>
    </tr>
  ]]
  
  -- Add file rows
  for file, stats in pairs(report.files) do
    local line_pct = stats.total_lines > 0 and 
                    (stats.covered_lines / stats.total_lines * 100) or 0
    local func_pct = stats.total_functions > 0 and 
                    (stats.covered_functions / stats.total_functions * 100) or 0
    
    html = html .. [[
    <tr>
      <td>]].. file ..[[</td>
      <td>]].. stats.covered_lines ..[[ / ]].. stats.total_lines ..[[</td>
      <td>
        <div class="progress">
          <div class="progress-bar ]].. (line_pct < 50 and "low" or (line_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, line_pct) ..[[%;"></div>
        </div>
        ]].. string.format("%.2f%%", line_pct) ..[[
      </td>
      <td>]].. stats.covered_functions ..[[ / ]].. stats.total_functions ..[[</td>
      <td>
        <div class="progress">
          <div class="progress-bar ]].. (func_pct < 50 and "low" or (func_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, func_pct) ..[[%;"></div>
        </div>
        ]].. string.format("%.2f%%", func_pct) ..[[
      </td>
    </tr>
    ]]
  end
  
  -- Close HTML
  html = html .. [[
  </table>
</body>
</html>
  ]]
  
  return html
end

-- Generate an LCOV coverage report
coverage_formatters.lcov = function(coverage_data)
  local lcov = ""
  
  for file, data in pairs(coverage_data.files) do
    lcov = lcov .. "SF:" .. file .. "\n"
    
    -- Add function coverage
    local func_count = 0
    for func_name, covered in pairs(data.functions or {}) do
      func_count = func_count + 1
      -- If function name is a line number, use that
      if func_name:match("^line_(%d+)$") then
        local line = func_name:match("^line_(%d+)$")
        lcov = lcov .. "FN:" .. line .. "," .. func_name .. "\n"
      else
        -- We don't have line information for named functions in this simple implementation
        lcov = lcov .. "FN:1," .. func_name .. "\n"
      end
      lcov = lcov .. "FNDA:1," .. func_name .. "\n"
    end
    
    lcov = lcov .. "FNF:" .. func_count .. "\n"
    lcov = lcov .. "FNH:" .. func_count .. "\n"
    
    -- Add line coverage
    local lines_data = {}
    for line, covered in pairs(data.lines or {}) do
      if type(line) == "number" then
        table.insert(lines_data, line)
      end
    end
    table.sort(lines_data)
    
    for _, line in ipairs(lines_data) do
      lcov = lcov .. "DA:" .. line .. ",1\n"
    end
    
    -- Get line count, safely handling different data structures
    local line_count = data.line_count or data.total_lines or #lines_data or 0
    lcov = lcov .. "LF:" .. line_count .. "\n"
    lcov = lcov .. "LH:" .. #lines_data .. "\n"
    lcov = lcov .. "end_of_record\n"
  end
  
  return lcov
end

-- Quality report formatters
local quality_formatters = {}

-- Generate a summary quality report
quality_formatters.summary = function(quality_data)
  -- Simply return the structured data for summary reports
  return {
    level = quality_data.level,
    level_name = quality_data.level_name,
    tests_analyzed = quality_data.summary.tests_analyzed,
    tests_passing_quality = quality_data.summary.tests_passing_quality,
    quality_pct = quality_data.summary.quality_percent,
    assertions_total = quality_data.summary.assertions_total,
    assertions_per_test_avg = quality_data.summary.assertions_per_test_avg,
    assertion_types_found = quality_data.summary.assertion_types_found or {},
    issues = quality_data.summary.issues or {},
    tests = quality_data.tests or {}
  }
end

-- Generate a JSON quality report
quality_formatters.json = function(quality_data)
  local report = quality_formatters.summary(quality_data)
  return json_module.encode(report)
end

-- Generate an HTML quality report
quality_formatters.html = function(quality_data)
  local report = quality_formatters.summary(quality_data)
  
  -- Generate HTML header
  local html = [[
<!DOCTYPE html>
<html>
<head>
  <title>Lust-Next Test Quality Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    .summary { margin: 20px 0; background: #f5f5f5; padding: 10px; border-radius: 5px; }
    .progress { background-color: #e0e0e0; border-radius: 5px; height: 20px; }
    .progress-bar { height: 20px; border-radius: 5px; background-color: #4CAF50; }
    .low { background-color: #f44336; }
    .medium { background-color: #ff9800; }
    .high { background-color: #4CAF50; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .issue { color: #f44336; }
  </style>
</head>
<body>
  <h1>Lust-Next Test Quality Report</h1>
  <div class="summary">
    <h2>Quality Summary</h2>
    <p>Quality Level: ]].. report.level_name .. " (Level " .. report.level .. [[ of 5)</p>
    <div class="progress">
      <div class="progress-bar ]].. (report.quality_pct < 50 and "low" or (report.quality_pct < 80 and "medium" or "high")) ..[[" style="width: ]].. math.min(100, report.quality_pct) ..[[%;"></div>
    </div>
    <p>Tests Passing Quality: ]].. report.tests_passing_quality ..[[ / ]].. report.tests_analyzed ..[[ (]].. string.format("%.2f%%", report.quality_pct) ..[[)</p>
    <p>Average Assertions per Test: ]].. string.format("%.2f", report.assertions_per_test_avg) ..[[</p>
  </div>
  ]]
  
  -- Add issues if any
  if #report.issues > 0 then
    html = html .. [[
  <h2>Quality Issues</h2>
  <table>
    <tr>
      <th>Test</th>
      <th>Issue</th>
    </tr>
  ]]
    
    for _, issue in ipairs(report.issues) do
      html = html .. [[
    <tr>
      <td>]].. issue.test ..[[</td>
      <td class="issue">]].. issue.issue ..[[</td>
    </tr>
  ]]
    end
    
    html = html .. [[
  </table>
  ]]
  end
  
  -- Add test details
  html = html .. [[
  <h2>Test Details</h2>
  <table>
    <tr>
      <th>Test</th>
      <th>Quality Level</th>
      <th>Assertions</th>
      <th>Assertion Types</th>
    </tr>
  ]]
  
  for test_name, test_info in pairs(report.tests) do
    -- Convert assertion types to a string
    local assertion_types = {}
    for atype, count in pairs(test_info.assertion_types or {}) do
      table.insert(assertion_types, atype .. " (" .. count .. ")")
    end
    local assertion_types_str = table.concat(assertion_types, ", ")
    
    html = html .. [[
    <tr>
      <td>]].. test_name ..[[</td>
      <td>]].. (test_info.quality_level_name or "") .. " (Level " .. (test_info.quality_level or 0) .. [[)</td>
      <td>]].. (test_info.assertion_count or 0) ..[[</td>
      <td>]].. assertion_types_str ..[[</td>
    </tr>
    ]]
  end
  
  html = html .. [[
  </table>
</body>
</html>
  ]]
  
  return html
end

---------------------------
-- OUTPUT GENERATION
---------------------------

-- Format coverage data
function M.format_coverage(coverage_data, format)
  format = format or "summary"
  
  -- Use the appropriate formatter
  if coverage_formatters[format] then
    return coverage_formatters[format](coverage_data)
  else
    -- Default to summary if format not supported
    return coverage_formatters.summary(coverage_data)
  end
end

-- Format quality data
function M.format_quality(quality_data, format)
  format = format or "summary"
  
  -- Use the appropriate formatter
  if quality_formatters[format] then
    return quality_formatters[format](quality_data)
  else
    -- Default to summary if format not supported
    return quality_formatters.summary(quality_data)
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

-- Auto-save reports to default locations
function M.auto_save_reports(coverage_data, quality_data, base_dir)
  base_dir = base_dir or "./coverage-reports"
  local results = {}
  
  -- Debug output for troubleshooting
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
  
  -- Try different directory creation methods to ensure success
  print("DEBUG [Reporting] Ensuring directory exists using multiple methods...")
  
  -- First, try the standard ensure_directory function
  local dir_ok, dir_err = ensure_directory(base_dir)
  if not dir_ok then
    print("WARNING [Reporting] Standard directory creation failed: " .. tostring(dir_err))
    
    -- Try direct mkdir command as fallback
    print("DEBUG [Reporting] Trying direct mkdir -p command...")
    os.execute('mkdir -p "' .. base_dir .. '"')
    
    -- Verify directory exists after fallback
    local test_cmd = package.config:sub(1,1) == "\\" and
      'if exist "' .. base_dir .. '\\*" (exit 0) else (exit 1)' or
      'test -d "' .. base_dir .. '"'
    
    local exists = os.execute(test_cmd)
    if exists == true or exists == 0 then
      print("DEBUG [Reporting] Directory created successfully with fallback method")
      dir_ok = true
    else
      print("ERROR [Reporting] Failed to create directory with all methods")
      dir_ok = false
    end
  else
    print("DEBUG [Reporting] Directory exists or was created: " .. base_dir)
  end
  
  -- Always save both HTML and LCOV reports if coverage data is provided
  if coverage_data then
    -- Save HTML report
    local html_path = base_dir .. "/coverage-report.html"
    print("DEBUG [Reporting] Saving HTML report to: " .. html_path)
    local html_ok, html_err = M.save_coverage_report(html_path, coverage_data, "html")
    results.html = {
      success = html_ok,
      error = html_err,
      path = html_path
    }
    print("DEBUG [Reporting] HTML save result: " .. (html_ok and "success" or "failed: " .. tostring(html_err)))
    
    -- Save LCOV report
    local lcov_path = base_dir .. "/coverage-report.lcov"
    print("DEBUG [Reporting] Saving LCOV report to: " .. lcov_path)
    local lcov_ok, lcov_err = M.save_coverage_report(lcov_path, coverage_data, "lcov")
    results.lcov = {
      success = lcov_ok,
      error = lcov_err,
      path = lcov_path
    }
    print("DEBUG [Reporting] LCOV save result: " .. (lcov_ok and "success" or "failed: " .. tostring(lcov_err)))
    
    -- Also save JSON for machine readable format
    local json_path = base_dir .. "/coverage-report.json"
    print("DEBUG [Reporting] Saving JSON report to: " .. json_path)
    local json_ok, json_err = M.save_coverage_report(json_path, coverage_data, "json")
    results.json = {
      success = json_ok,
      error = json_err,
      path = json_path
    }
    print("DEBUG [Reporting] JSON save result: " .. (json_ok and "success" or "failed: " .. tostring(json_err)))
  end
  
  -- Save HTML quality report if quality data is provided
  if quality_data then
    local quality_path = base_dir .. "/quality-report.html"
    print("DEBUG [Reporting] Saving quality HTML report to: " .. quality_path)
    local quality_ok, quality_err = M.save_quality_report(quality_path, quality_data, "html")
    results.quality_html = {
      success = quality_ok,
      error = quality_err,
      path = quality_path
    }
    print("DEBUG [Reporting] Quality HTML save result: " .. (quality_ok and "success" or "failed: " .. tostring(quality_err)))
    
    -- Also save JSON quality report
    local quality_json_path = base_dir .. "/quality-report.json"
    print("DEBUG [Reporting] Saving quality JSON report to: " .. quality_json_path)
    local quality_json_ok, quality_json_err = M.save_quality_report(quality_json_path, quality_data, "json")
    results.quality_json = {
      success = quality_json_ok,
      error = quality_json_err,
      path = quality_json_path
    }
    print("DEBUG [Reporting] Quality JSON save result: " .. (quality_json_ok and "success" or "failed: " .. tostring(quality_json_err)))
  end
  
  return results
end

-- Return the module
return M