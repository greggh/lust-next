-- lust-next test coverage module
-- Implementation of code coverage tracking using Lua's debug hooks

local M = {}

-- Helper function to check if a file matches patterns
local function matches_pattern(file, patterns)
  if not patterns or #patterns == 0 then
    return false
  end
  
  for _, pattern in ipairs(patterns) do
    if file:match(pattern) then
      return true
    end
  end
  
  return false
end

-- File cache for source code analysis
local file_cache = {}

-- Read a file and return its contents as an array of lines
local function read_file(filename)
  if file_cache[filename] then
    return file_cache[filename]
  end
  
  local file = io.open(filename, "r")
  if not file then
    return {}
  end
  
  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()
  
  file_cache[filename] = lines
  return lines
end

-- Count the number of executable lines in a file
local function count_executable_lines(filename)
  local lines = read_file(filename)
  local count = 0
  
  for i, line in ipairs(lines) do
    -- Skip comments and empty lines
    if not line:match("^%s*%-%-") and not line:match("^%s*$") then
      count = count + 1
    end
  end
  
  return count
end

-- Coverage data structure
M.data = {
  files = {}, -- Coverage data per file
  lines = {}, -- Lines executed across all files
  functions = {}, -- Functions called
}

-- Coverage statistics
M.stats = {
  files = {}, -- Stats per file
  total_files = 0,
  covered_files = 0,
  total_lines = 0,
  covered_lines = 0,
  total_functions = 0,
  covered_functions = 0,
}

-- Configuration
M.config = {
  enabled = false,
  include = {".*%.lua$"}, -- Default: include all Lua files
  exclude = {"test_", "_spec%.lua$", "_test%.lua$"}, -- Default: exclude test files
  threshold = 80, -- Default coverage threshold (percentage)
}

-- State tracking
local coverage_active = false
local original_hook = nil

-- Debug hook function to track line execution
local function coverage_hook(event, line)
  if event == "line" then
    local info = debug.getinfo(2, "S")
    local source = info.source
    
    -- Skip files that don't have a source name
    if not source or source:sub(1, 1) ~= "@" then
      return
    end
    
    -- Get the file path
    local file = source:sub(2) -- Remove the @ prefix
    
    -- Skip files that don't match include patterns
    if not matches_pattern(file, M.config.include) then
      return
    end
    
    -- Skip files that match exclude patterns
    if matches_pattern(file, M.config.exclude) then
      return
    end
    
    -- Initialize file entry if it doesn't exist
    if not M.data.files[file] then
      M.data.files[file] = {
        lines = {},
        functions = {},
        line_count = count_executable_lines(file),
      }
    end
    
    -- Track line execution
    M.data.files[file].lines[line] = true
    
    -- Track global line execution
    local global_key = file .. ":" .. line
    M.data.lines[global_key] = true
  elseif event == "call" then
    local info = debug.getinfo(2, "Sn")
    local source = info.source
    
    -- Skip files that don't have a source name
    if not source or source:sub(1, 1) ~= "@" then
      return
    end
    
    -- Get the file path
    local file = source:sub(2) -- Remove the @ prefix
    
    -- Skip files that don't match include patterns
    if not matches_pattern(file, M.config.include) then
      return
    end
    
    -- Skip files that match exclude patterns
    if matches_pattern(file, M.config.exclude) then
      return
    end
    
    -- Initialize file entry if it doesn't exist
    if not M.data.files[file] then
      M.data.files[file] = {
        lines = {},
        functions = {},
        line_count = count_executable_lines(file),
      }
    end
    
    -- Function name or line number if name is not available
    local func_name = info.name or ("line_" .. info.linedefined)
    local func_key = file .. ":" .. func_name
    
    -- Track function execution
    M.data.files[file].functions[func_name] = true
    M.data.functions[func_key] = true
  end
  
  -- Call the original hook if it exists
  if original_hook then
    original_hook(event, line)
  end
end

-- Initialize coverage module
function M.init(options)
  options = options or {}
  
  -- Apply options with defaults
  if type(options) == "table" then
    for k, v in pairs(options) do
      M.config[k] = v
    end
  end
  
  M.reset()
  return M
end

-- Reset coverage data
function M.reset()
  -- Clear data
  M.data = {
    files = {},
    lines = {},
    functions = {},
  }
  
  -- Clear statistics
  M.stats = {
    files = {},
    total_files = 0,
    covered_files = 0,
    total_lines = 0,
    covered_lines = 0,
    total_functions = 0,
    covered_functions = 0,
  }
  
  -- Clear file cache
  file_cache = {}
  
  return M
end

-- Start collecting coverage data
function M.start()
  if not M.config.enabled then
    return M
  end
  
  if coverage_active then
    return M -- Already running
  end
  
  -- Save the original hook
  original_hook = debug.gethook()
  
  -- Set the coverage hook
  debug.sethook(coverage_hook, "cl") -- Track calls and lines
  
  coverage_active = true
  return M
end

-- Stop collecting coverage data
function M.stop()
  if not coverage_active then
    return M -- Not running
  end
  
  -- Restore the original hook
  debug.sethook(original_hook)
  
  coverage_active = false
  return M
end

-- Get coverage report
function M.report(format)
  format = format or "summary" -- summary, json, html, lcov
  
  -- Calculate statistics from data
  M.calculate_stats()
  
  if format == "summary" then
    return M.summary_report()
  elseif format == "json" then
    return M.json_report()
  elseif format == "html" then
    return M.html_report()
  elseif format == "lcov" then
    return M.lcov_report()
  else
    return M.summary_report()
  end
end

-- Generate a summary report
function M.summary_report()
  local report = {
    files = M.stats.files,
    total_files = M.stats.total_files,
    covered_files = M.stats.covered_files,
    files_pct = M.stats.covered_files / math.max(1, M.stats.total_files) * 100,
    
    total_lines = M.stats.total_lines,
    covered_lines = M.stats.covered_lines,
    lines_pct = M.stats.covered_lines / math.max(1, M.stats.total_lines) * 100,
    
    total_functions = M.stats.total_functions,
    covered_functions = M.stats.covered_functions,
    functions_pct = M.stats.covered_functions / math.max(1, M.stats.total_functions) * 100,
    
    overall_pct = 0,
  }
  
  -- Calculate overall percentage as weighted average of lines and functions
  report.overall_pct = (report.lines_pct * 0.8) + (report.functions_pct * 0.2)
  
  return report
end

-- Generate a JSON report
function M.json_report()
  -- Try to load JSON module 
  local json_module = package.loaded["src.json"] or require("src.json")
  -- Fallback if JSON module isn't available
  if not json_module then
    json_module = { encode = function(t) return "{}" end }
  end
  return json_module.encode(M.summary_report())
end

-- Generate an HTML report
function M.html_report()
  local report = M.summary_report()
  
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
    local line_pct = stats.covered_lines / math.max(1, stats.total_lines) * 100
    local func_pct = stats.covered_functions / math.max(1, stats.total_functions) * 100
    
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

-- Generate an LCOV report
function M.lcov_report()
  local lcov = ""
  
  for file, data in pairs(M.data.files) do
    lcov = lcov .. "SF:" .. file .. "\n"
    
    -- Add function coverage
    local func_count = 0
    for func_name, _ in pairs(data.functions) do
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
    for line, _ in pairs(data.lines) do
      table.insert(lines_data, line)
    end
    table.sort(lines_data)
    
    for _, line in ipairs(lines_data) do
      lcov = lcov .. "DA:" .. line .. ",1\n"
    end
    
    lcov = lcov .. "LF:" .. data.line_count .. "\n"
    lcov = lcov .. "LH:" .. #lines_data .. "\n"
    lcov = lcov .. "end_of_record\n"
  end
  
  return lcov
end

-- Check if coverage meets threshold
function M.meets_threshold(threshold)
  threshold = threshold or M.config.threshold
  local report = M.summary_report()
  return report.overall_pct >= threshold
end

-- Calculate coverage statistics
function M.calculate_stats()
  -- Reset statistics
  M.stats = {
    files = {},
    total_files = 0,
    covered_files = 0,
    total_lines = 0,
    covered_lines = 0,
    total_functions = 0,
    covered_functions = 0,
  }
  
  -- Process each file
  for file, data in pairs(M.data.files) do
    -- Calculate lines covered
    local covered_lines = 0
    for _ in pairs(data.lines) do
      covered_lines = covered_lines + 1
    end
    
    -- Calculate functions covered
    local covered_functions = 0
    for _ in pairs(data.functions) do
      covered_functions = covered_functions + 1
    end
    
    -- Update file statistics
    M.stats.files[file] = {
      total_lines = data.line_count,
      covered_lines = covered_lines,
      total_functions = covered_functions, -- We only track called functions for now
      covered_functions = covered_functions,
    }
    
    -- Update global statistics
    M.stats.total_files = M.stats.total_files + 1
    M.stats.covered_files = M.stats.covered_files + (covered_lines > 0 and 1 or 0)
    M.stats.total_lines = M.stats.total_lines + data.line_count
    M.stats.covered_lines = M.stats.covered_lines + covered_lines
    M.stats.total_functions = M.stats.total_functions + covered_functions
    M.stats.covered_functions = M.stats.covered_functions + covered_functions
  end
  
  return M
end

-- Utility function to write a file
function M.write_file(file_path, content)
  local file = io.open(file_path, "w")
  if not file then
    return false, "Could not open file for writing: " .. file_path
  end
  
  file:write(content)
  file:close()
  return true
end

-- Save a coverage report to a file
function M.save_report(file_path, format)
  format = format or "html"
  local content = M.report(format)
  return M.write_file(file_path, content)
end

-- Return the module
return M