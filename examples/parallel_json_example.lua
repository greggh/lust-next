-- Parallel JSON Output Example
-- Shows how lust-next can use JSON output for parallel test execution

-- Import the testing framework
local lust = require "../lust-next"

-- Create multiple test files
local function write_test_file(name, pass, fail, skip)
  local file_path = os.tmpname() .. ".lua"
  local file = io.open(file_path, "w")
  if not file then
    error("Failed to create test file: " .. file_path)
  end
  
  local content = [[
-- Test file: ]] .. name .. [[

local lust = require "lust-next"
local describe, it, expect = lust.describe, lust.it, lust.expect

describe("]] .. name .. [[", function()
]]

  -- Add passing tests
  for i = 1, pass do
    content = content .. [[
  it("should pass test ]] .. i .. [[", function()
    expect(]] .. i .. [[ + ]] .. i .. [[).to.equal(]] .. (i + i) .. [[)
  end)
]]
  end
  
  -- Add failing tests
  for i = 1, fail do
    content = content .. [[
  it("should fail test ]] .. i .. [[", function()
    expect(]] .. i .. [[).to.equal(]] .. (i + 1) .. [[)
  end)
]]
  end
  
  -- Add skipped tests
  for i = 1, skip do
    content = content .. [[
  it("should skip test ]] .. i .. [[", function()
    lust.pending("Skipped for example")
  end)
]]
  end
  
  content = content .. [[
end)
]]
  
  file:write(content)
  file:close()
  
  return file_path
end

-- Create 3 test files with different passing/failing/skipping patterns
local test_files = {
  write_test_file("Test1", 3, 1, 1),  -- 3 pass, 1 fail, 1 skip
  write_test_file("Test2", 5, 0, 0),  -- 5 pass, 0 fail, 0 skip
  write_test_file("Test3", 2, 2, 1)   -- 2 pass, 2 fail, 1 skip
}

print("Created test files:")
for i, file in ipairs(test_files) do
  print("  " .. i .. ". " .. file)
end

-- Run the tests in parallel
local parallel = require "lib.tools.parallel"
parallel.register_with_lust(lust)

local results = parallel.run_tests(test_files, {
  workers = 2,
  verbose = true,
  show_worker_output = true,
  results_format = "json"  -- Enable JSON output
})

-- Clean up the test files
for _, file in ipairs(test_files) do
  os.remove(file)
end

-- Manually count the results from test outputs
local total_tests = 0
local passed_tests = 0
local failed_tests = 0
local skipped_tests = 0

-- Function to count tests manually from output (for verification)
local function count_tests_from_output(output)
  local tests = 0
  local passes = 0 
  local fails = 0
  local skips = 0
  
  -- Remove ANSI color codes for better pattern matching
  output = output:gsub("\027%[[^m]*m", "")
  
  for line in output:gmatch("[^\r\n]+") do
    if line:match("PASS%s+should") then
      passes = passes + 1
      tests = tests + 1
    elseif line:match("FAIL%s+should") then
      fails = fails + 1
      tests = tests + 1
    elseif line:match("SKIP%s+should") or line:match("PENDING:%s+") then
      skips = skips + 1
      tests = tests + 1
    end
  end
  
  return tests, passes, fails, skips
end

-- Verify our parallel execution results by manually counting tests
for _, worker_output in ipairs(results.worker_outputs or {}) do
  local tests, passes, fails, skips = count_tests_from_output(worker_output)
  total_tests = total_tests + tests
  passed_tests = passed_tests + passes
  failed_tests = failed_tests + fails
  skipped_tests = skipped_tests + skips
end

-- Output the aggregated results
print("\nParallel Test Results:")
print("  Total tests: " .. (results.passed + results.failed + results.skipped))
print("  Passed: " .. results.passed)
print("  Failed: " .. results.failed)
print("  Skipped: " .. results.skipped)
print("  Total time: " .. string.format("%.2f", results.elapsed) .. " seconds")

-- Show verification results
print("\nVerification (manually counted):")
print("  Total tests: " .. total_tests)
print("  Passed: " .. passed_tests)
print("  Failed: " .. failed_tests)
print("  Skipped: " .. skipped_tests)

-- Return success status
return results.failed == 0