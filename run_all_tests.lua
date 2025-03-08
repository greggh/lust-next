#!/usr/bin/env lua
-- Enhanced test runner for lust-next that runs individual test files
-- properly handling module isolation to prevent cross-test interference

local lust_next = require("lust-next")

print("lust-next Test Runner")
print("--------------------")
print("")

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

-- Run a single test file and return its result
local function run_test_file(file_path)
  print("\nRunning test: " .. file_path)
  print(string.rep("-", 50))
  
  -- Create a clean environment for each test
  local success, result
  success, result = pcall(function()
    -- Before running each test file, reset the lust_next state
    -- This is critical to prevent tests from affecting each other
    lust_next.reset()
    
    -- Load the file and execute it
    local chunk, err = loadfile(file_path)
    if not chunk then
      error("Error loading file: " .. tostring(err), 2)
    end
    
    -- Execute the chunk with lust_next in its environment
    return chunk()
  end)
  
  -- Return the result of running the test
  return success, result
end

-- Get all test files
local test_files = get_test_files()
if #test_files == 0 then
  print("No test files found in tests/ directory!")
  os.exit(1)
end

-- Run each test file
local passed = 0
local failed = 0
local failed_tests = {}

for _, file_path in ipairs(test_files) do
  local success, result = run_test_file(file_path)
  
  if success and (result == nil or result == true) then
    passed = passed + 1
  else
    failed = failed + 1
    table.insert(failed_tests, {
      file = file_path,
      error = not success and tostring(result) or "Test returned false"
    })
  end
end

-- Print summary
print("\n" .. string.rep("-", 50))
print("Test Summary")
print(string.rep("-", 50))
print("Total tests: " .. #test_files)
print("Passed: " .. passed)
print("Failed: " .. failed)

if failed > 0 then
  print("\nFailed tests:")
  for _, test in ipairs(failed_tests) do
    print("  - " .. test.file)
    if test.error then
      print("    Error: " .. test.error)
    end
  end
  os.exit(1)
else
  print("\n✅ ALL TESTS PASSED")
  os.exit(0)
end