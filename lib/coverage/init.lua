-- lust-next test coverage module
-- Implementation of code coverage tracking using Lua's debug hooks

local M = {}

-- Import filesystem module for file operations
local fs = require("lib.tools.filesystem")

-- Helper function to check if a file matches patterns
local function matches_pattern(file, patterns)
  if not patterns or #patterns == 0 then
    return false
  end
  
  -- Normalize the file path for consistent matching
  local normalized_file = fs.normalize_path(file)
  
  for _, pattern in ipairs(patterns) do
    -- Use filesystem module's pattern matching
    if fs.matches_pattern(normalized_file, pattern) then
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
  
  local content = fs.read_file(filename)
  if not content then
    return {}
  end
  
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
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
  source_dirs = {".", "src", "lib"}, -- Directories to scan for source files
  use_default_patterns = true,       -- Whether to use default include/exclude patterns
  discover_uncovered = true,         -- Discover files that aren't executed by tests
  -- Default include all Lua files, plus typical glob patterns
  include = {
    "*.lua",          -- Glob pattern for all Lua files
    "**/*.lua",       -- Glob pattern for all Lua files in subdirectories
    "src/**/*.lua",   -- Glob pattern for Lua files in src directory
    "lib/**/*.lua",   -- Glob pattern for Lua files in lib directory
  },
  -- Default exclude test files
  exclude = {
    "*_test.lua",     -- Glob pattern for files ending with _test.lua
    "*_spec.lua",     -- Glob pattern for files ending with _spec.lua
    "test_*.lua",     -- Glob pattern for files starting with test_
    "tests/**/*.lua", -- Glob pattern for files in tests directory
    "**/test/**/*.lua", -- Glob pattern for files in any test directory
    "**/tests/**/*.lua", -- Glob pattern for files in any tests directory
    "**/spec/**/*.lua",  -- Glob pattern for files in any spec directory
    "**/*.test.lua",     -- Alternative test naming pattern
    "**/*.spec.lua",     -- Alternative spec naming pattern
  },
  threshold = 80,     -- Default coverage threshold (percentage),
  debug = false       -- Enable debug output
}

-- State tracking
local coverage_active = false
local original_hook = nil
M.debug_mode = false -- Debug output flag

-- Debug hook function to track line execution
local function coverage_hook(event, line)
  -- Track hook calls for debugging
  M.hook_calls = (M.hook_calls or 0) + 1
  if M.debug_mode and M.hook_calls % 1000 == 0 then
    print("DEBUG [Coverage] Hook called " .. M.hook_calls .. " times")
  end
  
  -- Add error handling to prevent silent failures
  local success, err = pcall(function()
    if event == "line" then
      local info = debug.getinfo(2, "S")
      local source = info.source
      
      -- Skip files that don't have a source name
      if not source or source:sub(1, 1) ~= "@" then
        if M.debug_mode and source then
          print("DEBUG [Coverage] Skipping non-file source: " .. source)
        end
        return
      end
      
      -- Get the file path and normalize it
      local file = source:sub(2) -- Remove the @ prefix
      local normalized_file = fs.normalize_path(file)
      
      -- Get filename for logging (shorter path)
      local filename = fs.get_file_name(normalized_file) or normalized_file
      
      -- Only print debug info if debug mode is enabled
      if M.debug_mode then
        print("DEBUG [Coverage] Checking line in file: " .. normalized_file)
        
        print("DEBUG [Coverage] Checking if matches include patterns:")
        for i, pattern in ipairs(M.config.include) do
          -- Convert glob pattern to Lua pattern for debugging
          local lua_pattern = glob_to_pattern(pattern)
          local matches = normalized_file:match(lua_pattern) ~= nil
          print("  Pattern " .. i .. ": " .. pattern .. " -> " .. tostring(lua_pattern) .. " (Match: " .. tostring(matches) .. ")")
        end
      end
      
      -- TEMPORARY: Accept all Lua files for testing
      local is_lua_file = fs.get_extension(normalized_file) == "lua"
      local should_include = is_lua_file and not matches_pattern(normalized_file, M.config.exclude)
      
      -- Only check patterns if not accepting all Lua files
      if not should_include then
        -- Skip files that don't match include patterns
        if not matches_pattern(normalized_file, M.config.include) then
          if M.debug_mode then
            print("DEBUG [Coverage] File does not match include patterns: " .. normalized_file)
          end
          return
        end
        
        -- Skip files that match exclude patterns
        if matches_pattern(normalized_file, M.config.exclude) then
          if M.debug_mode then
            print("DEBUG [Coverage] File matches exclude patterns: " .. normalized_file)
          end
          return
        end
      end
      
      -- If we got here, the file should be tracked
      if M.debug_mode then
        print("DEBUG [Coverage] TRACKING line " .. line .. " in file: " .. normalized_file)
        
        -- Print this file's source if present, limited to first few lines
        M.already_printed_files = M.already_printed_files or {}
        if not M.already_printed_files[normalized_file] then
          M.already_printed_files[normalized_file] = true
          local lines = read_file(file)
          print("DEBUG [Coverage] First 5 lines of source:")
          for i = 1, math.min(5, #lines) do
            print("  " .. i .. ": " .. lines[i])
          end
        end
      end
      
      -- Use consistent file path as key for data storage
      if not M.data.files[normalized_file] then
        M.data.files[normalized_file] = {
          lines = {},
          functions = {},
          line_count = count_executable_lines(file), -- Use original path for reading file
        }
      end
      
      -- Track line execution
      M.data.files[normalized_file].lines[line] = true
      
      -- Track global line execution
      local global_key = normalized_file .. ":" .. line
      M.data.lines[global_key] = true
    elseif event == "call" then
      local info = debug.getinfo(2, "Sn")
      local source = info.source
      
      -- Skip files that don't have a source name
      if not source or source:sub(1, 1) ~= "@" then
        if M.debug_mode and source then
          print("DEBUG [Coverage] Skipping non-file source in call: " .. source)
        end
        return
      end
      
      -- Get the file path and normalize it
      local file = source:sub(2) -- Remove the @ prefix
      local normalized_file = fs.normalize_path(file)
      
      -- TEMPORARY: Accept all Lua files for testing
      local is_lua_file = fs.get_extension(normalized_file) == "lua"
      local should_include = is_lua_file and not matches_pattern(normalized_file, M.config.exclude)
      
      -- Only check patterns if not accepting all Lua files
      if not should_include then
        -- Skip files that don't match include patterns
        if not matches_pattern(normalized_file, M.config.include) then
          if M.debug_mode then
            print("DEBUG [Coverage] File does not match include patterns for call: " .. normalized_file)
          end
          return
        end
        
        -- Skip files that match exclude patterns
        if matches_pattern(normalized_file, M.config.exclude) then
          if M.debug_mode then
            print("DEBUG [Coverage] File matches exclude patterns for call: " .. normalized_file)
          end
          return
        end
      end
      
      -- Use consistent file path as key for data storage
      if not M.data.files[normalized_file] then
        M.data.files[normalized_file] = {
          lines = {},
          functions = {},
          line_count = count_executable_lines(file), -- Use original path for reading file
        }
      end
      
      -- Function name or line number if name is not available
      local func_name = info.name or ("line_" .. info.linedefined)
      if M.debug_mode then
        print("DEBUG [Coverage] TRACKING function " .. func_name .. " in file: " .. normalized_file)
      end
      
      -- Track function execution
      M.data.files[normalized_file].functions[func_name] = true
      local func_key = normalized_file .. ":" .. func_name
      M.data.functions[func_key] = true
    end
  end)
  
  -- Report any errors in the debug hook without breaking execution
  if not success then
    print("ERROR [Coverage] Error in debug hook: " .. tostring(err))
  end
  
  -- Call the original hook if it exists
  if original_hook then
    original_hook(event, line)
  end
end

-- Discover all source files based on include/exclude patterns
function M.discover_source_files()
  local discovered_files = {}
  
  -- Get current working directory
  local cwd = os.getenv("PWD") or io.popen("pwd"):read("*l") or "."
  
  if M.debug_mode then
    print("DEBUG [Coverage] Starting source file discovery from: " .. cwd)
    print("DEBUG [Coverage] Source directories to scan: ")
    for _, dir in ipairs(M.config.source_dirs) do
      print("  - " .. dir)
    end
  end
  
  -- Convert source dirs to absolute paths
  local absolute_dirs = {}
  for _, dir in ipairs(M.config.source_dirs) do
    local full_dir = dir:match("^/") and dir or fs.join_paths(cwd, dir)
    table.insert(absolute_dirs, full_dir)
    
    if M.debug_mode then
      print("DEBUG [Coverage] Using absolute directory: " .. full_dir)
    end
  end
  
  -- Use filesystem module's discover_files function
  local lua_files = fs.discover_files(
    absolute_dirs,
    M.config.include,
    M.config.exclude
  )
  
  -- Convert to a map for faster lookups
  for _, file_path in ipairs(lua_files) do
    local normalized_path = fs.normalize_path(file_path)
    discovered_files[normalized_path] = true
    
    if M.debug_mode then
      print("DEBUG [Coverage] Discovered source file: " .. normalized_path)
    end
  end
  
  -- Count discovered files
  local count = 0
  for _ in pairs(discovered_files) do
    count = count + 1
  end
  
  if M.debug_mode then
    print("DEBUG [Coverage] Discovered " .. count .. " source files")
  end
  
  return discovered_files
end

-- Initialize coverage module
function M.init(options)
  options = options or {}
  
  -- Apply options with defaults
  if type(options) == "table" then
    for k, v in pairs(options) do
      if k == "include" or k == "exclude" then
        -- Replace arrays entirely if configured not to use defaults
        if options.use_default_patterns == false then
          M.config[k] = v
        else
          -- Otherwise append to existing arrays
          if type(v) == "table" then
            for _, pattern in ipairs(v) do
              table.insert(M.config[k], pattern)
            end
          end
        end
      elseif k == "source_dirs" and type(v) == "table" then
        -- Replace source_dirs array
        M.config.source_dirs = v
      else
        M.config[k] = v
      end
    end
  end
  
  -- Set debug mode from config
  M.debug_mode = M.config.debug or false
  
  if M.debug_mode then
    print("DEBUG [Coverage] Initializing coverage module with options:")
    for k, v in pairs(M.config) do
      if type(v) == "table" then
        print("  " .. k .. ":")
        for i, pattern in ipairs(v) do
          print("    " .. i .. ": " .. pattern)
        end
      else
        print("  " .. k .. " = " .. tostring(v))
      end
    end
  end
  
  M.reset()
  
  -- Discover all source files upfront if enabled
  if M.config.enabled and M.config.discover_uncovered then
    local discovered_files = M.discover_source_files()
    for file_path in pairs(discovered_files) do
      if not M.data.files[file_path] then
        -- Try to count executable lines
        local line_count = count_executable_lines(file_path)
        
        M.data.files[file_path] = {
          lines = {},
          functions = {},
          line_count = line_count,
          discovered = true  -- Mark as discovered, not executed
        }
        
        if M.debug_mode then
          print("DEBUG [Coverage] Added discovered file to tracking: " .. file_path .. " (" .. line_count .. " lines)")
        end
      end
    end
  end
  
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
  
  -- Track which files we've already printed for debugging
  M.already_printed_files = {}
  
  return M
end

-- Start collecting coverage data
function M.start()
  if not M.config.enabled then
    print("DEBUG [Coverage] Not starting coverage - disabled in config")
    return M
  end
  
  if coverage_active then
    print("DEBUG [Coverage] Not starting coverage - already running")
    return M -- Already running
  end
  
  -- Print configuration for debugging
  print("DEBUG [Coverage] Starting coverage with configuration:")
  print("  Debug mode: " .. tostring(M.debug_mode))
  print("  Include patterns: ")
  for i, pattern in ipairs(M.config.include) do
    print("    " .. i .. ": " .. pattern)
  end
  print("  Exclude patterns: ")
  for i, pattern in ipairs(M.config.exclude) do
    print("    " .. i .. ": " .. pattern)
  end
  
  -- Save the original hook
  original_hook = debug.gethook()
  
  -- Set the coverage hook
  debug.sethook(coverage_hook, "cl") -- Track calls and lines
  print("DEBUG [Coverage] Successfully set debug hook")
  
  coverage_active = true
  return M
end

-- Stop collecting coverage data
function M.stop()
  if not coverage_active then
    print("DEBUG [Coverage] Not stopping coverage - not running")
    return M -- Not running
  end
  
  print("DEBUG [Coverage] Stopping coverage collection")
  
  -- Restore the original hook
  debug.sethook(original_hook)
  
  -- Print summary of what was collected
  print("DEBUG [Coverage] Coverage data collected:")
  print("  Number of files tracked: " .. (function()
    local count = 0
    for _ in pairs(M.data.files) do
      count = count + 1
    end
    return count
  end)())
  
  print("  Number of lines tracked: " .. (function()
    local count = 0
    for _ in pairs(M.data.lines) do
      count = count + 1
    end
    return count
  end)())
  
  print("  Number of functions tracked: " .. (function()
    local count = 0
    for _ in pairs(M.data.functions) do
      count = count + 1
    end
    return count
  end)())
  
  coverage_active = false
  return M
end

-- Get coverage report
function M.report(format)
  format = format or "summary" -- summary, json, html, lcov
  
  -- Calculate statistics from data
  M.calculate_stats()
  
  -- Print debugging info for statistics
  print("DEBUG [Coverage] Statistics calculated:")
  print("  Files tracked: " .. M.stats.total_files)
  print("  Files with coverage: " .. M.stats.covered_files)
  print("  Lines tracked: " .. M.stats.total_lines)
  print("  Lines covered: " .. M.stats.covered_lines)
  print("  Functions tracked: " .. M.stats.total_functions)
  print("  Functions covered: " .. M.stats.covered_functions)
  
  -- Print all files tracked
  print("DEBUG [Coverage] Files being tracked:")
  for file, _ in pairs(M.data.files) do
    print("  " .. file)
  end
  
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

-- Generate data for a summary report
function M.get_report_data()
  -- Make sure stats are calculated before generating report data
  M.calculate_stats()
  
  -- Generate structured data for reporting module
  local structured_data = {
    files = M.stats.files,
    summary = {
      total_files = M.stats.total_files,
      covered_files = M.stats.covered_files,
      total_lines = M.stats.total_lines,
      covered_lines = M.stats.covered_lines,
      total_functions = M.stats.total_functions,
      covered_functions = M.stats.covered_functions,
      line_coverage_percent = M.stats.total_lines > 0 and 
                         (M.stats.covered_lines / M.stats.total_lines * 100) or 0,
      function_coverage_percent = M.stats.total_functions > 0 and 
                             (M.stats.covered_functions / M.stats.total_functions * 100) or 0,
    }
  }
  
  -- Calculate overall percentage as weighted average of lines and functions
  structured_data.summary.overall_percent = (structured_data.summary.line_coverage_percent * 0.8) + 
                                          (structured_data.summary.function_coverage_percent * 0.2)
  
  -- Debug output for troubleshooting
  print("DEBUG [Coverage] get_report_data returning data with:")
  print("  Total files: " .. structured_data.summary.total_files)
  print("  Total lines: " .. structured_data.summary.total_lines)
  print("  Covered lines: " .. structured_data.summary.covered_lines)
  print("  Coverage percent: " .. string.format("%.2f%%", structured_data.summary.line_coverage_percent))
  
  -- Dump the files structure to debug data flow
  print("DEBUG [Coverage] Files in report data:")
  for file, stats in pairs(structured_data.files) do
    print("  - " .. file .. ": " .. stats.covered_lines .. "/" .. stats.total_lines .. " lines, " .. 
          stats.covered_functions .. "/" .. stats.total_functions .. " functions")
  end
  
  return structured_data
end

-- Generate a summary report (for backward compatibility)
function M.summary_report()
  local reporting_module = package.loaded["lib.reporting"] or require("lib.reporting")
  -- Get structured data and format it as a summary report
  local data = M.get_report_data()
  
  if reporting_module then
    return reporting_module.format_coverage(data, "summary")
  else
    -- Fallback summary report format for backward compatibility
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
      
      overall_pct = data.summary.overall_percent,
    }
    
    return report
  end
end

-- Generate a JSON report (for backward compatibility)
function M.json_report()
  local reporting_module = package.loaded["lib.reporting"] or require("lib.reporting")
  local data = M.get_report_data()
  
  if reporting_module then
    return reporting_module.format_coverage(data, "json")
  else
    -- Fallback if reporting module isn't available
    -- Try to load JSON module 
    local json_module = package.loaded["src.json"] or require("src.json")
    -- Fallback if JSON module isn't available
    if not json_module then
      json_module = { encode = function(t) return "{}" end }
    end
    return json_module.encode(M.summary_report())
  end
end

-- Generate an HTML report (for backward compatibility)
function M.html_report()
  local reporting_module = package.loaded["lib.reporting"] or require("lib.reporting")
  local data = M.get_report_data()
  
  if reporting_module then
    return reporting_module.format_coverage(data, "html")
  else
    -- Fallback to legacy HTML formatting if reporting module isn't available
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
end

-- Generate an LCOV report (for backward compatibility)
function M.lcov_report()
  local reporting_module = package.loaded["lib.reporting"] or require("lib.reporting")
  local data = M.get_report_data()
  
  if reporting_module then
    return reporting_module.format_coverage(data, "lcov")
  else
    -- Fallback to legacy LCOV formatting if reporting module isn't available
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
end

-- Check if coverage meets threshold
function M.meets_threshold(threshold)
  threshold = threshold or M.config.threshold
  local report = M.summary_report()
  return report.overall_pct >= threshold
end

-- Calculate coverage statistics
function M.calculate_stats()
  print("DEBUG [Coverage] Calculating coverage statistics...")
  
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
  
  -- Print the file data we've collected
  print("DEBUG [Coverage] Files tracked in M.data.files:")
  local tracked_files = {}
  for file, _ in pairs(M.data.files) do
    table.insert(tracked_files, file)
  end
  
  if #tracked_files == 0 then
    print("  WARNING: No files tracked in coverage data")
    
    -- If no files are tracked and discover_uncovered is enabled, discover them now
    if M.config.discover_uncovered then
      print("  Discovering source files based on include/exclude patterns...")
      local discovered_files = M.discover_source_files()
      
      for file_path in pairs(discovered_files) do
        local normalized_file = normalize_path(file_path)
        print("  Checking file: " .. normalized_file)
        
        local line_count = count_executable_lines(file_path)
        print("  File exists with " .. line_count .. " executable lines")
        
        -- Add this file to our data with zero coverage
        if not M.data.files[normalized_file] then
          print("  Adding file to coverage data: " .. normalized_file)
          M.data.files[normalized_file] = {
            lines = {},
            functions = {},
            line_count = line_count,
            discovered = true
          }
        end
      end
    else
      print("  File discovery is disabled. Enable with M.config.discover_uncovered = true")
    end
  else
    for i, file in ipairs(tracked_files) do
      if i <= 10 then -- Just show the first 10 files
        print("  " .. i .. ": " .. file)
      end
    end
    if #tracked_files > 10 then
      print("  ... and " .. (#tracked_files - 10) .. " more files")
    end
  end
  
  -- Process each file
  local file_count = 0
  for file, data in pairs(M.data.files) do
    file_count = file_count + 1
    print("DEBUG [Coverage] Processing file #" .. file_count .. ": " .. file)
    
    -- Check if this is a discovered file with no coverage
    local is_discovered_only = data.discovered and next(data.lines) == nil
    if is_discovered_only then
      print("  File was discovered but has no coverage")
    end
    
    -- Count tracked lines
    local line_keys = {}
    local covered_lines = 0
    for line, _ in pairs(data.lines) do
      covered_lines = covered_lines + 1
      table.insert(line_keys, line)
    end
    
    -- Sort and print first few lines
    if covered_lines > 0 then
      table.sort(line_keys, function(a, b) return tonumber(a) < tonumber(b) end)
      for i = 1, math.min(5, #line_keys) do
        print("  Covered line: " .. line_keys[i])
      end
    end
    print("  Total lines covered: " .. covered_lines)
    
    -- Count tracked functions
    local function_keys = {}
    local covered_functions = 0
    for func_name, _ in pairs(data.functions) do
      covered_functions = covered_functions + 1
      table.insert(function_keys, func_name)
    end
    
    -- Print first few functions
    if covered_functions > 0 then
      for i = 1, math.min(5, #function_keys) do
        print("  Covered function: " .. function_keys[i])
      end
    end
    print("  Total functions covered: " .. covered_functions)
    
    -- Update file statistics
    M.stats.files[file] = {
      total_lines = data.line_count or 0,
      covered_lines = covered_lines,
      total_functions = math.max(1, covered_functions), -- Ensure at least 1 function per file for calculation
      covered_functions = covered_functions,
      is_discovered_only = is_discovered_only
    }
    
    print("  Line count: " .. (data.line_count or 0) .. ", Covered: " .. covered_lines)
    
    -- Update global statistics
    M.stats.total_files = M.stats.total_files + 1
    M.stats.covered_files = M.stats.covered_files + (covered_lines > 0 and 1 or 0)
    M.stats.total_lines = M.stats.total_lines + (data.line_count or 0)
    M.stats.covered_lines = M.stats.covered_lines + covered_lines
    M.stats.total_functions = M.stats.total_functions + math.max(1, covered_functions)
    M.stats.covered_functions = M.stats.covered_functions + covered_functions
  end
  
  print("DEBUG [Coverage] Statistics calculation completed:")
  print("  Total files: " .. M.stats.total_files)
  print("  Covered files: " .. M.stats.covered_files)
  print("  Total lines: " .. M.stats.total_lines)
  print("  Covered lines: " .. M.stats.covered_lines)
  
  return M
end

-- Save a coverage report to a file
function M.save_report(file_path, format)
  format = format or "html"
  
  -- Try to load the reporting module
  local reporting_module = package.loaded["lib.reporting"] or require("lib.reporting")
  
  if reporting_module then
    -- Get the data and use the reporting module to save it
    local data = M.get_report_data()
    return reporting_module.save_coverage_report(file_path, data, format)
  else
    -- Fallback to directly saving the content
    local content = M.report(format)
    
    -- Use filesystem module to write the file
    local success, err = fs.write_file(file_path, content)
    if not success then
      return false, "Could not write to file: " .. (err or file_path)
    end
    
    return true
  end
end

-- Return the module
return M