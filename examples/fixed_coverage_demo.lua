--[[
  fixed_coverage_demo.lua
  
  This test file verifies that the fixed coverage system correctly processes
  the entire file, properly handling control flow, multiline comments and
  execution counts.

  It specifically tests:
  1. Full file processing (coverage tracking doesn't stop partway)
  2. Accurate execution counts (lines executed multiple times show correct counts)
  3. Proper handling of nested blocks and their parent-child relationships
]]

local firmo = require("firmo")
local coverage = require("lib.coverage")
local debug_hook = require("lib.coverage.debug_hook")
local fs = require("lib.tools.filesystem")

-- Enable detailed logging to debug coverage issues
local logger = require("lib.tools.logging")
logger.set_level(logger.LEVELS.DEBUG)

-- Get the current file path
local current_file = debug.getinfo(1).source:sub(2)  -- Remove @ prefix
print("Current file path:", current_file)

--[[ 
This multiline comment should be properly detected
and not marked as executable code
]]

-------------------------------------
-- Define test functions
-------------------------------------

-- This function will be called multiple times to test execution counts
local function repeat_function(iterations)
  local sum = 0
  for i = 1, iterations do
    sum = sum + i  -- This line should have execution count equal to 'iterations'
  end
  return sum
end

-- This function tests nested blocks
local function test_nested_conditions(a, b, c)
  local result = ""
  
  if a > 0 then
    result = result .. "a_positive"
    
    if b > 0 then
      result = result .. "_b_positive"
      
      if c > 0 then
        result = result .. "_c_positive"
      else
        result = result .. "_c_negative"
      end
    else
      result = result .. "_b_negative"
    end
  else
    result = result .. "a_negative"
    
    if b < 0 then
      result = result .. "_b_negative"
    else
      result = result .. "_b_positive"
    end
  end
  
  return result
end

-- This function contains an execution path that won't be covered
local function partial_coverage(value)
  if value > 100 then
    -- This branch won't be covered in our test
    return "value is very large"
  elseif value > 0 then
    return "value is positive"
  else
    return "value is zero or negative"
  end
end

-------------------------------------
-- Initialize coverage
-------------------------------------

print("Initializing coverage tracking...")
coverage.init({
  enabled = true,
  debug = true,
  track_blocks = true,
  use_static_analysis = true,
  include_patterns = {"examples/.*%.lua$"},
  source_dirs = {".", "examples"}
})

-- Explicitly track this file
print("Tracking current file...")
local tracking_result, tracking_err = coverage.track_file(current_file)
if tracking_err then
  print("Warning: Error tracking file:", tracking_err.message)
else
  print("File tracked successfully")
end

-- Start coverage
print("Starting coverage tracking...")
coverage.start()

-------------------------------------
-- Run test code
-------------------------------------

print("\nRunning test functions...")

-- Test execution counts with multiple calls
print("Testing repeat_function with different iteration counts:")
print("  3 iterations:", repeat_function(3))
print("  5 iterations:", repeat_function(5))
print("  10 iterations:", repeat_function(10))

-- Test nested conditions with different inputs
print("\nTesting nested conditions with various inputs:")
print("  All positive:", test_nested_conditions(1, 2, 3))
print("  Mixed values:", test_nested_conditions(1, 2, -3))
print("  Negative first:", test_nested_conditions(-1, 2, 3))
print("  Negative first and second:", test_nested_conditions(-1, -2, 3))

-- Test partial coverage function
print("\nTesting partial_coverage function:")
print("  With negative value:", partial_coverage(-5))
print("  With positive value:", partial_coverage(50))
-- Deliberately don't test with value > 100 to show incomplete coverage

-- Stop coverage
print("\nStopping coverage tracking...")
coverage.stop()

-------------------------------------
-- Analyze and display results
-------------------------------------

print("\nAnalyzing coverage data...")

-- Function to count table entries
local function count_table_entries(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

-- Verify file tracking status
if debug_hook.has_file(current_file) then
  local file_data = debug_hook.get_file_data(current_file)
  if not file_data then
    print("ERROR: File data not found despite has_file returning true!")
  else
    -- Check for execution counts
    print("\nExecution count analysis:")
    if file_data._execution_counts then
      local count = count_table_entries(file_data._execution_counts)
      print(string.format("  Found execution data for %d lines", count))
      
      -- Find the line with the highest execution count (should be in repeat_function)
      local max_count = 0
      local max_line = 0
      for line, count in pairs(file_data._execution_counts) do
        if count > max_count then
          max_count = count
          max_line = line
        end
      end
      
      print(string.format("  Highest execution count: Line %d executed %d times", max_line, max_count))
      
      -- Check if the count is correct (should be at least 18 from our repeat_function calls)
      if max_count >= 18 then
        print("  ✓ Execution count tracking is working correctly")
      else
        print("  ✗ Execution count is unexpectedly low - tracking may be broken")
      end
      
      -- Print some execution counts for reference
      print("  Sample execution counts:")
      local sorted_lines = {}
      for line, _ in pairs(file_data._execution_counts) do
        table.insert(sorted_lines, line)
      end
      table.sort(sorted_lines)
      
      -- Show first 5 executed lines
      local shown = 0
      for _, line in ipairs(sorted_lines) do
        if shown < 5 then
          print(string.format("    Line %d: executed %d times", line, file_data._execution_counts[line]))
          shown = shown + 1
        end
      end
    else
      print("  No execution count data found!")
    end
    
    -- Check block tracking
    print("\nBlock tracking analysis:")
    if file_data.logical_chunks then
      local total_blocks = count_table_entries(file_data.logical_chunks)
      local executed_blocks = 0
      local unexecuted_blocks = 0
      
      -- Count executed vs unexecuted blocks
      for _, block_data in pairs(file_data.logical_chunks) do
        if block_data.executed then
          executed_blocks = executed_blocks + 1
        else
          unexecuted_blocks = unexecuted_blocks + 1
        end
      end
      
      print(string.format("  Total blocks: %d", total_blocks))
      print(string.format("  Executed blocks: %d (%.1f%%)", 
                         executed_blocks, 
                         total_blocks > 0 and (executed_blocks / total_blocks * 100) or 0))
      print(string.format("  Unexecuted blocks: %d", unexecuted_blocks))
      
      -- Show some block details
      print("  Block details sample:")
      local count = 0
      for block_id, block_data in pairs(file_data.logical_chunks) do
        if count < 3 then
          local block_type = block_data.type or "unknown"
          local start_line = block_data.start_line or 0
          local end_line = block_data.end_line or 0
          local executed = block_data.executed and "yes" or "no"
          local exec_count = block_data.execution_count or 0
          
          print(string.format("    %s (type: %s, lines: %d-%d, executed: %s, count: %d)",
                             block_id, block_type, start_line, end_line, executed, exec_count))
          count = count + 1
        end
      end
    else
      print("  No logical chunks data found!")
    end
    
    -- Check multiline comment detection
    print("\nMultiline comment detection:")
    if file_data.line_classification then
      local comment_lines = 0
      local executable_lines = 0
      local comment_and_executable = 0
      
      for line_num, classification in pairs(file_data.line_classification) do
        if classification.in_multiline_comment then
          comment_lines = comment_lines + 1
        end
        
        if file_data.executable_lines and file_data.executable_lines[line_num] then
          executable_lines = executable_lines + 1
          
          if classification.in_multiline_comment then
            comment_and_executable = comment_and_executable + 1
          end
        end
      end
      
      print(string.format("  Detected %d lines in multiline comments", comment_lines))
      print(string.format("  Found %d executable lines", executable_lines))
      
      if comment_and_executable > 0 then
        print(string.format("  ERROR: %d lines are both in multiline comments and marked executable!", 
                          comment_and_executable))
      else
        print("  ✓ No multiline comment lines are marked as executable")
      end
    else
      print("  No line classification data found!")
    end
    
    -- Check source line to identify coverage gaps
    if file_data.source and file_data.executable_lines then
      print("\nCoverage continuity check:")
      local last_executable = 0
      local last_executed = 0
      local coverage_gap = false
      local total_lines = #file_data.source
      
      -- Find the last executable and last executed line
      for i = 1, total_lines do
        if file_data.executable_lines[i] then
          last_executable = i
          
          if file_data._execution_counts and file_data._execution_counts[i] then
            last_executed = i
          end
        end
      end
      
      -- Check for coverage gaps
      for i = 1, last_executable do
        if file_data.executable_lines[i] and 
           (not file_data._execution_counts or not file_data._execution_counts[i]) and
           i < last_executed then
          coverage_gap = true
          print(string.format("  ⚠ Coverage gap detected: Line %d is executable but not executed, while later line %d was executed", 
                            i, last_executed))
          break
        end
      end
      
      if not coverage_gap then
        print("  ✓ No unexpected coverage gaps detected")
      end
      
      -- Calculate coverage percentage
      local total_executable = 0
      local total_executed = 0
      
      for i = 1, total_lines do
        if file_data.executable_lines[i] then
          total_executable = total_executable + 1
          if file_data._execution_counts and file_data._execution_counts[i] then
            total_executed = total_executed + 1
          end
        end
      end
      
      print(string.format("  Coverage status: %d of %d executable lines executed (%.1f%%)",
                        total_executed,
                        total_executable,
                        total_executable > 0 and (total_executed / total_executable * 100) or 0))
    end
  end
else
  print("ERROR: Current file is not being tracked!")
end

-- Generate HTML report
print("\nGenerating HTML report...")
local report_data = coverage.get_report_data()
local report_path = "/tmp/fixed-coverage-demo.html"

-- Use the reporting module to save the coverage report
local reporting = require("lib.reporting")
local success, err = reporting.save_coverage_report(report_path, report_data, "html")

if success then
  print("HTML coverage report saved to: " .. report_path)
  print("\nMeasured execution counts and coverage data:")
  
  -- Display count of lines with different execution counts
  for file_path, file_data in pairs(report_data.files) do
    if file_path:match("fixed_coverage_demo") then
      print("  File: " .. file_path)
      if file_data.lines then
        local exec_counts = {}
        
        -- Get original file data to check execution counts
        local original_file = report_data.original_files and report_data.original_files[file_path]
        if original_file and original_file._execution_counts then
          -- Count lines by execution count
          for line, count in pairs(original_file._execution_counts) do
            exec_counts[count] = (exec_counts[count] or 0) + 1
          end
          
          -- Display counts
          print("  Execution count distribution:")
          
          local counts = {}
          for count, lines in pairs(exec_counts) do
            table.insert(counts, {count = count, lines = lines})
          end
          
          -- Sort by count
          table.sort(counts, function(a, b) return a.count < b.count end)
          
          -- Display distribution
          for _, data in ipairs(counts) do
            print(string.format("    %d lines executed %d times", data.lines, data.count))
          end
        end
      end
    end
  end
  
  -- Open the report
  print("\nOpening report in browser...")
  os.execute("xdg-open " .. report_path .. " &>/dev/null")
else
  print("Failed to generate HTML report: " .. (err and err.message or "unknown error"))
end

print("\nFixed coverage demo complete!")