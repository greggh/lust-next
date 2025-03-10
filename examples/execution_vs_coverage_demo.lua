--[[
  execution_vs_coverage_demo.lua
  
  Demonstration of the distinction between execution (code that runs) and 
  coverage (code validated by tests) in the lust-next coverage module.
]]

local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

-- Create a sample module for testing
local DemoModule = {}

-- Function with conditional branches to demonstrate different coverage states
function DemoModule.evaluate(value)
  local result = ""
  
  -- This will execute for all calls but will only be validated by the tests for value=-5
  if value < 0 then
    result = "negative"
    
  -- This will execute only for zero values but won't be validated by tests
  elseif value == 0 then
    result = "zero"
    
  -- This will execute only for positive values and will be validated by tests for value=5
  else
    result = "positive"
  end
  
  -- This line always executes
  return result
end

-- Get the current file path
local current_file = debug.getinfo(1, "S").source:sub(2)

-- Initialize coverage only for this file
coverage.init({
  enabled = true,
  debug = true,
  include = {current_file},
  exclude = {},
  source_dirs = {"."},
  track_blocks = true,
})

print("Starting coverage tracking...")
coverage.start()

-- TEST 1: Executed and covered (green)
print("\nTest 1: Executing with value=5 and validating result")
local result1 = DemoModule.evaluate(5)
print("Result:", result1)
assert(result1 == "positive", "Expected 'positive' for value=5")
-- Mark this branch as officially covered through validation
coverage.track_line(current_file, 28)  -- positive branch (else)
coverage.track_line(current_file, 29)  -- result = "positive"

-- TEST 2: Just executed, not covered (amber)
print("\nTest 2: Executing with value=0 but NOT validating result")
local result2 = DemoModule.evaluate(0)
print("Result:", result2)
-- No test assertions here, so it's executed but not covered
-- Use the proper API to track execution for lines that debug hooks might miss
print("\nTracking execution with the proper API for the zero branch")
coverage.track_execution(current_file, 23)  -- elseif line
coverage.track_execution(current_file, 24)  -- zero branch

-- TEST 3: Executed and covered, different branch (green)
print("\nTest 3: Executing with value=-5 and validating result")
local result3 = DemoModule.evaluate(-5)
print("Result:", result3)
assert(result3 == "negative", "Expected 'negative' for value=-5")
-- Mark this branch as officially covered through validation
coverage.track_line(current_file, 19)  -- negative branch (if value < 0)
coverage.track_line(current_file, 20)  -- result = "negative"

-- Stop coverage tracking
coverage.stop()

-- Generate HTML report
local report_path = "/tmp/execution_vs_coverage_demo.html"
coverage.save_report(report_path, "html")
print("\nGenerated HTML report:", report_path)

-- Print validation summary
print("\nCoverage summary:")
local summary = coverage.get_report_data().summary
print(string.format("- Line coverage: %.2f%%", summary.line_coverage_percent))

-- Debug executed vs covered lines
local raw_data = coverage.get_raw_data()
local file_data = nil
for path, data in pairs(raw_data.files) do
  if path:match("execution_vs_coverage_demo.lua") then
    file_data = data
    break
  end
end

if file_data then
  print("\nDebug - Executed lines:")
  local executed_lines = {}
  for line_num, executed in pairs(file_data._executed_lines or {}) do
    if executed and line_num >= 19 and line_num <= 29 then
      table.insert(executed_lines, tostring(line_num))
    end
  end
  table.sort(executed_lines, function(a, b) return tonumber(a) < tonumber(b) end)
  print(table.concat(executed_lines, ", "))
  
  print("\nDebug - Covered lines:")
  local covered_lines = {}
  for line_num, covered in pairs(file_data.lines or {}) do
    if covered and line_num >= 19 and line_num <= 29 then
      table.insert(covered_lines, tostring(line_num))
    end
  end
  table.sort(covered_lines, function(a, b) return tonumber(a) < tonumber(b) end)
  print(table.concat(covered_lines, ", "))
end

print("\nCheck the HTML report to see:")
print("- GREEN: Lines executed AND validated by tests (lines 19-20, 28-29)")
print("- AMBER: Lines executed but NOT validated (lines 23-24)")
print("- RED: Lines not executed (any branches not taken)")
print("- GRAY: Non-executable lines (comments, whitespace)")
print("\nThis distinction helps identify portions of your code that run during tests")
print("but aren't properly validated by assertions.")