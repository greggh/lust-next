--[[
  comprehensive_coverage_example.lua
  
  A comprehensive example demonstrating proper integration between the coverage
  module and the reporting module for generating HTML reports with block visualization.
]]

-- Import the coverage module
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

-- Create a test module with various control structures to test coverage
local test_module = {}

-- Function with conditional branching
function test_module.analyze_value(value)
  -- Type checking branch
  if type(value) ~= "number" then
    if type(value) == "string" then
      -- Try to convert string to number
      local num = tonumber(value)
      if num then
        return test_module.analyze_value(num)
      else
        return "non-numeric string"
      end
    elseif type(value) == "boolean" then
      return value and "true" or "false"
    else
      return "unsupported type"
    end
  end

  -- Number classification branch
  if value < 0 then
    -- Negative numbers
    if value < -100 then
      return "very small"
    elseif value < -10 then
      return "small"
    else
      return "negative"
    end
  elseif value == 0 then
    return "zero"
  else
    -- Positive numbers
    if value <= 10 then
      return "small positive"
    elseif value <= 100 then
      return "medium positive"
    else
      return "large positive"
    end
  end
end

-- Function with loops
function test_module.process_data(data, mode)
  local result = {}
  local sum = 0

  -- For loop with conditional branches
  for i, value in ipairs(data) do
    if mode == "filter" then
      -- Filter mode branch
      if type(value) == "number" and value > 0 then
        table.insert(result, value)
      end
    elseif mode == "transform" then
      -- Transform mode branch
      if type(value) == "number" then
        table.insert(result, value * 2)
      elseif type(value) == "string" then
        table.insert(result, value:upper())
      else
        -- This branch will be uncovered
        table.insert(result, value)
      end
    elseif mode == "analyze" then
      -- Analyze mode branch
      table.insert(result, test_module.analyze_value(value))
    end
    
    -- Accumulate sum if possible
    if type(value) == "number" then
      sum = sum + value
    end
  end
  
  -- While loop example
  local i = 1
  while i <= #result do
    -- Add index metadata for debugging
    if mode == "debug" then
      if type(result[i]) == "string" then
        result[i] = i .. ":" .. result[i]
      elseif type(result[i]) == "number" then
        result[i] = i .. ":" .. tostring(result[i])
      end
    end
    i = i + 1
  end
  
  -- Repeat loop example - will not be executed in our tests
  local has_modified = false
  repeat
    if mode == "strict" and #result > 5 then
      -- Only keep first 5 elements
      while #result > 5 do
        table.remove(result)
      end
      has_modified = true
    end
  until has_modified or mode ~= "strict"
  
  return result, sum
end

-- Function with nested function definitions
function test_module.create_calculator()
  local calculator = {}
  
  -- Inner function 1
  function calculator.add(a, b)
    return a + b
  end
  
  -- Inner function 2
  function calculator.subtract(a, b)
    return a - b
  end
  
  -- Inner function 3 - will not be called
  function calculator.multiply(a, b)
    return a * b
  end
  
  return calculator
end

-- First, write this example file to a temporary location for isolated testing
local temp_file_path = os.tmpname() .. ".lua"
fs.write_file(temp_file_path, fs.read_file("examples/comprehensive_coverage_example.lua"))
print("Created temporary file at: " .. temp_file_path)

-- Initialize coverage
print("Initializing coverage with block tracking...")
coverage.init({
  enabled = true,
  track_blocks = true,                -- Enable block tracking
  use_static_analysis = true,         -- Use static analysis for accurate block tracking
  debug = true,                       -- Output extra debugging information
  discover_uncovered = false,         -- Don't discover unrelated files
  use_default_patterns = false,       -- Don't use default include patterns
  include = {temp_file_path},         -- Only track our temporary file
  source_dirs = {"/tmp"}              -- Look in /tmp for source files
})

-- Start tracking coverage
print("Starting coverage tracking...")
coverage.start()

-- Enable detailed debug output for function tracking
local old_debug = coverage.debug
coverage.debug_functions = function()
  print("\nDEBUG: Function Coverage Information:")
  local data = coverage.get_report_data()
  local count = 0
  
  for file_path, file_data in pairs(data.files) do
    if file_path:match("/tmp/") then
      print("  File: " .. file_path)
      print("  Functions tracked: " .. file_data.total_functions)
      
      if file_data.functions then
        for _, func in ipairs(file_data.functions) do
          print(string.format("    %s (line %d): executed=%s, calls=%d",
            func.name, func.line, tostring(func.executed), func.calls or 0))
        end
      else
        print("    No function data available")
      end
      count = count + 1
    end
  end
  
  if count == 0 then
    print("  No function data found for the test file!")
  end
end

-- Execute test code that covers most but not all blocks
print("\nExecuting test code...")

-- Test analyze_value with different types
print("Testing analyze_value:")
print("  String: " .. test_module.analyze_value("hello"))
print("  Numeric string: " .. test_module.analyze_value("123"))
print("  Boolean: " .. test_module.analyze_value(true))
print("  Number (negative small): " .. test_module.analyze_value(-5))
print("  Number (zero): " .. test_module.analyze_value(0))
print("  Number (positive large): " .. test_module.analyze_value(200))
-- Note: We're deliberately not testing all branches

-- Test process_data with different modes
print("\nTesting process_data:")
local data = {1, -2, "hello", 10, "test"}  -- Changed true to "test" to avoid table.concat issue
local result1, sum1 = test_module.process_data(data, "filter")
print("  Filter mode: " .. table.concat(result1, ", ") .. " (sum: " .. sum1 .. ")")

local result2, sum2 = test_module.process_data(data, "transform")
print("  Transform mode: " .. table.concat(result2, ", ") .. " (sum: " .. sum2 .. ")")

-- Test calculator
print("\nTesting calculator:")
local calc = test_module.create_calculator()
print("  Addition: " .. calc.add(5, 3))
print("  Subtraction: " .. calc.subtract(10, 4))
-- Note: We're deliberately not testing the multiply function

-- Stop coverage tracking
print("\nStopping coverage tracking...")
coverage.stop()

-- Debug function information
if coverage.debug_functions then
  coverage.debug_functions()
end

-- Get coverage report data
local report_data = coverage.get_report_data()

-- Clean up temporary file at the end
local function cleanup()
  fs.delete_file(temp_file_path)
  print("Cleaned up temporary file")
end

-- Register cleanup on script exit
local old_exit = os.exit
os.exit = function(code)
  cleanup()
  old_exit(code)
end

-- Generate and save different report formats
print("\nGenerating reports...")

-- 1. Save HTML report directly using the coverage module
local html_path = "/tmp/comprehensive-coverage.html"
-- Get coverage report data
local report_data = coverage.get_report_data()

-- Use the reporting module to save the coverage report
local reporting = require("lib.reporting")
local success, err = reporting.save_coverage_report(html_path, report_data, "html")
if success then
  print("HTML report saved to: " .. html_path)
else
  print("Failed to save HTML report")
end

-- 2. Try using the reporting module directly
local reporting_module = require("lib.reporting")
local report_dir = "/tmp/coverage-reports"

-- Ensure directory exists
fs.ensure_directory_exists(report_dir)

-- Save reports using the reporting module's auto_save_reports function
local reports = reporting_module.auto_save_reports(
  report_data,         -- coverage data
  nil,                 -- quality data (none for this example)
  nil,                 -- test results data (none for this example)
  {                    -- configuration options
    report_dir = report_dir,
    report_suffix = "-" .. os.date("%Y%m%d"),
    verbose = true
  }
)

-- Print coverage statistics
print("\nCoverage Statistics:")
print("  Files: " .. report_data.summary.covered_files .. "/" .. report_data.summary.total_files)
print("  Lines: " .. report_data.summary.covered_lines .. "/" .. report_data.summary.total_lines .. 
     " (" .. string.format("%.1f%%", report_data.summary.line_coverage_percent) .. ")")
print("  Functions: " .. report_data.summary.covered_functions .. "/" .. report_data.summary.total_functions .. 
     " (" .. string.format("%.1f%%", report_data.summary.function_coverage_percent) .. ")")

-- Print block coverage statistics if available
if report_data.summary.total_blocks and report_data.summary.total_blocks > 0 then
  print("  Blocks: " .. report_data.summary.covered_blocks .. "/" .. report_data.summary.total_blocks .. 
       " (" .. string.format("%.1f%%", report_data.summary.block_coverage_percent) .. ")")
end

print("  Overall Coverage: " .. string.format("%.1f%%", report_data.summary.overall_percent))

-- Print report locations
print("\nReports saved to:")
print("  - " .. html_path .. " (primary HTML report)")
for format, result in pairs(reports) do
  if result.success then
    print("  - " .. result.path .. " (" .. format .. ")")
  end
end

print("\nOpen the HTML report in a browser to view the visualization with block highlighting.")
os.execute("xdg-open " .. html_path .. " &>/dev/null")

print("\nComprehensive coverage example complete!")