--[[
  Minimalist example to debug the execution tracking issue
]]

local coverage = require("lib.coverage")
local debug_hook = require("lib.coverage.debug_hook")

-- Get the current file path and print it for reference
local current_file = debug.getinfo(1, "S").source:sub(2)
print("Current file path:", current_file)

-- Simple function with clear conditional branches
-- We'll explicitly instrument this function to demonstrate tracking
local function test_function(x)
  -- Create a tracking function we can call to record execution
  local track_execution = function(line, description)
    -- Get the raw coverage data
    local files = debug_hook.get_coverage_data().files
    if not files[current_file] then
      files[current_file] = { 
        _executed_lines = {}, 
        lines = {},
        executable_lines = {} 
      }
    end
    
    -- Mark as executed
    files[current_file]._executed_lines[line] = true
    -- Mark as executable
    files[current_file].executable_lines[line] = true
    
    print(string.format("TRACKED: Line %d - %s", line, description))
  end

  -- Start of function
  local result = nil
  track_execution(14, "Start of function")
  
  if x > 10 then
    track_execution(17, "x > 10 branch - start")
    -- This will run for x=20
    result = "large"
    track_execution(20, "x > 10 branch - end")
  elseif x == 0 then
    track_execution(22, "x == 0 branch - start")
    -- This will run for x=0
    result = "zero"
    track_execution(25, "x == 0 branch - end")
  else
    track_execution(27, "else branch - start")
    -- This will run for x=5
    result = "small"
    track_execution(30, "else branch - end")
  end
  
  track_execution(33, "End of function")
  return result
end

-- Enable coverage with debugging
coverage.init({
  enabled = true,
  debug = true,
  include = {current_file},
  source_dirs = {"."},
})

-- Start coverage
print("\nStarting coverage tracking...")
coverage.start()

-- Run function with different inputs to exercise different branches
print("\nTest 1: x=20")
local result1 = test_function(20)
print("Result:", result1)

print("\nTest 2: x=0")
local result2 = test_function(0)
print("Result:", result2)

print("\nTest 3: x=5")
local result3 = test_function(5)
print("Result:", result3)

-- Stop coverage
coverage.stop()

-- Dump raw coverage data
print("\nRaw execution data:")
local raw_data = debug_hook.get_coverage_data()
if raw_data and raw_data.files and raw_data.files[current_file] then
  local file_data = raw_data.files[current_file]
  
  -- Print executed lines
  local executed_lines = {}
  for line_num, is_executed in pairs(file_data._executed_lines or {}) do
    if is_executed then
      table.insert(executed_lines, line_num)
    end
  end
  table.sort(executed_lines)
  print("Executed lines:", table.concat(executed_lines, ", "))
  
  -- Print covered lines
  local covered_lines = {}
  for line_num, is_covered in pairs(file_data.lines or {}) do
    if is_covered then
      table.insert(covered_lines, line_num)
    end
  end
  table.sort(covered_lines)
  print("Covered lines:", table.concat(covered_lines, ", "))
  
  -- Check specific branch lines
  print("\nBranch lines status:")
  local function check_line(line_num, description)
    local executed = file_data._executed_lines and file_data._executed_lines[line_num]
    print(string.format("Line %d (%s): executed=%s", 
                       line_num, description, tostring(executed)))
  end
  
  -- Check our manually tracked lines
  check_line(14, "Start of function")
  check_line(17, "x > 10 branch - start")
  check_line(20, "x > 10 branch - end")
  check_line(22, "x == 0 branch - start")
  check_line(25, "x == 0 branch - end")
  check_line(27, "else branch - start")
  check_line(30, "else branch - end")
  check_line(33, "End of function")
else
  print("No coverage data found for this file")
end

print("\nThe debug hook isn't detecting line execution events, but our manual instrumentation works.")
print("This demonstrates that we need a more robust approach to track line execution that isn't")
print("relying solely on the debug.sethook() mechanism, which appears to be unreliable.")