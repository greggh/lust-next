-- Test script to verify test summary reporting in runner.lua
local fs = require("lib.tools.filesystem")
local test_dir = "/tmp/firmo_test_summary_check"

-- Helper function to capture command output
local function capture_output(command)
  local temp_file = os.tmpname()
  local full_command = command .. " > " .. temp_file .. " 2>&1"
  local success = os.execute(full_command)
  
  local file = io.open(temp_file, "r")
  local output = file:read("*all")
  file:close()
  
  os.remove(temp_file)
  return output, success
end

-- Create test directory
fs.create_directory(test_dir)

-- Create test files with known outcomes
local passing_test = [[
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Passing Test File", function()
  it("should pass this test", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("should also pass this test", function()
    expect("test").to.be.a("string")
  end)
end)
]]

local failing_test = [[
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Failing Test File", function()
  it("should pass this test", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("should fail this test", function()
    expect(1 + 1).to.equal(3) -- This will fail
  end)
end)
]]

local mixed_test = [[
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Mixed Test File", function()
  it("should pass this test", function()
    expect(1 + 1).to.equal(2)
  end)
  
  it("should fail this test", function()
    expect(1 + 1).to.equal(3) -- This will fail
  end)
  
  it("should pass another test", function()
    expect(true).to.be_truthy()
  end)
end)
]]

-- Write test files
fs.write_file(test_dir .. "/passing_test.lua", passing_test)
fs.write_file(test_dir .. "/failing_test.lua", failing_test)
fs.write_file(test_dir .. "/mixed_test.lua", mixed_test)

-- Run test files and capture output
print("Running tests and analyzing summary output...")

-- Run passing test file
print("\nRunning passing test file:")
local passing_output = capture_output("env -C /home/gregg/Projects/lua-library/firmo lua test.lua " .. test_dir .. "/passing_test.lua")
print("Output summary (truncated):")
print(passing_output:sub(-500))  -- Just show the last part with summary

-- Run failing test file
print("\nRunning failing test file:")
local failing_output = capture_output("env -C /home/gregg/Projects/lua-library/firmo lua test.lua " .. test_dir .. "/failing_test.lua")
print("Output summary (truncated):")
print(failing_output:sub(-500))  -- Just show the last part with summary

-- Run mixed test file
print("\nRunning mixed test file:")
local mixed_output = capture_output("env -C /home/gregg/Projects/lua-library/firmo lua test.lua " .. test_dir .. "/mixed_test.lua")
print("Output summary (truncated):")
print(mixed_output:sub(-500))  -- Just show the last part with summary

-- Run all test files
print("\nRunning all test files:")
local all_output = capture_output("env -C /home/gregg/Projects/lua-library/firmo lua test.lua " .. test_dir)
print("Output summary (truncated):")
print(all_output:sub(-500))  -- Just show the last part with summary

-- Analyze summary information
print("\nAnalysis of test summaries:")

-- Helper function to extract summary information
local function extract_summary(output)
  local files_passed = output:match("files_passed[= ]*(%d+)")
  local files_failed = output:match("files_failed[= ]*(%d+)")
  local tests_passed = output:match("tests_passed[= ]*(%d+)")
  local tests_failed = output:match("tests_failed[= ]*(%d+)")
  local passes = output:match("passes[= ]*(%d+)")
  local failures = output:match("failures[= ]*(%d+)")
  
  return {
    files_passed = tonumber(files_passed) or 0,
    files_failed = tonumber(files_failed) or 0,
    tests_passed = tonumber(tests_passed) or 0,
    tests_failed = tonumber(tests_failed) or 0,
    passes = tonumber(passes) or 0,
    failures = tonumber(failures) or 0
  }
end

local passing_summary = extract_summary(passing_output)
local failing_summary = extract_summary(failing_output)
local mixed_summary = extract_summary(mixed_output)
local all_summary = extract_summary(all_output)

print("Passing file summary:")
print("  - Files passed: " .. (passing_summary.files_passed or "N/A"))
print("  - Tests passed: " .. (passing_summary.tests_passed or "N/A"))
print("  - Passes: " .. (passing_summary.passes or "N/A"))

print("\nFailing file summary:")
print("  - Files failed: " .. (failing_summary.files_failed or "N/A"))
print("  - Tests failed: " .. (failing_summary.tests_failed or "N/A"))
print("  - Failures: " .. (failing_summary.failures or "N/A"))

print("\nMixed file summary:")
print("  - Files failed: " .. (mixed_summary.files_failed or "N/A"))
print("  - Tests failed: " .. (mixed_summary.tests_failed or "N/A"))
print("  - Failures: " .. (mixed_summary.failures or "N/A"))
print("  - Passes: " .. (mixed_summary.passes or "N/A"))

print("\nAll files summary:")
print("  - Files passed: " .. (all_summary.files_passed or "N/A"))
print("  - Files failed: " .. (all_summary.files_failed or "N/A"))
print("  - Tests passed: " .. (all_summary.tests_passed or "N/A"))
print("  - Tests failed: " .. (all_summary.tests_failed or "N/A"))
print("  - Passes: " .. (all_summary.passes or "N/A"))
print("  - Failures: " .. (all_summary.failures or "N/A"))

-- Check for inconsistencies
print("\nChecking for inconsistencies in summary reporting:")

local function check_inconsistency(summary)
  if summary.passes ~= summary.tests_passed and summary.tests_passed then
    print("  - Inconsistency detected: passes (" .. summary.passes .. ") doesn't match tests_passed (" .. summary.tests_passed .. ")")
  end
  
  if summary.failures ~= summary.tests_failed and summary.tests_failed then
    print("  - Inconsistency detected: failures (" .. summary.failures .. ") doesn't match tests_failed (" .. summary.tests_failed .. ")")
  end
end

check_inconsistency(passing_summary)
check_inconsistency(failing_summary)
check_inconsistency(mixed_summary)
check_inconsistency(all_summary)

-- Clean up
print("\nCleaning up test files...")
fs.delete_file(test_dir .. "/passing_test.lua")
fs.delete_file(test_dir .. "/failing_test.lua")
fs.delete_file(test_dir .. "/mixed_test.lua")
fs.delete_directory(test_dir)

print("Done.")