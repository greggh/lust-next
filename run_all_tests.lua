#!/usr/bin/env lua
-- Enhanced test runner for lust-next that runs individual test files
-- properly handling module isolation to prevent cross-test interference

local lust_next = require("lust-next")

print("lust-next Test Runner")
print("--------------------")
print("")

-- Add a counter for tests
lust_next.test_stats = {
  total = 0,
  passes = 0,
  failures = 0,
  pending = 0,
  by_file = {}
}

-- Patch lust_next.it to keep track of test counts
local original_it = lust_next.it
lust_next.it = function(name, fn, options)
  -- Get the source location to track which file this test is from
  local info = debug.getinfo(2, "S")
  local file = info.source:match("@(.+)") or info.source
  local file_name = file:match("([^/\\]+)%.lua$") or file
  
  -- Initialize file stats if needed
  if not lust_next.test_stats.by_file[file_name] then
    lust_next.test_stats.by_file[file_name] = {
      total = 0,
      passes = 0,
      failures = 0,
      pending = 0
    }
  end
  
  -- Wrap the function to track pass/fail status
  local wrapped_fn = nil
  if type(fn) == "function" then
    wrapped_fn = function(...)
      lust_next.test_stats.total = lust_next.test_stats.total + 1
      lust_next.test_stats.by_file[file_name].total = lust_next.test_stats.by_file[file_name].total + 1
      
      -- Handle excluded tests
      if options and options.excluded then
        lust_next.test_stats.pending = lust_next.test_stats.pending + 1
        lust_next.test_stats.by_file[file_name].pending = lust_next.test_stats.by_file[file_name].pending + 1
        return fn(...)
      end
      
      -- Count test results
      local success, result = pcall(fn, ...)
      if success then
        lust_next.test_stats.passes = lust_next.test_stats.passes + 1
        lust_next.test_stats.by_file[file_name].passes = lust_next.test_stats.by_file[file_name].passes + 1
      else
        lust_next.test_stats.failures = lust_next.test_stats.failures + 1
        lust_next.test_stats.by_file[file_name].failures = lust_next.test_stats.by_file[file_name].failures + 1
      end
      
      if not success then
        error(result, 2) -- Re-throw the error to maintain original behavior
      end
      return result
    end
  else
    wrapped_fn = fn -- Pass through non-function values (like pending tests)
  end
  
  return original_it(name, wrapped_fn, options)
end

-- Also patch pending for proper counting
local original_pending = lust_next.pending
lust_next.pending = function(message)
  -- Get the source location
  local info = debug.getinfo(2, "S")
  local file = info.source:match("@(.+)") or info.source
  local file_name = file:match("([^/\\]+)%.lua$") or file
  
  -- Initialize file stats if needed
  if not lust_next.test_stats.by_file[file_name] then
    lust_next.test_stats.by_file[file_name] = {
      total = 0,
      passes = 0,
      failures = 0,
      pending = 0
    }
  end
  
  -- Count this pending test
  lust_next.test_stats.total = lust_next.test_stats.total + 1
  lust_next.test_stats.pending = lust_next.test_stats.pending + 1
  lust_next.test_stats.by_file[file_name].total = lust_next.test_stats.by_file[file_name].total + 1
  lust_next.test_stats.by_file[file_name].pending = lust_next.test_stats.by_file[file_name].pending + 1
  
  return original_pending(message)
end

-- Get files from tests directory
local function get_test_files()
  local command = "ls -1 tests/*.lua"
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  
  local files = {}
  for file in result:gmatch("([^\n]+)") do
    table.insert(files, file)
  end
  
  return files
end

-- Count test assertions in output text
local function extract_test_counts(output)
  local passes = 0
  local failures = 0
  local pending = 0
  
  -- Parse the output for colorized test results
  -- First try to capture using a more specific pattern
  for line in output:gmatch("[^\r\n]+") do
    if line:match(".*%[32mPASS%[0m") then
      passes = passes + 1
    elseif line:match(".*%[31mFAIL%[0m") then 
      failures = failures + 1
    elseif line:match(".*%[33mPENDING:%[0m") then
      pending = pending + 1
    end
  end
  
  return {
    passes = passes,
    failures = failures,
    pending = pending,
    total = passes + failures + pending
  }
end

-- Enable debug mode
local DEBUG = false

-- Run a single test file with isolated environment
local function run_test_file(file_path)
  print("\nRunning test: " .. file_path)
  print(string.rep("-", 50))
  
  -- Reset lust_next state and stats before running tests
  lust_next.reset()
  
  -- Reset the test stats for this file
  local file_name = file_path:match("([^/\\]+)%.lua$") or file_path
  lust_next.test_stats.by_file[file_name] = {
    total = 0,
    passes = 0,
    failures = 0,
    pending = 0,
    file_path = file_path
  }
  
  -- Capture all output to count test results
  local original_print = print
  local captured_output = {}
  
  -- Override print to capture output
  _G.print = function(...)
    local args = {...}
    local line = ""
    for i, v in ipairs(args) do
      line = line .. tostring(v)
      if i < #args then line = line .. "\t" end
    end
    
    -- Check if this line has a test result marker and log for debugging
    if DEBUG then
      if line:match(".*%[32mPASS%[0m") then
        original_print("DEBUG: Found PASS result in: " .. line)
      elseif line:match(".*%[31mFAIL%[0m") then 
        original_print("DEBUG: Found FAIL result in: " .. line)
      elseif line:match(".*%[33mPENDING:%[0m") then
        original_print("DEBUG: Found PENDING result in: " .. line)
      end
    end
    
    table.insert(captured_output, line)
    original_print(...)
  end
  
  -- Run the test in isolated environment
  local success, result = pcall(function()
    -- Reset lust_next state before each test file
    lust_next.reset()
    
    -- Load and execute the test file
    local chunk, err = loadfile(file_path)
    if not chunk then
      error("Error loading file: " .. tostring(err), 2)
    end
    
    return chunk()
  end)
  
  -- Restore original print function
  _G.print = original_print
  
  -- Combine captured output
  local output = table.concat(captured_output, "\n")
  
  -- Extract test counts from output
  local counts = extract_test_counts(output)
  
  return {
    success = success,
    result = result,
    output = output,
    counts = counts,
    file_path = file_path,
    file_name = file_path:match("([^/\\]+)%.lua$") or file_path
  }
end

-- Get all test files
local test_files = get_test_files()
if #test_files == 0 then
  print("No test files found in tests/ directory!")
  os.exit(1)
end

-- Run all test files and collect results
local test_results = {}
local passed_files = 0
local failed_files = 0
local total_passes = 0
local total_failures = 0
local total_pending = 0

for _, file_path in ipairs(test_files) do
  local result = run_test_file(file_path)
  
  -- Store results
  test_results[#test_results + 1] = result
  
  -- Update totals
  total_passes = total_passes + result.counts.passes
  total_failures = total_failures + result.counts.failures
  total_pending = total_pending + result.counts.pending
  
  -- Track file success/failure
  if result.success and (result.result == nil or result.result == true) then
    passed_files = passed_files + 1
  else
    failed_files = failed_files + 1
  end
end

local total_tests = total_passes + total_failures + total_pending

-- Print summary
print("\n" .. string.rep("-", 70))
print("Test Summary")
print(string.rep("-", 70))

-- File summary
print("Test files:")
print("  Total files: " .. #test_files)
print("  Passed files: " .. passed_files)
print("  Failed files: " .. failed_files)

-- Detailed results
print("\nDetailed test results by file:")
print(string.rep("-", 70))
print(string.format("%-40s %10s %10s %10s %10s", "Test File", "Total", "Passed", "Failed", "Pending"))
print(string.rep("-", 70))

-- Convert by_file table to array for sorting
local file_results = {}
for file_name, stats in pairs(lust_next.test_stats.by_file) do
  table.insert(file_results, {
    file_name = file_name,
    stats = stats
  })
end

-- Sort results by file name for readability
table.sort(file_results, function(a, b) return a.file_name < b.file_name end)

-- Print each file's results
for _, result in ipairs(file_results) do
  local stats = result.stats
  local status_indicator = " "
  
  -- Add colored status indicators
  if stats.failures > 0 then
    status_indicator = "\27[31m✗\27[0m" -- Red X for failures
  elseif stats.passes > 0 and stats.failures == 0 then
    status_indicator = "\27[32m✓\27[0m" -- Green check for passes
  elseif stats.pending > 0 then
    status_indicator = "\27[33m⚠\27[0m" -- Yellow warning for pending tests
  elseif stats.total == 0 then
    status_indicator = "\27[34m•\27[0m" -- Blue dot for zero tests
  end
  
  print(string.format("%s %-38s %10d %10d %10d %10d", 
    status_indicator,
    result.file_name,
    stats.total,
    stats.passes,
    stats.failures,
    stats.pending
  ))
end

-- Print totals row
print(string.rep("-", 70))
print(string.format("%-40s %10d %10d %10d %10d", 
  "TOTAL",
  lust_next.test_stats.total,
  lust_next.test_stats.passes,
  lust_next.test_stats.failures,
  lust_next.test_stats.pending
))

-- Test assertions summary
print("\nTest assertions:")
if lust_next.test_stats.total > 0 then
  print("  Total assertions: " .. lust_next.test_stats.total)
  print("  Passed: " .. lust_next.test_stats.passes .. " (" .. string.format("%.1f%%", lust_next.test_stats.passes / lust_next.test_stats.total * 100) .. ")")
  print("  Failed: " .. lust_next.test_stats.failures)
  print("  Pending: " .. lust_next.test_stats.pending)
else
  print("  No assertions detected in tests")
end

-- Print failed files if any
if failed_files > 0 then
  print("\nFailed tests:")
  for _, result in ipairs(test_results) do
    if not result.success or (result.result ~= nil and result.result ~= true) then
      print("  - " .. result.file_path)
      if not result.success then
        print("    Error: " .. tostring(result.result))
      end
    end
  end
  os.exit(1)
else
  print("\n✅ ALL TESTS PASSED")
  os.exit(0)
end