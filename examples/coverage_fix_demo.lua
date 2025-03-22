--[[
  coverage_fix_demo.lua
  
  A specialized test file to verify the fixes to the coverage system.
  This file is specifically designed to test:
  
  1. Execution count tracking (lines are executed multiple times)
  2. Multiline comment detection (comments are not marked as executable)
  3. Block coverage tracking (blocks are properly marked as executed)
]]

local firmo = require("firmo")
local coverage = require("lib.coverage")
local debug_hook = require("lib.coverage.debug_hook")

-- Utility functions 
local function count_table_entries(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

-- Test module with various test cases
local TestModule = {}

--[[ 
This is a multiline comment that should not be considered executable
function not_real_function()
  return "This should not be executed"
end
]]

-- Simple function to test execution counts
function TestModule.count_calls(n)
  local result = 0
  for i = 1, n do
    result = result + 1  -- This line will be executed multiple times
  end
  return result
end

-- Function with conditional branches to test block coverage
function TestModule.conditional_function(a, b)
  if a > b then
    return "a is greater"
  elseif a < b then
    return "b is greater"
  else
    return "equal"
  end
end

-- Function with nested blocks to test nested block tracking
function TestModule.nested_blocks(value)
  if value > 0 then
    if value > 10 then
      return "large positive"
    else
      return "small positive"
    end
  else
    if value < -10 then
      return "large negative"
    else
      return "small negative or zero"
    end
  end
end

-- Function with multiple exit points for block coverage edge cases
function TestModule.multi_exit(list)
  if not list or #list == 0 then
    return 0  -- Early exit
  end
  
  local sum = 0
  for _, v in ipairs(list) do
    if type(v) ~= "number" then
      return nil  -- Exit on invalid input
    end
    sum = sum + v
  end
  
  return sum
end

-- Initialize coverage tracking
print("Initializing coverage tracking...")
coverage.init({
  enabled = true,
  track_blocks = true,
  use_static_analysis = true,
  debug = true,
  should_track_example_files = true,
  source_dirs = {".", "lib", "examples"},
  include_patterns = {"examples/.*%.lua$"}
})

-- Explicitly track this file
local current_file = debug.getinfo(1).source:sub(2)  -- Remove @ prefix
print("Current file: " .. current_file)
coverage.track_file(current_file)
coverage.start()

-- Run tests with multiple executions to verify count tracking
print("\nRunning tests...")
print("Testing count_calls with 5 iterations: " .. TestModule.count_calls(5))
print("Testing count_calls with 10 iterations: " .. TestModule.count_calls(10))

-- Test conditional branches
print("\nTesting conditional branches:")
print("a > b: " .. TestModule.conditional_function(10, 5))
print("a < b: " .. TestModule.conditional_function(5, 10))
print("a = b: " .. TestModule.conditional_function(7, 7))

-- Test nested blocks
print("\nTesting nested blocks:")
print("Large positive: " .. TestModule.nested_blocks(20))
print("Small positive: " .. TestModule.nested_blocks(5))
print("Large negative: " .. TestModule.nested_blocks(-20))
print("Small negative: " .. TestModule.nested_blocks(-5))

-- Test multi-exit function
print("\nTesting multi-exit function:")
print("Empty list: " .. tostring(TestModule.multi_exit({})))
print("Valid list: " .. tostring(TestModule.multi_exit({1, 2, 3})))
print("Invalid list: " .. tostring(TestModule.multi_exit({1, "not a number", 3})))

-- Stop coverage tracking
coverage.stop()

-- Check if the current file is being tracked
print("\nVerifying file tracking:")
if debug_hook.has_file(current_file) then
  print("Current file is tracked properly")
  
  -- Examine file data
  local file_data = debug_hook.get_file_data(current_file)
  
  -- Check execution counts
  print("\nExecution count data:")
  if file_data._execution_counts then
    local total_lines = 0
    local executed_lines = 0
    local line_with_highest_count = 0
    local highest_count = 0
    
    for line_num, count in pairs(file_data._execution_counts) do
      total_lines = total_lines + 1
      executed_lines = executed_lines + (count > 0 and 1 or 0)
      
      if count > highest_count then
        highest_count = count
        line_with_highest_count = line_num
      end
      
      -- Print the first 5 execution counts
      if total_lines <= 5 then
        print(string.format("  Line %d: executed %d times", line_num, count))
      end
    end
    
    if total_lines > 5 then
      print(string.format("  ... and %d more executed lines", total_lines - 5))
    end
    
    print(string.format("  Total executed lines: %d", executed_lines))
    print(string.format("  Highest execution count: Line %d was executed %d times", 
                      line_with_highest_count, highest_count))
  else
    print("No execution count data found!")
  end
  
  -- Check block data
  print("\nBlock coverage data:")
  if file_data.logical_chunks then
    local total_blocks = count_table_entries(file_data.logical_chunks)
    local executed_blocks = 0
    
    for block_id, block_data in pairs(file_data.logical_chunks) do
      if block_data.executed then
        executed_blocks = executed_blocks + 1
      end
    end
    
    print(string.format("  Total blocks: %d", total_blocks))
    print(string.format("  Executed blocks: %d", executed_blocks))
    print(string.format("  Block coverage: %.1f%%", 
                      total_blocks > 0 and (executed_blocks / total_blocks * 100) or 0))
    
    -- Show details of a few blocks
    print("\n  Block details:")
    local i = 0
    for block_id, block_data in pairs(file_data.logical_chunks) do
      i = i + 1
      if i <= 5 then
        print(string.format("    %s: type=%s, lines=%d-%d, executed=%s, count=%s", 
                         block_id,
                         block_data.type or "unknown",
                         block_data.start_line or 0,
                         block_data.end_line or 0,
                         block_data.executed and "yes" or "no",
                         block_data.execution_count or "unknown"))
      end
    end
    
    if i > 5 then
      print(string.format("    ... and %d more blocks", i - 5))
    end
  else
    print("No logical chunks data found!")
  end
  
  -- Check multiline comment detection
  print("\nMultiline comment detection:")
  if file_data.line_classification then
    local multiline_start = 0
    local multiline_end = 0
    
    for line_num, classification in pairs(file_data.line_classification) do
      if classification.in_multiline_comment and multiline_start == 0 then
        multiline_start = line_num
      elseif not classification.in_multiline_comment and multiline_start > 0 and multiline_end == 0 then
        multiline_end = line_num - 1
        break
      end
    end
    
    if multiline_start > 0 then
      print(string.format("  Detected multiline comment from lines %d to %d", multiline_start, multiline_end))
      
      -- Check if any lines inside the comment are marked as executable
      local executable_in_comment = false
      for line_num = multiline_start, multiline_end do
        if file_data.executable_lines and file_data.executable_lines[line_num] then
          executable_in_comment = true
          print(string.format("  ERROR: Line %d is inside a multiline comment but marked as executable!", line_num))
        end
      end
      
      if not executable_in_comment then
        print("  Success: No lines inside multiline comments are marked as executable")
      end
    else
      print("  No multiline comments detected or detection failed")
    end
  else
    print("No line classification data found!")
  end
else
  print("ERROR: Current file is not being tracked!")
end

-- Generate and save HTML report
print("\nGenerating HTML report...")
local report_data = coverage.get_report_data()
local report_path = "/tmp/coverage-fix-demo.html"

-- Use the reporting module to save the coverage report
local reporting = require("lib.reporting")
local success, err = reporting.save_coverage_report(report_path, report_data, "html")

if success then
  print("HTML coverage report saved to: " .. report_path)
  print("Opening report in browser...")
  os.execute("xdg-open " .. report_path .. " &>/dev/null")
else
  print("Failed to generate HTML report: " .. (err and err.message or "unknown error"))
end

print("\nCoverage fix demo complete!")