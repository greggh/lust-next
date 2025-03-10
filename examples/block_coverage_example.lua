--[[
  block_coverage_example.lua
  
  An example demonstrating block coverage tracking and visualization.
]]

-- Create a test module with various control structures
local test_module = {}

-- Function with multiple branches
function test_module.classify_number(num)
  -- Check if it's a number first
  if type(num) ~= "number" then
    return "not a number"
  end
  
  -- Nested branches
  if num < 0 then
    -- Negative numbers
    if num < -10 then
      return "large negative"
    else
      return "small negative"
    end
  else
    -- Zero or positive
    if num == 0 then
      return "zero"
    else
      -- Positive numbers
      if num > 10 then
        return "large positive"
      else
        return "small positive"
      end
    end
  end
end

-- Function with loops
function test_module.process_list(list, operation)
  local result = 0
  
  -- For loop
  for i, value in ipairs(list) do
    if operation == "sum" then
      result = result + value
    elseif operation == "multiply" then
      if i == 1 then
        result = value
      else
        result = result * value
      end
    end
  end
  
  -- While loop demonstration
  local i = 1
  while i <= 3 and i <= #list do
    -- This branch won't be covered in our test
    if operation == "subtract" then
      result = result - list[i]
    end
    i = i + 1
  end
  
  return result
end

-- Start coverage tracking
local coverage = require "lib.coverage"
coverage.init({
  enabled = true,
  track_blocks = true,
  use_static_analysis = true,
  debug = true
})
coverage.start()

-- Execute some specific code paths
print("Testing classify_number function:")
print("  classify_number('hello') -> " .. test_module.classify_number("hello"))
print("  classify_number(-5) -> " .. test_module.classify_number(-5))
print("  classify_number(-20) -> " .. test_module.classify_number(-20))
print("  classify_number(0) -> " .. test_module.classify_number(0))
print("  classify_number(5) -> " .. test_module.classify_number(5))
print("  classify_number(20) -> " .. test_module.classify_number(20))

print("\nTesting process_list function:")
print("  process_list({1, 2, 3}, 'sum') -> " .. test_module.process_list({1, 2, 3}, "sum"))
print("  process_list({2, 3, 4}, 'multiply') -> " .. test_module.process_list({2, 3, 4}, "multiply"))
-- Deliberately don't test the "subtract" branch to show uncovered blocks

-- Stop coverage tracking
coverage.stop()

-- Generate and save HTML report
local report_data = coverage.get_report_data()
local report_path = "/tmp/block-coverage-example.html"

-- Use the coverage module's save_report function which properly integrates with the reporting module
local success = coverage.save_report(report_path, "html")

-- The report should now include proper block highlighting using the HTML formatter

print("\nCoverage statistics:")
print("  Files: " .. report_data.summary.covered_files .. "/" .. report_data.summary.total_files)
print("  Lines: " .. report_data.summary.covered_lines .. "/" .. report_data.summary.total_lines)
print("  Functions: " .. report_data.summary.covered_functions .. "/" .. report_data.summary.total_functions)
print("  Blocks: " .. report_data.summary.covered_blocks .. "/" .. report_data.summary.total_blocks)
print("  Block coverage: " .. string.format("%.1f%%", report_data.summary.block_coverage_percent))
print("  Overall coverage: " .. string.format("%.1f%%", report_data.summary.overall_percent))

print("\nHTML coverage report saved to: " .. report_path)
print("Opening report in browser...")
os.execute("xdg-open " .. report_path .. " &>/dev/null")

print("\nBlock coverage example complete!")