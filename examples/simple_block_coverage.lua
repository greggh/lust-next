--[[
  simple_block_coverage.lua
  
  A simplified example demonstrating proper block coverage tracking with 
  correct line and function statistics.
]]

local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

-- Simple test module with various control structures
local TestModule = {}

-- Function with conditional branches
function TestModule.classify(value)
  if value < 0 then
    return "negative"
  elseif value == 0 then
    return "zero"
  else
    return "positive"
  end
end

-- Function with nested conditionals
function TestModule.analyze(value)
  if type(value) ~= "number" then
    return "not a number"
  end
  
  if value < 0 then
    if value < -10 then
      return "very negative"
    else
      return "slightly negative"
    end
  else
    if value > 10 then
      return "very positive"
    else
      return "slightly positive"
    end
  end
end

-- Function with a loop
function TestModule.sum(values)
  local total = 0
  for i, v in ipairs(values) do
    total = total + v
  end
  return total
end

-- Create a copy of this file to temp directory
local file_source = fs.read_file("examples/simple_block_coverage.lua")
local temp_file = os.tmpname() .. ".lua"
fs.write_file(temp_file, file_source)
print("Created temporary file: " .. temp_file)

-- Initialize coverage module
print("Initializing coverage...")
coverage.init({
  enabled = true,
  track_blocks = true,
  use_static_analysis = true,
  debug = true,
  discover_uncovered = false,
  use_default_patterns = false,
  include = {temp_file},     -- Only track our temp file
  source_dirs = {"/tmp"}
})

-- Start coverage tracking
print("Starting coverage tracking...")
coverage.start()

-- Execute functions with different inputs to create coverage
print("\nExecuting test functions:")
print("  classify(-5): " .. TestModule.classify(-5))
print("  classify(0): " .. TestModule.classify(0))
print("  classify(5): " .. TestModule.classify(5))

print("  analyze('hello'): " .. TestModule.analyze("hello"))
print("  analyze(-20): " .. TestModule.analyze(-20))
print("  analyze(20): " .. TestModule.analyze(20))

print("  sum({1,2,3}): " .. TestModule.sum({1,2,3}))

-- Stop tracking and generate report
print("\nStopping coverage tracking...")
coverage.stop()

-- Generate report
local report_data = coverage.get_report_data()

-- Save HTML report
local html_path = "/tmp/simple-block-coverage.html"
-- Get coverage report data
local report_data = coverage.get_report_data()

-- Use the reporting module to save the coverage report
local reporting = require("lib.reporting")
local success, err = reporting.save_coverage_report(html_path, report_data, "html")

print("\nCoverage Statistics:")
print("  Files: " .. report_data.summary.covered_files .. "/" .. report_data.summary.total_files)
print("  Lines: " .. report_data.summary.covered_lines .. "/" .. report_data.summary.total_lines .. 
     " (" .. string.format("%.1f%%", report_data.summary.line_coverage_percent) .. ")")
print("  Functions: " .. report_data.summary.covered_functions .. "/" .. report_data.summary.total_functions .. 
     " (" .. string.format("%.1f%%", report_data.summary.function_coverage_percent) .. ")")

if report_data.summary.total_blocks and report_data.summary.total_blocks > 0 then
  print("  Blocks: " .. report_data.summary.covered_blocks .. "/" .. report_data.summary.total_blocks .. 
       " (" .. string.format("%.1f%%", report_data.summary.block_coverage_percent) .. ")")
end

print("  Overall: " .. string.format("%.1f%%", report_data.summary.overall_percent))

-- Print details about our temporary file
for file_path, file_data in pairs(report_data.files) do
  if file_path:match(temp_file:gsub("%-", "%%-")) then
    print("\nDetailed coverage for test file:")
    print("  Total executable lines: " .. file_data.total_lines)
    print("  Covered lines: " .. file_data.covered_lines)
    print("  Line coverage: " .. string.format("%.1f%%", file_data.line_coverage_percent))
    
    -- Print actual line coverage status
    if file_data.lines then
      print("\nLine-by-line coverage status:")
      for i = 1, 60 do -- Check first 60 lines
        local covered = file_data.lines[i] and "covered" or "not covered"
        local executable = file_data.executable_lines and file_data.executable_lines[i]
        if executable ~= nil then
          print(string.format("  Line %2d: %s (executable: %s)", 
            i, covered, tostring(executable)))
        end
      end
    end
  end
end

print("\nHTML report saved to: " .. html_path)
print("Opening report in browser...")
os.execute("xdg-open " .. html_path .. " &>/dev/null")

-- Clean up
fs.delete_file(temp_file)
print("Cleaned up temporary file")

print("\nSimple block coverage example completed.")