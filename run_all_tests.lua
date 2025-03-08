#!/usr/bin/env lua
-- Comprehensive test runner for lust-next
-- Tests all modules and features

print("lust-next Comprehensive Test Runner")
print("----------------------------------")
print("")

-- Utility functions
local function print_separator()
  print(string.rep("-", 50))
end

local function run_test(test_file, description)
  print_separator()
  print("Running " .. description .. ": " .. test_file)
  print_separator()
  
  -- Execute the test file
  local command = "lua " .. test_file
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  
  -- Print the result
  print(result)
  
  return result:match("All tests passed!") ~= nil
end

local function run_example(example_file, description)
  print_separator()
  print("Running " .. description .. ": " .. example_file)
  print_separator()
  
  -- Execute the example file
  local command = "lua " .. example_file
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  
  -- Print the result
  print(result)
  
  return true -- Examples don't typically report pass/fail
end

-- Define test categories
local core_tests = {
  {file = "tests/lust_test.lua", desc = "Core Functionality Test"},
  {file = "tests/assertions_test.lua", desc = "Assertions Test"},
  {file = "tests/mocking_test.lua", desc = "Mocking Test"},
  {file = "tests/discovery_test.lua", desc = "Test Discovery Test"},
  {file = "tests/tagging_test.lua", desc = "Test Tagging Test"},
  {file = "tests/async_test.lua", desc = "Async Testing Test"},
  {file = "tests/reporting_test.lua", desc = "Reporting Test"},
  {file = "tests/quality_test.lua", desc = "Quality Module Test"},
  {file = "tests/codefix_test.lua", desc = "Codefix Module Test"}
}

local examples = {
  {file = "examples/basic_example.lua", desc = "Basic Example"},
  {file = "examples/assertions_example.lua", desc = "Assertions Example"},
  {file = "examples/mocking_example.lua", desc = "Mocking Example"},
  {file = "examples/enhanced_mocking_example.lua", desc = "Enhanced Mocking Example"},
  {file = "examples/mock_sequence_example.lua", desc = "Mock Sequence Example"},
  {file = "examples/tagging_example.lua", desc = "Tagging Example"},
  {file = "examples/focused_tests_example.lua", desc = "Focused Tests Example"},
  {file = "examples/async_example.lua", desc = "Async Example"},
  {file = "examples/coverage_example.lua", desc = "Coverage Example"},
  {file = "examples/quality_example.lua", desc = "Quality Validation Example"},
  {file = "examples/report_example.lua", desc = "Reporting Example"},
  {file = "examples/codefix_example.lua", desc = "Codefix Example"},
}

-- Run all core tests
print("Running Core Tests...")
local all_passed = true
local failed_tests = {}

for _, test in ipairs(core_tests) do
  local success = run_test(test.file, test.desc)
  all_passed = all_passed and success
  
  if not success then
    table.insert(failed_tests, test.file)
  end
end

-- Run all examples
print("\nRunning Examples...")
for _, example in ipairs(examples) do
  run_example(example.file, example.desc)
end

-- Print summary
print_separator()
print("Test Summary")
print_separator()

if all_passed then
  print("✅ ALL TESTS PASSED!")
else
  print("❌ SOME TESTS FAILED:")
  for _, test in ipairs(failed_tests) do
    print("  - " .. test)
  end
end

-- Exit with appropriate code
os.exit(all_passed and 0 or 1)