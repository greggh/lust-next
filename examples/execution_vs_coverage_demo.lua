--[[
  execution_vs_coverage_demo.lua
  
  Demonstration of the distinction between code execution and coverage validation.
  This example clearly shows the difference between code that:
  1. Is executed but not validated by tests (execution)
  2. Is executed and validated by tests (coverage)
  3. Is never executed at all
]]

local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Import the coverage module
local coverage = require("lib.coverage")

-- Function with different execution paths
local function calculate(a, b, operation)
  -- This line will be covered (executed and validated)
  if not a or not b then
    return nil, "Missing operands"
  end
  
  -- This line will be covered
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, "Operands must be numbers"
  end
  
  -- This block will be executed but not covered (no assertions for the result)
  if operation == "add" then
    return a + b
  end
  
  -- This block will be covered (executed and validated)
  if operation == "subtract" then
    return a - b
  end
  
  -- This block will not be executed at all
  if operation == "multiply" then
    return a * b
  end
  
  -- This block will not be executed
  if operation == "divide" then
    if b == 0 then
      return nil, "Division by zero"
    end
    return a / b
  end
  
  -- This return statement will be executed but not covered
  return nil, "Unsupported operation"
end

-- Start coverage tracking
coverage.start({
  include_patterns = {".*"}
})

-- Explicitly track this file to ensure it's included
local current_file = debug.getinfo(1, "S").source:sub(2) -- Get current file path
coverage.track_file(current_file)

-- Test suite that will demonstrate execution vs. coverage distinction
describe("Execution vs. Coverage Demo", function()
  it("validates proper error for missing operands", function()
    local result, err = calculate(nil, 5, "add")
    expect(result).to_not.exist()
    expect(err).to.equal("Missing operands")
  end)
  
  it("validates proper error for non-number operands", function()
    local result, err = calculate("string", 5, "add")
    expect(result).to_not.exist()
    expect(err).to.equal("Operands must be numbers")
  end)
  
  it("executes addition without validating the result", function()
    -- This test EXECUTES the addition but doesn't VALIDATE the result
    -- The add operation code path will be marked as executed but NOT covered
    local result = calculate(5, 3, "add")
    -- Intentionally missing assertions for the result
  end)
  
  it("validates subtraction result", function()
    -- This test both EXECUTES AND VALIDATES the subtraction
    -- The subtract operation code path will be marked as both executed AND covered
    local result = calculate(10, 4, "subtract")
    expect(result).to.equal(6)
  end)
  
  -- No tests for multiply or divide operations
  -- Those blocks will not be executed at all
end)

-- Stop coverage tracking
coverage.stop()

-- Generate an HTML coverage report
print("\nGenerating HTML coverage report...\n")
local report_data = coverage.get_report_data()

-- Print details about the coverage data for debugging
print("Coverage summary:")
print(string.format("  Total files: %d", report_data.summary.total_files))
print(string.format("  Covered files: %d", report_data.summary.covered_files))
print(string.format("  Total lines: %d", report_data.summary.total_lines))
print(string.format("  Covered lines: %d", report_data.summary.covered_lines))
print(string.format("  Executed lines: %d", report_data.summary.executed_lines))

print("\nFiles in report data:")
local file_count = 0
for file_path, _ in pairs(report_data.files) do
  file_count = file_count + 1
  print("  " .. file_count .. ": " .. file_path)
end

if file_count == 0 then
  print("  No files in report data! Adding current file explicitly...")
  local current_file = debug.getinfo(1, "S").source:sub(2)
  report_data.files[current_file] = {
    source = "-- File content not available",
    lines = {},
    total_lines = 0,
    covered_lines = 0,
    line_coverage_percent = 0
  }
  report_data.summary.total_files = 1
end

local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

-- Format the coverage data as HTML
local html_report = reporting.format_coverage(report_data, "html")

-- Save the HTML report to a file
local report_dir = "examples/reports/coverage-reports"
fs.ensure_directory_exists(report_dir)
local report_path = fs.join_paths(report_dir, "execution_vs_coverage_demo.html")
fs.write_file(report_path, html_report)

print(string.format("HTML coverage report saved to: %s", report_path))
print(string.format("Open this file in your web browser to see the enhanced visualization"))
print("\nCode states demonstrated in this example:")
print("1. Covered lines: Executed AND validated by test assertions")
print("2. Executed-not-covered lines: Executed but NOT validated by test assertions")
print("3. Uncovered lines: Not executed at all during tests")
print("4. Non-executable lines: Comments and other non-code lines")